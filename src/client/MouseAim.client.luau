local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local player = Players.LocalPlayer

-- Aim after the fixed camera is updated. No turn-speed limit or smoothing.
RunService:BindToRenderStep("DeclineMouseAim", Enum.RenderPriority.Camera.Value + 2, function()
 local character = player.Character
 local root = character and character:FindFirstChild("HumanoidRootPart")
 local humanoid = character and character:FindFirstChildOfClass("Humanoid")
 local camera = workspace.CurrentCamera
 if not root or not humanoid or not camera then return end
 humanoid.AutoRotate = false
 if character:GetAttribute("Knockout") or humanoid.Health <= 0 or humanoid.Sit or humanoid.PlatformStand or root.Anchored then return end
 if (((player:GetAttribute("TradeOpen") or player:GetAttribute("AdminOpen")) or player:GetAttribute("InventoryOpen")) or player:GetAttribute("TownMenuOpen") or (player:GetAttribute("ProgressionOpen") or player:GetAttribute("GroupOpen"))) then return end
 if UserInputService:GetFocusedTextBox() or GuiService.MenuIsOpen or not UserInputService.MouseEnabled then return end
 -- ViewportPointToRay takes raw mouse coordinates, without subtracting the top bar.
 local mouse = UserInputService:GetMouseLocation()
 local viewport = camera.ViewportSize
 if mouse.X < 0 or mouse.Y < 0 or mouse.X > viewport.X or mouse.Y > viewport.Y then return end
 local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
 if math.abs(ray.Direction.Y) < 0.0001 then return end
 local distance = (root.Position.Y - ray.Origin.Y) / ray.Direction.Y
 if distance <= 0 then return end
 local point = ray.Origin + ray.Direction * distance
 local direction = Vector3.new(point.X - root.Position.X, 0, point.Z - root.Position.Z)
 if direction.Magnitude < 0.1 then return end
 root.CFrame = CFrame.lookAt(root.Position, root.Position + direction, Vector3.yAxis)
end)
