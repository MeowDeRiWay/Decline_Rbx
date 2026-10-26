local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local player = Players.LocalPlayer
local Theme=require(ReplicatedStorage.Shared.UITheme)
local remotes = ReplicatedStorage:WaitForChild("TownRemotes")
local action, state, notice = remotes:WaitForChild("Action"), remotes:WaitForChild("State"), remotes:WaitForChild("Notice")
local Config = require(ReplicatedStorage.Shared.TownConfig)
local ProgressionConfig = require(ReplicatedStorage.Shared.ProgressionConfig)
local Interaction = require(ReplicatedStorage.Shared.Interaction)
local gui = Instance.new("ScreenGui")
gui.Name, gui.ResetOnSpawn, gui.DisplayOrder = "TownUI", false, 30
gui.Parent = player:WaitForChild("PlayerGui")
local panel = Instance.new("Frame")
panel.AnchorPoint, panel.Position = Vector2.new(.5,.5), UDim2.fromScale(.5,.5)
panel.Size, panel.BackgroundColor3 = UDim2.fromScale(.8,.78), Theme.Panel
local constraint = Instance.new("UISizeConstraint"); constraint.MaxSize = Vector2.new(640,640); constraint.Parent = panel
panel.Parent = gui
Theme.Bevel(panel)
local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size, title.Position = UDim2.new(1,-24,0,48), UDim2.fromOffset(12,10)
title.BackgroundTransparency, title.TextColor3 = 1, Theme.Text
title.Font, title.TextSize, title.TextXAlignment = Theme.Font, 26, Enum.TextXAlignment.Left
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
local expelTarget,expelReason=nil,""
local function send(command, value, extra) action:FireServer(command,value,extra) end
local function text(caption, size)
 local label = Instance.new("TextLabel")
 label.Size, label.AutomaticSize = UDim2.new(1,-8,0,0), Enum.AutomaticSize.Y
 label.BackgroundTransparency, label.TextColor3 = 1, Theme.Text
 label.Font, label.TextSize, label.TextWrapped, label.TextXAlignment = Theme.Font, size or 16, true, Enum.TextXAlignment.Left
 order += 1
 label.LayoutOrder = order
 label.Text, label.Parent = caption, content
 return label
end
local function button(caption, callback)
 local item = Instance.new("TextButton")
 item.Size, item.AutomaticSize = UDim2.new(1,-8,0,38), Enum.AutomaticSize.Y
 item.BackgroundColor3, item.TextColor3 = Theme.Button, Theme.Text
 item.Font, item.TextSize, item.TextWrapped = Theme.Font, 16, true
 order += 1
 item.LayoutOrder = order
 item.Text, item.Parent = caption, content
 Theme.Bevel(item)
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
  if (section == "Diplomacy" or section == "Citizens") and town.LeaderID ~= player.UserId then section = nil end
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
    text("The mayor approves construction and manages town diplomacy and building ownership. Votes are anonymous and end after 30 seconds or when everyone has voted. A tied removal vote keeps the mayor. A successful removal starts an election, where you can also vote for yourself.")
    if town.VoteEndsAt then text("A vote is in progress. Check your notification for the remaining time.")
    elseif town.LeaderID == 0 then button("Start election",function() send("Election") end)
    elseif town.LeaderID == player.UserId then
     text("You cannot start a removal vote against yourself. Resigning immediately leaves office and starts an election for a new mayor.")
     button("Resign as mayor",function() confirm("Resign now and start an election for a new mayor?", "Resign") end)
    elseif town.CooldownEndsAt > workspace:GetServerTimeNow() then text("Next removal vote available in: " .. math.ceil(town.CooldownEndsAt-workspace:GetServerTimeNow()) .. " s")
    else button("Start a vote",function() confirm("Start an anonymous vote to remove the mayor?", "Vote") end) end
   end
   if town.LeaderID == player.UserId then
    if not section or section == "Citizens" then button("Citizens",function() expelTarget=nil;expelReason="";toggle("Citizens") end) end
    if section == "Citizens" then
     text("Expel a citizen from the faction. A reason is required and shared with every faction member.")
     for _,member in ipairs(town.Members) do
      if member.ID~=player.UserId then button(member.Name,function() expelTarget=member.ID;expelReason="";render() end) end
     end
     if expelTarget then
      local targetName
      for _,member in ipairs(town.Members) do if member.ID==expelTarget then targetName=member.Name end end
      if targetName then
       text("Expel "..targetName.." · Reason (up to 200 characters)")
       local input=Instance.new("TextBox")
       order+=1;input.LayoutOrder=order;input.Size=UDim2.new(1,-8,0,70)
       input.BackgroundColor3=Theme.Card;input.TextColor3=Theme.Text;input.Font=Theme.Font;input.TextSize=16
       input.TextWrapped=true;input.ClearTextOnFocus=false;input.PlaceholderText="Required reason";input.Text=expelReason;input.Parent=content
       input:GetPropertyChangedSignal("Text"):Connect(function() expelReason=input.Text end)
       button("Expel citizen",function()
        if expelReason:find("%S") then confirm("Expel "..targetName.."? Reason: "..expelReason,"Expel",expelTarget,expelReason) end
       end)
      end
     end
    end
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
   local isMayor = town.LeaderID == player.UserId
   local owners = require(ReplicatedStorage.Shared.TownRules).ParseOwners(plot.CoOwners)
   local owner = plot.OwnerID == player.UserId or owners[player.UserId] or isMayor
   local manageOwners = plot.OwnerID == player.UserId or isMayor
   if (section == "Owner" and not isMayor) or (section == "CoOwner" and not manageOwners) or not plot.BuildingID then section = nil end
   local function back()
    section, confirmation = nil,nil
    scroll.CanvasPosition = Vector2.zero
    render()
   end
   if section == "Owner" then
    title.Text = "Owner"
    button("← Back to building",back)
    text("Current owner: " .. plot.OwnerName,20)
    text("Select a town member to assign ownership of this building.")
    button("Remove owner",function() send("Owner",0) end)
    for _, member in ipairs(town.Members) do
     button(member.Name .. (member.ID == plot.OwnerID and " · Current owner" or ""),function() send("Owner",member.ID) end)
    end
   elseif section == "CoOwner" then
    title.Text = "Co-owners"
    button("← Back to building",back)
    text("Manage shared access",20)
    text("Add or remove co-owners for this building. The primary owner is managed separately.")
    local count = 0
    for _, member in ipairs(town.Members) do
     if member.ID ~= plot.OwnerID then
      count += 1
      button((owners[member.ID] and "Remove: " or "Add: ") .. member.Name,function() send("CoOwner",member.ID,not owners[member.ID]) end)
     end
    end
    for id in pairs(owners) do
     local online = false
     for _, member in ipairs(town.Members) do if member.ID == id then online = true end end
     if not online then count += 1; button("Remove UserID " .. id,function() send("CoOwner",id,false) end) end
    end
    if count == 0 then text("There are no other town members to add yet.") end
   else
    local count = 0
    for _ in pairs(owners) do count += 1 end
    text(plot.BuildingID and ((Config.Buildings[plot.BuildingID] and Config.Buildings[plot.BuildingID].Name or plot.BuildingID) .. " · level " .. plot.Level .. "\nOwner: " .. plot.OwnerName .. "\nCo-owners: " .. count) or "Empty plot")
    if plot.Pending then text("Waiting for the mayor.")
    elseif not plot.BuildingID or owner then
     local function materials(cost)
      local parts={}
      for id,amount in pairs(cost or {}) do table.insert(parts,tostring(amount).." "..id) end
      table.sort(parts);return table.concat(parts,", ")
     end
     for _, option in ipairs(plot.Options) do
      local requirements={}
      local rule=ProgressionConfig.BuildingRequirements[option.ID] or {}
      for id,amount in pairs(rule.Skills or {}) do
       table.insert(requirements,(ProgressionConfig.Names[id] or id).." "..amount)
      end
      table.sort(requirements)
      local caption=(plot.BuildingID and "Upgrade: " or "Build: ") .. option.Name .. " · level " .. option.Level .. " · Cost: " .. materials(option.Cost)
      if #requirements>0 then caption..="\nRequires: "..table.concat(requirements,", ") end
      local locked=option.CanBuild==false
      if locked then caption..="\nRequirements not met" end
      local item=button(caption,function() if not locked then send("Build",option.ID) end end)
      if locked then item.TextColor3=Theme.Muted;item.AutoButtonColor=false end
     end
     if plot.BuildingID and #plot.Options == 0 then text("No further upgrades are available.") end
    end
    if plot.BuildingID then
     if isMayor then button("Owner",function() scroll.CanvasPosition=Vector2.zero; toggle("Owner") end) end
     if manageOwners then button("Co-owners",function() scroll.CanvasPosition=Vector2.zero; toggle("CoOwner") end) end
     if owner then
      button("Demolish building",function() confirm("Demolish this building?", "Destroy") end)
     end
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
caption.Font, caption.TextSize, caption.LayoutOrder, caption.Parent = Theme.Font, 17, 1, notifications
local answers = Instance.new("Frame"); answers.BackgroundTransparency = 1; answers.LayoutOrder = 2; answers.Size = UDim2.new(1,0,0,38); answers.Parent = notifications
local function reply(choice)
 local request = queue[1]
 if not request or request.Answered or request.Participating then return end
 send("Reply",request.ID,choice)
 if request.Kind == "Election" then
  request.Participating, request.Answered = choice, not choice
  return
 end
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
local candidateList = Instance.new("ScrollingFrame")
candidateList.Name, candidateList.LayoutOrder = "ElectionCandidates", 3
candidateList.Size, candidateList.CanvasSize = UDim2.new(1,0,0,160), UDim2.new()
candidateList.AutomaticCanvasSize, candidateList.ScrollBarThickness = Enum.AutomaticSize.Y, 6
candidateList.BackgroundTransparency, candidateList.Visible, candidateList.Parent = 1, false, notifications
local candidateLayout = Instance.new("UIListLayout")
candidateLayout.SortOrder, candidateLayout.Padding, candidateLayout.Parent = Enum.SortOrder.LayoutOrder, UDim.new(0,4), candidateList
local function updateCandidates(election)
 for _, child in ipairs(candidateList:GetChildren()) do if child ~= candidateLayout then child:Destroy() end end
 if not election or not election.Participating or election.Answered then return end
 for index, candidate in ipairs(election.Candidates) do
  local item = Instance.new("TextButton")
  item.LayoutOrder, item.Size = index, UDim2.new(1,-8,0,36)
  item.Text = candidate.Name .. (candidate.ID == player.UserId and " (you)" or "")
  item.Font, item.TextSize = Theme.Font, 15
  item.BackgroundColor3, item.TextColor3, item.Parent = Color3.fromRGB(58,75,76), Color3.new(1,1,1), candidateList
  item.Activated:Connect(function()
   send("VoteCandidate",election.ID,candidate.ID)
  end)
 end
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
hoverLabel.BackgroundColor3 = Theme.Card
hoverLabel.BackgroundTransparency, hoverLabel.BorderSizePixel = .1, 0
hoverLabel.TextColor3 = Color3.fromRGB(240,240,235)
hoverLabel.Font, hoverLabel.TextSize, hoverLabel.Visible = Theme.Font, 15, false
hoverLabel.Parent = gui
RunService.RenderStepped:Connect(function()
 local time = workspace:GetServerTimeNow()
 for index = #queue,1,-1 do if queue[index].EndsAt <= time then table.remove(queue,index) end end
 local request = queue[1]
 notifications.Visible = request ~= nil or messageUntil > time
 answers.Visible = request ~= nil and not request.Answered and not request.Participating
 candidateList.Visible = request ~= nil and request.Kind == "Election" and request.Participating == true and not request.Answered
 if request then
  caption.Text = request.Text .. "\n" .. (request.Answered and "Your response has been recorded." or (request.Kind == "Election" and
   (request.Participating and "Choose the next mayor below. You may vote for yourself." or "Y — participate · N — skip") or
   (request.Kind == "Vote" and "Y — remove the mayor · N — keep in office" or "Y — approve · N — decline"))) .. "\n" .. math.ceil(request.EndsAt-time) .. " s" .. (#queue>1 and (" · Queued requests: " .. #queue) or "")
 else caption.Text = message end
 hovered, highlight.Enabled, hoverLabel.Visible = nil, false, false
 if panel.Visible or player:GetAttribute("GroupOpen") or player:GetAttribute("ProgressionOpen") or player:GetAttribute("InventoryOpen") or GuiService.MenuIsOpen or UserInputService:GetFocusedTextBox() then return end
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
  elseif object.Name == "BuildingMenu" then
   local plot=object.Parent
   while plot and plot~=workspace and plot.Name~="BuildingSpace" do plot=plot.Parent end
   if plot and plot~=workspace then
    highlight.Adornee, highlight.Enabled = object, true
    if Interaction.Distance(object,root.Position) <= Config.InteractionDistance then hovered = plot end
    break
   end
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
 if data.Election then
  for _, request in ipairs(queue) do
   if request.ID == data.Election.ID then request.Participating, request.Answered = data.Election.Participating, data.Election.Answered end
  end
 end
 table.sort(queue, function(a,b)
  local answeredA, answeredB = a.Answered == true, b.Answered == true
  if answeredA ~= answeredB then return not answeredA end
  return a.ID < b.ID
 end)
 updateCandidates(data.Election)
 snapshot = data; render()
 player:SetAttribute("TownStateReady",true)
end)
send("Request")
