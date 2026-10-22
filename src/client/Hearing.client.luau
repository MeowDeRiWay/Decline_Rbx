-- Listener-local range only; authored volume/mixes/microphones remain untouched.
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local SoundService=game:GetService("SoundService")
local R=require(ReplicatedStorage.Shared.SensesRules)
local player=Players.LocalPlayer
local gain=R.Hearing(player:GetAttribute("HearingAttention") or player:GetAttribute("Attention"))
local sounds,emitters={},{}
local function soundEligible(sound)
 local c=player.Character
 if c and sound:IsDescendantOf(c) and (sound.Name=="PlayingShotSound" or sound.Name=="PlayingReloadSound") then return false end
 return sound:IsDescendantOf(workspace) or (sound.Parent==SoundService and (sound.Name=="OwnerPlayingShotSound" or sound.Name=="OwnerPlayingReloadSound"))
end
local function applySound(sound,r)
 if r.Busy then return end;r.Busy=true
 local active=soundEligible(sound) and sound.Playing
 local maximum=sound:GetAttribute("FootstepBaseDistance") or r.Max
 local minimum=sound:GetAttribute("FootstepBaseMin") or r.Min
 sound.RollOffMaxDistance=maximum*(active and gain or 1)
 sound.RollOffMinDistance=math.min(minimum,sound.RollOffMaxDistance)
 r.Busy=false
end
local function applyEmitter(emitter,r)
 if r.Busy then return end;r.Busy=true
 local scale=emitter:IsDescendantOf(workspace) and gain or 1
 pcall(function()
  if r.Mode==Enum.DistanceAttenuationMode.Custom then emitter:SetDistanceAttenuation(R.Curve(r.Curve,scale))
  else emitter.DistanceAttenuationBounds=NumberRange.new(math.min(r.Bounds.Min,r.Bounds.Max*scale),r.Bounds.Max*scale) end
 end)
 r.Busy=false
end
local function register(object)
 if object:IsA("Sound") and not sounds[object] then
  -- Authored templates outside the playing world are never altered.
  if not soundEligible(object) then return end
  local r={Min=object.RollOffMinDistance,Max=object.RollOffMaxDistance};sounds[object]=r
  for property,key in pairs({RollOffMinDistance="Min",RollOffMaxDistance="Max"}) do
   object:GetPropertyChangedSignal(property):Connect(function() if not r.Busy then r[key]=object[property];applySound(object,r) end end)
  end
  object:GetAttributeChangedSignal("FootstepBaseDistance"):Connect(function() applySound(object,r) end)
  object:GetAttributeChangedSignal("FootstepBaseMin"):Connect(function() applySound(object,r) end)
  object:GetPropertyChangedSignal("Playing"):Connect(function() applySound(object,r) end)
  object.AncestryChanged:Connect(function() applySound(object,r) end)
  object.Destroying:Once(function() sounds[object]=nil end)
  applySound(object,r)
 elseif object:IsA("AudioEmitter") and not emitters[object] then
  local ok,curve=pcall(function() return object:GetDistanceAttenuation() end)
  if not ok then return end
  local r={Curve=curve,Bounds=object.DistanceAttenuationBounds,Mode=object.DistanceAttenuationMode};emitters[object]=r
  object:GetPropertyChangedSignal("DistanceAttenuationBounds"):Connect(function() if not r.Busy then r.Bounds=object.DistanceAttenuationBounds;applyEmitter(object,r) end end)
  object:GetPropertyChangedSignal("DistanceAttenuationMode"):Connect(function() if not r.Busy then r.Mode=object.DistanceAttenuationMode;applyEmitter(object,r) end end)
  object.AncestryChanged:Connect(function() applyEmitter(object,r) end)
  object.Destroying:Once(function() emitters[object]=nil end)
  applyEmitter(object,r)

 end
end
for _,object in ipairs(game:GetDescendants()) do register(object) end
game.DescendantAdded:Connect(function(object) task.defer(register,object) end)
local function refresh()
 gain=R.Hearing(player:GetAttribute("HearingAttention") or player:GetAttribute("Attention"))
 for sound,r in pairs(sounds) do applySound(sound,r) end
 for emitter,r in pairs(emitters) do applyEmitter(emitter,r) end
end
player:GetAttributeChangedSignal("Attention"):Connect(refresh)
player:GetAttributeChangedSignal("HearingAttention"):Connect(refresh)
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(refresh)
player.CharacterAdded:Connect(refresh)
