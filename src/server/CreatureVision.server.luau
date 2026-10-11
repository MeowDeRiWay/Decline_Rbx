-- Model-level sight blocking is independent of physical collision.
local function prepare(model)
 if not model or not model:IsA("Model") then return end
 if model.Name ~= "Mannikin" and not model:FindFirstChildOfClass("Humanoid") then return end
 -- Keep explicit Studio settings; all new creatures block vision by default.
 if model:GetAttribute("BlocksVision") == nil then model:SetAttribute("BlocksVision",true) end
 for _,part in ipairs(model:GetDescendants()) do
  if part:IsA("BasePart") then part.CanQuery = true end
 end
end
for _,object in ipairs(workspace:GetDescendants()) do
 if object:IsA("Model") then prepare(object) end
end
workspace.DescendantAdded:Connect(function(object)
 if object:IsA("Model") then task.defer(prepare,object)
 elseif object:IsA("Humanoid") then prepare(object.Parent)
 elseif object:IsA("BasePart") then
  local ancestor = object.Parent
  while ancestor and ancestor ~= workspace do
   if ancestor:IsA("Model") and (ancestor.Name == "Mannikin" or ancestor:FindFirstChildOfClass("Humanoid")) then
    object.CanQuery = true
    break
   end
   ancestor = ancestor.Parent
  end
 end
end)
