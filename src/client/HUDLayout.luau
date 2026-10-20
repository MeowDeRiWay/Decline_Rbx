local Players=game:GetService("Players")
local Run=game:GetService("RunService")
local Theme=require(game:GetService("ReplicatedStorage").Shared.UITheme)
local gui=Instance.new("ScreenGui")
gui.Name="SurvivalConsole";gui.ResetOnSpawn=false;gui.IgnoreGuiInset=true;gui.Parent=Players.LocalPlayer:WaitForChild("PlayerGui")
local bar=Instance.new("Frame")
bar.Name="Console";bar.AnchorPoint=Vector2.new(.5,1);bar.Position=UDim2.new(.5,0,1,-8);bar.Size=UDim2.fromOffset(1020,170)
bar.BackgroundColor3=Theme.Panel;bar.Parent=gui;Theme.Bevel(bar)
local scale=Instance.new("UIScale");scale.Parent=bar
Run.RenderStepped:Connect(function()
 local camera=workspace.CurrentCamera
 if camera then scale.Scale=math.min(1,(camera.ViewportSize.X-16)/1020) end
end)
local function event() return Instance.new("BindableEvent") end
return {Gui=gui,Bar=bar,Inventory=event(),Character=event(),Log=event()}
