local Players=game:GetService("Players")
local Run=game:GetService("RunService")
local player=Players.LocalPlayer
local gui=Instance.new("ScreenGui");gui.Name="DebuffStatus";gui.ResetOnSpawn=false;gui.Parent=player:WaitForChild("PlayerGui")
local label=Instance.new("TextLabel");label.AnchorPoint=Vector2.new(1,0);label.Position=UDim2.new(1,-16,0,55);label.Size=UDim2.fromOffset(260,50);label.BackgroundTransparency=.2;label.BackgroundColor3=Color3.fromRGB(43,42,35);label.TextColor3=Color3.fromRGB(182,105,73);label.TextWrapped=true;label.Font=Enum.Font.RobotoMono;label.TextSize=14;label.Visible=false;label.Parent=gui
Run.Heartbeat:Connect(function()
 local c=player.Character
 label.Visible=c~=nil and c:GetAttribute("Poisoned")==true and not c:GetAttribute("IsDead")
 if label.Visible then label.Text=c:GetAttribute("HospitalResting") and "Poisoning: hospital treatment" or "Poisoning: Sick +1 per second" end
end)
