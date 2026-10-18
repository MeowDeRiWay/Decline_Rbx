-- Keep live Chest instances (and ChestService storage) when replacing a building.
local Service = {}
local function chests(building)
 local result = {}
 if building then
  for _, object in ipairs(building:GetDescendants()) do
   if object:IsA("Model") and object.Name == "Chest" then table.insert(result, object) end
  end
 end
 return result
end
function Service.PrepareUpgrade(previous, replacement)
 local old, new = chests(previous), chests(replacement)
 local moves, used = {}, {}
 for _, chest in ipairs(old) do
  local target
  local id = chest:GetAttribute("StorageID")
  for _, candidate in ipairs(new) do
   if not used[candidate] and ((#old == 1 and #new == 1) or (id ~= nil and candidate:GetAttribute("StorageID") == id)) then
    if target then return nil, "Upgrade cancelled: duplicate chest StorageID." end
    target = candidate
   end
  end
  if not target then return nil, "Upgrade cancelled: the new building needs a matching Chest (StorageID for multiple chests)." end
  used[target] = true
  table.insert(moves, {Chest = chest, Target = target})
 end
 return function()
  for _, move in ipairs(moves) do
   local chest, target = move.Chest, move.Target
   chest:PivotTo(target:GetPivot())
   chest.Parent = target.Parent
   target:Destroy()
  end
 end
end
return Service
