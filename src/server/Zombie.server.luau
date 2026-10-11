-- Passive zombies for the first map test. The model geometry is authored in Studio.
local registered = setmetatable({},{__mode="k"})
local function positive(value)
 return typeof(value) == "number" and value == value and value > 0 and value < math.huge
end
local function prepare(model)
 if not model:IsA("Model") or registered[model] then return end
 if model.Name ~= "Zombie" and model:GetAttribute("CreatureType") ~= "Zombie" then return end
 local body = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Body")
 local head = model:FindFirstChild("Head")
 if not body or not body:IsA("BasePart") or not head or not head:IsA("BasePart") then return end
 registered[model] = true
 local humanoid = model:FindFirstChildOfClass("Humanoid") or Instance.new("Humanoid")
 humanoid.RequiresNeck = false
 humanoid.BreakJointsOnDeath = false
 humanoid.WalkSpeed = 0
 humanoid.AutoRotate = false
 humanoid.AutoJumpEnabled = false
 humanoid.JumpPower = 0
 humanoid.JumpHeight = 0
 humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
 local maximum = model:GetAttribute("MaxHealth")
 if not positive(maximum) then maximum = positive(humanoid.MaxHealth) and humanoid.MaxHealth or 100 end
 humanoid.MaxHealth = maximum
 humanoid.Health = maximum
 humanoid.Parent = model
 model.PrimaryPart = body
 model:SetAttribute("CreatureType","Zombie")
 if model:GetAttribute("DisplayName") == nil then model:SetAttribute("DisplayName","Zombie") end
 if model:GetAttribute("BlocksVision") == nil then model:SetAttribute("BlocksVision",true) end
 -- Keep every authored part exactly where it was placed; AI and a home floor
 -- will be added later. There is no movement, attack, regeneration or respawn.
 for _,part in ipairs(model:GetDescendants()) do
  if part:IsA("BasePart") then part.Anchored = true; part.CanQuery = true end
 end
 local function sync()
  model:SetAttribute("Health",humanoid.Health)
  model:SetAttribute("MaxHealth",humanoid.MaxHealth)
  model:SetAttribute("IsDead",humanoid.Health <= 0)
 end
 humanoid.HealthChanged:Connect(sync)
 humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(sync)
 sync()
end
local function consider(object)
 if object:IsA("Model") then prepare(object) end
 local ancestor = object.Parent
 while ancestor and ancestor ~= workspace do
  if ancestor:IsA("Model") then prepare(ancestor) end
  ancestor = ancestor.Parent
 end
end
for _,object in ipairs(workspace:GetDescendants()) do consider(object) end
workspace.DescendantAdded:Connect(function(object) task.defer(consider,object) end)
