local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local Theme=require(ReplicatedStorage.Shared.UITheme)
local player=Players.LocalPlayer
local gui=Instance.new("ScreenGui")
gui.Name="CharacterHUD";gui.ResetOnSpawn=false;gui.IgnoreGuiInset=true;gui.Parent=player:WaitForChild("PlayerGui")
local panel=Instance.new("Frame")
panel.AnchorPoint=Vector2.new(0,1);panel.Position=UDim2.new(0,16,1,-16);panel.Size=UDim2.fromOffset(210,58)
panel.BackgroundColor3=Theme.Panel;panel.Parent=gui;Theme.Bevel(panel)
local label=Instance.new("TextLabel")
label.Position=UDim2.fromOffset(12,6);label.Size=UDim2.new(1,-24,0,28);label.BackgroundTransparency=1
label.Font=Theme.Font;label.TextSize=16;label.TextColor3=Theme.Text;label.TextXAlignment=Enum.TextXAlignment.Left;label.Parent=panel
local track=Instance.new("Frame")
track.Position=UDim2.fromOffset(12,40);track.Size=UDim2.new(1,-24,0,6);track.BackgroundColor3=Theme.Card;track.BorderSizePixel=0;track.Parent=panel
local fill=Instance.new("Frame")
fill.BorderSizePixel=0;fill.BackgroundColor3=Theme.Green;fill.Size=UDim2.fromScale(0,1);fill.Parent=track
local elapsed=0
RunService.Heartbeat:Connect(function(dt)
 elapsed+=dt;if elapsed<.1 then return end;elapsed=0
 local character=player.Character
 local health=character and character:GetAttribute("Health")
 local maximum=character and character:GetAttribute("MaxHealth") or 100
 if typeof(health)~="number" then label.Text="Health —";fill.Size=UDim2.fromScale(0,1);return end
 label.Text=string.format("Health %.0f / %.0f",health,maximum)
 fill.Size=UDim2.fromScale(math.clamp(health/math.max(1,maximum),0,1),1)
 fill.BackgroundColor3=health<maximum*.25 and Theme.Danger or Theme.Green
end)
