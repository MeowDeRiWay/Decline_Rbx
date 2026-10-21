local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Input=game:GetService("UserInputService")
local Run=game:GetService("RunService")
local Context=game:GetService("ContextActionService")
local GuiService=game:GetService("GuiService")
local Theme=require(ReplicatedStorage.Shared.UITheme)
local Affiliation=require(ReplicatedStorage.Shared.AffiliationRules)
local Layout=require(script.Parent.HUDLayout)
local View=require(script.Parent.EventVisibility)
local player=Players.LocalPlayer
local remotes=ReplicatedStorage:WaitForChild("GroupRemotes")
local action=remotes:WaitForChild("Action")
local state={Members={},ID=0,Leader=0,Maximum=8}
local gui=Instance.new("ScreenGui");gui.Name="GroupsUI";gui.ResetOnSpawn=false;gui.DisplayOrder=25;gui.Parent=player:WaitForChild("PlayerGui")
local panel=Instance.new("Frame")
panel.AnchorPoint=Vector2.new(.5,.5);panel.Position=UDim2.fromScale(.5,.45);panel.Size=UDim2.fromOffset(480,490)
panel.BackgroundColor3=Theme.Panel;panel.Visible=false;panel.Parent=gui;Theme.Bevel(panel)
local scale=Instance.new("UIScale");scale.Parent=panel
local title=Instance.new("TextLabel");title.Position=UDim2.fromOffset(18,10);title.Size=UDim2.fromOffset(444,34)
title.BackgroundTransparency=1;title.Font=Theme.Font;title.TextSize=20;title.TextColor3=Theme.Text;title.Text="Group · G to close";title.Parent=panel
local list=Instance.new("ScrollingFrame")
list.Position=UDim2.fromOffset(18,56);list.Size=UDim2.new(1,-36,1,-74);list.BackgroundTransparency=1;list.BorderSizePixel=0
list.ScrollBarThickness=4;list.AutomaticCanvasSize=Enum.AutomaticSize.Y;list.CanvasSize=UDim2.new();list.Parent=panel
local layout=Instance.new("UIListLayout");layout.Padding=UDim.new(0,8);layout.SortOrder=Enum.SortOrder.LayoutOrder;layout.Parent=list
local function row(text,callback)
 local item=Instance.new(callback and "TextButton" or "TextLabel")
 item.Size=UDim2.new(1,-8,0,44);item.Text=text;item.TextWrapped=true;item.TextSize=14;item.Font=Theme.Font
 item.BackgroundColor3=callback and Theme.Button or Theme.Card;item.TextColor3=Theme.Text;item.BorderSizePixel=0;item.Parent=list
 if callback then Theme.Bevel(item);item.Activated:Connect(callback) end
 return item
end
local function open(value)
 if value and (player:GetAttribute("InventoryOpen") or player:GetAttribute("ProgressionOpen") or player:GetAttribute("TownMenuOpen") or GuiService.MenuIsOpen or not player.Character or player.Character:GetAttribute("Knockout")) then return end
 panel.Visible=value;player:SetAttribute("GroupOpen",value)
 if value then
  Context:BindActionAtPriority("GroupBlockMovement",function() return Enum.ContextActionResult.Sink end,false,Enum.ContextActionPriority.High.Value+2,
   Enum.PlayerActions.CharacterForward,Enum.PlayerActions.CharacterBackward,Enum.PlayerActions.CharacterLeft,Enum.PlayerActions.CharacterRight,Enum.PlayerActions.CharacterJump)
 else Context:UnbindAction("GroupBlockMovement") end
end
local function redraw()
 for _,child in ipairs(list:GetChildren()) do if child:IsA("GuiObject") then child:Destroy() end end
 local invite=state.Invite
 if invite and invite.Expires>workspace:GetServerTimeNow() then
  row(invite.Name.." invited you to a group.")
  row("Accept invitation",function() action:FireServer("Reply",true) end)
  row("Decline invitation",function() action:FireServer("Reply",false) end)
 end
 if state.ID~=0 then
  row(string.format("Members: %d / %d",#state.Members,state.Maximum))
  for _,member in ipairs(state.Members) do
   local caption=member.Name..(member.ID==state.Leader and " · Leader" or "")
   if state.Leader==player.UserId and member.ID~=player.UserId then
    row(caption.." · Remove",function() action:FireServer("Kick",member.ID) end)
   else row(caption) end
  end
  row("Leave group",function() action:FireServer("Leave") end)
 else row("No group. Invite a nearby faction member to start one.") end
 if state.ID==0 or state.Leader==player.UserId then
  row("Nearby faction members · Invite")
  local camera=workspace.CurrentCamera
  local character=player.Character
  local root=character and character:FindFirstChild("HumanoidRootPart")
  local found=false
  for _,other in ipairs(Players:GetPlayers()) do
   local target=other.Character
   local part=target and target:FindFirstChild("HumanoidRootPart")
   local hp=target and target:FindFirstChildOfClass("Humanoid")
   if other~=player and Affiliation.SameFaction(player,other) and (other:GetAttribute("GroupID") or 0)==0 and root and camera and part and hp and hp.Health>0 and not target:GetAttribute("Knockout") and (part.Position-root.Position).Magnitude<=40 and View.Check(target,root,character,camera) then
    found=true
    row("Invite "..(other.DisplayName or other.Name),function() action:FireServer("Invite",other.UserId) end)
   end
  end
  if not found then row("No available players in sight.") end
 end
end
local function toggle() if panel.Visible then open(false) else redraw();open(true) end end
Layout.Group.Event:Connect(toggle)
Input.InputBegan:Connect(function(key,processed)
 if processed or Input:GetFocusedTextBox() then return end
 if key.KeyCode==Enum.KeyCode.G then toggle()
 elseif key.KeyCode==Enum.KeyCode.Escape then open(false) end
end)
remotes:WaitForChild("State").OnClientEvent:Connect(function(value)
 local previous=state.Invite;state=value
 if value.Invite and (not previous or previous.Token~=value.Invite.Token) then redraw();open(true)
 elseif panel.Visible then redraw() end
end)
for _,attribute in ipairs({"InventoryOpen","ProgressionOpen","TownMenuOpen"}) do
 player:GetAttributeChangedSignal(attribute):Connect(function() if player:GetAttribute(attribute) then open(false) end end)
end
player.CharacterRemoving:Connect(function() open(false) end)
-- Group labels live in PlayerGui, independent of the creature visibility mask.
local tags={}
Players.PlayerRemoving:Connect(function(other) if tags[other] then tags[other]:Destroy();tags[other]=nil end end)
local elapsed,refresh=0,0
Run.RenderStepped:Connect(function(dt)
 if panel.Visible then
  local camera=workspace.CurrentCamera
  if camera then scale.Scale=math.min(1,camera.ViewportSize.X*.9/480,camera.ViewportSize.Y*.8/490) end
  local hp=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
  if GuiService.MenuIsOpen or not hp or hp.Health<=0 or player.Character:GetAttribute("Knockout") then open(false)
  else hp:Move(Vector3.zero,false) end
 end
 elapsed+=dt;refresh+=dt
 if elapsed<.1 then return end;elapsed=0
 local group=player:GetAttribute("GroupID") or 0
 for _,other in ipairs(Players:GetPlayers()) do
  local tag=tags[other]
  local character=other.Character
  local hp=character and character:FindFirstChildOfClass("Humanoid")
  local anchor=character and (character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart"))
  local member=other~=player and group~=0 and other:GetAttribute("GroupID")==group
  if member and not tag then
   tag=Instance.new("BillboardGui");tag.Name="GroupMemberName";tag.Size=UDim2.fromOffset(190,28);tag.AlwaysOnTop=true;tag.MaxDistance=0;tag.Parent=gui
   local text=Instance.new("TextLabel");text.Size=UDim2.fromScale(1,1);text.BackgroundTransparency=1;text.TextColor3=Theme.Accent;text.TextStrokeTransparency=.3;text.Font=Theme.Font;text.TextSize=14;text.Parent=tag
   tags[other]=tag
  end
  if tag then
   tag.Enabled=member and anchor~=nil and hp~=nil and hp.Health>0
   if tag.Enabled then tag.Adornee=anchor;tag.StudsOffsetWorldSpace=Vector3.new(0,anchor.Size.Y/2+.65,0);tag:FindFirstChildOfClass("TextLabel").Text=other.DisplayName or other.Name end
  end
 end
 if refresh>=1 then
  refresh=0
  if state.Invite and state.Invite.Expires<=workspace:GetServerTimeNow() then state.Invite=nil end
  if panel.Visible then redraw() end
 end
end)
action:FireServer("Request")
