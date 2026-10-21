-- Listener-local hearing; never changes microphones, permissions or other clients.
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local SoundService=game:GetService("SoundService")
local Config=require(ReplicatedStorage.Shared.GameConfig)
local R=require(ReplicatedStorage.Shared.SensesRules)
local player=Players.LocalPlayer
local gain=R.Hearing(player:GetAttribute("Attention"))
local sounds,emitters,wires={},{},{}
local changingWire=setmetatable({},{__mode="k"})
local watchedWire=setmetatable({},{__mode="k"})
local function soundEligible(sound)
 local c=player.Character
 if c and sound:IsDescendantOf(c) and (sound.Name=="PlayingShotSound" or sound.Name=="PlayingReloadSound") then return false end
 return sound:IsDescendantOf(workspace) or (sound.Parent==SoundService and (sound.Name=="OwnerPlayingShotSound" or sound.Name=="OwnerPlayingReloadSound"))
end
local function applySound(sound,r)
 if r.Busy then return end;r.Busy=true
 local active=soundEligible(sound) and sound.Playing
 local volume=r.Volume
 if sound.Name=="Running" then volume=math.min(volume,Config.FootstepVolume*(sound:GetAttribute("FootstepNoiseMultiplier") or 1)) end
 sound.Volume=math.clamp(volume*(active and gain or 1),0,10)
 sound.RollOffMinDistance=r.Min*(active and gain or 1)
 sound.RollOffMaxDistance=r.Max*(active and gain or 1)
 r.Busy=false
end
local function applyEmitter(emitter,r)
 if r.Busy then return end;r.Busy=true
 local scale=emitter:IsDescendantOf(workspace) and gain or 1
 pcall(function()
  if r.Mode==Enum.DistanceAttenuationMode.Custom then emitter:SetDistanceAttenuation(R.Curve(r.Curve,scale))
  else emitter.DistanceAttenuationBounds=NumberRange.new(r.Bounds.Min*scale,r.Bounds.Max*scale) end
 end)
 r.Busy=false
end
local function removeWire(wire)
 local r=wires[wire];if not r then return end;wires[wire]=nil
 changingWire[wire]=true
 if wire.Parent and wire.SourceInstance==r.Fader then wire.SourceInstance=r.Source;wire.SourceName=r.Pin end
 r.Bridge:Destroy();r.Fader:Destroy();changingWire[wire]=nil
end
local function wireChanged(wire)
 if changingWire[wire] then return end
 local r=wires[wire]
 if r and wire.SourceInstance==r.Fader and wire.TargetInstance==r.Target then return end
 if r then removeWire(wire) end
 local source,target=wire.SourceInstance,wire.TargetInstance
 if not source or not target or not target:IsA("AudioDeviceOutput") or (target.Player and target.Player~=player) then return end
 local fader=Instance.new("AudioFader");fader.Name="AttentionHearingGain";fader.Volume=gain;fader.Parent=SoundService
 local bridge=Instance.new("Wire");bridge.Name="AttentionHearingInput"
 local pin=wire.SourceName
 wires[wire]={Fader=fader,Bridge=bridge,Source=source,Target=target,Pin=pin}
 bridge.SourceInstance=source;bridge.SourceName=pin;bridge.TargetInstance=fader;bridge.Parent=fader
 wire.SourceName="Output";wire.SourceInstance=fader
end
local function register(object)
 if object:IsA("Sound") and not sounds[object] then
  -- Authored templates outside the playing world are never altered.
  if not soundEligible(object) then return end
  local r={Volume=object.Volume,Min=object.RollOffMinDistance,Max=object.RollOffMaxDistance};sounds[object]=r
  for property,key in pairs({Volume="Volume",RollOffMinDistance="Min",RollOffMaxDistance="Max"}) do
   object:GetPropertyChangedSignal(property):Connect(function() if not r.Busy then r[key]=object[property];applySound(object,r) end end)
  end
  object:GetAttributeChangedSignal("FootstepNoiseMultiplier"):Connect(function() applySound(object,r) end)
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
 elseif object:IsA("Wire") and not watchedWire[object] then
  watchedWire[object]=true
  object:GetPropertyChangedSignal("SourceInstance"):Connect(function() wireChanged(object) end)
  object:GetPropertyChangedSignal("TargetInstance"):Connect(function() wireChanged(object) end)
  object.Destroying:Once(function() removeWire(object) end)
  wireChanged(object)
 end
end
for _,object in ipairs(game:GetDescendants()) do register(object) end
game.DescendantAdded:Connect(function(object) task.defer(register,object) end)
local function refresh()
 gain=R.Hearing(player:GetAttribute("Attention"))
 for sound,r in pairs(sounds) do applySound(sound,r) end
 for emitter,r in pairs(emitters) do applyEmitter(emitter,r) end
 for wire,r in pairs(wires) do r.Fader.Volume=gain;wireChanged(wire) end
end
player:GetAttributeChangedSignal("Attention"):Connect(refresh)
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(refresh)
player.CharacterAdded:Connect(refresh)
