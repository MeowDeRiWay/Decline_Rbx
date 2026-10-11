local ServerStorage = game:GetService("ServerStorage")
local Characters = {}
local function fallback()
 local model = Instance.new("Model")
 model.Name = "PlayerCharacter"
 local root = Instance.new("Part")
 root.Name, root.Size, root.Transparency = "HumanoidRootPart", Vector3.new(2, 2, 1), 1
 root.CanCollide = false
 root.Parent = model
 local function body(name, size, offset, color)
  local p = Instance.new("Part")
  p.Name, p.Size, p.CFrame, p.Color = name, size, CFrame.new(offset), color
  p.CanCollide, p.Massless = name == "Torso", true
  p.Parent = model
  local joint = Instance.new("Motor6D")
  joint.Name, joint.Part0, joint.Part1, joint.C0 = name .. "Joint", root, p, CFrame.new(offset)
  joint.Parent = root
 end
 body("Torso", Vector3.new(2, 2, 1), Vector3.zero, Color3.fromRGB(80, 95, 70))
 body("Head", Vector3.new(1.4, 1, 1), Vector3.new(0, 1.5, 0), Color3.fromRGB(190, 165, 135))
 body("Left Arm", Vector3.new(0.7, 2, 0.8), Vector3.new(-1.4, 0, 0), Color3.fromRGB(80, 95, 70))
 body("Right Arm", Vector3.new(0.7, 2, 0.8), Vector3.new(1.4, 0, 0), Color3.fromRGB(80, 95, 70))
 body("Left Leg", Vector3.new(0.8, 2, 0.8), Vector3.new(-0.5, -2, 0), Color3.fromRGB(45, 50, 40))
 body("Right Leg", Vector3.new(0.8, 2, 0.8), Vector3.new(0.5, -2, 0), Color3.fromRGB(45, 50, 40))
 local humanoid = Instance.new("Humanoid")
 humanoid.RequiresNeck = false
 humanoid.HipHeight = 2
 humanoid.Parent = model
 model.PrimaryPart = root
 return model
end
function Characters.Spawn(player, position, config)
 local assets = ServerStorage:FindFirstChild("DeclineAssets")
 local template = assets and assets:FindFirstChild("PlayerCharacter")
 local model = template and template:Clone() or fallback()
 local humanoid = model:FindFirstChildOfClass("Humanoid")
 local root = model:FindFirstChild("HumanoidRootPart")
 assert(humanoid and root and root:IsA("BasePart"), "PlayerCharacter requires Humanoid and HumanoidRootPart")
 model.PrimaryPart = root
 model.Name = player.Name
 model:SetAttribute("User_ID", player.UserId)
 model:SetAttribute("Town_ID", player:GetAttribute("Town_ID") or 0)
 model:SetAttribute("Knockout", false)
 model:SetAttribute("AFK", false)
 humanoid.MaxHealth, humanoid.Health = config.MaxHealth, config.MaxHealth
 humanoid.BreakJointsOnDeath = false
 humanoid.WalkSpeed, humanoid.JumpPower, humanoid.JumpHeight = config.WalkSpeed, 0, 0
 humanoid.DisplayName = player.DisplayName
 humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
 model:PivotTo(CFrame.new(position + Vector3.new(0, 4, 0)))
 model.Parent = workspace
 local old = player.Character
 player.Character = model
 if old and not old:GetAttribute("Corpse") then old:Destroy() end
 root:SetNetworkOwner(player)
 return model
end
return Characters
