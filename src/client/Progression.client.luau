local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Input=game:GetService("UserInputService")
local Context=game:GetService("ContextActionService")
local Run=game:GetService("RunService")
local player=Players.LocalPlayer
local config=require(ReplicatedStorage.Shared.ProgressionConfig)
local Rules=require(ReplicatedStorage.Shared.ProgressionRules)
local remotes=ReplicatedStorage:WaitForChild("ProgressionRemotes")
local action=remotes:WaitForChild("Action")
local palette={Background=Color3.fromRGB(22,28,33),Panel=Color3.fromRGB(22,28,33),Card=Color3.fromRGB(30,38,45),Button=Color3.fromRGB(42,53,62),Accent=Color3.fromRGB(235,240,244),Border=Color3.fromRGB(63,73,82),Text=Color3.fromRGB(235,240,244),Muted=Color3.fromRGB(160,174,184),Green=Color3.fromRGB(90,220,145)}
local function frame(parent,position,size,color)
 local object=Instance.new("Frame")
 object.Position=position; object.Size=size; object.BackgroundColor3=color or palette.Panel; object.BorderSizePixel=0; object.Parent=parent
 return object
end
local function label(parent,text,position,size,fontSize,color)
 local object=Instance.new("TextLabel")
 object.Position=position; object.Size=size; object.BackgroundTransparency=1; object.Text=text; object.TextWrapped=true
 object.Font=Enum.Font.GothamMedium; object.TextSize=fontSize or 18; object.TextColor3=color or palette.Text; object.TextXAlignment=Enum.TextXAlignment.Left; object.Parent=parent
 return object
end
local function button(parent,text,position,size,callback)
 local object=Instance.new("TextButton")
 object.Position=position; object.Size=size; object.BackgroundColor3=palette.Button; object.BorderSizePixel=0
 object.Text=text; object.Font=Enum.Font.Gotham; object.TextSize=15; object.TextColor3=palette.Accent; object.Parent=parent
 object.Activated:Connect(callback)
 return object
end
local gui=Instance.new("ScreenGui")
gui.Name="CharacterProgression"; gui.ResetOnSpawn=false; gui.IgnoreGuiInset=true; gui.DisplayOrder=20; gui.Parent=player:WaitForChild("PlayerGui")
local panel=frame(gui,UDim2.fromScale(.5,.5),UDim2.fromOffset(1100,720),palette.Background)
panel.AnchorPoint=Vector2.new(.5,.5); panel.Visible=false
local scale=Instance.new("UIScale"); scale.Parent=panel
local title=label(panel,"Character",UDim2.fromOffset(26,12),UDim2.fromOffset(650,36),28,palette.Accent)
title.Font=Enum.Font.GothamMedium; title.TextSize=18
label(panel,"[P] Close",UDim2.new(1,-150,0,22),UDim2.fromOffset(90,20),12,palette.Muted)
local left=frame(panel,UDim2.fromOffset(18,62),UDim2.fromOffset(462,640))
local right=frame(panel,UDim2.fromOffset(494,62),UDim2.fromOffset(588,640))
local leftHeading=label(left,"Attributes",UDim2.fromOffset(20,10),UDim2.fromOffset(420,35),25,palette.Accent)
leftHeading.Font=Enum.Font.GothamMedium; leftHeading.TextSize=18
local rightHeading=label(right,"Talents",UDim2.fromOffset(20,10),UDim2.fromOffset(530,35),25,palette.Accent)
rightHeading.Font=Enum.Font.GothamMedium; rightHeading.TextSize=18
local summary=label(left,"Level 0",UDim2.fromOffset(20,48),UDim2.fromOffset(420,24),17)
local xp=label(left,"XP 0 / 100",UDim2.fromOffset(20,79),UDim2.fromOffset(420,20),12,palette.Muted)
local xpTrack=frame(left,UDim2.fromOffset(20,104),UDim2.fromOffset(422,6),palette.Background)
local xpFill=frame(xpTrack,UDim2.new(),UDim2.fromScale(0,1),palette.Accent)
local points=label(left,"Unspent points: 0",UDim2.fromOffset(20,122),UDim2.fromOffset(420,26),16,palette.Accent)
local snapshot,selectedTalent,hoveredAttribute
local cards={}
local initials={Strength="STR",Endurance="END",Attention="ATT",Luck="LCK"}
for order,stat in ipairs(config.Stats) do
 local card=frame(left,UDim2.fromOffset(20,160+(order-1)*78),UDim2.fromOffset(422,68),palette.Card)
 local emblem=frame(card,UDim2.fromOffset(10,12),UDim2.fromOffset(44,44),palette.Background)
 local icon=label(emblem,initials[stat],UDim2.new(),UDim2.fromScale(1,1),12,palette.Accent); icon.TextXAlignment=Enum.TextXAlignment.Center
 label(card,stat,UDim2.fromOffset(66,20),UDim2.fromOffset(230,28),16)
 local value=label(card,"0",UDim2.fromOffset(300,20),UDim2.fromOffset(50,24),19,palette.Accent); value.TextXAlignment=Enum.TextXAlignment.Right
 local plus=button(card,"+",UDim2.fromOffset(366,16),UDim2.fromOffset(40,36),function()
  if snapshot and snapshot.Points>0 then action:FireServer("Spend",stat) end
 end)
 card.MouseEnter:Connect(function() hoveredAttribute=stat end)
 card.MouseLeave:Connect(function() if hoveredAttribute==stat then hoveredAttribute=nil end end)
 cards[stat]={Frame=card,Value=value,Plus=plus}
end
frame(panel,UDim2.fromOffset(487,62),UDim2.fromOffset(1,640),palette.Border)
local tooltip=label(gui,"",UDim2.new(),UDim2.fromOffset(340,200),15)
tooltip.Name="AttributeTooltip"; tooltip.BackgroundTransparency=.05
 tooltip.BackgroundColor3=Color3.fromRGB(20,26,31); tooltip.ZIndex=30; tooltip.Visible=false
 tooltip.TextXAlignment=Enum.TextXAlignment.Center
local function attributeText(stat)
 local bonus=snapshot.Bonuses
 local header=stat.." · "..snapshot.Stats[stat].."\n\n"
 if stat=="Strength" then
  return header..string.format("Per point: +1 kg carry capacity\n+1 melee damage\n\nCarry capacity: %g kg\nMelee damage bonus: +%g\nNo attribute limit",bonus.CarryLimitKg,bonus.MeleeBonus)
 elseif stat=="Endurance" then
  return header..string.format("Per point: +0.2 running speed\n+5 maximum HP\n\nRun speed bonus: +%g\nMaximum health: %g HP\nWalking speed is unchanged · No limit",bonus.RunBonus,bonus.MaxHealth)
 elseif stat=="Attention" then
  return header..string.format("Per point: +2%% accuracy\n+2 studs forward view\n\nAccuracy: %.0f%% · Maximum: 90%%\nForward view bonus: +%g studs\nFailed living-target attacks show Miss",bonus.Accuracy*100,bonus.ViewBonus)
 end
 return header..string.format("Per point: +3%% bonus loot chance\n+1 bonus item per 3 invested points\n\nBonus chance: %.0f%% · Maximum: 50%%\nExtra items on success: %d\nApplies to newly generated loot",bonus.LuckChance*100,bonus.LuckAmount)
end
local profession=label(right,"No profession selected",UDim2.fromOffset(20,48),UDim2.fromOffset(340,28),18)
local permissions=label(right,"",UDim2.fromOffset(20,82),UDim2.fromOffset(340,30),12,palette.Muted)
local choose=button(right,"Choose Cook",UDim2.fromOffset(378,46),UDim2.fromOffset(190,32),function() action:FireServer("Choose","Cook") end)
local chooseWorker=button(right,"Choose Worker",UDim2.fromOffset(378,84),UDim2.fromOffset(190,30),function() action:FireServer("Choose","Worker") end)
local talentPoints=label(right,"Talent points: 0",UDim2.fromOffset(20,114),UDim2.fromOffset(340,18),13)
local tree=Instance.new("ScrollingFrame")
tree.Position=UDim2.fromOffset(20,134); tree.Size=UDim2.fromOffset(548,330); tree.BackgroundColor3=palette.Background
 tree.BorderSizePixel=0; tree.ScrollBarThickness=4; tree.ScrollBarImageColor3=palette.Accent; tree.CanvasSize=UDim2.new(); tree.Parent=right
local detail=frame(right,UDim2.fromOffset(20,480),UDim2.fromOffset(548,138),palette.Background)
local detailTitle=label(detail,"Talent details",UDim2.fromOffset(14,10),UDim2.fromOffset(520,24),17,palette.Accent)
local detailText=label(detail,"Select a talent to inspect its requirements and effects.",UDim2.fromOffset(14,40),UDim2.fromOffset(350,84),12,palette.Muted)
detailText.TextYAlignment=Enum.TextYAlignment.Top
local learn=button(detail,"Learn",UDim2.fromOffset(386,82),UDim2.fromOffset(148,38),function()
 if selectedTalent and snapshot then
  local profession=config.Professions[snapshot.Profession]
  if profession and profession.Talents[selectedTalent] then action:FireServer("Talent",selectedTalent) end
 end
end)
learn.Visible=false
local function canLearn(id,definition) return Rules.CanLearn(snapshot,id,definition) end
local function talentDetails(id,definition)
 detailTitle.Text=(definition.Name or id).." · "..Rules.Rank(snapshot,id).." / 10"
 local prerequisiteNames={}
 local current=config.Professions[snapshot.Profession]
 for _,parent in ipairs(definition.Requires or {}) do table.insert(prerequisiteNames,current.Talents[parent] and (current.Talents[parent].Name or parent) or parent) end
 detailText.Text=(definition.Description or "").."\nRequires profession level "..(definition.Level or 0)..(#prerequisiteNames>0 and "\nRequires: "..table.concat(prerequisiteNames,", ") or "")
 learn.Visible=true
 local available=canLearn(id,definition)
 learn.Text=Rules.Rank(snapshot,id)>=10 and "Max rank" or available and "Upgrade (1 point)" or "Locked"
 learn.Active=available; learn.AutoButtonColor=available; learn.TextColor3=available and palette.Accent or palette.Muted
end
local function redraw()
 if not snapshot then return end
 local definition=config.Professions[snapshot.Profession]
 local name=definition and definition.Name or "No profession"
 summary.Text=name.." · Level "..snapshot.Level
 xp.Text=string.format("Experience   %d / %d",snapshot.XP,snapshot.NextXP)
 xpFill.Size=UDim2.fromScale(math.clamp(snapshot.XP/snapshot.NextXP,0,1),1)
 points.Text="Unspent attribute points: "..snapshot.Points
 for stat,card in pairs(cards) do
  card.Value.Text=tostring(snapshot.Stats[stat]); card.Plus.Active=snapshot.Points>0; card.Plus.AutoButtonColor=snapshot.Points>0
  card.Plus.TextColor3=snapshot.Points>0 and palette.Accent or palette.Muted
 end
 profession.Text=definition and definition.Name.." · Level "..snapshot.Level or "Choose a profession"
 choose.Visible=definition==nil; chooseWorker.Visible=definition==nil
 talentPoints.Text="Talent points: "..snapshot.TalentPoints
 if definition then
  local stations,buildings={},{}
  for station in pairs(definition.Stations) do table.insert(stations,station) end
  for building in pairs(definition.Buildings) do table.insert(buildings,building=="Workbench" and "Workshop" or building) end
  table.sort(stations); table.sort(buildings)
  permissions.Text=table.concat(stations," / ").." · Build: "..table.concat(buildings,", ")
 else permissions.Text="Select a profession for this server session." end
 for _,child in ipairs(tree:GetChildren()) do if child:IsA("GuiObject") then child:Destroy() end end
 local talents=definition and definition.Talents or {}
 local ids={}; for id in pairs(talents) do table.insert(ids,id) end
 table.sort(ids,function(a,b) local x,y=talents[a].Level or 0,talents[b].Level or 0; return x==y and a<b or x<y end)
 local positions={}
 local nextRow,level,row,column=0,nil,0,0
 for _,id in ipairs(ids) do
  local required=talents[id].Level or 0
  if required~=level then level=required; row=nextRow; column=0 end
  if column>=3 then row+=1; column=0 end
  positions[id]=Vector2.new(18+column*174,20+row*128)
  nextRow=math.max(nextRow,row+1); column+=1
 end
 for _,id in ipairs(ids) do
  for _,parent in ipairs(talents[id].Requires or {}) do
   if positions[parent] then
    local a=positions[parent]+Vector2.new(79,48)
    local b=positions[id]+Vector2.new(79,48)
    local delta=b-a
    local connector=frame(tree,UDim2.fromOffset((a.X+b.X)/2,(a.Y+b.Y)/2),UDim2.fromOffset(delta.Magnitude,2),palette.Border)
    connector.AnchorPoint=Vector2.new(.5,.5); connector.Rotation=math.deg(math.atan2(delta.Y,delta.X)); connector.ZIndex=1
   end
  end
 end
 for _,id in ipairs(ids) do
  local talent=talents[id]
  local node=button(tree,(talent.Name or id).."\nRank "..Rules.Rank(snapshot,id).." / 10 · Requires level "..(talent.Level or 1),UDim2.fromOffset(positions[id].X,positions[id].Y),UDim2.fromOffset(158,96),function()
   selectedTalent=id; talentDetails(id,talent)
  end)
  node.TextWrapped=true; node.TextSize=13; node.ZIndex=2
  node.TextColor3=Rules.Rank(snapshot,id)>0 and palette.Green or canLearn(id,talent) and palette.Accent or palette.Muted
 end
 tree.CanvasSize=UDim2.fromOffset(0,math.max(330,nextRow*128+20))
 if #ids==0 then
  local emptyTitle=label(tree,definition and string.upper(definition.Name) or "NO PROFESSION",UDim2.fromOffset(30,78),UDim2.fromOffset(480,44),28,palette.Accent)
  emptyTitle.Font=Enum.Font.GothamMedium; emptyTitle.TextXAlignment=Enum.TextXAlignment.Center
  local emptyText=label(tree,definition and "No talents available yet.\nYour profession tree will appear here." or "Choose a profession to view its talent tree.",UDim2.fromOffset(60,140),UDim2.fromOffset(420,76),15,palette.Muted)
  emptyText.TextXAlignment=Enum.TextXAlignment.Center
 end
 if selectedTalent and talents[selectedTalent] then talentDetails(selectedTalent,talents[selectedTalent])
 else selectedTalent=nil; detailTitle.Text="Talent details"; detailText.Text="Select a talent to inspect its requirements and effects.\nTalents unlock at the required profession level."; learn.Visible=false end
end
local function setOpen(open)
 panel.Visible=open; tooltip.Visible=false; hoveredAttribute=nil; player:SetAttribute("ProgressionOpen",open)
 if open then
  Context:BindActionAtPriority("ProgressionBlockMovement",function() return Enum.ContextActionResult.Sink end,false,Enum.ContextActionPriority.High.Value+2,Enum.PlayerActions.CharacterForward,Enum.PlayerActions.CharacterBackward,Enum.PlayerActions.CharacterLeft,Enum.PlayerActions.CharacterRight,Enum.PlayerActions.CharacterJump)
  action:FireServer("Request")
 else Context:UnbindAction("ProgressionBlockMovement") end
end
button(panel,"X",UDim2.new(1,-48,0,17),UDim2.fromOffset(30,28),function() setOpen(false) end)
Run.RenderStepped:Connect(function()
 tooltip.Visible=false
 if not panel.Visible then return end
 local camera=workspace.CurrentCamera
 if not camera then return end
 scale.Scale=math.min(1,camera.ViewportSize.X*.95/1100,camera.ViewportSize.Y*.9/720)
 if not snapshot then return end
 local mouse=Input:GetMouseLocation()
 if hoveredAttribute then
  tooltip.Text=attributeText(hoveredAttribute)
  local width=math.min(340,math.max(1,camera.ViewportSize.X-16))
  tooltip.Size=UDim2.fromOffset(width,200)
  tooltip.Position=UDim2.fromOffset(math.clamp(mouse.X+16,0,math.max(0,camera.ViewportSize.X-width)),math.clamp(mouse.Y+16,0,math.max(0,camera.ViewportSize.Y-200)))
  tooltip.Visible=true
 end
end)
Input.InputBegan:Connect(function(input,processed)
 if processed or Input:GetFocusedTextBox() then return end
 if input.KeyCode==Enum.KeyCode.P and not player:GetAttribute("InventoryOpen") and not player:GetAttribute("TownMenuOpen") then setOpen(not panel.Visible) end
 if input.KeyCode==Enum.KeyCode.Escape and panel.Visible then setOpen(false) end
end)
remotes:WaitForChild("State").OnClientEvent:Connect(function(value) snapshot=value; redraw() end)
player.CharacterRemoving:Connect(function() setOpen(false) end)
action:FireServer("Request")
