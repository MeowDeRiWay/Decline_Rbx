local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local Input=game:GetService("UserInputService")
local GuiService=game:GetService("GuiService")
local Debris=game:GetService("Debris")
local Cursor=require(script.Parent.CursorQuery)
local Locale=require(script.Parent.LocaleController)
local Config=require(ReplicatedStorage.Shared.VehicleConfig)
local Rules=require(ReplicatedStorage.Shared.VehicleRules)
local Interaction=require(ReplicatedStorage.Shared.Interaction)
local player=Players.LocalPlayer
local remotes=ReplicatedStorage:WaitForChild("VehicleRemotes")
local action=remotes:WaitForChild("Action")
local controls=remotes:WaitForChild("Input")
local vehicles={}
local hovered
local focused=true
local lastPacket=0
local previousVehicle
local function blocked()
 if not focused or GuiService.MenuIsOpen or Input:GetFocusedTextBox() then return true end
 for _,name in ipairs({"InventoryOpen","TradeOpen","ExchangeOpen","MapOpen","HelpOpen","AdminOpen","TownMenuOpen","ProgressionOpen","GroupOpen","LoadingScreenOpen"}) do
  if player:GetAttribute(name) then return true end
 end
 return false
end
local function vehicleOf(object)
 while object and object~=workspace do
  if object:GetAttribute("Vehicle")==true then return object end
  object=object.Parent
 end
end
local function seatContext()
 local c=player.Character
 local hp=c and c:FindFirstChildOfClass("Humanoid")
 local seat=hp and hp.SeatPart
 return seat and vehicleOf(seat),seat
end
local function recordComponent(data,model)
 if not model:IsA("Model") or not model:GetAttribute("VehicleComponent") or data.Components[model] then return end
 data.Components[model]={Kind=model:GetAttribute("VehicleComponent"),Spin=0}
end
local function register(model)
 if not model:IsA("Model") or model:GetAttribute("Vehicle")~=true or vehicles[model] then return end
 local data={Components={},Links={}}
 vehicles[model]=data
 for _,object in ipairs(model:GetDescendants()) do recordComponent(data,object) end
 table.insert(data.Links,model.DescendantAdded:Connect(function(object)
  task.defer(function() if vehicles[model]==data then recordComponent(data,object) end end)
 end))
 table.insert(data.Links,model.Destroying:Connect(function()
  for _,link in ipairs(data.Links) do link:Disconnect() end
  vehicles[model]=nil
 end))
end
task.spawn(function()
 local folder=workspace:WaitForChild("Vehicles")
 for _,model in ipairs(folder:GetChildren()) do register(model) end
 folder.ChildAdded:Connect(register)
end)
local gui=Instance.new("ScreenGui")
gui.Name="VehicleHUD";gui.ResetOnSpawn=false;gui:SetAttribute("LocalizationIgnore",true)
gui.Parent=player:WaitForChild("PlayerGui")
local panel=Instance.new("Frame")
panel.AnchorPoint=Vector2.new(1,0);panel.Position=UDim2.new(1,-20,0,65);panel.Size=UDim2.fromOffset(420,170)
local scale=Instance.new("UIScale");scale.Parent=panel
local function resize()
 local camera=workspace.CurrentCamera
 if camera then scale.Scale=math.min(1,(camera.ViewportSize.X-30)/420) end
end
resize()
panel.BackgroundColor3=Color3.fromRGB(31,32,24);panel.BackgroundTransparency=.12
panel.BorderColor3=Color3.fromRGB(104,102,65);panel.Visible=false;panel.Parent=gui
local function label(y,height)
 local text=Instance.new("TextLabel");text.BackgroundTransparency=1
 text.Position=UDim2.fromOffset(10,y);text.Size=UDim2.new(1,-20,0,height)
 text.TextXAlignment=Enum.TextXAlignment.Left;text.TextColor3=Color3.fromRGB(207,207,164)
 text.Font=Enum.Font.Code;text.TextSize=14;text.Text="";text.Parent=panel
 return text
end
local stateLabel=label(5,22)
local speedLabel=label(27,44);speedLabel.TextSize=32
local revLabel=label(72,22)
local resourceLabel=label(105,22)
local keysLabel=label(133,30);keysLabel.TextSize=12;keysLabel.TextWrapped=true
local rpmTrack=Instance.new("Frame");rpmTrack.Position=UDim2.new(0,10,0,97)
rpmTrack.Size=UDim2.new(1,-20,0,5);rpmTrack.BackgroundColor3=Color3.fromRGB(55,56,40)
rpmTrack.BorderSizePixel=0;rpmTrack.Parent=panel
local rpmBar=Instance.new("Frame");rpmBar.BorderSizePixel=0;rpmBar.Size=UDim2.fromScale(0,1)
rpmBar.BackgroundColor3=Color3.fromRGB(150,180,90);rpmBar.Parent=rpmTrack
local prompt=Instance.new("TextLabel")
prompt.AnchorPoint=Vector2.new(.5,0);prompt.Position=UDim2.new(.5,0,0,65)
prompt.Size=UDim2.fromOffset(340,30);prompt.BackgroundColor3=panel.BackgroundColor3
prompt.BackgroundTransparency=.15;prompt.BorderSizePixel=0;prompt.TextColor3=stateLabel.TextColor3
prompt.Font=Enum.Font.Code;prompt.TextSize=15;prompt.Visible=false;prompt.Parent=gui
local highlight=Instance.new("Highlight")
highlight.Name="VehicleHover";highlight.DepthMode=Enum.HighlightDepthMode.Occluded
highlight.FillTransparency=.75;highlight.FillColor=Color3.fromRGB(110,210,140)
highlight.OutlineColor=highlight.FillColor;highlight.Enabled=false;highlight.Parent=workspace
local function interactable(model)
 local kind=model:GetAttribute("VehicleComponent")
 if kind=="Door" or kind=="Hood" or kind=="Trunk" then return true end
 if kind=="DriverSeat" or kind=="PassengerSeat" then
  local door=model:FindFirstChild("EntryDoor")
  local seat=model:FindFirstChildWhichIsA("Seat",true) or model:FindFirstChildWhichIsA("VehicleSeat",true)
  return seat and not seat.Occupant and (not door or door.Value and door.Value:GetAttribute("Open")==true)
 end
 return false
end
Cursor.Subscribe("Vehicles",3,function()
 hovered=nil;highlight.Enabled=false;prompt.Visible=false
 local c=player.Character
 local root=c and c:FindFirstChild("HumanoidRootPart")
 if not root or blocked() or c:GetAttribute("VehicleSeated") or c:GetAttribute("Knockout") or c:GetAttribute("IsDead") then return end
 local sample=Cursor.Get()
 if not sample then return end
 local candidates={}
 for vehicle,data in pairs(vehicles) do
  if not vehicle:IsDescendantOf(workspace) then continue end
  for model in pairs(data.Components) do
   if model.Parent and interactable(model) and Interaction.Distance(model,root.Position)<=Config.InteractionDistance then
    table.insert(candidates,model)
   end
  end
 end
 if #candidates==0 then return end
 local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Include;params.FilterDescendantsInstances=candidates
 local hit=workspace:Raycast(sample.Ray.Origin,sample.Ray.Direction*1000,params)
 if not hit then return end
 local target=hit.Instance
 while target and target~=workspace and not target:GetAttribute("VehicleComponent") do target=target.Parent end
 if not target or target==workspace then return end
 -- Seats can be selected inside their own car, never through a building.
 local first=sample.Hit
 if first and (first.Position-sample.Ray.Origin).Magnitude+ .03<hit.Distance
  and vehicleOf(first.Instance)~=vehicleOf(target) then return end
 hovered=target;highlight.Adornee=target;highlight.Enabled=true
 local kind=target:GetAttribute("VehicleComponent")
 local text=(kind=="DriverSeat" or kind=="PassengerSeat") and "E · Sit"
  or target:GetAttribute("Open") and "E · Close" or "E · Open"
 prompt.Text=Locale.Text(text);prompt.Visible=true
end)
local gearKeys={
 [Enum.KeyCode.One]=1,[Enum.KeyCode.Two]=2,[Enum.KeyCode.Three]=3,
 [Enum.KeyCode.Four]=4,[Enum.KeyCode.Five]=5,[Enum.KeyCode.Six]=6,
 [Enum.KeyCode.Seven]=7,[Enum.KeyCode.Eight]=8,[Enum.KeyCode.Nine]=9,
 [Enum.KeyCode.N]=0,[Enum.KeyCode.R]=-1,
}
Input.InputBegan:Connect(function(input,processed)
 if processed or blocked() then return end
 local vehicle=seatContext()
 if not vehicle and input.KeyCode==Enum.KeyCode.E and hovered then action:FireServer("Interact",hovered)
 elseif vehicle then
  if input.KeyCode==Enum.KeyCode.X then action:FireServer("Exit")
  elseif input.KeyCode==Enum.KeyCode.V then action:FireServer("Engine")
  elseif input.KeyCode==Enum.KeyCode.L then action:FireServer("Lights")
  elseif gearKeys[input.KeyCode]~=nil then action:FireServer("Gear",gearKeys[input.KeyCode]) end
 end
end)
Input.WindowFocusReleased:Connect(function() focused=false;controls:FireServer(0,0) end)
Input.WindowFocused:Connect(function() focused=true end)
local hudElapsed=0
RunService.RenderStepped:Connect(function(dt)
 local vehicle,seat=seatContext()
 panel.Visible=vehicle~=nil
 if vehicle and seat:IsA("VehicleSeat") then
  if os.clock()-lastPacket>=1/15 then
   lastPacket=os.clock()
   local throttle,steer=0,0
   if not blocked() then
    throttle=(Input:IsKeyDown(Enum.KeyCode.W) and 1 or 0)-(Input:IsKeyDown(Enum.KeyCode.S) and 1 or 0)
    steer=(Input:IsKeyDown(Enum.KeyCode.D) and 1 or 0)-(Input:IsKeyDown(Enum.KeyCode.A) and 1 or 0)
   end
   controls:FireServer(throttle,steer)
  end
 elseif previousVehicle then controls:FireServer(0,0) end
 previousVehicle=vehicle
 hudElapsed+=dt
 if not vehicle or hudElapsed<.1 then return end
 hudElapsed=0
 local state=vehicle:GetAttribute("EngineStarting") and "Starting" or vehicle:GetAttribute("EngineOn") and "Running" or "Stopped"
 stateLabel.Text=Locale.Text(vehicle:GetAttribute("DisplayName") or "Interceptor").." · "..Locale.Text(state)
 resize()
 local ukrainian=Locale.Language()=="uk"
 local speed=math.abs(vehicle:GetAttribute("Speed") or 0)*(ukrainian and 3.6 or 2.236936)
 local gear=vehicle:GetAttribute("Gear") or 0
 local gearText=gear==-1 and "R" or gear==0 and "N" or tostring(gear)
 speedLabel.Text=string.format("%03d %s     [%s]",math.floor(speed+.5),ukrainian and "км/год" or "mph",gearText)
 local rpm=vehicle:GetAttribute("RPM") or 0
 revLabel.Text=string.format(Locale.Text("Engine %d RPM · Gear %s"),rpm,gearText)
 rpmBar.Size=UDim2.fromScale(math.clamp(rpm/Config.RedlineRPM,0,1),1)
 rpmBar.BackgroundColor3=rpm>Config.RedlineRPM*.85 and Color3.fromRGB(210,100,65) or Color3.fromRGB(150,180,90)
 resourceLabel.Text=string.format(Locale.Text("Fuel %.1f L · Battery %.2f V"),vehicle:GetAttribute("Fuel") or 0,vehicle:GetAttribute("Charge") or 0)
 keysLabel.Text=seat:IsA("VehicleSeat") and string.format(Locale.Text("WASD · Drive   1–%d · Gear   N · Neutral   R · Reverse   V · Engine   L · Lights   X · Exit"),#Config.GearSpeeds) or Locale.Text("X · Exit")
end)
RunService.PreSimulation:Connect(function(dt)
 local c=player.Character
 local root=c and c:FindFirstChild("HumanoidRootPart")
 if not root then return end
 for vehicle,data in pairs(vehicles) do
  if not vehicle.Parent or (vehicle:GetPivot().Position-root.Position).Magnitude>200 then continue end
  local speed=vehicle:GetAttribute("Speed") or 0
  local steer=vehicle:GetAttribute("Steering") or 0
  for model,record in pairs(data.Components) do
   if not model:IsDescendantOf(vehicle) then data.Components[model]=nil;continue end
   if record.Kind~="Wheel" and record.Kind~="SteeringWheel" then continue end
   local motor=model:FindFirstChild("VehicleJoint",true)
   if not motor then continue end
   if record.Kind=="Wheel" then
    record.Spin=(record.Spin-speed*dt/math.max(.05,model:GetAttribute("WheelRadius") or .3))%(2*math.pi)
    local rest=motor:GetAttribute("VehicleRestC0") or motor.C0
    local rotation=rest-rest.Position
    local turn=model:GetAttribute("Steerable") and -steer*math.rad(Config.SteeringAngle) or 0
    motor.Transform=rotation:Inverse()*CFrame.Angles(0,turn,0)*rotation*CFrame.Angles(record.Spin,0,0)
   else motor.Transform=CFrame.Angles(0,0,-steer*math.rad(120)) end
  end
 end
end)
remotes:WaitForChild("Effects").OnClientEvent:Connect(function(point,radius)
 if typeof(point)~="Vector3" or typeof(radius)~="number" then return end
 local explosion=Instance.new("Explosion")
 explosion.Position=point;explosion.BlastRadius=radius
 explosion.BlastPressure=0;explosion.DestroyJointRadiusPercent=0
 explosion.ExplosionType=Enum.ExplosionType.NoCraters;explosion.Parent=workspace
 Debris:AddItem(explosion,2)
end)
