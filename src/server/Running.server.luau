local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage.Shared.GameConfig)
local Rules = require(ReplicatedStorage.Shared.MovementRules)
local remote = Instance.new("RemoteEvent")
remote.Name = "SetRunning"
remote.Parent = ReplicatedStorage
local requested = {}
remote.OnServerEvent:Connect(function(player,value)
 if typeof(value) ~= "boolean" then return end
 requested[player] = value
end)
local function added(player)
 player.CharacterAdded:Connect(function() requested[player] = false end)
 requested[player] = false
end
Players.PlayerAdded:Connect(added)
Players.PlayerRemoving:Connect(function(player) requested[player] = nil end)
for _,player in ipairs(Players:GetPlayers()) do added(player) end
RunService.Heartbeat:Connect(function()
 for player,wantsRun in pairs(requested) do
  local character = player.Character
  local humanoid = character and character:FindFirstChildOfClass("Humanoid")
  if not humanoid then continue end
  local running = wantsRun and humanoid.Health > 0 and not humanoid.Sit and not humanoid.PlatformStand and not character:GetAttribute("Knockout")
  local multiplier = Rules.LoadMultiplier(character:GetAttribute("LoadKg"),Config)
  local speed = (character:GetAttribute("Knockout") or character:GetAttribute("CraftingLocked")) and 0 or (Config.WalkSpeed + (running and Config.RunSpeedBonus or 0))*multiplier
  if humanoid.WalkSpeed ~= speed then humanoid.WalkSpeed = speed end
  if character:GetAttribute("Running") ~= running then character:SetAttribute("Running",running) end
 end
end)
