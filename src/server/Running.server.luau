local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage.Shared.GameConfig)
local Rules = require(ReplicatedStorage.Shared.MovementRules)
local remote = Instance.new("RemoteEvent")
remote.Name = "SetRunning"
remote.Parent = ReplicatedStorage
local Sprint=require(ReplicatedStorage.Shared.SprintRules)
local requested = {}
local reserves = {}
remote.OnServerEvent:Connect(function(player,value)
 if typeof(value) ~= "boolean" then return end
 requested[player] = value
end)
local function added(player)
 player.CharacterAdded:Connect(function() requested[player] = false; reserves[player]=nil end)
 requested[player] = false
end
Players.PlayerAdded:Connect(added)
Players.PlayerRemoving:Connect(function(player) requested[player] = nil;reserves[player]=nil end)
for _,player in ipairs(Players:GetPlayers()) do added(player) end
RunService.Heartbeat:Connect(function(dt)
 for player,wantsRun in pairs(requested) do
  local character = player.Character
  local humanoid = character and character:FindFirstChildOfClass("Humanoid")
  if not humanoid then continue end
  local allowed = humanoid.Health > 0 and not humanoid.Sit and not humanoid.PlatformStand and not character:GetAttribute("Knockout") and not character:GetAttribute("CraftingLocked")
  local maximum=Sprint.Maximum()
  local reserve=reserves[player]
  if not reserve or reserve.Character~=character then reserve={Character=character,Value=maximum,Exhausted=false};reserves[player]=reserve end
  local moving=humanoid.MoveDirection.Magnitude>.01
  local running
  reserve.Value,reserve.Exhausted,running=Sprint.Step(reserve.Value,maximum,reserve.Exhausted,wantsRun,moving,allowed,dt)
  local value=math.floor(reserve.Value*10)/10
  if character:GetAttribute("SprintRemaining")~=value then character:SetAttribute("SprintRemaining",value) end
  if character:GetAttribute("SprintMaximum")~=maximum then character:SetAttribute("SprintMaximum",maximum) end
  local multiplier = Rules.LoadMultiplier(character:GetAttribute("LoadKg"),Config,player:GetAttribute("CarryLimitKg"))
  local speed = (character:GetAttribute("Knockout") or character:GetAttribute("CraftingLocked")) and 0 or (Config.WalkSpeed+(player:GetAttribute("WalkBonus") or 0) + (running and (Config.RunSpeedBonus+(player:GetAttribute("RunBonus") or 0)) or 0))*multiplier
  if humanoid.WalkSpeed ~= speed then humanoid.WalkSpeed = speed end
  if character:GetAttribute("Running") ~= running then character:SetAttribute("Running",running) end
 end
end)
