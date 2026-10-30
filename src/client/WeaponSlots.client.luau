local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Input=game:GetService("UserInputService")
local Gui=game:GetService("GuiService")
local player=Players.LocalPlayer
local action=ReplicatedStorage:WaitForChild("InventoryRemotes"):WaitForChild("Action")
Input.InputBegan:Connect(function(input,processed)
 if processed or Input:GetFocusedTextBox() or Gui.MenuIsOpen then return end
 local slot
 if input.KeyCode==Enum.KeyCode.One or input.KeyCode==Enum.KeyCode.KeypadOne then slot="PrimaryWeapon"
 elseif input.KeyCode==Enum.KeyCode.Two or input.KeyCode==Enum.KeyCode.KeypadTwo then slot="SecondaryWeapon" end
 if not slot then return end
 for _,key in ipairs({"TradeOpen","InventoryOpen","TownMenuOpen","ProgressionOpen","GroupOpen","AdminOpen","MapOpen","HelpOpen","PlayerContextOpen","OutcastEnd"}) do if player:GetAttribute(key) then return end end
 local c=player.Character
 if not c or c:GetAttribute("HandsBusy") or c:GetAttribute("Knockout") or c:GetAttribute("IsDead") then return end
 player:SetAttribute("MedicalMode",nil)
 action:FireServer("WeaponSlot",slot)
end)
