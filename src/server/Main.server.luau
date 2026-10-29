local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Life = require(script.Parent.Services.PlayerLifeService)
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local Rig=require(ReplicatedStorage.Shared.CharacterRig)
Players.CharacterAutoLoads = false
StarterPlayer.LoadCharacterAppearance = false

local function prepare(character)
 local humanoid = character:FindFirstChildOfClass("Humanoid")
 local root = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Body")
 local head = character:FindFirstChild("Head")
 assert(humanoid and root and root:IsA("BasePart") and head and head:IsA("BasePart"),
  "StarterCharacter needs Humanoid, Body (or HumanoidRootPart), and Head")
 -- Keep the original collision body as the root.
 root.Name = "HumanoidRootPart"
 character.PrimaryPart = root
 humanoid.RequiresNeck = false
 humanoid.BreakJointsOnDeath = false
 humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead,false)
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
 if Rig.Prepare(character,root,humanoid) then return end
 -- Legacy two-part characters keep their original head weld.
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
  if not character:GetAttribute("ReturningSession") then prepare(character) end
  local humanoid = character:FindFirstChildOfClass("Humanoid")
  humanoid.HealthChanged:Connect(function(health)
   if health<=0 and not character:GetAttribute("IsDead") then Life.Knockout(player,character) end
  end)
  humanoid.Died:Connect(function()
   Life.Finish(player,character)
  end)
 end)
 -- TownService loads the first character after the player selects a city.
 if player.Parent == Players and player:GetAttribute("TownID") and not player:GetAttribute("Reconnecting") and not player.Character then require(script.Parent.Services.TownService).LoadCharacter(player) end
end
Players.PlayerAdded:Connect(added)
for _, player in ipairs(Players:GetPlayers()) do task.spawn(added, player) end
