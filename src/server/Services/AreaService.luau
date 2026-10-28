local Players = game:GetService("Players")
local Area = {}
function Area.Parts(model)
 local result = {}
 for _,part in ipairs(model:GetDescendants()) do
  if part:IsA("BasePart") then table.insert(result,part) end
 end
 return result
end
function Area.Contains(part, position, margin)
 local point = part.CFrame:PointToObjectSpace(position)
 return math.abs(point.X) <= part.Size.X/2 + (margin or 0) and math.abs(point.Z) <= part.Size.Z/2 + (margin or 0)
end
function Area.Occupied(home,surfaces,subjects)
 surfaces=surfaces or Area.Parts(home)
 if not subjects then
  subjects={}
  for _,player in ipairs(Players:GetPlayers()) do
   local character=player.Character
   local root=character and character:FindFirstChild("HumanoidRootPart")
   local humanoid=character and character:FindFirstChildOfClass("Humanoid")
   if root and humanoid and humanoid.Health>0 then table.insert(subjects,{Root=root,Humanoid=humanoid}) end
  end
 end
 for _,subject in ipairs(subjects) do
  local root,humanoid=subject.Root,subject.Humanoid
  local feet=root.Position-Vector3.new(0,root.Size.Y/2+humanoid.HipHeight,0)
  for _,part in ipairs(surfaces) do
   local point=part.CFrame:PointToObjectSpace(feet)
   local above=point.Y-part.Size.Y/2
   if math.abs(point.X)<=part.Size.X/2 and math.abs(point.Z)<=part.Size.Z/2 and above>=-.5 and above<=.5 then return true end
  end
 end
 return false
end
return Area
