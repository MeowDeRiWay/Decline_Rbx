local Players = game:GetService("Players")
local Teams = game:GetService("Teams")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Config = require(ReplicatedStorage.Shared.TownConfig)
local Rules = require(ReplicatedStorage.Shared.TownRules)
local Interaction = require(ReplicatedStorage.Shared.Interaction)
local Inventory = require(script.Parent.InventoryService)
local Service = {}
local towns, plots, sessions, pending, lastAction = {}, {}, {}, {}, {}
local sequence = 0
local remote, notice
local names = {}
local colors = {"Bright blue", "Bright red", "Bright green", "Bright yellow", "Bright violet", "Bright orange"}
local function now() return workspace:GetServerTimeNow() end
local function tell(player, text)
 if player and player.Parent == Players then notice:FireClient(player, {Text = text}) end
end
local function nameOf(id)
 if not Rules.ValidID(id) then return "Vacant" end
 local online = Players:GetPlayerByUserId(id)
 if online then return online.Name end
 if names[id] then return names[id] end
 names[id] = tostring(id)
 task.spawn(function()
  local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, id)
  if ok then names[id] = name; Service.Publish() end
 end)
 return names[id]
end
local function townOf(player) return towns[player:GetAttribute("TownID")] end
local function members(town)
 local result = {}
 for _, player in ipairs(Players:GetPlayers()) do
  if townOf(player) == town then table.insert(result, player) end
 end
 return result
end
local function alive(player)
 local character = player.Character
 local hp = character and character:FindFirstChildOfClass("Humanoid")
 local root = character and character:FindFirstChild("HumanoidRootPart")
 return hp and hp.Health > 0 and not character:GetAttribute("Knockout") and not character:GetAttribute("IsDead") and root
end
local function near(player, object)
 local root = alive(player)
 if not root or not object or not object:IsDescendantOf(workspace) then return false end
 local point = Interaction.NearestPoint(object, root.Position)
 if (point - root.Position).Magnitude > Config.InteractionDistance then return false end
 local params = RaycastParams.new()
 params.FilterType = Enum.RaycastFilterType.Exclude
 params.FilterDescendantsInstances = {player.Character}
 local hit = workspace:Raycast(root.Position, point - root.Position, params)
 return not hit or hit.Instance == object or hit.Instance:IsDescendantOf(object)
end
local function mayor(player, town) return town and townOf(player) == town and town.leader == player.UserId end
local function setLeader(town, id)
 if town.vote then
  town.vote = nil
  town.cooldown = now() + Config.VoteCooldown
  for _, member in ipairs(members(town)) do tell(member, "The vote was cancelled because the mayor changed.") end
 end
 town.leader = id
 for _, flag in ipairs(town.flags) do flag:SetAttribute("LeaderID", id) end
end
local function cancelRequests(town)
 for id, request in pairs(pending) do
  if request.town == town or request.other == town then
   pending[id] = nil
   if request.plot then request.plot.pending = nil end
   tell(request.player, "Request cancelled because leadership or membership changed.")
  end
 end
end
local function relation(a, b) return a.relations[b.id] or "Neutral" end
local function syncPlot(plot)
 plot.model:SetAttribute("OwnerID", plot.owner)
 plot.model:SetAttribute("Co-OwnerID", Rules.SerializeOwners(plot.coowners))
 plot.model:SetAttribute("BuildingID", plot.kind)
 plot.model:SetAttribute("BuildingLevel", plot.level)
 if plot.building then
  for _, key in ipairs({"OwnerID", "Co-OwnerID", "TeamID", "TownID", "BuildingID", "BuildingLevel"}) do
   plot.building:SetAttribute(key, plot.model:GetAttribute(key))
  end
 end
end
local function plotTown(plot)
 local town = towns[plot.model:GetAttribute("TownID")]
 return town and town.teamID == plot.model:GetAttribute("TeamID") and town or nil
end
local function owns(player, plot)
 return plot.owner == player.UserId or plot.coowners[player.UserId] or mayor(player, plotTown(plot))
end
local function buildingMenu(plot)
 return (plot.building and plot.building:FindFirstChild("BuildingMenu",true)) or plot.menu
end
local function costFor(kind,level)
 local definition=Config.Buildings[kind]
 return (definition and definition.Costs and definition.Costs[level]) or {}
end
local function hasMaterials(player,kind,level)
 local items=Inventory.Snapshot(player).Items
 for id,amount in pairs(costFor(kind,level)) do if (items[id] or 0)<amount then return false end end
 return true
end
local function plotSnapshot(plot)
 local town = plotTown(plot)
 local options = {}
 if plot.kind then
  local definition = Config.Buildings[plot.kind]
  if definition and definition.Levels[plot.level + 1] then
   table.insert(options, {ID = plot.kind, Name = definition.Name, Level = plot.level + 1, Cost = costFor(plot.kind,plot.level+1)})
  end
 else
  for id, definition in pairs(Config.Buildings) do
   table.insert(options, {ID = id, Name = definition.Name, Level = 1, Cost = costFor(id,1)})
  end
 end
 return {Model = plot.model, TownID = town and town.id, OwnerID = plot.owner, OwnerName = nameOf(plot.owner),
  CoOwners = Rules.SerializeOwners(plot.coowners), BuildingID = plot.kind, Level = plot.level,
  Options = options, Pending = plot.pending ~= nil}
end
function Service.Snapshot(player)
 local list = {}
 for _, town in pairs(towns) do
  local relations = {}
  for _, other in pairs(towns) do
   if town ~= other then table.insert(relations, {TownID = other.id, Name = other.name, Relation = relation(town, other)}) end
  end
  table.sort(relations, function(a,b) return a.TownID < b.TownID end)
  local people = {}
  for _, member in ipairs(members(town)) do table.insert(people, {ID = member.UserId, Name = member.Name}) end
  table.sort(people, function(a,b) return a.ID < b.ID end)
  table.insert(list, {ID = town.id, TeamID = town.teamID, Name = town.name, Count = #people,
   LeaderID = town.leader, LeaderName = nameOf(town.leader), Members = people, Relations = relations,
   VoteEndsAt = town.vote and town.vote.endsAt, CooldownEndsAt = town.cooldown})
 end
 table.sort(list, function(a,b) return a.ID < b.ID end)
 local session = sessions[player]
 if session and not near(player, session.target) then sessions[player] = nil; session = nil end
 local prompts = {}
 for _, town in pairs(towns) do
  if town.vote and town.vote.eligible[player.UserId] then table.insert(prompts, town.vote.id) end
 end
 for id, request in pairs(pending) do if request.leader == player.UserId then table.insert(prompts, id) end end
 local election
 local town = townOf(player)
 local vote = town and town.vote
 if vote and vote.kind == "Election" and vote.eligible[player.UserId] then
  local candidates = {}
  for id in pairs(vote.candidates) do
   local candidate = Players:GetPlayerByUserId(id)
   if candidate and townOf(candidate) == town then table.insert(candidates, {ID = id, Name = candidate.Name}) end
  end
  table.sort(candidates, function(a,b) return a.ID < b.ID end)
  election = {ID = vote.id, Candidates = candidates, Participating = vote.participants[player.UserId] == true,
   Answered = vote.votes[player.UserId] ~= nil, EndsAt = vote.endsAt}
 end
 return {Towns = list, Election = election, Prompts = prompts, TownID = player:GetAttribute("TownID"), Session = session and {
  Kind = session.kind, TownID = session.town and session.town.id,
  Plot = session.plot and plotSnapshot(session.plot),
 } or nil}
end
function Service.Publish()
 if not remote then return end
 for _, player in ipairs(Players:GetPlayers()) do remote:FireClient(player, Service.Snapshot(player)) end
end
local function requestApproval(player, town, data)
 local leader = Players:GetPlayerByUserId(town.leader)
 if not leader or not mayor(leader, town) then tell(player, "The town mayor is currently offline."); return end
 sequence += 1
 data.id, data.player, data.town, data.leader, data.endsAt = sequence, player, town, town.leader, now() + Config.ApprovalDuration
 pending[sequence] = data
 if data.plot then data.plot.pending = sequence end
 notice:FireClient(leader, {ID = sequence, Kind = "Approval", Text = data.text, EndsAt = data.endsAt})
 tell(player, "Request sent to the mayor.")
end
local function templateFor(kind, level)
 local definition = Config.Buildings[kind]
 local folder = ServerStorage:FindFirstChild("Buildings")
 local template = definition and folder and folder:FindFirstChild(definition.Levels[level])
 if not template and kind=="Kitchen" and level==1 and folder then template=folder:FindFirstChild("Kitchen_1") end
 return template and template:IsA("Model") and template:FindFirstChildWhichIsA("BasePart", true) and template or nil
end
local function build(plot, kind, level, player)
 local template = templateFor(kind, level)
 if not template then return false end
 local clone = template:Clone()
 local sourceSpace=clone:FindFirstChild("Space")
 local alignment=sourceSpace and sourceSpace:GetPivot():ToObjectSpace(clone:GetPivot()) or CFrame.new()
 clone:PivotTo(plot.frame*alignment)
 if not Inventory.ConsumeIngredients(player,{Ingredients=costFor(kind,level)},1) then
  clone:Destroy(); return false,"You need 1 Tree Log in your inventory to build this kitchen."
 end
 if plot.building then plot.building:Destroy() end
 if plot.space.Parent then plot.space.Parent = nil end
 plot.kind, plot.level, plot.building = kind, level, clone
 clone.Parent = plot.model
 if clone:FindFirstChild("BuildingMenu",true) then plot.menu.Parent=nil else plot.menu.Parent=plot.model end
 syncPlot(plot)
 return true
end
local function destroyBuilding(plot)
 if plot.building then plot.building:Destroy() end
 plot.building, plot.kind, plot.level, plot.owner, plot.coowners = nil, nil, 0, 0, {}
 plot.space.Parent = plot.model
 plot.menu.Parent = plot.model
 syncPlot(plot)
end
local function join(player, town)
 if player.Character and not alive(player) then tell(player, "Please wait until you respawn."); return end
 if townOf(player) then tell(player, "Leave your current team at its flag first."); return end
 local hasSpawn = false
 for _, object in ipairs(workspace:GetDescendants()) do
  if object.Name == "TownSpawn" and object:GetAttribute("TeamID") == town.teamID and (object:IsA("BasePart") or object:IsA("Model")) then hasSpawn = true; break end
 end
 if not hasSpawn then tell(player, "No TownSpawn with TeamID=" .. town.teamID .. " matches Flag.Team=" .. town.teamID .. "."); return end
 player:SetAttribute("TownID", town.id)
 player:SetAttribute("TeamID", town.teamID)
 player.Team, player.Neutral = town.team, false
 local claimedMayor = town.leader == 0
 if claimedMayor and not town.vote then setLeader(town, player.UserId) end
 sessions[player] = nil
 if player.Character then Service.PlaceCharacter(player, player.Character)
 elseif Service.LoadCharacter(player) == false then
  player.Team, player.Neutral = nil, true
  player:SetAttribute("TownID", nil); player:SetAttribute("TeamID", nil)
  if claimedMayor and town.leader == player.UserId then setLeader(town, 0) end
 end
 Service.Publish()
end
-- CharacterAdded fires before Roblox finishes moving a newly loaded character.
-- Position only after LoadCharacterAsync completes, for both joining and respawning.
function Service.LoadCharacter(player)
 if player.Parent ~= Players or player:GetAttribute("CharacterLoading") then return end
 player:SetAttribute("CharacterLoading", true)
 local ok, err = pcall(function() player:LoadCharacterAsync() end)
 player:SetAttribute("CharacterLoading", nil)
 if not ok then
  warn("[Decline] Character load failed: " .. tostring(err))
  tell(player, "Unable to spawn your character. Please try again.")
  return false
 end
 if player.Parent == Players and player.Character then Service.PlaceCharacter(player, player.Character) end
 return true
end
function Service.PlaceCharacter(player, character)
 local town = townOf(player)
 if not town then return end
 local spawn, hospital
 for _, object in ipairs(workspace:GetDescendants()) do
  if object.Name == "TownSpawn" and object:GetAttribute("TeamID") == town.teamID and (object:IsA("BasePart") or object:IsA("Model")) then spawn = spawn or object end
  if object:IsA("Model") and object:GetAttribute("BuildingID") == "Hospital" and object:GetAttribute("TownID") == town.id then
   local marker = object:FindFirstChild("HospitalSpawn", true)
   if marker and (marker:IsA("BasePart") or marker:IsA("Model")) then hospital = marker end
  end
 end
 local target = hospital or spawn
 if not target then warn("[Decline] Missing TownSpawn for team " .. town.teamID); return end
 local hp = character:WaitForChild("Humanoid", 10)
 local root = character:WaitForChild("HumanoidRootPart", 10)
 if player.Character ~= character or not hp or not root then return end
 local frame, size
 if target:IsA("Model") then frame, size = target:GetBoundingBox() else frame, size = target.CFrame, target.Size end
 local radius = math.abs(frame.RightVector.Y)*size.X/2 + math.abs(frame.UpVector.Y)*size.Y/2 + math.abs(frame.LookVector.Y)*size.Z/2
 character:PivotTo(CFrame.new(frame.Position + Vector3.new(0, radius + root.Size.Y/2 + hp.HipHeight + .1, 0)))
 root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
 hp.Health = hospital and hp.MaxHealth or 2
 character:SetAttribute("Health", hp.Health)
end
local startElection
local function finishVote(town)
 local vote = town.vote
 if not vote then return end
 town.vote = nil
 if vote.kind == "Election" then
  town.cooldown = now() + Config.VoteCooldown
  local counts, highest, winners = {}, 0, {}
  for _, candidate in pairs(vote.votes) do
   if typeof(candidate) == "number" and vote.candidates[candidate] then
    local member = Players:GetPlayerByUserId(candidate)
    if member and townOf(member) == town then counts[candidate] = (counts[candidate] or 0) + 1 end
   end
  end
  for id, count in pairs(counts) do
   if count > highest then highest, winners = count, {id}
   elseif count == highest then table.insert(winners, id) end
  end
  if #winners == 1 then
   setLeader(town, winners[1])
   for _, member in ipairs(members(town)) do tell(member, nameOf(winners[1]) .. " has been elected mayor with " .. highest .. " votes.") end
  elseif #winners > 1 and not vote.runoff then
   for _, member in ipairs(members(town)) do tell(member, "The election is tied. A runoff between the leading candidates is starting.") end
   startElection(town, winners)
  else
   for _, member in ipairs(members(town)) do tell(member, "No mayor was elected. The position remains vacant; start another election at the flag.") end
  end
  return
 end
 town.cooldown = now() + Config.VoteCooldown
 local keep, remove = 0, 0
 for _, choice in pairs(vote.votes) do if choice then remove += 1 else keep += 1 end end
 local removed = Rules.Removed(keep, remove)
 if removed and town.leader == vote.leader then cancelRequests(town); setLeader(town, 0) end
 for _, player in ipairs(members(town)) do
  tell(player, string.format("Vote ended: remove — %d, keep — %d. %s", remove, keep, removed and "A new mayor will now be elected." or "The mayor stays in office."))
 end
 if removed then startElection(town) end
end
local function completeVote(town)
 local vote = town.vote
 if not vote then return end
 for id in pairs(vote.eligible) do if vote.votes[id] == nil then return end end
 finishVote(town)
end
startElection = function(town, finalists)
 if town.vote then return end
 local citizens = members(town)
 if #citizens == 0 then return end
 sequence += 1
 local vote = {id = sequence, kind = "Election", endsAt = now() + Config.VoteDuration,
  eligible = {}, candidates = {}, participants = {}, votes = {}, runoff = finalists ~= nil}
 town.vote = vote
 for _, member in ipairs(citizens) do
  vote.eligible[member.UserId] = true
  if not finalists or table.find(finalists, member.UserId) then vote.candidates[member.UserId] = true end
 end
 for _, member in ipairs(citizens) do
  notice:FireClient(member, {ID = vote.id, Kind = "Election", Text = "Would you like to take part in electing a new mayor?", EndsAt = vote.endsAt})
 end
end
local function startVote(player, town, resignation)
 if mayor(player, town) ~= (resignation == true) then
  tell(player, "Only the mayor can resign. Other members can start a removal vote."); return
 end
 if town.vote then tell(player, "A vote is already in progress."); return end
 if town.leader == 0 then tell(player, "This town has no mayor."); return end
 if resignation then
  cancelRequests(town)
  setLeader(town, 0)
  for _, member in ipairs(members(town)) do tell(member, player.Name .. " has resigned as mayor.") end
  startElection(town)
  return
 end
 if town.cooldown > now() then tell(player, "Voting is not available yet."); return end
 sequence += 1
 local vote = {id = sequence, kind = "Removal", leader = town.leader, endsAt = now() + Config.VoteDuration, eligible = {}, votes = {}}
 town.vote = vote
 for _, member in ipairs(members(town)) do
  vote.eligible[member.UserId] = true
  notice:FireClient(member, {ID = vote.id, Kind = "Vote", Text = member.UserId == town.leader and
   "A vote to remove you from office has started." or "A vote to remove the mayor has started.", EndsAt = vote.endsAt})
 end
end
local function handle(player, command, value, extra)
 if command == "Request" then remote:FireClient(player, Service.Snapshot(player)); return end
 if command == "Close" then sessions[player] = nil; return end
 if command == "Join" then local town = towns[value]; if town then join(player, town) end; return end
 if command == "VoteCandidate" then
  local town = townOf(player)
  local vote = town and town.vote
  local candidate = Rules.ValidID(extra) and Players:GetPlayerByUserId(extra)
  if not vote or vote.kind ~= "Election" or vote.id ~= value or vote.endsAt <= now() or not vote.eligible[player.UserId]
   or not vote.participants[player.UserId] or vote.votes[player.UserId] ~= nil or not vote.candidates[extra]
   or not candidate or townOf(candidate) ~= town then return end
  vote.votes[player.UserId] = extra
  tell(player, "Your anonymous vote has been recorded.")
  completeVote(town); Service.Publish(); return
 end
 if command == "Reply" then
  if typeof(value) ~= "number" or typeof(extra) ~= "boolean" then return end
  for _, town in pairs(towns) do
   local vote = town.vote
   if vote and vote.id == value and vote.endsAt > now() and vote.eligible[player.UserId] and townOf(player) == town then
    if vote.votes[player.UserId] == nil then
     if vote.kind == "Election" then
      vote.participants[player.UserId] = extra
      if not extra then vote.votes[player.UserId] = false end
     else vote.votes[player.UserId] = extra end
     tell(player, vote.kind == "Election" and (extra and "Choose a candidate from your town." or "You declined to participate.") or "Your anonymous vote has been recorded.")
     completeVote(town)
     Service.Publish()
    end
    return
   end
  end
  local request = pending[value]
  if not request or request.endsAt <= now() or request.leader ~= player.UserId or not mayor(player, request.town) then return end
  pending[value] = nil
  if request.plot then request.plot.pending = nil end
  if not extra then tell(request.player, "The mayor declined your request."); return end
  if request.kind == "Build" then
   local plot = request.plot
   if not plot.model:IsDescendantOf(workspace) or plotTown(plot) ~= request.town or townOf(request.player) ~= request.town or plot.kind ~= request.previousKind or plot.level ~= request.previousLevel then return end
   if plot.kind and not owns(request.player, plot) then return end
   if not alive(request.player) or not near(request.player,buildingMenu(plot)) then
    tell(request.player,"Construction cancelled: return to the building sign and request approval again.")
    Service.Publish(); return
   end
   local built,reason=build(plot, request.building, request.level, request.player)
   if built then
    if request.level == 1 then plot.owner = request.player.UserId; syncPlot(plot) end
    tell(request.player, "Construction approved. The building is complete.")
   else tell(request.player, reason or "Building template not found in ServerStorage/Buildings.") end
  elseif request.kind == "Alliance" and mayor(request.player, request.other) then
   request.town.relations[request.other.id], request.other.relations[request.town.id] = "Ally", "Ally"
  end
  Service.Publish(); return
 end
 local root = alive(player)
 if not root then return end
 if command == "Open" then
  if typeof(value) ~= "Instance" then return end
  for _, town in pairs(towns) do
   for _, flag in ipairs(town.flags) do
    if flag == value and near(player, flag) then sessions[player] = {kind = "Flag", town = town, target = flag}; Service.Publish(); return end
   end
  end
  local plot = plots[value]
  local menu = plot and buildingMenu(plot)
  if menu and near(player, menu) then sessions[player] = {kind = "Building", plot = plot, target = menu}; Service.Publish() end
  return
 end
 local session = sessions[player]
 if not session or not near(player, session.target) then sessions[player] = nil; return end
 if session.kind == "Flag" then
  local town = session.town
  if command == "JoinFlag" then join(player, town); return end
  if townOf(player) ~= town then return end
  if command == "Leave" then
   if mayor(player, town) then cancelRequests(town); setLeader(town, 0) end
   if town.vote then town.vote.eligible[player.UserId] = nil; town.vote.votes[player.UserId] = nil
    if town.vote.kind == "Election" then
     town.vote.candidates[player.UserId] = nil
     for id, choice in pairs(town.vote.votes) do if choice == player.UserId then town.vote.votes[id] = nil end end
    end
    completeVote(town) end
   for id, request in pairs(pending) do
    if request.player == player then if request.plot then request.plot.pending = nil end; pending[id] = nil end
   end
   player.Team, player.Neutral = nil, true
   player:SetAttribute("TownID", nil); player:SetAttribute("TeamID", nil)
   sessions[player] = nil
  elseif command == "Vote" then startVote(player, town, false)
  elseif command == "Resign" then startVote(player, town, true)
  elseif command == "Election" and town.leader == 0 and not town.vote then startElection(town)
  elseif command == "Relation" and mayor(player, town) then
   local other = towns[value]
   if not other or other == town or not table.find(Config.Relations, extra) then return end
   if extra == "Ally" then
    if relation(town, other) == "Ally" then return end
    for _, request in pairs(pending) do
     if request.kind == "Alliance" and ((request.town == town and request.other == other) or (request.town == other and request.other == town)) then tell(player, "An alliance request is already awaiting a response."); return end
    end
    requestApproval(player, other, {kind = "Alliance", other = town, text = "The mayor of " .. town.name .. " (" .. player.Name .. ") proposes an alliance."})
   else
    for id, request in pairs(pending) do
     if request.kind == "Alliance" and ((request.town == town and request.other == other) or (request.town == other and request.other == town)) then pending[id] = nil end
    end
    town.relations[other.id], other.relations[town.id] = extra, extra
   end
  end
 else
  local plot = session.plot
  local town = plotTown(plot)
  if not town or townOf(player) ~= town then return end
  if command == "Build" then
   local definition = typeof(value) == "string" and Config.Buildings[value]
   local level = plot.kind and plot.level + 1 or 1
   if not definition or not definition.Levels[level] or (plot.kind and (plot.kind ~= value or not owns(player, plot))) or plot.pending then return end
   if not templateFor(value, level) then tell(player, "Add the model ServerStorage/Buildings/" .. definition.Levels[level]); return end
   if not hasMaterials(player,value,level) then tell(player,"You need 1 Tree Log in your inventory to build this kitchen."); return end
   requestApproval(player, town, {kind = "Build", plot = plot, building = value, level = level,
    previousKind = plot.kind, previousLevel = plot.level, text = player.Name .. " wants to " .. (level == 1 and "start construction: " or "upgrade: ") .. definition.Name .. ". Cost: 1 Tree Log from the builder's inventory."})
  elseif command == "Destroy" and plot.kind and owns(player, plot) then
   if plot.pending then pending[plot.pending] = nil; plot.pending = nil end
   destroyBuilding(plot)
  elseif command == "Owner" and plot.kind and mayor(player, town) then
   if value == 0 then plot.owner = 0; syncPlot(plot)
   else
    local member = Rules.ValidID(value) and Players:GetPlayerByUserId(value)
    if member and townOf(member) == town then plot.owner = value; plot.coowners[value] = nil; syncPlot(plot) end
   end
  elseif command == "CoOwner" and plot.kind and owns(player, plot) and Rules.ValidID(value) and typeof(extra) == "boolean" then
   if not extra then plot.coowners[value] = nil; syncPlot(plot)
   else
    local member = Players:GetPlayerByUserId(value)
    if member and townOf(member) == town and plot.owner ~= value then plot.coowners[value] = true; syncPlot(plot) end
   end
  end
 end
 Service.Publish()
end
function Service.Start()
 local folder = Instance.new("Folder"); folder.Name = "TownRemotes"; folder.Parent = ReplicatedStorage
 remote = Instance.new("RemoteEvent"); remote.Name = "State"; remote.Parent = folder
 notice = Instance.new("RemoteEvent"); notice.Name = "Notice"; notice.Parent = folder
 local action = Instance.new("RemoteEvent"); action.Name = "Action"; action.Parent = folder
 local flags = {}
 for _, object in ipairs(workspace:GetDescendants()) do if object:IsA("Model") and object.Name == "Flag" then table.insert(flags, object) end end
 table.sort(flags, function(a,b)
  if (a:GetAttribute("Main") == true) ~= (b:GetAttribute("Main") == true) then return a:GetAttribute("Main") == true end
  return a:GetFullName() < b:GetFullName()
 end)
 for _, flag in ipairs(flags) do
  local id, teamID = flag:GetAttribute("TownID"), flag:GetAttribute("Team")
  if not Rules.ValidID(id) or not Rules.ValidID(teamID) or not flag:FindFirstChildWhichIsA("BasePart", true) then warn("[Decline] Flag needs positive TownID, Team and physical parts"); continue end
  local town = towns[id]
  if not town then
   local collision = false
   for _, other in pairs(towns) do if other.teamID == teamID then collision = true end end
   if collision then warn("[Decline] Town teams must have unique numeric IDs"); continue end
   local team = Instance.new("Team"); team.Name = tostring(flag:GetAttribute("Town_name") or ("Town " .. id))
   team.TeamColor = BrickColor.new(colors[(id - 1) % #colors + 1]); team.AutoAssignable = false; team:SetAttribute("TeamID", teamID); team.Parent = Teams
   town = {id = id, teamID = teamID, name = team.Name, team = team, flags = {}, leader = Rules.ValidID(flag:GetAttribute("LeaderID")) and flag:GetAttribute("LeaderID") or 0, relations = {}, cooldown = 0}
   towns[id] = town
  end
  if town.teamID ~= teamID then warn("[Decline] Conflicting Team for TownID " .. id); continue end
  table.insert(town.flags, flag); flag:SetAttribute("LeaderID", town.leader)
  local colorModel = flag:FindFirstChild("TeamColor")
  if colorModel then for _, part in ipairs(colorModel:GetDescendants()) do if part:IsA("BasePart") then part.Color = town.team.TeamColor.Color end end end
 end
 for _, object in ipairs(workspace:GetDescendants()) do
  if object:IsA("Model") and object.Name == "BuildingSpace" then
   local space, menu = object:FindFirstChild("Space"), object:FindFirstChild("BuildingMenu")
   if space and menu and (space:IsA("Model") or space:IsA("BasePart")) then
    local plot = {model = object, space = space, menu = menu, frame = space:GetPivot(), owner = object:GetAttribute("OwnerID") or 0,
     coowners = Rules.ParseOwners(object:GetAttribute("Co-OwnerID")), kind = nil, level = 0}
    -- Existing configured buildings survive service startup.
    for _, child in ipairs(object:GetChildren()) do
     local kind = child:GetAttribute("BuildingID")
     if child:IsA("Model") and Config.Buildings[kind] then plot.building, plot.kind, plot.level = child, kind, child:GetAttribute("BuildingLevel") or 1; space.Parent = nil; break end
    end
    if plot.building and plot.building:FindFirstChild("BuildingMenu",true) then menu.Parent=nil end
    plots[object] = plot; syncPlot(plot)
    if not plotTown(plot) then warn("[Decline] BuildingSpace TownID/TeamID do not match a Flag") end
   else warn("[Decline] BuildingSpace needs Space and BuildingMenu") end
  end
 end
 local function added(player)
  player.Neutral = true
  if player.Character then task.defer(Service.PlaceCharacter, player, player.Character) end
 end
 Players.PlayerAdded:Connect(added)
 for _, player in ipairs(Players:GetPlayers()) do added(player) end
 Players.PlayerRemoving:Connect(function(player)
  sessions[player], lastAction[player] = nil, nil
  for _, town in pairs(towns) do if town.vote then town.vote.eligible[player.UserId] = nil; town.vote.votes[player.UserId] = nil
    if town.vote.kind == "Election" then
     town.vote.candidates[player.UserId] = nil
     for id, choice in pairs(town.vote.votes) do if choice == player.UserId then town.vote.votes[id] = nil end end
    end
    completeVote(town) end end
  for id, request in pairs(pending) do if request.player == player then if request.plot then request.plot.pending = nil end; pending[id] = nil end end
  task.defer(Service.Publish)
 end)
 action.OnServerEvent:Connect(function(player, command, value, extra)
  if typeof(command) ~= "string" then return end
  local time = os.clock()
  if time - (lastAction[player] or -math.huge) < .1 then return end
  lastAction[player] = time
  handle(player, command, value, extra)
 end)
 task.spawn(function()
  while true do
   task.wait(1)
   for _, town in pairs(towns) do if town.vote and town.vote.endsAt <= now() then finishVote(town) end end
   for id, request in pairs(pending) do
    if request.endsAt <= now() then pending[id] = nil; if request.plot then request.plot.pending = nil end; tell(request.player, "The request expired without a response from the mayor.") end
   end
   for _, player in ipairs(Players:GetPlayers()) do
    local root = alive(player)
    local closest, distance
    if root then
     for _, town in pairs(towns) do
      for _, flag in ipairs(town.flags) do
       if flag:IsDescendantOf(workspace) then
        local delta = root.Position - flag:GetPivot().Position
        local d = Vector3.new(delta.X, 0, delta.Z).Magnitude
        if d <= Config.Radius and (not distance or d < distance) then closest, distance = town, d end
       end
      end
     end
    end
    player:SetAttribute("TerritoryTownID", closest and closest.id)
    player:SetAttribute("TerritoryTeamID", closest and closest.teamID)
   end
   Service.Publish()
  end
 end)
end
return Service
