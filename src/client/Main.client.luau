local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local player = Players.LocalPlayer
-- Default Roblox controls handle walking relative to the fixed camera.
ContextActionService:BindActionAtPriority("DeclineNoJump", function()
 return Enum.ContextActionResult.Sink
end, false, Enum.ContextActionPriority.High.Value + 1, Enum.PlayerActions.CharacterJump)
local function added(character)
 local humanoid = character:WaitForChild("Humanoid")
 humanoid.AutoJumpEnabled = false
 humanoid.JumpPower = 0
 humanoid.JumpHeight = 0
 humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
end
player.CharacterAdded:Connect(added)
if player.Character then task.spawn(added, player.Character) end
RunService:BindToRenderStep("DeclineCamera", Enum.RenderPriority.Camera.Value + 1, function()
 local character = player.Character
 local root = character and character:FindFirstChild("HumanoidRootPart")
 local camera = workspace.CurrentCamera
 if not root or not camera then return end
 camera.CameraType = Enum.CameraType.Scriptable
 camera.FieldOfView = Config.CameraFieldOfView
 local target = root.Position
 camera.CFrame = CFrame.lookAt(target + Vector3.new(0, Config.CameraHeight, Config.CameraBack), target, Vector3.new(0, 0, -1))
 camera.Focus = CFrame.new(target)
end)
