-- ReplicatedFirst runs before the normal client scripts. Keep this UI self-contained.
local Players=game:GetService("Players")
local First=game:GetService("ReplicatedFirst")
local Tween=game:GetService("TweenService")
local Run=game:GetService("RunService")
local player=Players.LocalPlayer
local gui=Instance.new("ScreenGui")
gui.Name="DeclineLoading";gui.IgnoreGuiInset=true;gui.ResetOnSpawn=false;gui.DisplayOrder=1000
local function make(class,parent,props)
 local o=Instance.new(class)
 for key,value in pairs(props) do o[key]=value end
 o.Parent=parent;return o
end
local textColor=Color3.fromRGB(199,205,171)
local accent=Color3.fromRGB(178,195,126)
local background=make("CanvasGroup",gui,{Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.fromRGB(24,25,21),BorderSizePixel=0})
-- Consume pointer input until the town menu is ready.
make("TextButton",background,{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Text="",AutoButtonColor=false,Selectable=false})
local panel=make("Frame",background,{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.new(.85,0,0,280),BackgroundTransparency=1})
make("UISizeConstraint",panel,{MaxSize=Vector2.new(560,280)})
local function label(text,y,height,size,color)
 return make("TextLabel",panel,{Text=text,Position=UDim2.new(0,0,0,y),Size=UDim2.new(1,0,0,height),BackgroundTransparency=1,TextColor3=color or textColor,Font=Enum.Font.RobotoMono,TextSize=size,TextWrapped=true})
end
label("DECLINE",0,72,48,accent)
label("Choose your town. Find your place. Survive.",76,42,14)
local status=label("Connecting to the world...",142,36,16)
local track=make("Frame",panel,{Position=UDim2.new(0,0,0,188),Size=UDim2.new(1,0,0,5),BackgroundColor3=Color3.fromRGB(57,57,44),BorderSizePixel=0})
local fill=make("Frame",track,{Size=UDim2.fromScale(0,1),BackgroundColor3=accent,BorderSizePixel=0})
local steps=label("0 / 3",204,24,12)
local skip=make("TextButton",panel,{Text="Continue",Position=UDim2.new(.5,-90,0,246),Size=UDim2.fromOffset(180,32),BackgroundColor3=Color3.fromRGB(57,57,44),BorderColor3=Color3.fromRGB(103,100,76),TextColor3=textColor,Font=Enum.Font.RobotoMono,TextSize=14,Visible=false})
gui.Parent=player:WaitForChild("PlayerGui")
First:RemoveDefaultLoadingScreen()
player:SetAttribute("LoadingScreenOpen",true)
local started=os.clock()
local done=false
local connection
local function finish()
 if done then return end
 done=true
 if connection then connection:Disconnect() end
 player:SetAttribute("LoadingScreenOpen",false)
 local fade=Tween:Create(background,TweenInfo.new(.35),{GroupTransparency=1})
 fade:Play()
 fade.Completed:Once(function() gui:Destroy() end)
end
skip.Activated:Connect(finish)
local previous=-1
connection=Run.Heartbeat:Connect(function()
 local loaded=game:IsLoaded()
 local city=workspace:GetAttribute("InitialCityReady")==true
 local menu=player:GetAttribute("TownStateReady")==true
 local count=(loaded and 1 or 0)+(city and 1 or 0)+(menu and 1 or 0)
 if count~=previous then
  previous=count;steps.Text=count.." / 3"
  Tween:Create(fill,TweenInfo.new(.2),{Size=UDim2.fromScale(count/3,1)}):Play()
 end
 if not loaded then status.Text="Loading the world..."
 elseif not city then status.Text="Preparing the city..."
 elseif not menu then status.Text="Receiving towns..."
 else status.Text="Ready";finish();return end
 if os.clock()-started>=20 then
  skip.Visible=true
  steps.Text="Taking longer than usual. You can continue waiting."
 end
end)
