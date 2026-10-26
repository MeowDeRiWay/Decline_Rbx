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
 local maxDistance=maximum*(active and gain or 1)
 if sound.RollOffMaxDistance~=maxDistance then sound.RollOffMaxDistance=maxDistance end
 local minDistance=math.min(minimum,sound.RollOffMaxDistance)
 if sound.RollOffMinDistance~=minDistance then sound.RollOffMinDistance=minDistance end
 -- Signals can run after Busy is cleared. Remember engine-rounded values so
 -- our own writes never become new authored bases and compound hearing gain.
 r.AppliedMax=sound.RollOffMaxDistance
 r.AppliedMin=sound.RollOffMinDistance
 r.Busy=false
end
local function applyEmitter(emitter,r)
 if r.Busy then return end;r.Busy=true
 local scale=emitter:IsDescendantOf(workspace) and gain or 1
 pcall(function()
  if r.Mode==Enum.DistanceAttenuationMode.Custom then emitter:SetDistanceAttenuation(R.Curve(r.Curve,scale))
  else
   local minimum,maximum=math.min(r.Bounds.Min,r.Bounds.Max*scale),r.Bounds.Max*scale
   local current=emitter.DistanceAttenuationBounds
   if current.Min~=minimum or current.Max~=maximum then emitter.DistanceAttenuationBounds=NumberRange.new(minimum,maximum) end
   r.AppliedBounds=emitter.DistanceAttenuationBounds
  end
 end)
 r.Busy=false
end
local function register(object)
 if object:IsA("Sound") and not sounds[object] then
  -- A Sound directly under a Model is non-positional; silence combat templates.
  if object.Name:match("^Punch%d+$") or object.Name:match("^Miss%d+$") or object.Name:match("^ShotEvade%d+$") then
   object:Stop();object.PlayOnRemove=false;object.Volume=0;return
  end
  -- Authored templates outside the playing world are never altered.
  if not soundEligible(object) then return end
  local r={Min=object.RollOffMinDistance,Max=object.RollOffMaxDistance};sounds[object]=r
  for property,key in pairs({RollOffMinDistance="Min",RollOffMaxDistance="Max"}) do
   object:GetPropertyChangedSignal(property):Connect(function()
    local value=object[property]
    if not r.Busy and value~=r["Applied"..key] then r[key]=value;applySound(object,r) end
   end)
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
  object:GetPropertyChangedSignal("DistanceAttenuationBounds"):Connect(function()
   local value,applied=object.DistanceAttenuationBounds,r.AppliedBounds
   if not r.Busy and (not applied or value.Min~=applied.Min or value.Max~=applied.Max) then r.Bounds=value;applyEmitter(object,r) end
  end)
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
