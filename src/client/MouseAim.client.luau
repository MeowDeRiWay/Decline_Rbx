local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local player = Players.LocalPlayer
local lastMouse = nil
local aimPoint = nil
player.CharacterAdded:Connect(function()
 lastMouse, aimPoint = nil, nil
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
 -- Keep the last world target until the mouse moves. Recasting merely because
 -- the camera turned would feed its rotation back into aim and cause spinning.
 if not lastMouse or (mouse - lastMouse).Magnitude > 0.1 or not aimPoint then
 local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
 if math.abs(ray.Direction.Y) < 0.0001 then return end

 -- Intersect the mouse ray with the horizontal plane through the body.
 -- Buildings and the character itself cannot intercept this aim calculation.
 local distance = (root.Position.Y - ray.Origin.Y) / ray.Direction.Y
 if distance <= 0 then return end
 aimPoint = ray.Origin + ray.Direction * distance
 lastMouse = mouse
 end
 local direction = Vector3.new(aimPoint.X - root.Position.X, 0, aimPoint.Z - root.Position.Z)
 if direction.Magnitude < 0.1 then return end
 -- Keep the body upright and preserve its position; rotate only around Y.
 local forward = root.CFrame.LookVector
 local currentYaw = math.atan2(-forward.X, -forward.Z)
 local targetYaw = math.atan2(-direction.X, -direction.Z)
 -- Wrap to [-pi, pi] so crossing 180 degrees takes the shorter turn.
 local difference = math.atan2(math.sin(targetYaw - currentYaw), math.cos(targetYaw - currentYaw))
 local maxStep = math.rad(math.max(0, Config.TurnSpeed or 120)) * dt
 local yaw = currentYaw + math.clamp(difference, -maxStep, maxStep)
 root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, yaw, 0)
end)
