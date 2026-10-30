local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Input=game:GetService("UserInputService")
local Context=game:GetService("ContextActionService")
local Run=game:GetService("RunService")
local GuiService=game:GetService("GuiService")
local Theme=require(ReplicatedStorage.Shared.UITheme)
local Rules=require(ReplicatedStorage.Shared.MapRules)
local player=Players.LocalPlayer
local state=ReplicatedStorage:WaitForChild("MapState")
local request=ReplicatedStorage:WaitForChild("MapRequest")
local function make(class,parent,props)
 local o=Instance.new(class);for k,v in pairs(props) do o[k]=v end;o.Parent=parent;return o
end
local function label(parent,text,position,size,fontSize)
 return make("TextLabel",parent,{Text=text,Position=position,Size=size,TextColor3=Theme.Text,Font=Theme.Font,TextSize=fontSize or 15,BackgroundTransparency=1})
end
local function button(parent,text,position,size)
 local b=make("TextButton",parent,{Text=text,Position=position,Size=size,BackgroundColor3=Theme.Button,TextColor3=Theme.Text,Font=Theme.Font,TextSize=15});Theme.Bevel(b);return b
end
local gui=make("ScreenGui",player:WaitForChild("PlayerGui"),{Name="WorldMap",ResetOnSpawn=false,DisplayOrder=75,Enabled=false})
local cover=make("TextButton",gui,{Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.new(),BackgroundTransparency=.35,Text="",AutoButtonColor=false,Modal=true,Selectable=false})
local panel=make("Frame",cover,{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(900,620),BackgroundColor3=Theme.Panel})
Theme.Bevel(panel)
local scale=make("UIScale",panel,{Scale=1})
label(panel,"MAP",UDim2.fromOffset(16,10),UDim2.fromOffset(150,34),24).TextXAlignment=Enum.TextXAlignment.Left
local info=label(panel,"",UDim2.fromOffset(175,13),UDim2.fromOffset(500,28),13)
local center=button(panel,"Center",UDim2.new(1,-166,0,12),UDim2.fromOffset(100,28))
local close=button(panel,"X",UDim2.new(1,-50,0,12),UDim2.fromOffset(32,28))
local view=make("Frame",panel,{Name="MapViewport",Position=UDim2.fromOffset(16,56),Size=UDim2.new(1,-32,1,-156),BackgroundColor3=Color3.fromRGB(9,12,10),BorderSizePixel=0,ClipsDescendants=true,Active=true})
local tiles=make("Frame",view,{Size=UDim2.fromScale(1,1),BackgroundTransparency=1})
local arrow=label(view,"▲",UDim2.new(),UDim2.fromOffset(24,24),23)
arrow.AnchorPoint=Vector2.new(.5,.5);arrow.TextColor3=Color3.fromRGB(245,237,195);arrow.ZIndex=5
label(panel,"Drag to pan  ·  Wheel to zoom  ·  M to close  ·  North ↑",UDim2.new(0,16,1,-88),UDim2.new(1,-32,0,25),13)
local colors={Ground=Color3.fromRGB(54,64,43),Forest=Color3.fromRGB(31,64,35),ScrapYard=Color3.fromRGB(90,75,57),StoneYard=Color3.fromRGB(109,108,92),House=Color3.fromRGB(207,165,139),Infrastructure=Color3.fromRGB(71,132,192)}
local legend={{"House",colors.House},{"Infrastructure",colors.Infrastructure},{"Forest",colors.Forest},{"Scrapyard",colors.ScrapYard},{"Unexplored",view.BackgroundColor3}}
for i,entry in ipairs(legend) do
 make("Frame",panel,{Position=UDim2.new(0,18+(i-1)*173,1,-43),Size=UDim2.fromOffset(12,12),BorderSizePixel=0,BackgroundColor3=entry[2]})
 local t=label(panel,entry[1],UDim2.new(0,35+(i-1)*173,1,-48),UDim2.fromOffset(145,24),12);t.TextXAlignment=Enum.TextXAlignment.Left
end
local explored={}
local originX,originZ=0,0
local zoom=1
local focusX,focusZ=0,0 -- world studs relative to grid origin; one stud is one base pixel.
local dragging
local dirty=true
local pool={}
local function tile(index)
 if pool[index] then return pool[index] end
 local f=make("Frame",tiles,{BorderSizePixel=0})
 local a=make("Frame",f,{BorderSizePixel=0,ZIndex=3})
 local b=make("Frame",f,{BorderSizePixel=0})
 local icon=label(f,"",UDim2.new(),UDim2.fromScale(1,1),13)
 icon.ZIndex=4
 pool[index]={Frame=f,A=a,B=b,Icon=icon,Roads={}};return pool[index]
end
local function paint(t,cell,x,z,size)
 local kind,mask=cell.Kind,cell.RoadMask or 0
 t.Frame.Position=UDim2.fromOffset(x,z);t.Frame.Size=UDim2.fromOffset(size,size)
 if t.Kind==kind and t.Mask==mask and t.Zoom==zoom then return end
 t.Kind,t.Mask,t.Zoom=kind,mask,zoom
 t.Frame.BackgroundColor3=colors[kind] or colors.Ground
 t.A.Visible=false;t.B.Visible=false;t.Icon.Text=""
 if kind=="House" or kind=="Infrastructure" then
  t.Frame.BackgroundColor3=colors.Ground;t.A.Visible=true;t.A.BackgroundColor3=colors[kind]
  t.A.Position=UDim2.fromScale(.1,.1);t.A.Size=UDim2.fromScale(.8,.8)
 elseif kind=="ScrapYard" then t.Icon.Text="▪▫";t.Icon.TextColor3=Color3.fromRGB(155,142,115)
 elseif kind=="StoneYard" then t.Icon.Text="◆";t.Icon.TextColor3=Color3.fromRGB(160,159,142) end
 if mask~=0 then t.Icon.Text="" end
 local rectangles=Rules.RoadRects(mask)
 for i,rect in ipairs(rectangles) do
  local road=t.Roads[i]
  if not road then road=make("Frame",t.Frame,{BorderSizePixel=0,ZIndex=2,BackgroundColor3=Color3.fromRGB(133,132,121)});t.Roads[i]=road end
  road.Visible=true;road.Position=UDim2.fromScale(rect.X,rect.Z);road.Size=UDim2.fromScale(rect.W,rect.H)
 end
 for i=#rectangles+1,#t.Roads do t.Roads[i].Visible=false end
 t.Icon.TextSize=math.max(8,math.floor(14*zoom))
end
local function draw()
 local w,h=view.AbsoluteSize.X/scale.Scale,view.AbsoluteSize.Y/scale.Scale
 local cellSize=20*zoom
 local minX=math.floor((focusX-w/(2*zoom))/20)
 local maxX=math.floor((focusX+w/(2*zoom))/20)
 local minZ=math.floor((focusZ-h/(2*zoom))/20)
 local maxZ=math.floor((focusZ+h/(2*zoom))/20)
 local used=0
 -- Virtualize: only explored cells currently inside the viewport get UI objects.
 for z=minZ,maxZ do for x=minX,maxX do
  local cell=explored[Rules.Key(x,z)]
  if cell then
   used+=1;local t=tile(used);t.Frame.Visible=true
   paint(t,cell,w/2+(x*20-focusX)*zoom,h/2+(z*20-focusZ)*zoom,cellSize)
  end
 end end
 for i=used+1,#pool do pool[i].Frame.Visible=false end
 info.Text=string.format("%d%%  ·  20 studs = 20 px at 100%%",math.floor(zoom*100+.5))
 dirty=false
end
local function recenter()
 local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
 if root then focusX=root.Position.X-originX;focusZ=root.Position.Z-originZ end
 dirty=true
end
local function busy()
 if GuiService.MenuIsOpen then return true end
 for _,name in ipairs({"TradeOpen","InventoryOpen","TownMenuOpen","ProgressionOpen","GroupOpen","AdminOpen","FarmMenuOpen","HelpOpen","LoadingScreenOpen","OutcastEnd"}) do if player:GetAttribute(name) then return true end end
 return false
end
local function setOpen(open)
 local character=player.Character
 if open and (busy() or not character or character:GetAttribute("Knockout") or character:GetAttribute("IsDead") or player:GetAttribute("AttributesConfirmed")~=true) then return end
 gui.Enabled=open;player:SetAttribute("MapOpen",open);dragging=nil
 if open then
  player:SetAttribute("MedicalMode",nil);recenter();request:FireServer()
  Context:BindActionAtPriority("MapBlockInput",function() return Enum.ContextActionResult.Sink end,false,Enum.ContextActionPriority.High.Value+12,
   Enum.PlayerActions.CharacterForward,Enum.PlayerActions.CharacterBackward,Enum.PlayerActions.CharacterLeft,Enum.PlayerActions.CharacterRight,Enum.PlayerActions.CharacterJump,
   Enum.KeyCode.One,Enum.KeyCode.Two,Enum.KeyCode.KeypadOne,Enum.KeyCode.KeypadTwo,Enum.KeyCode.Q,Enum.KeyCode.E,Enum.KeyCode.C,Enum.KeyCode.T,Enum.KeyCode.G,Enum.KeyCode.H,Enum.KeyCode.R,Enum.KeyCode.V,Enum.KeyCode.B,Enum.KeyCode.Four,Enum.KeyCode.KeypadFour,Enum.KeyCode.F6)
 else Context:UnbindAction("MapBlockInput") end
end
close.Activated:Connect(function() setOpen(false) end)
center.Activated:Connect(recenter)
Input.InputBegan:Connect(function(input,processed)
 if not processed and not Input:GetFocusedTextBox() and input.KeyCode==Enum.KeyCode.M then setOpen(not gui.Enabled) end
end)
view.InputBegan:Connect(function(input)
 if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then dragging={Input=input,Position=input.Position} end
end)
Input.InputChanged:Connect(function(input)
 if not gui.Enabled then return end
 if input.UserInputType==Enum.UserInputType.MouseWheel then
  local mouse=Input:GetMouseLocation();local p,s=view.AbsolutePosition,view.AbsoluteSize
  if mouse.X>=p.X and mouse.Y>=p.Y and mouse.X<=p.X+s.X and mouse.Y<=p.Y+s.Y then zoom=math.clamp(zoom*1.2^input.Position.Z,.5,4);dirty=true end
 elseif dragging and (input.UserInputType==Enum.UserInputType.MouseMovement or input==dragging.Input) then
  local delta=input.Position-dragging.Position
  focusX-=delta.X/(scale.Scale*zoom);focusZ-=delta.Y/(scale.Scale*zoom)
  dragging.Position=input.Position;dirty=true
 end
end)
Input.InputEnded:Connect(function(input)
 if dragging and (input==dragging.Input or input.UserInputType==Enum.UserInputType.MouseButton1) then dragging=nil end
end)
Input.WindowFocusReleased:Connect(function() dragging=nil end)
state.OnClientEvent:Connect(function(packet)
 if packet.Reset then explored={} end
 originX,originZ=packet.OriginX,packet.OriginZ
 for _,cell in ipairs(packet.Cells) do explored[Rules.Key(cell.X,cell.Z)]=cell end
 dirty=true
end)
player.CharacterRemoving:Connect(function() setOpen(false) end)
Run.RenderStepped:Connect(function()
 if not gui.Enabled then return end
 local character=player.Character
 if not character or character:GetAttribute("Knockout") or character:GetAttribute("IsDead") or busy() then setOpen(false);return end
 local camera=workspace.CurrentCamera
 if camera then
  local size=math.min(1,(camera.ViewportSize.X-24)/900,(camera.ViewportSize.Y-24)/620)
  if scale.Scale~=size then scale.Scale=size;dirty=true end
 end
 local hp=character:FindFirstChildOfClass("Humanoid");if hp then hp:Move(Vector3.zero,false) end
 if dirty then draw() end
 local root=character:FindFirstChild("HumanoidRootPart")
 if root then
  local w,h=view.AbsoluteSize.X/scale.Scale,view.AbsoluteSize.Y/scale.Scale
  arrow.Position=UDim2.fromOffset(w/2+(root.Position.X-originX-focusX)*zoom,h/2+(root.Position.Z-originZ-focusZ)*zoom)
  arrow.Rotation=math.deg(math.atan2(root.CFrame.LookVector.X,-root.CFrame.LookVector.Z))
  arrow.Visible=true
 else arrow.Visible=false end
end)
request:FireServer()
