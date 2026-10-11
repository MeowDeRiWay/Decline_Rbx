local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local player = Players.LocalPlayer
local AimState = require(script.Parent:WaitForChild("AimState"))
local cameraYaw = nil
local cameraRoot = nil
-- Default Roblox controls handle walking relative to the camera.
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
RunService:BindToRenderStep("DeclineCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
 local character = player.Character
 local root = character and character:FindFirstChild("HumanoidRootPart")
 local camera = workspace.CurrentCamera
 if not root or not camera then return end
 camera.CameraType = Enum.CameraType.Scriptable
 camera.FieldOfView = Config.CameraFieldOfView
 if cameraRoot ~= root then
  cameraRoot = root
  cameraYaw = math.atan2(-root.CFrame.LookVector.X, -root.CFrame.LookVector.Z)
  AimState.Yaw = cameraYaw
 end
 -- Camera follows mouse direction independently of the body's TurnSpeed.
 cameraYaw = AimState.Step(cameraYaw, AimState.Yaw or cameraYaw, Config.CameraTurnSpeed or 180, dt)
 local forward = Vector3.new(-math.sin(cameraYaw), 0, -math.cos(cameraYaw))
 -- Look ahead so the body appears near the bottom of the viewport.
 -- Optional Config.CameraForward overrides the default forward shift.
 local height, back = Config.CameraHeight, Config.CameraBack
 local framing = 0.75 -- Body at about 87.5% of the screen height.
 local tangent = math.tan(math.rad(Config.CameraFieldOfView / 2))
 local defaultShift = framing * (height * height + back * back) * tangent / (height + framing * back * tangent)
 local shift = Config.CameraForward or defaultShift
 local target = root.Position + forward * shift
 local position = target + Vector3.yAxis * Config.CameraHeight - forward * Config.CameraBack
 camera.CFrame = CFrame.lookAt(position, target, forward)
 camera.Focus = CFrame.new(target)
end)
