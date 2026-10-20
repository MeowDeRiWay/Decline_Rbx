-- Default Roblox character sounds are created locally on every listener's client.
-- Apply to every player's rig, including respawns and late-created Running sounds.
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Config=require(ReplicatedStorage.Shared.GameConfig)
local watched=setmetatable({},{__mode="k"})
local function configure(sound)
 if not sound:IsA("Sound") or sound.Name~="Running" or watched[sound] then return end
 watched[sound]=true
 sound.RollOffMode=Enum.RollOffMode.InverseTapered
 sound.RollOffMinDistance=Config.FootstepMinDistance
 sound.RollOffMaxDistance=Config.FootstepMaxDistance
 local function volume()
  -- Preserve any lower volume selected by the default sound controller.
  if sound.Volume>Config.FootstepVolume then sound.Volume=Config.FootstepVolume end
 end
 volume()
 sound:GetPropertyChangedSignal("Volume"):Connect(volume)
end
local characterConnections={}
local function bind(player)
 local function characterAdded(character)
  if characterConnections[player] then characterConnections[player]:Disconnect() end
  characterConnections[player]=character.DescendantAdded:Connect(configure)
  for _,object in ipairs(character:GetDescendants()) do configure(object) end
 end
 player.CharacterAdded:Connect(characterAdded)
 if player.Character then characterAdded(player.Character) end
end
Players.PlayerAdded:Connect(bind)
Players.PlayerRemoving:Connect(function(player)
 if characterConnections[player] then characterConnections[player]:Disconnect();characterConnections[player]=nil end
end)
for _,player in ipairs(Players:GetPlayers()) do bind(player) end
