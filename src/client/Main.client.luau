local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local ProgressionRules=require(ReplicatedStorage.Shared.ProgressionRules)
local Input=game:GetService("UserInputService")
local GuiService=game:GetService("GuiService")
local targetHeight=Config.CameraHeight
local currentHeight=targetHeight
local activityView
local nextViewReport=0
local player = Players.LocalPlayer
local function maximumHeight()
 local _,maximum=ProgressionRules.ZoomBounds(player:GetAttribute("ViewBonus") or 0,Config.CameraHeight,Config.CameraFieldOfView)
 return maximum
end
Input.InputChanged:Connect(function(input,processed)
 if processed or input.UserInputType~=Enum.UserInputType.MouseWheel or Input:GetFocusedTextBox() or GuiService.MenuIsOpen then return end
 if player:GetAttribute("InventoryOpen") or player:GetAttribute("TownMenuOpen") or player:GetAttribute("ProgressionOpen") then return end
 targetHeight=math.clamp(targetHeight-input.Position.Z*2,18,maximumHeight())
end)
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
 local target = root.Position
 targetHeight=math.clamp(targetHeight,18,maximumHeight())
 currentHeight+=(targetHeight-currentHeight)*(1-math.exp(-12*dt))
 local position=target+Vector3.new(0,currentHeight,Config.CameraBack*currentHeight/Config.CameraHeight)
 camera.CFrame = CFrame.lookAt(position, target, Vector3.new(0, 0, -1))
 camera.Focus = CFrame.new(target)
 if os.clock()>=nextViewReport and camera.ViewportSize.Y>0 then
  nextViewReport=os.clock()+.5
  activityView=activityView or ReplicatedStorage:FindFirstChild("ZombieActivityView")
  if activityView then activityView:FireServer(currentHeight,camera.ViewportSize.X/camera.ViewportSize.Y) end
 end
end)
