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
local yaw=0
local orbiting=false
local previousMouseBehavior
local function blocked()
 if Input:GetFocusedTextBox() or GuiService.MenuIsOpen then return true end
 for _,name in ipairs({"TradeOpen","InventoryOpen","TownMenuOpen","ProgressionOpen","GroupOpen","AdminOpen","FarmMenuOpen","LoadingScreenOpen","HelpOpen"}) do
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
for _,name in ipairs({"TradeOpen","InventoryOpen","TownMenuOpen","ProgressionOpen","GroupOpen","AdminOpen","FarmMenuOpen","LoadingScreenOpen","HelpOpen"}) do
 player:GetAttributeChangedSignal(name):Connect(function() if blocked() then stopOrbit() end end)
end
local function maximumHeight()
 local _,maximum=ProgressionRules.ZoomBounds(player:GetAttribute("ViewRange") or 25,Config.CameraHeight,Config.CameraFieldOfView)
 return maximum
end
Input.InputChanged:Connect(function(input,processed)
 if blocked() then stopOrbit();return end
 if orbiting and input.UserInputType==Enum.UserInputType.MouseMovement then
  yaw=(yaw-input.Delta.X*Config.CameraOrbitSensitivity)%(2*math.pi)
  return
 end
 if processed or input.UserInputType~=Enum.UserInputType.MouseWheel then return end
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
 if orbiting and blocked() then stopOrbit() end
 local character = player.Character
 local root = character and character:FindFirstChild("HumanoidRootPart")
 local camera = workspace.CurrentCamera
 if not root or not camera then return end
 camera.CameraType = Enum.CameraType.Scriptable
 camera.FieldOfView = Config.CameraFieldOfView
 local target = root.Position
 targetHeight=math.clamp(targetHeight,18,maximumHeight())
 currentHeight+=(targetHeight-currentHeight)*(1-math.exp(-12*dt))
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
