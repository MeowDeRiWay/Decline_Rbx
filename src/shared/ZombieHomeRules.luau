local Rules = {}
Rules.DefaultLimit = 3
function Rules.House(floor)
 local parent = floor
 while parent do
  if parent:IsA("Model") and parent:GetAttribute("ZHouse") == true then return parent end
  parent = parent.Parent
 end
 return floor
end
function Rules.Limit(floor)
 local house = Rules.House(floor)
 local value = house:GetAttribute("ZNumber")
 if value == nil then value = floor:GetAttribute("ZNumber") end
 if typeof(value) ~= "number" or value ~= value or math.abs(value) == math.huge then return Rules.DefaultLimit end
 return math.max(0, math.floor(value))
end
function Rules.Count(floor, creatures, world)
 local house, count = Rules.House(floor), 0
 for _, zombie in ipairs(creatures:GetChildren()) do
  local reference = zombie:FindFirstChild("ZombieHome")
  local humanoid = zombie:FindFirstChildOfClass("Humanoid")
  if reference and reference:IsA("ObjectValue") and reference.Value and humanoid and humanoid.Health > 0
   and zombie:IsDescendantOf(world) and not zombie:GetAttribute("IsDead") and not zombie:GetAttribute("IsCorpse")
   and Rules.House(reference.Value) == house then count += 1 end
 end
 return count
end
return Rules
