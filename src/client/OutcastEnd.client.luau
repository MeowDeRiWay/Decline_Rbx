local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Context=game:GetService("ContextActionService")
local Run=game:GetService("RunService")
local player=Players.LocalPlayer
local remote=ReplicatedStorage:WaitForChild("OutcastRestart")
local function make(class,parent,properties)
 local object=Instance.new(class)
 for key,value in pairs(properties) do object[key]=value end
 object.Parent=parent;return object
end
local gui=make("ScreenGui",player:WaitForChild("PlayerGui"),{Name="OutcastEnd",ResetOnSpawn=false,IgnoreGuiInset=true,DisplayOrder=1100,Enabled=false})
local background=make("TextButton",gui,{Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.fromRGB(8,9,8),BorderSizePixel=0,Text="",AutoButtonColor=false,Modal=true,Selectable=false})
local panel=make("Frame",background,{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(760,360),BackgroundTransparency=1})
local scale=make("UIScale",panel,{Scale=1})
make("TextLabel",panel,{Position=UDim2.fromOffset(0,10),Size=UDim2.fromOffset(760,70),BackgroundTransparency=1,Text="THIS IS THE END",TextColor3=Color3.fromRGB(185,164,123),Font=Enum.Font.RobotoMono,TextSize=40})
make("TextLabel",panel,{Position=UDim2.fromOffset(40,110),Size=UDim2.fromOffset(680,130),BackgroundTransparency=1,
 Text="You decided you could face this world alone. But the world swallowed you, and your empty shell is now just another part of its scenery.",
 TextColor3=Color3.fromRGB(190,188,175),Font=Enum.Font.RobotoMono,TextSize=22,TextWrapped=true})
local okay=make("TextButton",panel,{Name="AcknowledgeEnd",AnchorPoint=Vector2.new(.5,0),Position=UDim2.new(.5,0,0,285),Size=UDim2.fromOffset(150,44),Text="OK",BackgroundColor3=Color3.fromRGB(40,39,32),TextColor3=Color3.fromRGB(210,200,170),Font=Enum.Font.RobotoMono,TextSize=20})
local pending=false
local function refresh()
 local ended=player:GetAttribute("OutcastEnd")==true
 gui.Enabled=ended
 if not ended then pending=false;okay.Text="OK" end
 if ended then
  player:SetAttribute("MedicalMode",nil)
  Context:BindActionAtPriority("OutcastEndBlock",function() return Enum.ContextActionResult.Sink end,false,Enum.ContextActionPriority.High.Value+20,
   Enum.PlayerActions.CharacterForward,Enum.PlayerActions.CharacterBackward,Enum.PlayerActions.CharacterLeft,Enum.PlayerActions.CharacterRight,Enum.PlayerActions.CharacterJump,
   Enum.KeyCode.Q,Enum.KeyCode.E,Enum.KeyCode.C,Enum.KeyCode.T,Enum.KeyCode.G,Enum.KeyCode.H,Enum.KeyCode.Four,Enum.KeyCode.KeypadFour,Enum.KeyCode.F6)
 else Context:UnbindAction("OutcastEndBlock") end
end
okay.Activated:Connect(function()
 if pending or player:GetAttribute("OutcastEnd")~=true then return end
 pending=true;okay.Text="..."
 remote:FireServer()
 -- Keep the screen until the server has reset the character. Allow a retry if
 -- the request failed rather than dismissing locally or leaving a stuck button.
 task.delay(5,function() if gui.Enabled and pending then pending=false;okay.Text="OK" end end)
end)
player:GetAttributeChangedSignal("OutcastEnd"):Connect(refresh)
Run.RenderStepped:Connect(function()
 if not gui.Enabled then return end
 local camera=workspace.CurrentCamera
 if camera then scale.Scale=math.min(1,(camera.ViewportSize.X-32)/760,(camera.ViewportSize.Y-32)/360) end
end)
refresh()
