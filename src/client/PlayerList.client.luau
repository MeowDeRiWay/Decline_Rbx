local Players=game:GetService("Players")
local StarterGui=game:GetService("StarterGui")
local Context=game:GetService("ContextActionService")
local Input=game:GetService("UserInputService")
local GuiService=game:GetService("GuiService")
local function disable()
 -- Core scripts may not be initialized at the first client frame.
 for _=1,12 do
  local ok=pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList,false) end)
  if ok then return end
  task.wait(.25)
 end
 warn("[Decline] Could not disable the default player list.")
end
Context:BindActionAtPriority("DeclineHidePlayerList",function()
 if Input:GetFocusedTextBox() or GuiService.MenuIsOpen then return Enum.ContextActionResult.Pass end
 return Enum.ContextActionResult.Sink
end,false,Enum.ContextActionPriority.High.Value+1,Enum.KeyCode.Tab)
Players.LocalPlayer.CharacterAdded:Connect(function() task.spawn(disable) end)
task.spawn(disable)
-- The protected Escape/People menu has no supported distance-filter API.
-- Actual Player instances and Roblox reporting/blocking controls are untouched.
