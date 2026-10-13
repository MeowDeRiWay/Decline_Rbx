local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("TownRemotes")
local action, state, notice = remotes:WaitForChild("Action"), remotes:WaitForChild("State"), remotes:WaitForChild("Notice")
local Config = require(ReplicatedStorage.Shared.TownConfig)
local Interaction = require(ReplicatedStorage.Shared.Interaction)
local gui = Instance.new("ScreenGui")
gui.Name, gui.ResetOnSpawn, gui.DisplayOrder = "TownUI", false, 30
gui.Parent = player:WaitForChild("PlayerGui")
local panel = Instance.new("Frame")
panel.AnchorPoint, panel.Position = Vector2.new(.5,.5), UDim2.fromScale(.5,.5)
panel.Size, panel.BackgroundColor3 = UDim2.fromScale(.8,.78), Color3.fromRGB(24,29,33)
local constraint = Instance.new("UISizeConstraint"); constraint.MaxSize = Vector2.new(640,640); constraint.Parent = panel
panel.Parent = gui
local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size, title.Position = UDim2.new(1,-24,0,48), UDim2.fromOffset(12,10)
title.BackgroundTransparency, title.TextColor3 = 1, Color3.fromRGB(239,239,229)
title.Font, title.TextSize, title.TextXAlignment = Enum.Font.GothamBold, 26, Enum.TextXAlignment.Left
title.Text, title.Parent = "Choose a town", panel
local scroll = Instance.new("ScrollingFrame")
scroll.Size, scroll.Position = UDim2.new(1,-24,1,-82), UDim2.fromOffset(12,70)
scroll.BackgroundTransparency, scroll.BorderSizePixel, scroll.ScrollBarThickness = 1, 0, 6
scroll.AutomaticCanvasSize, scroll.CanvasSize = Enum.AutomaticSize.Y, UDim2.new()
scroll.Parent = panel
local layout = Instance.new("UIListLayout"); layout.SortOrder = Enum.SortOrder.LayoutOrder; layout.Padding = UDim.new(0,8); layout.Parent = scroll
local content, order = scroll, 0
local snapshot, selected, section = {Towns = {}}, nil, nil
local hidden = false
local queue, messageUntil, message = {}, 0, ""
local confirmation
local function send(command, value, extra) action:FireServer(command,value,extra) end
local function text(caption, size)
 local label = Instance.new("TextLabel")
 label.Size, label.AutomaticSize = UDim2.new(1,-8,0,0), Enum.AutomaticSize.Y
 label.BackgroundTransparency, label.TextColor3 = 1, Color3.fromRGB(239,239,229)
 label.Font, label.TextSize, label.TextWrapped, label.TextXAlignment = Enum.Font.Gotham, size or 16, true, Enum.TextXAlignment.Left
 order += 1
 label.LayoutOrder = order
 label.Text, label.Parent = caption, content
 return label
end
local function button(caption, callback)
 local item = Instance.new("TextButton")
 item.Size, item.AutomaticSize = UDim2.new(1,-8,0,38), Enum.AutomaticSize.Y
 item.BackgroundColor3, item.TextColor3 = Color3.fromRGB(48,59,64), Color3.fromRGB(244,244,233)
 item.Font, item.TextSize, item.TextWrapped = Enum.Font.GothamMedium, 16, true
 order += 1
 item.LayoutOrder = order
 item.Text, item.Parent = caption, content
 item.Activated:Connect(callback)
 return item
end
local function townByID(id)
 for _, town in ipairs(snapshot.Towns) do if town.ID == id then return town end end
 return nil
end
local relationNames = {Neutral = "Neutral", Ally = "Alliance", War = "War"}
local render
local function toggle(value) section = if section == value then nil else value; confirmation = nil; render() end
local function confirm(caption, command, value, extra)
 confirmation = {caption, command, value, extra}; render()
end
local function detail(town)
 text(town.Name, 24)
 text("Team members: " .. town.Count .. "\nMayor: " .. town.LeaderName)
 for _, relation in ipairs(town.Relations) do text(relation.Name .. " — " .. relationNames[relation.Relation]) end
end
render = function()
 local offset = scroll.CanvasPosition
 content, order = scroll, 0
 for _, child in ipairs(scroll:GetChildren()) do if child ~= layout then child:Destroy() end end
 local session = snapshot.Session
 local choosing = not snapshot.TownID
 panel.Visible = (choosing and not hidden) or session ~= nil
 player:SetAttribute("TownMenuOpen", panel.Visible)
 if not panel.Visible then return end
 title.Text = if confirmation then "Confirm action" elseif not session then "Choose a town" elseif session.Kind == "Flag" then "Town" else "Construction"
 if confirmation then
  text(confirmation[1], 22)
  button("Confirm", function() local data = confirmation; confirmation = nil; send(data[2],data[3],data[4]); render() end)
  button("Cancel", function() confirmation = nil; render() end)
  return
 end
 if not session then
  if #snapshot.Towns == 0 then text("No towns are available.") end
  for _, town in ipairs(snapshot.Towns) do
   button(town.Name, function() selected = if selected == town.ID then nil else town.ID; render() end)
   if selected == town.ID then
    local details = Instance.new("Frame")
    order += 1
    details.Name, details.LayoutOrder = "TownDetails", order
    details.Size, details.AutomaticSize = UDim2.new(1,-8,0,0), Enum.AutomaticSize.Y
    details.BackgroundTransparency, details.Parent = 1, scroll
    local detailsLayout = Instance.new("UIListLayout")
    detailsLayout.SortOrder, detailsLayout.Padding, detailsLayout.Parent = Enum.SortOrder.LayoutOrder, UDim.new(0,8), details
    content = details
    detail(town)
    button("Join", function() send("Join",town.ID) end)
    content = scroll
   end
  end
  if player.Character then button("Close", function() hidden = true; render() end) end
 elseif session.Kind == "Flag" then
  local town = townByID(session.TownID)
  if not town then return end
  if section == "Diplomacy" and town.LeaderID ~= player.UserId then section = nil end
  if snapshot.TownID ~= town.ID and section ~= "Member" then section = nil end
  detail(town)
  if not section or section == "Member" then button("Membership",function() toggle("Member") end) end
  if section == "Member" then
   text("Join a town to become one of its citizens. To move to another town, leave your current team at its flag first.")
   if snapshot.TownID == town.ID then button("Leave team",function() confirm("Leave this town team?", "Leave") end)
   elseif not snapshot.TownID then button("Join",function() send("JoinFlag") end)
   else text("You currently belong to another town.") end
  end
  if snapshot.TownID == town.ID then
   if not section or section == "Power" then button("Leadership",function() toggle("Power") end) end
   if section == "Power" then
    text("The mayor approves construction and manages town diplomacy and building ownership. Votes are anonymous and end after 30 seconds or when everyone has voted. A tie keeps the mayor in office.")
    if town.LeaderID == 0 then button("Become mayor",function() send("ClaimMayor") end)
    elseif town.VoteEndsAt then text("A vote is in progress. Check your notification for the remaining time.")
    elseif town.CooldownEndsAt > workspace:GetServerTimeNow() then text("Next vote available in: " .. math.ceil(town.CooldownEndsAt-workspace:GetServerTimeNow()) .. " s")
    elseif town.LeaderID == player.UserId then
     text("You cannot start a removal vote against yourself. You can offer your resignation for the town to vote on.")
     button("Offer resignation",function() confirm("Offer your resignation and start a town vote?", "Resign") end)
    else button("Start a vote",function() confirm("Start an anonymous vote to remove the mayor?", "Vote") end) end
   end
   if town.LeaderID == player.UserId then
    if not section or section == "Diplomacy" then button("Diplomacy",function() toggle("Diplomacy") end) end
    if section == "Diplomacy" then
     text("Towns begin with neutral relations. An alliance needs approval from the other mayor. War and neutrality take effect for both towns as soon as you select them.")
     if #town.Relations == 0 then text("There are no other towns to contact.") end
     for _, relation in ipairs(town.Relations) do
      text(relation.Name .. " — " .. relationNames[relation.Relation])
      for _, value in ipairs(Config.Relations) do
       button(relationNames[value] .. (value == "Ally" and " — propose" or " — set"),function() send("Relation",relation.TownID,value) end)
      end
     end
    end
   end
  end
 else
  local plot = session.Plot
  local town = plot and townByID(plot.TownID)
  if not town then text("This plot is not assigned to a town.")
  elseif snapshot.TownID ~= town.ID then text("Only members of " .. town.Name .. " may build here.")
  else
   text(plot.BuildingID and ("Kitchen · level " .. plot.Level .. "\nOwner: " .. plot.OwnerName .. "\nCo-owners (UserID): " .. (plot.CoOwners ~= "" and plot.CoOwners or "none")) or "Empty plot")
   local isMayor = town.LeaderID == player.UserId
   local co = string.find("," .. plot.CoOwners .. ",", "," .. player.UserId .. ",", 1, true) ~= nil
   local owner = plot.OwnerID == player.UserId or co or isMayor
   if plot.Pending then text("Waiting for the mayor.")
   elseif not plot.BuildingID or owner then
    for _, option in ipairs(plot.Options) do button((plot.BuildingID and "Upgrade: " or "Build: ") .. option.Name .. " · level " .. option.Level,function() send("Build",option.ID) end) end
    if plot.BuildingID and #plot.Options == 0 then text("No further upgrades are available.") end
   end
   if plot.BuildingID then
    if isMayor then
     button("Change owner",function() toggle("Owner") end)
     if section == "Owner" then
      button("Remove owner",function() send("Owner",0) end)
      for _, member in ipairs(town.Members) do button(member.Name,function() send("Owner",member.ID) end) end
     end
    end
    if owner then
     button("Co-owners",function() toggle("CoOwner") end)
     if section == "CoOwner" then
      local owners = require(ReplicatedStorage.Shared.TownRules).ParseOwners(plot.CoOwners)
      for _, member in ipairs(town.Members) do
       if member.ID ~= plot.OwnerID then button((owners[member.ID] and "Remove: " or "Add: ") .. member.Name,function() send("CoOwner",member.ID,not owners[member.ID]) end) end
      end
      for id in pairs(owners) do
       local online = false
       for _, member in ipairs(town.Members) do if member.ID == id then online = true end end
       if not online then button("Remove UserID " .. id,function() send("CoOwner",id,false) end) end
      end
     end
     button("Demolish building",function() confirm("Demolish this building?", "Destroy") end)
    end
   end
  end
 end
 if session then button("Close",function() send("Close"); snapshot.Session = nil; confirmation = nil; hidden = true; render() end) end
 scroll.CanvasPosition = offset
end
local notifications = Instance.new("Frame")
notifications.AnchorPoint, notifications.Position = Vector2.new(1,.5), UDim2.fromScale(.98,.5)
notifications.Size, notifications.AutomaticSize = UDim2.new(.28,0,0,0), Enum.AutomaticSize.Y
notifications.BackgroundColor3, notifications.Visible = Color3.fromRGB(30,39,44), false
notifications.Parent = gui
local noticeLayout = Instance.new("UIListLayout"); noticeLayout.SortOrder = Enum.SortOrder.LayoutOrder; noticeLayout.Padding = UDim.new(0,6); noticeLayout.Parent = notifications
local caption = Instance.new("TextLabel")
caption.Size, caption.AutomaticSize = UDim2.new(1,0,0,0), Enum.AutomaticSize.Y
caption.BackgroundTransparency, caption.TextColor3, caption.TextWrapped = 1, Color3.fromRGB(255,239,184), true
caption.Font, caption.TextSize, caption.LayoutOrder, caption.Parent = Enum.Font.GothamMedium, 17, 1, notifications
local answers = Instance.new("Frame"); answers.BackgroundTransparency = 1; answers.LayoutOrder = 2; answers.Size = UDim2.new(1,0,0,38); answers.Parent = notifications
local function reply(choice)
 local request = queue[1]
 if not request or request.Answered then return end
 send("Reply",request.ID,choice)
 table.remove(queue,1)
 if request.Kind == "Vote" then request.Answered = true; table.insert(queue,request) end
end
for index, yes in ipairs({true,false}) do
 local item = Instance.new("TextButton")
 item.Size, item.Position = UDim2.new(.5,-4,1,0), UDim2.new((index-1)*.5,0,0,0)
 item.Text, item.TextSize = yes and "Y" or "N", 18
 item.BackgroundColor3, item.TextColor3, item.Parent = Color3.fromRGB(58,75,76), Color3.new(1,1,1), answers
 item.Activated:Connect(function() reply(yes) end)
end
local hovered
local highlight = Instance.new("Highlight")
highlight.Name = "TownInteractionHover"
highlight.FillColor, highlight.OutlineColor = Color3.fromRGB(80,190,110), Color3.fromRGB(125,255,160)
highlight.FillTransparency, highlight.DepthMode = .7, Enum.HighlightDepthMode.Occluded
highlight.Enabled, highlight.Parent = false, workspace
local hoverLabel = Instance.new("TextLabel")
hoverLabel.Name = "TownHoverLabel"
hoverLabel.Size = UDim2.fromOffset(200,44)
hoverLabel.BackgroundColor3 = Color3.fromRGB(22,28,33)
hoverLabel.BackgroundTransparency, hoverLabel.BorderSizePixel = .1, 0
hoverLabel.TextColor3 = Color3.fromRGB(240,240,235)
hoverLabel.Font, hoverLabel.TextSize, hoverLabel.Visible = Enum.Font.GothamMedium, 15, false
hoverLabel.Parent = gui
RunService.RenderStepped:Connect(function()
 local time = workspace:GetServerTimeNow()
 for index = #queue,1,-1 do if queue[index].EndsAt <= time then table.remove(queue,index) end end
 local request = queue[1]
 notifications.Visible = request ~= nil or messageUntil > time
 answers.Visible = request ~= nil and not request.Answered
 if request then
  caption.Text = request.Text .. "\n" .. (request.Answered and "Your vote has been recorded." or (request.Kind == "Vote" and "Y — keep the mayor · N — remove from office" or "Y — approve · N — decline")) .. "\n" .. math.ceil(request.EndsAt-time) .. " s" .. (#queue>1 and (" · Queued requests: " .. #queue) or "")
 else caption.Text = message end
 hovered, highlight.Enabled, hoverLabel.Visible = nil, false, false
 if panel.Visible or player:GetAttribute("InventoryOpen") or GuiService.MenuIsOpen or UserInputService:GetFocusedTextBox() then return end
 local character, camera = player.Character, workspace.CurrentCamera
 local root = character and character:FindFirstChild("HumanoidRootPart")
 if not root or not camera or character:GetAttribute("Knockout") then return end
 local mouse = UserInputService:GetMouseLocation()
 if mouse.X < 0 or mouse.Y < 0 or mouse.X > camera.ViewportSize.X or mouse.Y > camera.ViewportSize.Y then return end
 local ray = camera:ViewportPointToRay(mouse.X,mouse.Y)
 local params = RaycastParams.new(); params.FilterType = Enum.RaycastFilterType.Exclude; params.FilterDescendantsInstances = {character}
 local hit = workspace:Raycast(ray.Origin,ray.Direction*1000,params)
 local object = hit and hit.Instance
 while object and object ~= workspace do
  if object:IsA("Model") and object.Name == "Flag" then
   highlight.Adornee, highlight.Enabled = object, true
   if Interaction.Distance(object,root.Position) <= Config.InteractionDistance then hovered = object end
   break
  elseif object.Name == "BuildingMenu" and object.Parent and object.Parent.Name == "BuildingSpace" then
   highlight.Adornee, highlight.Enabled = object, true
   if Interaction.Distance(object,root.Position) <= Config.InteractionDistance then hovered = object.Parent end
   break
  end
  object = object.Parent
 end
 if highlight.Enabled then
  local label = if object.Name == "Flag" then "Flag" else "Building Menu"
  hoverLabel.Text = label .. (hovered and "\n[E] Open" or "\nToo far")
  hoverLabel.Position = UDim2.fromOffset(
   math.clamp(mouse.X+16,0,math.max(0,camera.ViewportSize.X-200)),
   math.clamp(mouse.Y+16,0,math.max(0,camera.ViewportSize.Y-44)))
  hoverLabel.Visible = true
 end
end)
UserInputService.InputBegan:Connect(function(input,processed)
 if processed or UserInputService:GetFocusedTextBox() then return end
 if queue[1] and (input.KeyCode == Enum.KeyCode.Y or input.KeyCode == Enum.KeyCode.N) then reply(input.KeyCode == Enum.KeyCode.Y)
 elseif input.KeyCode == Enum.KeyCode.E and hovered then hidden = false; section, confirmation = nil,nil; send("Open",hovered)
 elseif input.KeyCode == Enum.KeyCode.Escape and panel.Visible and player.Character then hidden = true; snapshot.Session = nil; confirmation = nil; send("Close"); render() end
end)
notice.OnClientEvent:Connect(function(data)
 if data.Kind then
  local index = #queue + 1
  for i, item in ipairs(queue) do if item.Answered then index = i; break end end
  table.insert(queue,index,data)
 else message, messageUntil = data.Text, workspace:GetServerTimeNow()+6 end
end)
state.OnClientEvent:Connect(function(data)
 local old = snapshot.Session
 if (old and old.Kind) ~= (data.Session and data.Session.Kind) or (old and old.TownID) ~= (data.Session and data.Session.TownID) then section, confirmation = nil,nil end
 if snapshot.TownID and not data.TownID then hidden = false end
 for index = #queue,1,-1 do
  if not table.find(data.Prompts or {}, queue[index].ID) then table.remove(queue,index) end
 end
 snapshot = data; render()
end)
send("Request")
