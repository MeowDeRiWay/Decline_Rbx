local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Input=game:GetService("UserInputService")
local Context=game:GetService("ContextActionService")
local Run=game:GetService("RunService")
local player=Players.LocalPlayer
local config=require(ReplicatedStorage.Shared.ProgressionConfig)
local Rules=require(ReplicatedStorage.Shared.ProgressionRules)
local Sheet=require(ReplicatedStorage.Shared.CharacterStats)
local Items=require(ReplicatedStorage.Shared.ItemConfig).Items
local Presentation=require(ReplicatedStorage.Shared.ProgressionPresentation)
local TextService=game:GetService("TextService")
local remotes=ReplicatedStorage:WaitForChild("ProgressionRemotes")
local action=remotes:WaitForChild("Action")
local palette=require(ReplicatedStorage.Shared.UITheme)
local function frame(parent,position,size,color)
 local object=Instance.new("Frame")
 object.Position=position; object.Size=size; object.BackgroundColor3=color or palette.Panel; object.BorderSizePixel=0; object.Parent=parent
 return object
end
local function label(parent,text,position,size,fontSize,color)
 local object=Instance.new("TextLabel")
 object.Position=position; object.Size=size; object.BackgroundTransparency=1; object.Text=text; object.TextWrapped=true
 object.Font=palette.Font; object.TextSize=fontSize or 18; object.TextColor3=color or palette.Text; object.TextXAlignment=Enum.TextXAlignment.Left; object.Parent=parent
 return object
end
local function button(parent,text,position,size,callback)
 local object=Instance.new("TextButton")
 object.Position=position; object.Size=size; object.BackgroundColor3=palette.Button; object.BorderSizePixel=0
 object.Text=text; object.Font=palette.Font; object.TextSize=15; object.TextColor3=palette.Accent; object.Parent=parent
 palette.Bevel(object)
 object.Activated:Connect(callback)
 return object
end
local gui=Instance.new("ScreenGui")
gui.Name="CharacterProgression"; gui.ResetOnSpawn=false; gui.IgnoreGuiInset=true; gui.DisplayOrder=20; gui.Parent=player:WaitForChild("PlayerGui")
local panel=frame(gui,UDim2.fromScale(.5,.5),UDim2.fromOffset(1100,720),palette.Background)
palette.Bevel(panel)
panel.AnchorPoint=Vector2.new(.5,.5); panel.Visible=false
local scale=Instance.new("UIScale"); scale.Parent=panel
local title=label(panel,"Character",UDim2.fromOffset(26,12),UDim2.fromOffset(650,36),28,palette.Accent)
title.Font=palette.Font; title.TextSize=18
local closeHint=label(panel,"[C] close",UDim2.new(1,-150,0,22),UDim2.fromOffset(90,20),12,palette.Muted)
local left=frame(panel,UDim2.fromOffset(18,62),UDim2.fromOffset(462,640))
local right=frame(panel,UDim2.fromOffset(494,62),UDim2.fromOffset(588,640))
local leftHeading=label(left,"Attributes",UDim2.fromOffset(20,10),UDim2.fromOffset(420,35),25,palette.Accent)
leftHeading.Font=palette.Font; leftHeading.TextSize=18
local rightHeading=label(right,"Talents",UDim2.fromOffset(20,10),UDim2.fromOffset(530,35),25,palette.Accent)
rightHeading.Font=palette.Font; rightHeading.TextSize=18
local summary=label(left,"Level 0",UDim2.fromOffset(20,48),UDim2.fromOffset(420,24),17)
local xp=label(left,"XP 0 / 100",UDim2.fromOffset(20,79),UDim2.fromOffset(420,20),12,palette.Muted)
local xpTrack=frame(left,UDim2.fromOffset(20,104),UDim2.fromOffset(422,6),palette.Background)
local xpFill=frame(xpTrack,UDim2.new(),UDim2.fromScale(0,1),palette.Accent)
local points=label(left,"Unspent points: 0",UDim2.fromOffset(20,122),UDim2.fromOffset(420,26),16,palette.Accent)
local snapshot,hoveredTalent,hoveredAttribute
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
 card.MouseEnter:Connect(function() hoveredAttribute=stat;hoveredTalent=nil end)
 card.MouseLeave:Connect(function() if hoveredAttribute==stat then hoveredAttribute=nil end end)
 cards[stat]={Frame=card,Value=value,Plus=plus}
end
frame(panel,UDim2.fromOffset(487,62),UDim2.fromOffset(1,640),palette.Border)
local tooltip=label(gui,"",UDim2.new(),UDim2.fromOffset(340,200),15)
tooltip.Name="AttributeTooltip"; tooltip.BackgroundTransparency=.05
 tooltip.BackgroundColor3=palette.Card; tooltip.ZIndex=30; tooltip.Visible=false
 tooltip.TextXAlignment=Enum.TextXAlignment.Left
 tooltip.TextYAlignment=Enum.TextYAlignment.Top
local tooltipPadding=Instance.new("UIPadding");tooltipPadding.PaddingTop=UDim.new(0,10);tooltipPadding.PaddingBottom=UDim.new(0,10);tooltipPadding.PaddingLeft=UDim.new(0,12);tooltipPadding.PaddingRight=UDim.new(0,12);tooltipPadding.Parent=tooltip
local talentPanel=frame(right,UDim2.new(),UDim2.fromScale(1,1))
talentPanel.BackgroundTransparency=1
local mode="Stats"
local profession=label(talentPanel,"No profession selected",UDim2.fromOffset(20,48),UDim2.fromOffset(340,28),18)
local permissions=label(talentPanel,"",UDim2.fromOffset(20,82),UDim2.fromOffset(340,30),12,palette.Muted)
local choose=button(talentPanel,"Choose cook",UDim2.fromOffset(378,46),UDim2.fromOffset(190,32),function() action:FireServer("Choose","Cook") end)
local chooseWorker=button(talentPanel,"Choose worker",UDim2.fromOffset(378,84),UDim2.fromOffset(190,30),function() action:FireServer("Choose","Worker") end)
local chooseHunter=button(talentPanel,"Choose hunter",UDim2.fromOffset(378,122),UDim2.fromOffset(190,30),function() action:FireServer("Choose","Hunter") end)
local talentPoints=label(talentPanel,"Talent points: 0",UDim2.fromOffset(20,114),UDim2.fromOffset(340,18),13)
local tree=Instance.new("ScrollingFrame")
tree.Position=UDim2.fromOffset(20,134); tree.Size=UDim2.fromOffset(548,330); tree.BackgroundColor3=palette.Background
 tree.BorderSizePixel=0; tree.ScrollBarThickness=4; tree.ScrollBarImageColor3=palette.Accent; tree.CanvasSize=UDim2.new(); tree.Parent=talentPanel
local statsPanel=frame(right,UDim2.fromOffset(20,84),UDim2.fromOffset(548,532))
local statRows={
 {"Health","Health"},{"Absorption","Damage absorption"},{"Resistance","Damage resistance"},
 {"Sprint","Sprint duration"},{"Accuracy","Accuracy"},{"Dodge","Dodge"},
 {"MeleeDamage","Melee damage"},{"CriticalChance","Critical chance"},
 {"CriticalMultiplier","Critical multiplier"},{"Luck","Luck chance"},
}
local values={}
for index,row in ipairs(statRows) do
 local y=(index-1)*44
 local card=frame(statsPanel,UDim2.fromOffset(0,y),UDim2.fromOffset(548,38),palette.Card)
 label(card,row[2],UDim2.fromOffset(10,0),UDim2.fromOffset(250,38),15)
 values[row[1]]=label(card,"—",UDim2.fromOffset(260,0),UDim2.fromOffset(278,38),15,palette.Accent)
end
local function setMode(value)
 closeHint.Text=value=="Stats" and "[C] close" or "[T] close"
 mode=value;statsPanel.Visible=value=="Stats";talentPanel.Visible=value=="Talents"
 rightHeading.Text=value=="Stats" and "Final stats" or "Talents"
 hoveredTalent=nil
end
button(right,"Stats",UDim2.fromOffset(20,44),UDim2.fromOffset(112,28),function() setMode("Stats") end)
button(right,"Talents",UDim2.fromOffset(144,44),UDim2.fromOffset(112,28),function() setMode("Talents") end)
-- Reserve the upper strip for switching between the final sheet and the talent tree.
for _,object in ipairs({profession,permissions,choose,chooseWorker,chooseHunter,talentPoints}) do object.Position+=UDim2.fromOffset(0,34) end
setMode("Stats")
local function refreshStats()
 local character=player.Character
 local attributes=player:GetAttributes()
 local definition=character and Items[character:GetAttribute("HandsItem")]
 local stats=Sheet.Calculate(attributes,definition,character and character:GetAttribute("WeaponCondition"),character and character:GetAttribute("Health"),character and character:GetAttribute("MaxHealth"))
 local function percent(value) return string.format("%g%%",math.floor(value*10000+.5)/100) end
 values.Health.Text=string.format("%.0f / %.0f HP",stats.Health,stats.MaxHealth)
 values.Absorption.Text=string.format("%g melee · %g other",stats.MeleeAbsorption,stats.Absorption)
 values.Resistance.Text=percent(stats.Resistance)
 values.Sprint.Text=string.format("%g seconds",stats.Sprint)
 values.Accuracy.Text=string.format("%g",stats.Accuracy)
 values.Dodge.Text=string.format("%g",stats.Dodge)
 values.MeleeDamage.Text=string.format("%g%s",stats.MeleeDamage,stats.MeleeEquipped and "" or " (unarmed bonus)")
 values.CriticalChance.Text=percent(stats.CriticalChance)
 values.CriticalMultiplier.Text=string.format("×%d–×%d",stats.CriticalMin,stats.CriticalMax)
 values.Luck.Text=percent(stats.Luck)
end
local function canLearn(id,definition) return Rules.CanLearn(snapshot,id,definition) end
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
 choose.Visible=definition==nil; chooseWorker.Visible=definition==nil; chooseHunter.Visible=definition==nil
 tree.Position=UDim2.fromOffset(20,definition and 168 or 206)
 tree.Size=UDim2.fromOffset(548,definition and 450 or 412)
 talentPoints.Text="Talent points: "..snapshot.TalentPoints
 if definition then
  local stations,buildings={},{}
  for station in pairs(definition.Stations) do table.insert(stations,station) end
  for building in pairs(definition.Buildings) do table.insert(buildings,building=="Workbench" and "Workshop" or building) end
  table.sort(stations); table.sort(buildings)
  permissions.Text=snapshot.Profession=="Hunter" and "Weapon specialist" or table.concat(stations," / ").." · Build: "..table.concat(buildings,", ")
 else permissions.Text="Select a profession for this server session." end
 for _,child in ipairs(tree:GetChildren()) do if child:IsA("GuiObject") then child:Destroy() end end
 local talents=definition and definition.Talents or {}
 local ids={}; for id in pairs(talents) do table.insert(ids,id) end
 table.sort(ids,function(a,b) local x,y=talents[a].Level or 0,talents[b].Level or 0; return x==y and a<b or x<y end)
 local y,index=10,1
 while index<=#ids do
  local required=talents[ids[index]].Level or 1
  label(tree,"Requires level "..required..":",UDim2.fromOffset(8,y),UDim2.fromOffset(520,26),15,palette.Accent)
  y+=34
  local column=0
  while index<=#ids and (talents[ids[index]].Level or 1)==required do
   local id=ids[index]
   local talent=talents[id]
   local node=button(tree,(talent.Name or id).."\n"..Rules.Rank(snapshot,id).." / 10",UDim2.fromOffset(8+column*266,y),UDim2.fromOffset(254,58),function()
    if canLearn(id,talent) then action:FireServer("Talent",id) end
   end)
   node.TextWrapped=true;node.TextSize=14
   node.AutoButtonColor=canLearn(id,talent)
   node.TextColor3=Rules.Rank(snapshot,id)>0 and palette.Green or canLearn(id,talent) and palette.Accent or palette.Muted
   node.MouseEnter:Connect(function() hoveredTalent=id;hoveredAttribute=nil end)
   node.MouseLeave:Connect(function() if hoveredTalent==id then hoveredTalent=nil end end)
   index+=1;column+=1
   if column==2 then column=0;y+=68 end
  end
  if column>0 then y+=68 end
  y+=12
 end
 tree.CanvasSize=UDim2.fromOffset(0,y)
 if hoveredTalent and not talents[hoveredTalent] then hoveredTalent=nil end
 if #ids==0 then
  local emptyTitle=label(tree,definition and string.upper(definition.Name) or "NO PROFESSION",UDim2.fromOffset(30,78),UDim2.fromOffset(480,44),28,palette.Accent)
  emptyTitle.Font=palette.Font; emptyTitle.TextXAlignment=Enum.TextXAlignment.Center
  local emptyText=label(tree,definition and "No talents available yet.\nYour profession tree will appear here." or "Choose a profession to view its talent tree.",UDim2.fromOffset(60,140),UDim2.fromOffset(420,76),15,palette.Muted)
  emptyText.TextXAlignment=Enum.TextXAlignment.Center
 end

end
local function setOpen(open)
 if open and player.Character and player.Character:GetAttribute("Knockout") then return end
 panel.Visible=open; tooltip.Visible=false; hoveredAttribute=nil; hoveredTalent=nil; player:SetAttribute("ProgressionOpen",open)
 if open then
  refreshStats()
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
 if mode=="Stats" then refreshStats() end
 local mouse=Input:GetMouseLocation()
 local text
 if hoveredAttribute then text=Presentation.Attribute(hoveredAttribute)
 elseif hoveredTalent then
  local profession=config.Professions[snapshot.Profession]
  local talent=profession and profession.Talents[hoveredTalent]
  if talent then text=Presentation.Talent(snapshot,hoveredTalent,talent) end
 end
 if text then
  tooltip.Text=text
  local natural=TextService:GetTextSize(text,15,tooltip.Font,Vector2.new(1000,1000))
  local width=math.min(hoveredAttribute and 300 or 340,math.max(180,natural.X+24),math.max(1,camera.ViewportSize.X-16))
  local measured=TextService:GetTextSize(text,15,tooltip.Font,Vector2.new(math.max(1,width-24),1000))
  local _,lineCount=text:gsub("\n", "")
  local height=math.max(measured.Y+24,(lineCount+1)*20+24)
  tooltip.Size=UDim2.fromOffset(width,height)
  tooltip.Position=UDim2.fromOffset(math.clamp(mouse.X+16,0,math.max(0,camera.ViewportSize.X-width)),math.clamp(mouse.Y+16,0,math.max(0,camera.ViewportSize.Y-height)))
  tooltip.Visible=true
 end
end)
require(script.Parent.HUDLayout).Character.Event:Connect(function()
 if not player:GetAttribute("InventoryOpen") and not player:GetAttribute("TownMenuOpen") then
  local opening=not panel.Visible or mode~="Stats"
  setMode("Stats");setOpen(opening)
 end
end)
require(script.Parent.HUDLayout).Skills.Event:Connect(function()
 if not player:GetAttribute("InventoryOpen") and not player:GetAttribute("TownMenuOpen") then
  local opening=not panel.Visible or mode~="Talents"
  setMode("Talents");setOpen(opening)
 end
end)
Input.InputBegan:Connect(function(input,processed)
 if processed or Input:GetFocusedTextBox() then return end
 if not player:GetAttribute("InventoryOpen") and not player:GetAttribute("TownMenuOpen") then
  if input.KeyCode==Enum.KeyCode.C then require(script.Parent.HUDLayout).Character:Fire()
  elseif input.KeyCode==Enum.KeyCode.T then require(script.Parent.HUDLayout).Skills:Fire() end
 end
 if input.KeyCode==Enum.KeyCode.Escape and panel.Visible then setOpen(false) end
end)
remotes:WaitForChild("State").OnClientEvent:Connect(function(value) snapshot=value; redraw() end)
player.CharacterRemoving:Connect(function() setOpen(false) end)
action:FireServer("Request")
