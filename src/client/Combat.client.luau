local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Input = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local CombatRules=require(ReplicatedStorage.Shared.CombatRules)
local Motion = require(ReplicatedStorage.Shared.WeaponMotion)
local player = Players.LocalPlayer
local items = require(ReplicatedStorage.Shared.ItemConfig).Items
local remote = ReplicatedStorage:WaitForChild("WeaponAttack")
local MineTarget=require(script.Parent.MineTarget)
local ready = 0
local sequence=0
Input.InputBegan:Connect(function(input,processed)
 if (player.Character and (player.Character:GetAttribute("HandsBusy") or player.Character:GetAttribute("MedicalHeld"))) or (player:GetAttribute("PlayerContextOpen") or player:GetAttribute("ExchangeOpen")) or processed or input.UserInputType ~= Enum.UserInputType.MouseButton1 or Input:GetFocusedTextBox() or GuiService.MenuIsOpen or (player:GetAttribute("MedicalMode") or (((player:GetAttribute("MapOpen") or player:GetAttribute("HelpOpen")) or player:GetAttribute("AdminOpen")) or player:GetAttribute("InventoryOpen")) or player:GetAttribute("TownMenuOpen") or (player:GetAttribute("ProgressionOpen") or player:GetAttribute("GroupOpen"))) then return end
 if MineTarget.Get() then return end
 local character = player.Character
 local held = character and character:FindFirstChild("HeldItem")
 local motor = held and held:FindFirstChild("WeaponGrip")
 local definition = character and items[character:GetAttribute("HandsItem")]
 local humanoid = character and character:FindFirstChildOfClass("Humanoid")
 if definition and (definition.Firearm or definition.Trap) then return end
 if (definition and (not motor or not definition.Weapon)) or not humanoid or humanoid.Health <= 0 or (character:GetAttribute("Knockout") or character:GetAttribute("InteractionLocked")) or os.clock() < ready then return end
 local weapon = definition and definition.Weapon or CombatRules.Unarmed
 if definition and definition.CraftTool=="Knife" then
  weapon=table.clone(weapon); weapon.AttacksPerMinute*=player:GetAttribute("KnifeMultiplier") or 1
 end
 local cooldown = 60/weapon.AttacksPerMinute
 ready = os.clock()+cooldown
 sequence=(sequence%2147483646)+1
 remote:FireServer(sequence)
 if weapon.Animation=="Chop" or weapon.Animation=="Thrust" then Motion.PredictChop(motor,weapon,workspace:GetServerTimeNow(),sequence)
 else Motion.Play(motor,weapon) end
end)
