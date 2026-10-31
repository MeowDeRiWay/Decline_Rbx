-- Prepare both pocket inventories before committing either side. Equipment is
-- deliberately excluded, and received goods cannot fund the outgoing offer.
local Inventory=require(script.Parent.InventoryRules)
local Rules={MaxStacks=40,Distance=5,InviteSeconds=30,SessionSeconds=180,ConfirmDelay=2}
local function copy(state)
 local result=table.clone(state)
 result.Items=table.clone(state.Items);result.Conditions={};result.Weapons={}
 for id,list in pairs(state.Conditions or {}) do result.Conditions[id]=table.clone(list) end
 for id,list in pairs(state.Weapons or {}) do
  result.Weapons[id]={}
  for i,data in ipairs(list) do result.Weapons[id][i]=table.clone(data) end
 end
 return result
end
function Rules.Stage(a,b,definitions,offerA,offerB)
 local left,right=copy(a),copy(b)
 local removed={}
 for index,offer in ipairs({offerA,offerB}) do
  local source=index==1 and left or right
  local entries=0
  for key,entry in pairs(offer) do
   entries+=1
   if entries>Rules.MaxStacks or type(entry)~="table" or key~=entry.Key or type(key)~="string" or type(entry.ID)~="string" then return nil end
   local item=definitions[entry.ID]
   if not item or item.Lootable==false or item.Currency then return nil end
   local ok,conditions,data=Inventory.Remove(source,entry.ID,entry.Count,key)
   if not ok then return nil end
   table.insert(removed,{Target=index==1 and right or left,ID=entry.ID,Count=entry.Count,Conditions=conditions,Data=data})
  end
 end
 for _,entry in ipairs(removed) do
  if not Inventory.Add(entry.Target,definitions,entry.ID,entry.Count,entry.Conditions,entry.Data) then return nil end
 end
 return left,right
end
return Rules
