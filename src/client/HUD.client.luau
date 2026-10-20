local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Run=game:GetService("RunService")
local Input=game:GetService("UserInputService")
local Chat=game:GetService("TextChatService")
local Theme=require(ReplicatedStorage.Shared.UITheme)
local Professions=require(ReplicatedStorage.Shared.ProgressionConfig).Professions
local Layout=require(script.Parent.HUDLayout)
local Visibility=require(script.Parent.EventVisibility)
local Presentation=require(ReplicatedStorage.Shared.JournalPresentation)
local player=Players.LocalPlayer
local bar=Layout.Bar
local function label(parent,text,x,y,w,h,size)
 local t=Instance.new("TextLabel")
 t.Position=UDim2.fromOffset(x,y);t.Size=UDim2.fromOffset(w,h);t.BackgroundTransparency=1
 t.Font=Theme.Font;t.TextSize=size or 15;t.TextColor3=Theme.Text;t.Text=text;t.TextWrapped=true;t.Parent=parent
 return t
end
local function button(text,x,y,w,callback)
 local b=Instance.new("TextButton")
 b.Position=UDim2.fromOffset(x,y);b.Size=UDim2.fromOffset(w,38);b.BackgroundColor3=Theme.Button
 b.Font=Theme.Font;b.TextSize=14;b.TextColor3=Theme.Text;b.Text=text;b.Parent=bar;Theme.Bevel(b)
 b.Activated:Connect(callback);return b
end
-- A persistent, bounded event/chat journal. Only filtered TextChatService messages enter it.
local journal=Instance.new("ScrollingFrame")
journal.Position=UDim2.fromOffset(12,28);journal.Size=UDim2.fromOffset(330,98)
journal.BackgroundColor3=Theme.Card;journal.BorderSizePixel=0;journal.ScrollBarThickness=4
journal.AutomaticCanvasSize=Enum.AutomaticSize.Y;journal.CanvasSize=UDim2.new();journal.Parent=bar
local list=Instance.new("UIListLayout");list.Padding=UDim.new(0,3);list.Parent=journal
local rows={}
local function log(message)
 local row=label(journal,Presentation.Plain(message),0,0,320,0,12)
 row.AutomaticSize=Enum.AutomaticSize.Y;row.TextXAlignment=Enum.TextXAlignment.Left
 table.insert(rows,row)
 if #rows>100 then table.remove(rows,1):Destroy() end
 task.defer(function() journal.CanvasPosition=Vector2.new(0,math.max(0,journal.AbsoluteCanvasSize.Y-journal.AbsoluteSize.Y)) end)
end
Layout.Log.Event:Connect(log)
ReplicatedStorage:WaitForChild("CombatReport").OnClientEvent:Connect(function(event)
 if typeof(event)~="table" then return end
 if Visibility.Witnessed(event,player.Character,workspace.CurrentCamera) then log(Presentation.Combat(event)) end
end)
ReplicatedStorage:WaitForChild("PersonalNotice").OnClientEvent:Connect(log)
label(bar,"Events / chat",12,4,220,20,12)
local entry=Instance.new("TextBox")
entry.Position=UDim2.fromOffset(12,132);entry.Size=UDim2.fromOffset(330,26)
entry.BackgroundColor3=Theme.Card;entry.TextColor3=Theme.Text;entry.Font=Theme.Font;entry.TextSize=12
entry.PlaceholderText="Press / or click to chat";entry.Text="";entry.ClearTextOnFocus=false;entry.Parent=bar
Chat.ChatWindowConfiguration.Enabled=false
Chat.ChatInputBarConfiguration.Enabled=false
Chat.BubbleChatConfiguration.Enabled=false
local received={}
Chat.MessageReceived:Connect(function(message)
 if message.Status~=Enum.TextChatMessageStatus.Success then return end
 local id=message.MessageId
 if received[id] then return end
 received[id]=true
 task.delay(120,function() received[id]=nil end)
 local source=message.TextSource
 local sender=source and Players:GetPlayerByUserId(source.UserId)
 log((sender and (sender.DisplayName..": ") or "")..message.Text)
end)
entry.FocusLost:Connect(function(enter)
 if not enter or entry.Text:match("^%s*$") then return end
 local message=entry.Text;entry.Text=""
 task.spawn(function()
  local channels=Chat:FindFirstChild("TextChannels")
  local channel=Chat.ChatInputBarConfiguration.TargetTextChannel or (channels and channels:FindFirstChild("RBXGeneral"))
  local ok=channel and pcall(function() channel:SendAsync(message) end)
  if not ok then log("Chat is currently unavailable.") end
 end)
end)
Input.InputBegan:Connect(function(key,processed)
 if not processed and key.KeyCode==Enum.KeyCode.Slash and not Input:GetFocusedTextBox() then task.defer(function() entry:CaptureFocus() end) end
end)
local level=button("Level",12,-48,90,function() Layout.Character:Fire() end)
level.Visible=false
button("Holster",356,28,70,function() ReplicatedStorage.InventoryRemotes.Action:FireServer("Holster") end)
button("Inv",356,72,70,function() Layout.Inventory:Fire() end)
local menu=Instance.new("Frame")
menu.AnchorPoint=Vector2.new(.5,.5);menu.Position=UDim2.fromScale(.5,.45);menu.Size=UDim2.fromOffset(330,150)
menu.BackgroundColor3=Theme.Panel;menu.Visible=false;menu.Parent=Layout.Gui;Theme.Bevel(menu)
local menuTitle=label(menu,"Settings",12,10,306,32,20)
local menuBody=label(menu,"Sound and graphics settings will be added here.",20,48,290,70,14)
button("Menu",356,116,70,function()
 menu.Visible=not menu.Visible;menuTitle.Text="Settings";menuBody.Text="Sound and graphics settings will be added here."
end)
local dismiss=Instance.new("TextButton")
dismiss.Position=UDim2.new(1,-34,0,8);dismiss.Size=UDim2.fromOffset(26,26);dismiss.Text="×";dismiss.BackgroundColor3=Theme.Button;dismiss.TextColor3=Theme.Text;dismiss.Parent=menu
dismiss.Activated:Connect(function() menu.Visible=false end)
local health=label(bar,"HP —",658,42,116,35,23)
local armor=label(bar,"AC 0",658,88,116,35,23)
local staminaTrack=Instance.new("Frame")
staminaTrack.Position=UDim2.fromOffset(442,10);staminaTrack.Size=UDim2.fromOffset(204,8)
staminaTrack.BackgroundColor3=Theme.Card;staminaTrack.BorderSizePixel=0;staminaTrack.Parent=bar
local stamina=Instance.new("Frame")
stamina.Size=UDim2.fromScale(1,1);stamina.BackgroundColor3=Theme.Green;stamina.BorderSizePixel=0;stamina.Parent=staminaTrack

button("Skills",792,48,88,function()
 menu.Visible=not menu.Visible
 if menu.Visible then
  menuTitle.Text="Skills"
  local id=player:GetAttribute("Profession") or ""
  local profession=Professions[id]
  local stations,buildings={},{}
  for name in pairs(profession and profession.Stations or {}) do table.insert(stations,name=="CuttingBoard" and "cutting board" or name:lower()) end
  for name in pairs(profession and profession.Buildings or {}) do table.insert(buildings,name:lower()) end
  table.sort(stations);table.sort(buildings)
  menuBody.Text="Profession: "..(profession and profession.Name or "None").."\nSpecialty stations: "..(#stations>0 and table.concat(stations,", ") or "none").."\nBuildings: "..(#buildings>0 and table.concat(buildings,", ") or "none")
 end
end)
button("Cha",792,94,88,function() Layout.Character:Fire() end)
local combat=Instance.new("Frame")
combat.Position=UDim2.fromOffset(918,60);combat.Size=UDim2.fromOffset(62,62);combat.BackgroundColor3=Theme.Card;combat.Parent=bar;Theme.Bevel(combat)
label(bar,"Combat",894,128,110,20,12)
-- Track only models with the AI's replicated target attribute, not every part each frame.
local zombies,tracking={},{}
local function consider(object)
 if not object:IsA("Model") or not object:IsDescendantOf(workspace) or tracking[object] then return end
 if object:GetAttribute("TargetName")~=nil then zombies[object]=true end
 tracking[object]=object:GetAttributeChangedSignal("TargetName"):Connect(function() zombies[object]=true end)
end
workspace.DescendantRemoving:Connect(function(object)
 if tracking[object] then tracking[object]:Disconnect();tracking[object]=nil;zombies[object]=nil end
end)
for _,object in ipairs(workspace:GetDescendants()) do consider(object) end
workspace.DescendantAdded:Connect(function(object) if object:IsA("Model") then task.defer(consider,object) end end)
local elapsed=0
Run.Heartbeat:Connect(function(dt)
 elapsed+=dt;if elapsed<.25 then return end;elapsed=0
 level.Visible=(player:GetAttribute("AttributePoints") or 0)>0 or (player:GetAttribute("TalentPoints") or 0)>0
 local character=player.Character
 health.Text=string.format("HP %03d",character and character:GetAttribute("Health") or 0)
 armor.Text=string.format("AC %02d",math.floor((player:GetAttribute("DodgeChance") or 0)*100+.5))
 local remaining=character and character:GetAttribute("SprintRemaining") or 20
 local maximum=character and character:GetAttribute("SprintMaximum") or 20
 stamina.Size=UDim2.fromScale(math.clamp(remaining/math.max(1,maximum),0,1),1)

 local fighting=false
 local camera=workspace.CurrentCamera
 for zombie in pairs(zombies) do
  if not zombie:IsDescendantOf(workspace) then zombies[zombie]=nil;continue end
  local target=zombie:GetAttribute("TargetName")
  if target and target~="" then
   for _,other in ipairs(Players:GetPlayers()) do
    if other.Name==target and other.Character then
     local root=other.Character:FindFirstChild("HumanoidRootPart")
     if other==player then fighting=true
     elseif root and camera then local point,onScreen=camera:WorldToViewportPoint(root.Position);if onScreen and point.Z>0 then fighting=true end end
    end
   end
  end
  if fighting then break end
 end
 combat.BackgroundColor3=fighting and Theme.Danger or Theme.Card
end)
local lastLevel=player:GetAttribute("ProfessionLevel") or 0
player:GetAttributeChangedSignal("ProfessionLevel"):Connect(function()
 local value=player:GetAttribute("ProfessionLevel") or 0
 if value>lastLevel then log("Level up! Open character to spend your points.") end
 lastLevel=value
end)
task.spawn(function()
 local ok,allowed=pcall(function() return Chat:CanUserChatAsync(player.UserId) end)
 if ok and not allowed then entry.TextEditable=false;entry.PlaceholderText="Chat unavailable for this account" end
end)
log("Journal ready.")
