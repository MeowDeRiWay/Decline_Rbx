local Players=game:GetService("Players")
local Input=game:GetService("UserInputService")
local Gui=game:GetService("GuiService")
local Storage=game:GetService("ReplicatedStorage")
local player=Players.LocalPlayer
local action=Storage:WaitForChild("SetSneaking")
Input.InputBegan:Connect(function(key,processed)
 if processed or Input:GetFocusedTextBox() or Gui.MenuIsOpen then return end
 if key.KeyCode~=Enum.KeyCode.LeftControl and key.KeyCode~=Enum.KeyCode.RightControl then return end
 for _,attribute in ipairs({"InventoryOpen","TownMenuOpen","ProgressionOpen","GroupOpen"}) do if player:GetAttribute(attribute) then return end end
 local character=player.Character
 if character then action:FireServer(not character:GetAttribute("Sneaking")) end
end)
