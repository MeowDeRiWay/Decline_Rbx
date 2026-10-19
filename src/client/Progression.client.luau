local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Input=game:GetService("UserInputService")
local Context=game:GetService("ContextActionService")
local player=Players.LocalPlayer
local config=require(ReplicatedStorage.Shared.ProgressionConfig)
local remotes=ReplicatedStorage:WaitForChild("ProgressionRemotes")
local action=remotes:WaitForChild("Action")
local gui=Instance.new("ScreenGui")
gui.Name="CharacterProgression"; gui.ResetOnSpawn=false; gui.DisplayOrder=20; gui.Parent=player:WaitForChild("PlayerGui")
local panel=Instance.new("Frame")
panel.AnchorPoint=Vector2.new(.5,.5); panel.Position=UDim2.fromScale(.5,.5); panel.Size=UDim2.fromScale(.66,.76)
panel.BackgroundColor3=Color3.fromRGB(22,29,35); panel.Visible=false; panel.Parent=gui
local size=Instance.new("UISizeConstraint"); size.MaxSize=Vector2.new(800,700); size.MinSize=Vector2.new(320,300); size.Parent=panel
local title=Instance.new("TextLabel")
title.Position=UDim2.fromOffset(20,12); title.Size=UDim2.new(1,-80,0,32); title.BackgroundTransparency=1
title.Font=Enum.Font.GothamBold; title.TextSize=20; title.TextColor3=Color3.fromRGB(235,240,245); title.Text="Character · [P]"; title.Parent=panel
local list=Instance.new("ScrollingFrame")
list.Position=UDim2.fromOffset(20,58); list.Size=UDim2.new(1,-40,1,-76); list.BackgroundTransparency=1; list.BorderSizePixel=0
list.ScrollBarThickness=6; list.AutomaticCanvasSize=Enum.AutomaticSize.Y; list.CanvasSize=UDim2.new(); list.Parent=panel
local layout=Instance.new("UIListLayout"); layout.Padding=UDim.new(0,10); layout.SortOrder=Enum.SortOrder.LayoutOrder; layout.Parent=list
local snapshot
local order=0
local function row(text,callback,height)
 order+=1
 local object=Instance.new(callback and "TextButton" or "TextLabel")
 object.Size=UDim2.new(1,-10,0,height or 48); object.LayoutOrder=order; object.BackgroundColor3=Color3.fromRGB(36,48,57)
 object.TextColor3=Color3.fromRGB(235,240,245); object.TextWrapped=true; object.Font=Enum.Font.GothamMedium; object.TextSize=15
 object.Text=text; object.Parent=list
 if callback then object.Activated:Connect(callback) end
 return object
end
local function redraw()
 if not snapshot then return end
 for _,child in ipairs(list:GetChildren()) do if child:IsA("GuiObject") then child:Destroy() end end
 order=0
 row(string.format("%s · Level %d · XP %d / %d · Attribute points: %d",snapshot.Profession=="" and "No profession" or snapshot.Profession,snapshot.Level,snapshot.XP,snapshot.NextXP,snapshot.Points),nil,60)
 if snapshot.Profession=="" then
  row("Choose Cook",function() action:FireServer("Choose","Cook") end)
  row("Cook unlocks the stove, cutting board and kitchen construction. Profession selection is permanent for this server session.",nil,64)
 else row("Cook · Stove / Cutting Board · Build: Kitchen",nil,48) end
 local bonus=snapshot.Bonuses
 row(string.format("Carry: %g kg · Max HP: %g · Accuracy: %.0f%% · Luck: %.0f%%",bonus.CarryLimitKg,bonus.MaxHealth,bonus.Accuracy*100,bonus.LuckChance*100),nil,56)
 local descriptions={Strength="+1 kg carry capacity, +1 melee damage",Endurance="+0.2 running speed, +5 max HP",Attention="+2% accuracy (max 90%), +5 studs forward view",Luck="+3% bonus loot chance (max 50%); +1 bonus item per 3 points"}
 for _,stat in ipairs(config.Stats) do
  local button=row(string.format("%s: %d   [+]  %s",stat,snapshot.Stats[stat],descriptions[stat]),function() action:FireServer("Spend",stat) end,64)
  button.AutoButtonColor=snapshot.Points>0
 end
 row("Talents",nil,36)
 local profession=config.Professions[snapshot.Profession]
 local count=0
 if profession then
  local ids={}; for id in pairs(profession.Talents) do table.insert(ids,id) end; table.sort(ids)
  for _,id in ipairs(ids) do
   local talent=profession.Talents[id]; count+=1
   row(string.format("%s · Requires level %d%s",talent.Name or id,talent.Level or 0,snapshot.Talents[id] and " · Learned" or ""),function() action:FireServer("Talent",id) end)
  end
 end
 if count==0 then row("Cook talents have not been defined yet.",nil,46) end
end
local function setOpen(open)
 panel.Visible=open; player:SetAttribute("ProgressionOpen",open)
 if open then
  Context:BindActionAtPriority("ProgressionBlockMovement",function() return Enum.ContextActionResult.Sink end,false,Enum.ContextActionPriority.High.Value+2,Enum.PlayerActions.CharacterForward,Enum.PlayerActions.CharacterBackward,Enum.PlayerActions.CharacterLeft,Enum.PlayerActions.CharacterRight,Enum.PlayerActions.CharacterJump)
  action:FireServer("Request")
 else Context:UnbindAction("ProgressionBlockMovement") end
end
local close=Instance.new("TextButton")
close.Size=UDim2.fromOffset(36,32); close.Position=UDim2.new(1,-48,0,12); close.Text="X"; close.Parent=panel
close.Activated:Connect(function() setOpen(false) end)
Input.InputBegan:Connect(function(input,processed)
 if processed or Input:GetFocusedTextBox() then return end
 if input.KeyCode==Enum.KeyCode.P and not player:GetAttribute("InventoryOpen") and not player:GetAttribute("TownMenuOpen") then setOpen(not panel.Visible) end
 if input.KeyCode==Enum.KeyCode.Escape and panel.Visible then setOpen(false) end
end)
remotes:WaitForChild("State").OnClientEvent:Connect(function(value) snapshot=value; redraw() end)
player.CharacterRemoving:Connect(function() setOpen(false) end)
action:FireServer("Request")
