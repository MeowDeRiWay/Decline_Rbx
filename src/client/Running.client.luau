local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Input = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("SetRunning")
local focused,last = true,false
local function send(value)
 if value == last then return end
 last = value
 remote:FireServer(value)
end
Input.WindowFocusReleased:Connect(function() focused = false; send(false) end)
Input.WindowFocused:Connect(function() focused = true end)
player.CharacterAdded:Connect(function() last = false; remote:FireServer(false) end)
RunService.RenderStepped:Connect(function()
 local character = player.Character
 local humanoid = character and character:FindFirstChildOfClass("Humanoid")
 local allowed = focused and humanoid ~= nil and humanoid.Health > 0 and not humanoid.Sit and not humanoid.PlatformStand and not character:GetAttribute("Knockout") and not player:GetAttribute("InventoryOpen") and not GuiService.MenuIsOpen and Input:GetFocusedTextBox() == nil
 send(allowed and (Input:IsKeyDown(Enum.KeyCode.LeftShift) or Input:IsKeyDown(Enum.KeyCode.RightShift)))
end)
