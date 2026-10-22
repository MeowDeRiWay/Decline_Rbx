-- Source volume is independent of Attention; listeners extend hearing range only.
local Players=game:GetService("Players")
local Storage=game:GetService("ReplicatedStorage")
local Config=require(Storage.Shared.GameConfig)
local Noise=require(Storage.Shared.NoiseRules)
local watched=setmetatable({},{__mode="k"})
local function configure(sound,player,character)
 if not sound:IsA("Sound") or sound.Name~="Running" or watched[sound] then return end
 watched[sound]=true
 local applying=false
 local function apply()
  if applying then return end;applying=true
  local quiet=Noise.StepMultiplier(player:GetAttribute("SkillSneak"),character:GetAttribute("Running"),player:GetAttribute("SilentRunning"))
  sound:SetAttribute("FootstepNoiseMultiplier",quiet)
  sound.RollOffMode=Enum.RollOffMode.InverseTapered
  sound.RollOffMinDistance=Config.FootstepMinDistance*quiet
  local base=character:GetAttribute("Running") and Config.RunFootstepMaxDistance or Config.FootstepMaxDistance
  local radius=Noise.StepRadius(player:GetAttribute("SkillSneak"),character:GetAttribute("Running"),base,player:GetAttribute("SilentRunning"))
  sound:SetAttribute("FootstepBaseMin",Config.FootstepMinDistance*quiet)
  sound:SetAttribute("FootstepBaseDistance",radius)
  sound.RollOffMaxDistance=radius
  sound.Volume=Config.FootstepVolume*quiet
  applying=false
 end
 local a=character:GetAttributeChangedSignal("Running"):Connect(apply)
 local b=player:GetAttributeChangedSignal("SkillSneak"):Connect(apply)
 local perk=player:GetAttributeChangedSignal("SilentRunning"):Connect(apply)
 local c=sound:GetPropertyChangedSignal("Volume"):Connect(apply)
 sound.Destroying:Once(function() a:Disconnect();b:Disconnect();c:Disconnect();perk:Disconnect() end)
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
