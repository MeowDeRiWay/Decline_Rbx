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
local Layout=require(script.Parent.HUDLayout)
local gui=Instance.new("ScreenGui");gui.Name="CharacterProgression";gui.ResetOnSpawn=false;gui.IgnoreGuiInset=true;gui.DisplayOrder=20;gui.Parent=player:WaitForChild("PlayerGui")
local panel=frame(gui,UDim2.fromScale(.5,.5),UDim2.fromOffset(1100,720),palette.Background)
palette.Bevel(panel);panel.AnchorPoint=Vector2.new(.5,.5);panel.Visible=false
local scale=Instance.new("UIScale");scale.Parent=panel
label(panel,"Character",UDim2.fromOffset(26,14),UDim2.fromOffset(700,30),24,palette.Accent)
local left=frame(panel,UDim2.fromOffset(18,62),UDim2.fromOffset(462,640))
local right=frame(panel,UDim2.fromOffset(494,62),UDim2.fromOffset(588,640))
label(left,"Attributes",UDim2.fromOffset(20,10),UDim2.fromOffset(420,30),20,palette.Accent)
local summary=label(left,"",UDim2.fromOffset(20,46),UDim2.fromOffset(420,26),16)
local points=label(left,"",UDim2.fromOffset(20,80),UDim2.fromOffset(420,50),14,palette.Accent)
local snapshot,draft,hovered,closeControl
local mode="Stats"
local tips={Strength="Per point:\n+5 kg carrying capacity\n+5 heavy weapons, unarmed and melee\n+3 throwing\n+1 melee / unarmed damage",Attention="Per point:\n+5 light weapons and traps\n+3 heavy weapons and unarmed",Endurance="Per point:\n+10 HP\n+2 HP regeneration per minute",Intelligence="Per point:\n+5 first aid, doctor and repair\n+1 skill point per level",Agility="Per point:\n+5 armor class, unarmed, throwing and sneak\n+0.3 walk speed\n+1 sprint speed bonus",Luck="Per point:\n+1% critical chance"}
local cards={}
local function remaining()
 local sum=0;for _,value in pairs(draft or {}) do sum+=value end
 return 36-sum
end
local redraw
for index,id in ipairs(config.Stats) do
 local card=frame(left,UDim2.fromOffset(20,142+(index-1)*56),UDim2.fromOffset(422,48),palette.Card)
 label(card,id,UDim2.fromOffset(12,0),UDim2.fromOffset(210,48),16)
 local value=label(card,"5",UDim2.fromOffset(242,0),UDim2.fromOffset(60,48),18,palette.Accent)
 local minus=button(card,"−",UDim2.fromOffset(310,8),UDim2.fromOffset(38,32),function()
  if snapshot and not snapshot.Confirmed and draft[id]>1 then draft[id]-=1;redraw() end
 end)
 local plus=button(card,"+",UDim2.fromOffset(364,8),UDim2.fromOffset(38,32),function()
  if snapshot and not snapshot.Confirmed and draft[id]<10 and remaining()>0 then draft[id]+=1;redraw() end
 end)
 card.MouseEnter:Connect(function() hovered=id end);card.MouseLeave:Connect(function() if hovered==id then hovered=nil end end)
 cards[id]={Value=value,Minus=minus,Plus=plus}
end
local confirmedText=label(left,"",UDim2.fromOffset(20,490),UDim2.fromOffset(420,52),14,palette.Muted)
local confirming=false
local confirmButton=button(left,"Confirm attributes",UDim2.fromOffset(20,554),UDim2.fromOffset(422,40),function()
 if not snapshot or snapshot.Confirmed or remaining()~=0 then return end
 if not confirming then confirming=true;redraw();return end
 action:FireServer("Confirm",table.clone(draft));confirming=false
end)
local statPanel=frame(right,UDim2.fromOffset(20,94),UDim2.fromOffset(548,526))
local skillPanel=Instance.new("ScrollingFrame");skillPanel.Position=UDim2.fromOffset(20,94);skillPanel.Size=UDim2.fromOffset(548,526);skillPanel.BackgroundTransparency=1;skillPanel.BorderSizePixel=0;skillPanel.ScrollBarThickness=4;skillPanel.CanvasSize=UDim2.fromOffset(0,560);skillPanel.Parent=right
local perkPanel=frame(right,UDim2.fromOffset(20,94),UDim2.fromOffset(548,526))
label(perkPanel,"No perks available yet.",UDim2.fromOffset(16,30),UDim2.fromOffset(510,60),18,palette.Muted)
local function setMode(value) mode=value;statPanel.Visible=value=="Stats";skillPanel.Visible=value=="Skills";perkPanel.Visible=value=="Perks" end
for index,value in ipairs({"Stats","Skills","Perks"}) do button(right,value,UDim2.fromOffset(20+(index-1)*180,24),UDim2.fromOffset(166,38),function() setMode(value) end) end
local values={}
for index,row in ipairs({{"Health","Health"},{"ArmorClass","Armor class"},{"Carry","Carrying capacity"},{"MeleeDamage","Melee / unarmed damage"},{"Absorption","Damage absorption"},{"Resistance","Damage resistance"},{"WalkSpeed","Walk speed"},{"RunSpeed","Sprint speed"},{"Regeneration","Regeneration / minute"},{"CriticalChance","Critical chance"}}) do
 local card=frame(statPanel,UDim2.fromOffset(0,(index-1)*48),UDim2.fromOffset(548,42),palette.Card)
 label(card,row[2],UDim2.fromOffset(10,0),UDim2.fromOffset(270,42),15)
 values[row[1]]=label(card,"—",UDim2.fromOffset(284,0),UDim2.fromOffset(254,42),15,palette.Accent)
end
local skillRows={}
local function skillRow(id,index,passive)
 local y=(index-1)*40
 local card=frame(skillPanel,UDim2.fromOffset(0,y),UDim2.fromOffset(532,34),palette.Card)
 label(card,config.Names[id],UDim2.fromOffset(8,0),UDim2.fromOffset(238,34),15)
 local value=label(card,"0",UDim2.fromOffset(250,0),UDim2.fromOffset(220,34),14,palette.Accent)
 local plus
 if not passive then plus=button(card,"+",UDim2.fromOffset(486,2),UDim2.fromOffset(34,30),function() action:FireServer("Skill",id) end) end
 skillRows[id]={Value=value,Plus=plus}
end
for index,id in ipairs(config.Skills) do skillRow(id,index,false) end
label(skillPanel,"Practice skills · improve through harvesting",UDim2.fromOffset(8,400),UDim2.fromOffset(516,30),14,palette.Muted)
for index,id in ipairs(config.PassiveSkills) do skillRow(id,index+12,true) end
skillPanel.CanvasSize=UDim2.fromOffset(0,600)
local tooltip=label(gui,"",UDim2.new(),UDim2.fromOffset(350,180),14)
tooltip.BackgroundColor3=palette.Card;tooltip.BackgroundTransparency=.05;tooltip.Visible=false;tooltip.ZIndex=30
local padding=Instance.new("UIPadding");padding.PaddingLeft=UDim.new(0,10);padding.PaddingTop=UDim.new(0,8);padding.Parent=tooltip
local function refreshStats()
 local character=player.Character;local a=player:GetAttributes()
 local definition=character and Items[character:GetAttribute("HandsItem")]
 if snapshot and not snapshot.Confirmed and draft then for id,value in pairs(Rules.Bonuses(draft)) do a[id]=value end end
 local stats=Sheet.Calculate(a,definition,character and character:GetAttribute("WeaponCondition"),snapshot and not snapshot.Confirmed and a.MaxHealth or character and character:GetAttribute("Health"),snapshot and not snapshot.Confirmed and a.MaxHealth or character and character:GetAttribute("MaxHealth"))
 values.Health.Text=string.format("%.0f / %.0f HP",stats.Health,stats.MaxHealth)
 values.ArmorClass.Text=tostring(stats.Dodge)
 values.Carry.Text=string.format("%g kg",stats.Carry)
 values.MeleeDamage.Text=string.format("%g",stats.MeleeDamage)
 values.Absorption.Text=string.format("%g",stats.Absorption)
 values.Resistance.Text=string.format("%g%%",stats.Resistance*100)
 values.WalkSpeed.Text=string.format("%g studs/s",stats.WalkSpeed)
 values.RunSpeed.Text=string.format("%g studs/s",stats.RunSpeed)
 values.Regeneration.Text=string.format("%g HP",stats.Regeneration)
 values.CriticalChance.Text=string.format("%g%%",stats.CriticalChance*100)
end
redraw=function()
 if not snapshot then return end
 summary.Text=string.format("Level %d · XP %d / %d",snapshot.Level,snapshot.XP,snapshot.NextXP)
 points.Text="Skill points: "..snapshot.SkillPoints..(snapshot.Confirmed and "" or "\nAttribute points remaining: "..remaining())
 for id,card in pairs(cards) do
  card.Value.Text=tostring(snapshot.Confirmed and snapshot.Stats[id] or draft[id])
  card.Minus.Visible=not snapshot.Confirmed;card.Plus.Visible=not snapshot.Confirmed
 end
 confirmedText.Text=snapshot.Confirmed and "Attributes confirmed." or "Attributes must total 36. Confirm to unlock progression. The distribution will be locked."
 confirmButton.Visible=not snapshot.Confirmed
 confirmButton.Text=confirming and "Confirm permanently" or "Confirm attributes"
 for id,row in pairs(skillRows) do
  local preview=not snapshot.Confirmed and Rules.SkillValues(draft) or snapshot.Skills
  local value=preview[id] or 0;local practice=snapshot.Practice[id]
  row.Value.Text=practice and string.format("%d · XP %d / %d",value,practice.XP,100*(value+1)) or tostring(value)
  if row.Plus then row.Plus.Visible=snapshot.Confirmed and snapshot.SkillPoints>0 and value<300 end
 end
end
local function setOpen(value,force)
 if not force and not value and snapshot and not snapshot.Confirmed and player.Character then return end
 if value and (player:GetAttribute("InventoryOpen") or player:GetAttribute("TownMenuOpen") or player:GetAttribute("GroupOpen") or (player.Character and player.Character:GetAttribute("Knockout"))) then return end
 panel.Visible=value;player:SetAttribute("ProgressionOpen",value)
 if value then Context:BindActionAtPriority("ProgressionBlockMovement",function() return Enum.ContextActionResult.Sink end,false,Enum.ContextActionPriority.High.Value+2,Enum.PlayerActions.CharacterForward,Enum.PlayerActions.CharacterBackward,Enum.PlayerActions.CharacterLeft,Enum.PlayerActions.CharacterRight,Enum.PlayerActions.CharacterJump)
 else hovered=nil;tooltip.Visible=false;Context:UnbindAction("ProgressionBlockMovement") end
end
closeControl=button(panel,"X",UDim2.new(1,-48,0,17),UDim2.fromOffset(30,28),function() setOpen(false) end)
setMode("Stats")
Layout.Character.Event:Connect(function() local value=not panel.Visible or mode~="Stats";setMode("Stats");setOpen(value) end)
Layout.Skills.Event:Connect(function() local value=not panel.Visible or mode~="Skills";setMode("Skills");setOpen(value) end)
Input.InputBegan:Connect(function(key,processed)
 if processed or Input:GetFocusedTextBox() then return end
 if key.KeyCode==Enum.KeyCode.C then Layout.Character:Fire()
 elseif key.KeyCode==Enum.KeyCode.T then Layout.Skills:Fire()
 elseif key.KeyCode==Enum.KeyCode.Escape then setOpen(false) end
end)
Run.RenderStepped:Connect(function()
 if snapshot and not snapshot.Confirmed and not panel.Visible and not player:GetAttribute("TownMenuOpen") and player.Character then setOpen(true) end
 tooltip.Visible=false
 if closeControl and snapshot then closeControl.Visible=snapshot.Confirmed end
 if not panel.Visible then return end
 local character=player.Character
 if not character or character:GetAttribute("Knockout") then setOpen(false);return end
 local hp=character:FindFirstChildOfClass("Humanoid");if hp then hp:Move(Vector3.zero,false) end
 local camera=workspace.CurrentCamera;if not camera then return end
 scale.Scale=math.min(1,camera.ViewportSize.X*.95/1100,camera.ViewportSize.Y*.9/720)
 refreshStats()
 if hovered then
  local text=tips[hovered];local height=TextService:GetTextSize(text,14,tooltip.Font,Vector2.new(330,1000)).Y+24
  tooltip.Text=text;tooltip.Size=UDim2.fromOffset(350,height)
  local mouse=Input:GetMouseLocation();tooltip.Position=UDim2.fromOffset(math.clamp(mouse.X+16,0,math.max(0,camera.ViewportSize.X-350)),math.clamp(mouse.Y+16,0,math.max(0,camera.ViewportSize.Y-height)));tooltip.Visible=true
 end
end)
remotes:WaitForChild("State").OnClientEvent:Connect(function(value)
 snapshot=value;if not draft or value.Confirmed then draft=table.clone(value.Stats) end
 redraw()
end)
player.CharacterRemoving:Connect(function() setOpen(false,true) end)
action:FireServer("Request")
