-- Authored footstep source settings; Hearing applies each listener's gain afterwards.
local Players=game:GetService("Players")
local Storage=game:GetService("ReplicatedStorage")
local Config=require(Storage.Shared.GameConfig)
local Noise=require(Storage.Shared.NoiseRules)
local watched=setmetatable({},{__mode="k"})
local function configure(sound,player,character)
 if not sound:IsA("Sound") or sound.Name~="Running" or watched[sound] then return end
 watched[sound]=true
 local function apply()
  local quiet=Noise.StepMultiplier(player:GetAttribute("SkillSneak"),character:GetAttribute("Sneaking"))
  sound:SetAttribute("FootstepNoiseMultiplier",quiet)
  sound.RollOffMode=Enum.RollOffMode.InverseTapered
  sound.RollOffMinDistance=Config.FootstepMinDistance*quiet
  sound.RollOffMaxDistance=Config.FootstepMaxDistance*quiet
  sound.Volume=Config.FootstepVolume*quiet
 end
 local a=character:GetAttributeChangedSignal("Sneaking"):Connect(apply)
 local b=player:GetAttributeChangedSignal("SkillSneak"):Connect(apply)
 sound.Destroying:Once(function() a:Disconnect();b:Disconnect() end)
 apply()
end
local connections={}
local function bind(player)
 local function added(character)
  if connections[player] then connections[player]:Disconnect() end
  connections[player]=character.DescendantAdded:Connect(function(sound) configure(sound,player,character) end)
  for _,sound in ipairs(character:GetDescendants()) do configure(sound,player,character) end
 end
 player.CharacterAdded:Connect(added)
 if player.Character then added(player.Character) end
end
Players.PlayerAdded:Connect(bind)
Players.PlayerRemoving:Connect(function(p) if connections[p] then connections[p]:Disconnect();connections[p]=nil end end)
for _,p in ipairs(Players:GetPlayers()) do bind(p) end
