local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Input = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Motion = require(ReplicatedStorage.Shared.WeaponMotion)
local player = Players.LocalPlayer
local items = require(ReplicatedStorage.Shared.ItemConfig).Items
local remote = ReplicatedStorage:WaitForChild("WeaponAttack")
local ready = 0
Input.InputBegan:Connect(function(input,processed)
 if processed or input.UserInputType ~= Enum.UserInputType.MouseButton1 or Input:GetFocusedTextBox() or GuiService.MenuIsOpen or (player:GetAttribute("InventoryOpen") or player:GetAttribute("TownMenuOpen") or player:GetAttribute("ProgressionOpen")) then return end
 local character = player.Character
 local held = character and character:FindFirstChild("HeldItem")
 local motor = held and held:FindFirstChild("WeaponGrip")
 local definition = character and items[character:GetAttribute("HandsItem")]
 local humanoid = character and character:FindFirstChildOfClass("Humanoid")
 if not motor or not definition or not definition.Weapon or not humanoid or humanoid.Health <= 0 or character:GetAttribute("Knockout") or (character:GetAttribute("WeaponCondition") or 0) <= 0 or os.clock() < ready then return end
 local weapon = definition.Weapon
 if definition.CraftTool=="Knife" then
  weapon=table.clone(weapon); weapon.AttacksPerMinute*=player:GetAttribute("KnifeMultiplier") or 1
 end
 local cooldown = 60/weapon.AttacksPerMinute
 ready = os.clock()+cooldown
 remote:FireServer()
 Motion.Play(motor,weapon)
end)
