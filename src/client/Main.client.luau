local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local ProgressionRules=require(ReplicatedStorage.Shared.ProgressionRules)
local MovementRules=require(ReplicatedStorage.Shared.MovementRules)
local Input=game:GetService("UserInputService")
local GuiService=game:GetService("GuiService")
local targetHeight=Config.CameraHeight
local currentHeight=targetHeight
local activityView
local nextViewReport=0
local player = Players.LocalPlayer
local yaw=Config.CameraStartYaw
local orbiting=false
local previousMouseBehavior
local function blocked()
 if Input:GetFocusedTextBox() or GuiService.MenuIsOpen then return true end
 for _,name in ipairs({"ExchangeOpen","TradeOpen","InventoryOpen","TownMenuOpen","ProgressionOpen","GroupOpen","AdminOpen","FarmMenuOpen","LoadingScreenOpen","HelpOpen","MapOpen"}) do
  if player:GetAttribute(name) then return true end
 end
 return false
end
local function stopOrbit()
 if not orbiting then return end
 orbiting=false
 Input.MouseBehavior=previousMouseBehavior
end
Input.InputBegan:Connect(function(input,processed)
 if processed or input.UserInputType~=Enum.UserInputType.MouseButton3 or blocked() or not player.Character then return end
 if orbiting then return end
 previousMouseBehavior=Input.MouseBehavior
 orbiting=true
 Input.MouseBehavior=Enum.MouseBehavior.LockCurrentPosition
end)
Input.InputEnded:Connect(function(input)
 if input.UserInputType==Enum.UserInputType.MouseButton3 then stopOrbit() end
end)
Input.WindowFocusReleased:Connect(stopOrbit)
player.CharacterRemoving:Connect(stopOrbit)
for _,name in ipairs({"ExchangeOpen","TradeOpen","InventoryOpen","TownMenuOpen","ProgressionOpen","GroupOpen","AdminOpen","FarmMenuOpen","LoadingScreenOpen","HelpOpen","MapOpen"}) do
 player:GetAttributeChangedSignal(name):Connect(function() if blocked() then stopOrbit() end end)
end
local function minimumHeight()
 return player:GetAttribute("AdminAccess")==true and .65 or 18
end
local cameraDistance = math.sqrt(Config.CameraHeight^2 + Config.CameraBack^2)
local forwardDepthScale = Config.CameraBack / cameraDistance
local verticalSlope = math.tan(math.rad(Config.CameraFieldOfView / 2))

local function zoomBounds(camera)
 local range = player:GetAttribute("ViewRange") or (10 + 3 * (player:GetAttribute("Attention") or 5))
 local _, maximum = ProgressionRules.ZoomBounds(range, Config.CameraHeight, Config.CameraFieldOfView)
 local viewport = camera and camera.ViewportSize
 if viewport and viewport.X > 0 and viewport.Y > 0 then
  local halfAngle = math.rad(Config.CreatureViewAngle * (player:GetAttribute("ViewAngleMultiplier") or 1) / 2)
  local horizontalSlope = verticalSlope * viewport.X / viewport.Y
  -- Fit the unobstructed cone facing screen-forward, so aiming never changes zoom.
  local side = range * math.sin(halfAngle)
  local depth = range * math.cos(halfAngle) * forwardDepthScale
  local fitHeight = (side / horizontalSlope - depth) * Config.CameraHeight / cameraDistance
  maximum = math.min(maximum, math.max(.65, fitHeight))
 end
 return math.min(minimumHeight(), maximum), maximum
end
Input.InputChanged:Connect(function(input,processed)
 if blocked() then stopOrbit();return end
 if orbiting and input.UserInputType==Enum.UserInputType.MouseMovement then
  yaw=(yaw-input.Delta.X*Config.CameraOrbitSensitivity)%(2*math.pi)
  return
 end
 if processed or input.UserInputType~=Enum.UserInputType.MouseWheel then return end
 local minimum, maximum = zoomBounds(workspace.CurrentCamera)
 targetHeight=math.clamp(targetHeight-input.Position.Z*math.max(.08,math.min(2,targetHeight*.15)),minimum,maximum)
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
 humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
end
player.CharacterAdded:Connect(added)
if player.Character then task.spawn(added, player.Character) end
-- Run after the default controls, so held WASD cannot override the shot pause.
RunService:BindToRenderStep("DeclineShotMovement",Enum.RenderPriority.Input.Value+1,function()
 local character=player.Character
 if not character or not MovementRules.ShotLocked(character:GetAttribute("ShotMovementUntil"),workspace:GetServerTimeNow()) then return end
 local humanoid=character:FindFirstChildOfClass("Humanoid")
 if humanoid then humanoid:Move(Vector3.zero,false) end
end)
RunService:BindToRenderStep("DeclineCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
 if orbiting and blocked() then stopOrbit() end
 local character = player.Character
 local root = character and character:FindFirstChild("HumanoidRootPart")
 local camera = workspace.CurrentCamera
 if not root or not camera then return end
 camera.CameraType = Enum.CameraType.Scriptable
 camera.FieldOfView = Config.CameraFieldOfView
 local target = root.Position
 local minimum, maximum = zoomBounds(camera)
 targetHeight=math.clamp(targetHeight,minimum,maximum)
 currentHeight=math.min(maximum,currentHeight+(targetHeight-currentHeight)*(1-math.exp(-12*dt)))
 local sine,cosine=math.sin(yaw),math.cos(yaw)
 local back=Config.CameraBack*currentHeight/Config.CameraHeight
 local position=target+Vector3.new(sine*back,currentHeight,cosine*back)
 camera.CFrame = CFrame.lookAt(position, target, Vector3.new(-sine, 0, -cosine))
 camera.Focus = CFrame.new(target)
 if os.clock()>=nextViewReport and camera.ViewportSize.Y>0 then
  nextViewReport=os.clock()+.5
  activityView=activityView or ReplicatedStorage:FindFirstChild("ZombieActivityView")
  if activityView then activityView:FireServer(currentHeight,camera.ViewportSize.X/camera.ViewportSize.Y,yaw) end
 end
end)
