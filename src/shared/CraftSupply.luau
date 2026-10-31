-- Pure pooled inventory and reservation operations. No yielding is allowed
-- between checking stock and reserving it, so shared chests cannot double-spend.
local Inventory=require(script.Parent.InventoryRules)
local Supply={}
function Supply.Pool(sources,definitions)
 local items,tools={},{}
 local function tool(id,condition)
  local item=definitions[id]
  if item and item.CraftTool and (not item.Weapon or (condition or item.Weapon.MaxUses or 0)>0) then
   tools[item.CraftTool]=math.max(tools[item.CraftTool] or 0,item.CraftSpeed or 1)
  end
 end
 for _,source in ipairs(sources) do
  local state=source.State
  for id,count in pairs(state.Items) do
   if definitions[id] and count>0 then
    items[id]=(items[id] or 0)+count
    if definitions[id].Weapon then
     for _,condition in ipairs(state.Conditions[id] or {}) do tool(id,condition) end
    else tool(id) end
   end
  end
  for slot,id in pairs(state.Equipment or {}) do tool(id,(state.EquipmentCondition or {})[slot]) end
 end
 return items,tools
end
function Supply.Refund(cycles,first,definitions,target)
 for index=first,#cycles do
  local cycle=cycles[index]
  for _,receipt in ipairs(cycle.Receipts or {}) do
   local state=target and target(receipt.Source) or receipt.Source.State
   assert(Inventory.Add(state,definitions,receipt.ID,receipt.Count,receipt.Conditions,receipt.Weapons))
  end
  cycle.Receipts=nil
 end
end
function Supply.Reserve(cycles,sources,definitions)
 for _,cycle in ipairs(cycles) do
  cycle.Receipts={}
  for id,count in pairs(cycle.Ingredients) do
   local remaining=count
   for _,source in ipairs(sources) do
    local amount=math.min(remaining,source.State.Items[id] or 0)
    if amount>0 then
     local ok,conditions,weapons=Inventory.Remove(source.State,id,amount)
     if not ok then Supply.Refund(cycles,1,definitions);return false end
     table.insert(cycle.Receipts,{Source=source,ID=id,Count=amount,Conditions=conditions,Weapons=weapons})
     remaining-=amount
    end
    if remaining==0 then break end
   end
   if remaining>0 then Supply.Refund(cycles,1,definitions);return false end
  end
 end
 return true
end
return Supply
