local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Input = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer
local items = require(ReplicatedStorage.Shared.ItemConfig).Items
local remote = ReplicatedStorage:WaitForChild("WeaponAttack")
local ready = 0
Input.InputBegan:Connect(function(input,processed)
 if processed or input.UserInputType ~= Enum.UserInputType.MouseButton1 or Input:GetFocusedTextBox() or GuiService.MenuIsOpen or player:GetAttribute("InventoryOpen") then return end
 local character = player.Character
 local held = character and character:FindFirstChild("HeldItem")
 local motor = held and held:FindFirstChild("WeaponGrip")
 local definition = character and items[character:GetAttribute("HandsItem")]
 local humanoid = character and character:FindFirstChildOfClass("Humanoid")
 if not motor or not definition or not definition.Weapon or not humanoid or humanoid.Health <= 0 or (character:GetAttribute("WeaponCondition") or 0) <= 0 or os.clock() < ready then return end
 local weapon = definition.Weapon
 local cooldown = 60/weapon.AttacksPerMinute
 ready = os.clock()+cooldown
 remote:FireServer()
 local base = motor:GetAttribute("RestC0")
 if base then
  motor.C0 = CFrame.new(0,0,-weapon.Thrust)*base
  TweenService:Create(motor,TweenInfo.new(cooldown,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{C0=base}):Play()
 end
end)
