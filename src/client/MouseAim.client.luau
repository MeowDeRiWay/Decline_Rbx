local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local player = Players.LocalPlayer
local lastMouse = nil
local AimState = require(script.Parent:WaitForChild("AimState"))
player.CharacterAdded:Connect(function()
 lastMouse = nil
end)

-- Run after Main.client's camera update. This file does not change the camera.
RunService:BindToRenderStep("DeclineMouseAim", Enum.RenderPriority.Camera.Value + 2, function(dt)
 local character = player.Character
 local root = character and character:FindFirstChild("HumanoidRootPart")
 local humanoid = character and character:FindFirstChildOfClass("Humanoid")
 local camera = workspace.CurrentCamera
 if not root or not humanoid or not camera then return end
 -- Walking must not override the direction chosen with the mouse.
 humanoid.AutoRotate = false
 if humanoid.Health <= 0 or humanoid.Sit or humanoid.PlatformStand or root.Anchored then return end
 if UserInputService:GetFocusedTextBox() or GuiService.MenuIsOpen then return end
 if not UserInputService.MouseEnabled then return end

 local inset = GuiService:GetGuiInset()
 local mouse = UserInputService:GetMouseLocation() - inset
 local viewport = camera.ViewportSize
 if mouse.X < 0 or mouse.Y < 0 or mouse.X > viewport.X or mouse.Y > viewport.Y then return end
 -- Sample only real cursor movement: camera rotation must not generate new aim.
 if not lastMouse or (mouse - lastMouse).Magnitude > 0.1 then
  local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
  if math.abs(ray.Direction.Y) > 0.0001 then
   local distance = (root.Position.Y - ray.Origin.Y) / ray.Direction.Y
   if distance > 0 then
    local point = ray.Origin + ray.Direction * distance
    local direction = Vector3.new(point.X - root.Position.X, 0, point.Z - root.Position.Z)
    if direction.Magnitude >= 0.1 then
     AimState.Yaw = math.atan2(-direction.X, -direction.Z)
    end
   end
  end
  lastMouse = mouse
 end
 -- Store a world heading rather than a world point. Walking past the old
 -- cursor target must not suddenly rotate either the body or the camera.
 local forward = root.CFrame.LookVector
 local currentYaw = math.atan2(-forward.X, -forward.Z)
 local yaw = AimState.Step(currentYaw, AimState.Yaw or currentYaw, Config.TurnSpeed or 120, dt)
 root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, yaw, 0)
end)
