-- Preserve live storage models when a building is upgraded.
local Service={}
local function containers(building,kind)
 local result={}
 if building then
  for _,object in ipairs(building:GetDescendants()) do
   if object:IsA("Model") and ((kind=="Chest" and object.Name=="Chest") or (kind=="TradePost" and (object.Name=="TradePost" or object:GetAttribute("TradePost")==true))) then table.insert(result,object) end
  end
 end
 return result
end
function Service.CanDestroy(building)
 for _,post in ipairs(containers(building,"TradePost")) do
  if (post:GetAttribute("TradeOwnerID") or 0)>0 or post:GetAttribute("TradeInherited") or post:GetAttribute("TradeHasStock") then return false end
 end
 return true
end
function Service.PrepareUpgrade(previous,replacement)
 local moves,used={},{}
 for _,kind in ipairs({"Chest","TradePost"}) do
  local old,new=containers(previous,kind),containers(replacement,kind)
  local key=kind=="Chest" and "StorageID" or "TradePostID"
  for _,container in ipairs(old) do
   local target
   local id=container:GetAttribute(key)
   for _,candidate in ipairs(new) do
    if not used[candidate] and ((#old==1 and #new==1) or (id~=nil and candidate:GetAttribute(key)==id)) then
     if target then return nil,"Upgrade cancelled: duplicate "..kind.." "..key.."." end
     target=candidate
    end
   end
   if not target then return nil,"Upgrade cancelled: the new building needs a matching "..kind.." ("..key.." for multiple containers)." end
   used[target]=true;table.insert(moves,{Container=container,Target=target})
  end
 end
 return function()
  for _,move in ipairs(moves) do
   move.Container:PivotTo(move.Target:GetPivot());move.Container.Parent=move.Target.Parent;move.Target:Destroy()
  end
 end
end
return Service
