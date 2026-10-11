local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage.Shared.GameConfig)
local World = require(script.Parent.Services.World)
local Characters = require(script.Parent.Services.Characters)
Players.CharacterAutoLoads = false
local world = World.Start(Config)
local remotes = Instance.new("Folder")
remotes.Name, remotes.Parent = "DeclineRemotes", ReplicatedStorage
local function remote(name)
 local event = Instance.new("RemoteEvent")
 event.Name, event.Parent = name, remotes
 return event
end
local selectTown, openTerminal = remote("SelectTown"), remote("OpenTerminal")
local sprint, reset = remote("Sprint"), remote("Reset")
local states = {}
local function now() return workspace:GetServerTimeNow() end
local function townFor(id)
 for _, town in ipairs(world.Towns:GetChildren()) do
  local flag = town:FindFirstChild("Flag")
  if flag and flag:GetAttribute("Town_ID") == id then return town end
 end
end
local function sync(player, key, value)
 player:SetAttribute(key, value)
 if player.Character then player.Character:SetAttribute(key, value) end
end
local function spawn(player)
 local state = states[player]
 if not state then return end
 local town = townFor(player:GetAttribute("Town_ID"))
 local point = town and town.Spawn or world.Lobby.Spawn
 local character = Characters.Spawn(player, point.Position, Config)
 state.character, state.knockoutEnd, state.sprinting = character, nil, false
 state.health, state.food, state.water, state.sick = Config.MaxHealth, 100, 100, 100
 for key, value in pairs({Health = state.health, Food = 100, Water = 100, Sick = 100, Knockout = false, KnockoutEnd = 0, CorpseProtectedUntil = 0, AFK = false}) do sync(player, key, value) end
 character:SetAttribute("Leader", player:GetAttribute("Leader"))
end
local function knockout(player)
 local state = states[player]
 if not state or not state.character or state.knockoutEnd then return end
 state.health = 0
 state.knockoutEnd = now() + Config.KnockoutSeconds
 state.sprinting = false
 sync(player, "Health", 0)
 sync(player, "Knockout", true)
 sync(player, "KnockoutEnd", state.knockoutEnd)
 local humanoid = state.character:FindFirstChildOfClass("Humanoid")
 humanoid.WalkSpeed, humanoid.PlatformStand = 0, true
 local root = state.character.HumanoidRootPart
 root:SetNetworkOwner(nil)
 state.character:PivotTo(CFrame.new(root.Position.X, root.Position.Y - 2, root.Position.Z) * CFrame.Angles(math.pi / 2, 0, 0))
 root.Anchored = true
end
local function die(player)
 local state = states[player]
 local corpse = state.character
 corpse:SetAttribute("Corpse", true)
 corpse:SetAttribute("CorpseProtectedUntil", now() + Config.CorpseProtectionSeconds)
 corpse:SetAttribute("Knockout", false)
 local humanoid = corpse:FindFirstChildOfClass("Humanoid")
 humanoid.DisplayName = player.DisplayName .. " — загинув"
 humanoid.Health = 0
 for _, item in ipairs(corpse:GetDescendants()) do
  if item:IsA("BasePart") then item.Anchored = true end
 end
 task.delay(Config.CorpseLifetime, function() corpse:Destroy() end)
 spawn(player)
 sync(player, "CorpseProtectedUntil", corpse:GetAttribute("CorpseProtectedUntil"))
end
local function added(player)
 if states[player] then return end
 states[player] = {lastSelection = 0}
 for key, value in pairs({Town_ID = 0, User_ID = player.UserId, Leader = false, Profession = "", LoadKg = 0, Working = false}) do player:SetAttribute(key, value) end
 for _, profession in ipairs(Config.Professions) do
  player:SetAttribute(profession, 0)
  player:SetAttribute(profession .. "XP", 0)
 end
 spawn(player)
end
Players.PlayerAdded:Connect(added)
Players.PlayerRemoving:Connect(function(player)
 -- AFK retention will be added with a cross-server presence registry.
 local state = states[player]
 if state and state.character then state.character:Destroy() end
 states[player] = nil
end)
for _, player in ipairs(Players:GetPlayers()) do added(player) end
world.Lobby.Terminal.ProximityPrompt.Triggered:Connect(function(player)
 if player:GetAttribute("Town_ID") == 0 then openTerminal:FireClient(player) end
end)
selectTown.OnServerEvent:Connect(function(player, id, profession)
 local state = states[player]
 if not state or player:GetAttribute("Town_ID") ~= 0 or state.knockoutEnd then return end
 if now() - state.lastSelection < 0.5 then return end
 state.lastSelection = now()
 if typeof(id) ~= "number" or id ~= math.floor(id) or typeof(profession) ~= "string" or not table.find(Config.Professions, profession) then return end
 local town = townFor(id)
 local root = state.character and state.character:FindFirstChild("HumanoidRootPart")
 if not town or not root or (root.Position - world.Lobby.Terminal.Position).Magnitude > 16 then return end
 player:SetAttribute("Town_ID", id)
 player:SetAttribute("Profession", profession)
 local flag = town.Flag
 if flag:GetAttribute("LeaderUser_ID") == 0 then
  flag:SetAttribute("LeaderUser_ID", player.UserId)
  player:SetAttribute("Leader", true)
 end
 spawn(player)
end)
sprint.OnServerEvent:Connect(function(player, enabled)
 local state = states[player]
 if not state or typeof(enabled) ~= "boolean" or state.knockoutEnd then return end
 state.sprinting = enabled
 state.character.Humanoid.WalkSpeed = enabled and Config.RunSpeed or Config.WalkSpeed
end)
reset.OnServerEvent:Connect(knockout)
local elapsed = 0
RunService.Heartbeat:Connect(function(dt)
 elapsed += dt
 if elapsed < 0.25 then return end
 local step = elapsed
 elapsed = 0
 for player, state in pairs(states) do
  local character = state.character
  local humanoid = character and character:FindFirstChildOfClass("Humanoid")
  if not humanoid then continue end
  if state.knockoutEnd then
   if now() >= state.knockoutEnd then die(player) end
   continue
  end
  -- Health is authoritative here. Later damage services must call a shared damage API.
  if humanoid.Health < math.max(1, state.health) then state.health = humanoid.Health end
  if humanoid.Health <= 0 then knockout(player); continue end
  if player:GetAttribute("Town_ID") ~= 0 then
   local moving = humanoid.MoveDirection.Magnitude > 0.05
   local rate = moving and (state.sprinting and 0.04 or 0.02) or 0.01
   rate += player:GetAttribute("Working") and 0.01 or 0
   rate += math.max(0, player:GetAttribute("LoadKg") or 0) * 0.001
   state.food = math.max(0, state.food - rate * step)
   state.water = math.max(0, state.water - rate * step)
   if state.sick <= 49 then state.sick = math.max(0, state.sick - 0.05 * step) end
   local damage = (state.food == 0 and 0.1 or 0) + (state.water == 0 and 0.1 or 0) + (state.sick == 0 and 0.1 or 0)
   state.health = math.max(0, state.health - damage * step)
  end
  if state.health <= 0 then knockout(player) else humanoid.Health = state.health end
  for key, value in pairs({Health = state.health, Food = state.food, Water = state.water, Sick = state.sick}) do sync(player, key, value) end
 end
end)
print("[Decline] Foundation ready")
