local Players=game:GetService("Players")
local Storage=game:GetService("ReplicatedStorage")
local Input=game:GetService("UserInputService")
local player=Players.LocalPlayer
while player:GetAttribute("AdminAccess")==nil do player:GetAttributeChangedSignal("AdminAccess"):Wait() end
if player:GetAttribute("AdminAccess")~=true then return end
local remote=Storage:WaitForChild("AdminAction")
local Theme=require(Storage.Shared.UITheme)
local Items=require(Storage.Shared.ItemConfig).Items
local gui=Instance.new("ScreenGui")
gui.Name="AdminMenu";gui.ResetOnSpawn=false;gui.DisplayOrder=80;gui.Parent=player:WaitForChild("PlayerGui")
local function make(class,parent,props)
 local object=Instance.new(class)
 for key,value in pairs(props or {}) do object[key]=value end
 object.Parent=parent
 return object
end
local function label(parent,text,x,y,w,h)
 return make("TextLabel",parent,{Text=text,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),BackgroundTransparency=1,TextColor3=Theme.Text,Font=Theme.Font,TextSize=14,TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=true})
end
local function button(parent,text,x,y,w,callback)
 local b=make("TextButton",parent,{Text=text,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,32),BackgroundColor3=Theme.Button,TextColor3=Theme.Text,Font=Theme.Font,TextSize=14,BorderColor3=Theme.Border})
 b.Activated:Connect(callback)
 return b
end
local function field(parent,text,x,y,w)
 return make("TextBox",parent,{Text=text,ClearTextOnFocus=false,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,32),BackgroundColor3=Theme.Card,TextColor3=Theme.Accent,Font=Theme.Font,TextSize=14,BorderColor3=Theme.Border})
end
local function scroll(parent,x,y,w,h)
 local frame=make("ScrollingFrame",parent,{Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),BackgroundColor3=Theme.Card,BorderSizePixel=0,ScrollBarThickness=6,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y})
 make("UIListLayout",frame,{Padding=UDim.new(0,4),SortOrder=Enum.SortOrder.LayoutOrder})
 return frame
end
local panel=make("Frame",gui,{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(760,530),BackgroundColor3=Theme.Background,Visible=false})
Theme.Bevel(panel)
local scale=make("UIScale",panel,{Scale=1})
local function resize()
 local camera=workspace.CurrentCamera
 if camera then scale.Scale=math.min(1,(camera.ViewportSize.X-24)/760,(camera.ViewportSize.Y-80)/530) end
end
local opener=button(gui,"ADMIN [F6]",0,0,130,function() end)
opener.AnchorPoint=Vector2.new(1,1);opener.Position=UDim2.new(1,-16,1,-16)
local status=label(panel,"Ready.",16,486,728,32)
local busy=false
local function request(command,data)
 if busy then return end
 busy=true;status.Text="Working...";status.TextColor3=Theme.Muted
 task.spawn(function()
  local ok,result=pcall(function() return remote:InvokeServer(command,data) end)
  busy=false
  status.Text=ok and result.Message or "Server request failed."
  status.TextColor3=ok and result.OK and Theme.Green or Theme.Danger
 end)
end
local function setOpen(value)
 if value and (player:GetAttribute("InventoryOpen") or player:GetAttribute("TownMenuOpen") or player:GetAttribute("ProgressionOpen") or player:GetAttribute("GroupOpen")) then return end
 resize();panel.Visible=value;player:SetAttribute("AdminOpen",value)
 if value then player:SetAttribute("MedicalMode",nil) end
end
opener.Activated:Connect(function() setOpen(not panel.Visible) end)
label(panel,"DECLINE / ADMINISTRATION",16,8,660,32)
button(panel,"X",704,8,40,function() setOpen(false) end)
local pages={}
for _,name in ipairs({"Time","Characters","Items"}) do pages[name]=make("Frame",panel,{Position=UDim2.fromOffset(16,92),Size=UDim2.fromOffset(728,380),BackgroundTransparency=1,Visible=name=="Time"}) end
for index,name in ipairs({"Time","Characters","Items"}) do
 button(panel,name,16+(index-1)*244,50,236,function() for id,page in pairs(pages) do page.Visible=id==name end end)
end
local time=pages.Time
local clockLabel=label(time,"",0,0,720,38)
label(time,"Hour (0-23.999)",0,54,220,30)
local hour=field(time,"8",0,88,150)
button(time,"Set hour",162,88,150,function() request("SetHour",{Value=tonumber(hour.Text)}) end)
label(time,"Day speed (0.01-100x; 1x = 60-minute day)",0,138,700,30)
local speed=field(time,"1",0,174,150)
button(time,"Set speed",162,174,150,function() request("SetSpeed",{Value=tonumber(speed.Text)}) end)
button(time,"Pause",0,230,150,function() request("Pause",{Value=true}) end)
button(time,"Resume",162,230,150,function() request("Pause",{Value=false}) end)
label(time,"Changes apply to everyone in this server.",0,290,700,50)
local characters=pages.Characters
local playerList=scroll(characters,0,0,285,376)
local targetId=player.UserId
local targetLabel=label(characters,"",302,0,426,76)
local levels=field(characters,"1",302,92,110)
button(characters,"Add levels",424,92,200,function() request("Levels",{Target=targetId,Count=tonumber(levels.Text)}) end)
label(characters,"Normal skill and perk points. Maximum level: 30.",302,132,420,48)
button(characters,"Heal + cure sickness",302,194,400,function() request("Heal",{Target=targetId}) end)
button(characters,"Restore food + water",302,238,400,function() request("Needs",{Target=targetId}) end)
button(characters,"Revive from knockout",302,282,400,function() request("Revive",{Target=targetId}) end)
button(characters,"Reset to level 1 (skills + perks)",302,326,400,function() request("ResetProgression",{Target=targetId}) end)
local function refreshPlayers()
 for _,child in ipairs(playerList:GetChildren()) do if child:IsA("TextButton") then child:Destroy() end end
 local list=Players:GetPlayers();table.sort(list,function(a,b) return a.Name:lower()<b.Name:lower() end)
 for i,p in ipairs(list) do
  local b=button(playerList,p.DisplayName.." (@"..p.Name..")",0,0,275,function() targetId=p.UserId end)
  b.LayoutOrder=i;b.TextSize=12;b.TextWrapped=true;b.Size=UDim2.fromOffset(275,44)
 end
end
Players.PlayerAdded:Connect(refreshPlayers)
Players.PlayerRemoving:Connect(function(leaving)
 if targetId==leaving.UserId then targetId=player.UserId end
 task.defer(refreshPlayers)
end)
refreshPlayers()
local items=pages.Items
local search=field(items,"",0,0,480);search.PlaceholderText="Search item name or ID"
local quantity=field(items,"1",492,0,90)
label(items,"Quantity",592,0,130,32)
local itemList=scroll(items,0,44,728,332)
local function refreshItems()
 for _,child in ipairs(itemList:GetChildren()) do if child:IsA("Frame") then child:Destroy() end end
 local found={};local query=search.Text:lower()
 for id,item in pairs(Items) do
  if (item.Name.." "..id):lower():find(query,1,true) then table.insert(found,{ID=id,Item=item}) end
 end
 table.sort(found,function(a,b) return a.Item.Name==b.Item.Name and a.ID<b.ID or a.Item.Name<b.Item.Name end)
 for i,entry in ipairs(found) do
  local row=make("Frame",itemList,{Size=UDim2.fromOffset(712,48),BackgroundColor3=Theme.Panel,BorderSizePixel=0,LayoutOrder=i})
  label(row,entry.Item.Name,8,0,520,24)
  local idLabel=label(row,entry.ID.." / "..(entry.Item.Slot or "Item"),8,24,520,20);idLabel.TextSize=11;idLabel.TextColor3=Theme.Muted
  button(row,"Give to me",552,8,148,function() request("GiveItem",{ID=entry.ID,Count=tonumber(quantity.Text)}) end)
 end
 itemList.CanvasPosition=Vector2.zero
end
search:GetPropertyChangedSignal("Text"):Connect(refreshItems)
refreshItems()
Input.InputBegan:Connect(function(key,processed)
 if processed or Input:GetFocusedTextBox() then return end
 if key.KeyCode==Enum.KeyCode.F6 then setOpen(not panel.Visible) end
end)
for _,name in ipairs({"InventoryOpen","TownMenuOpen","ProgressionOpen","GroupOpen"}) do
 player:GetAttributeChangedSignal(name):Connect(function() if player:GetAttribute(name) then setOpen(false) end end)
end
task.spawn(function()
 while gui.Parent do
  if panel.Visible then
   resize()
   local h=workspace:GetAttribute("DayClockHour") or 8
   local minutes=math.floor(h*60)%1440
   clockLabel.Text=string.format("Server time %02d:%02d / %gx / %s",math.floor(minutes/60),minutes%60,workspace:GetAttribute("DayClockSpeed") or 1,workspace:GetAttribute("DayClockPaused") and "PAUSED" or "RUNNING")
   local target=Players:GetPlayerByUserId(targetId)
   local c=target and target.Character;local hp=c and c:FindFirstChildOfClass("Humanoid")
   targetLabel.Text=target and string.format("%s (@%s)\nLevel %d / HP %g / %g%s",target.DisplayName,target.Name,target:GetAttribute("CharacterLevel") or 0,hp and hp.Health or 0,hp and hp.MaxHealth or 0,c and c:GetAttribute("Knockout") and " / KNOCKOUT" or "") or "Select an online player."
  end
  task.wait(.5)
 end
end)
