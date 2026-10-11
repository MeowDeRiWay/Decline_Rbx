-- Only prepares user-authored models; no dummy geometry is generated.
local registered = setmetatable({},{__mode="k"})
local function prepare(model)
 if not model:IsA("Model") or model.Name ~= "Mannikin" or registered[model] then return end
 local part = model:FindFirstChildWhichIsA("BasePart",true)
 if not part then return end
 registered[model] = true
 local humanoid = model:FindFirstChildOfClass("Humanoid") or Instance.new("Humanoid")
 humanoid.RequiresNeck = false
 humanoid.BreakJointsOnDeath = false
 humanoid.WalkSpeed = 0
 humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
 local health = model:GetAttribute("MaxHealth")
 if typeof(health) ~= "number" or health ~= health or health <= 0 or health == math.huge then health = 100 end
 humanoid.MaxHealth = health
 humanoid.Health = health
 humanoid.Parent = model
 for _,object in ipairs(model:GetDescendants()) do
  if object:IsA("BasePart") then object.Anchored = true; object.CanQuery = true end
 end
 model:SetAttribute("Health",health)
 model:SetAttribute("MaxHealth",health)
end
for _,object in ipairs(workspace:GetDescendants()) do prepare(object) end
workspace.DescendantAdded:Connect(function(object)
 if object:IsA("Model") then task.defer(prepare,object)
 elseif object:IsA("BasePart") then
  local ancestor = object:FindFirstAncestorOfClass("Model")
  if ancestor then task.defer(prepare,ancestor) end
 end
end)
