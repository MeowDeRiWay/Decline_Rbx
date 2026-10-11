local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
Players.CharacterAutoLoads = false
StarterPlayer.LoadCharacterAppearance = false

local function prepare(character)
 local humanoid = character:FindFirstChildOfClass("Humanoid")
 local root = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Body")
 local head = character:FindFirstChild("Head")
 assert(humanoid and root and root:IsA("BasePart") and head and head:IsA("BasePart"),
  "StarterCharacter needs Humanoid, Body (or HumanoidRootPart), and Head")
 -- Body itself is the root; no model parts are generated.
 root.Name = "HumanoidRootPart"
 character.PrimaryPart = root
 humanoid.RequiresNeck = false
 humanoid.HipHeight = 0
 humanoid.WalkSpeed = Config.WalkSpeed
 humanoid.AutoRotate = true
 humanoid.AutoJumpEnabled = false
 humanoid.JumpPower = 0
 humanoid.JumpHeight = 0
 humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
 root.Anchored = false
 root.CanCollide = true
 head.Anchored = false
 head.CanCollide = false
 head.Massless = true
 -- Preserve an existing joint if the model already has one.
 local connected = false
 for _, item in ipairs(character:GetDescendants()) do
  if item:IsA("JointInstance") or item:IsA("WeldConstraint") then
   if (item.Part0 == root and item.Part1 == head) or (item.Part0 == head and item.Part1 == root) then connected = true end
  end
 end
 if not connected then
  local weld = Instance.new("WeldConstraint")
  weld.Name, weld.Part0, weld.Part1 = "HeadWeld", root, head
  weld.Parent = root
 end
end
local template = StarterPlayer:WaitForChild("StarterCharacter", 15)
if not template or not template:IsA("Model") then
 warn("[Decline] Place your Player_body model in StarterPlayer and rename it StarterCharacter")
 return
end
prepare(template)
local function added(player)
 player.CharacterAdded:Connect(function(character)
  prepare(character)
  local humanoid = character:FindFirstChildOfClass("Humanoid")
  humanoid.Died:Connect(function()
   task.delay(Players.RespawnTime, function()
    if player.Parent == Players and player.Character == character then player:LoadCharacterAsync() end
   end)
  end)
 end)
 if player.Parent == Players then player:LoadCharacterAsync() end
end
Players.PlayerAdded:Connect(added)
for _, player in ipairs(Players:GetPlayers()) do task.spawn(added, player) end
