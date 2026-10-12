local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local ContextActionService=game:GetService("ContextActionService")
local StarterGui=game:GetService("StarterGui")
local resetAllowed
local player=Players.LocalPlayer
local gui=Instance.new("ScreenGui")
gui.Name="KnockoutUI"
gui.ResetOnSpawn=false
gui.Parent=player:WaitForChild("PlayerGui")
local label=Instance.new("TextLabel")
label.AnchorPoint=Vector2.new(.5,0)
label.Position=UDim2.new(.5,0,0,60)
label.Size=UDim2.fromOffset(340,72)
label.BackgroundColor3=Color3.fromRGB(24,27,32)
label.BackgroundTransparency=.15
label.TextColor3=Color3.fromRGB(245,205,170)
label.Font=Enum.Font.GothamMedium
label.TextSize=20
label.Visible=false
label.Parent=gui
local corner=Instance.new("UICorner")
corner.CornerRadius=UDim.new(0,10)
corner.Parent=label
ContextActionService:BindActionAtPriority("KnockoutNoMovement",function()
 local character=player.Character
 return character and character:GetAttribute("Knockout") and Enum.ContextActionResult.Sink or Enum.ContextActionResult.Pass
end,false,Enum.ContextActionPriority.High.Value+10,Enum.PlayerActions.CharacterForward,Enum.PlayerActions.CharacterBackward,Enum.PlayerActions.CharacterLeft,Enum.PlayerActions.CharacterRight,Enum.PlayerActions.CharacterJump)
RunService.RenderStepped:Connect(function()
 local character=player.Character
 label.Visible=character~=nil and character:GetAttribute("Knockout")==true
 local allowed=not label.Visible
 if resetAllowed~=allowed then
  local ok=pcall(function() StarterGui:SetCore("ResetButtonCallback",allowed) end)
  if ok then resetAllowed=allowed end
 end
 if not label.Visible then return end
 local seconds=math.max(0,math.ceil((character:GetAttribute("KnockoutEndsAt") or 0)-workspace:GetServerTimeNow()))
 label.Text=string.format("Knocked out\nDeath in %02d:%02d",math.floor(seconds/60),seconds%60)
end)
