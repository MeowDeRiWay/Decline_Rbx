local Rules = {}
Rules.DefaultLimit = 3
Rules.WakeRadius = 300 -- studs from the home footprint, not its center
Rules.BucketSize = 256
Rules.HomesPerBatch = 16
Rules.SpawnsPerStep = 2
Rules.SpawnAttemptsPerFrame = 8
function Rules.Near(frame,size,position,radius)
 local point=frame:PointToObjectSpace(position)
 local x=math.max(0,math.abs(point.X)-size.X/2)
 local z=math.max(0,math.abs(point.Z)-size.Z/2)
 return x*x+z*z<=radius*radius
end
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
function Rules.Count(floor, creatures, world, dormant)
 local candidates=table.clone(creatures:GetChildren())
 for _,zombie in ipairs(dormant or {}) do table.insert(candidates,zombie) end
 local house, count = Rules.House(floor), 0
 for _, zombie in ipairs(candidates) do
  local reference = zombie:FindFirstChild("ZombieHome")
  local humanoid = zombie:FindFirstChildOfClass("Humanoid")
  if reference and reference:IsA("ObjectValue") and reference.Value and humanoid and humanoid.Health > 0
   and (zombie:IsDescendantOf(world) or table.find(dormant or {},zombie)) and not zombie:GetAttribute("IsDead") and not zombie:GetAttribute("IsCorpse")
   and Rules.House(reference.Value) == house then count += 1 end
 end
 return count
end
return Rules
