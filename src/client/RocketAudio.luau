-- Flight stays on the moving projectile; blast owns an independent sound anchor.
local Debris=game:GetService("Debris")
local Rules=require(game:GetService("ReplicatedStorage").Shared.ProjectileAudioRules)
local Audio={}
local function play(config,parent,looped)
 if not config or not config.SoundId or config.SoundId=="" then return end
 local sound=Instance.new("Sound")
 sound.Name=looped and "RocketFlight" or "RocketExplosion"
 sound.SoundId=config.SoundId;sound.Volume=config.Volume;sound.PlaybackSpeed=config.PlaybackSpeed
 sound.RollOffMode=Enum.RollOffMode.InverseTapered
 sound.RollOffMinDistance=config.MinDistance;sound.RollOffMaxDistance=config.MaxDistance
 sound.Looped=looped;sound.PlayOnRemove=false;sound.Parent=parent
 sound:Play()
 return sound
end
local function equalizer(sound,low,mid,high)
 local effect=Instance.new("EqualizerSoundEffect")
 effect.LowGain=low;effect.MidGain=mid;effect.HighGain=high;effect.Parent=sound
 return effect
end
function Audio.Start(record,config,flybyConfig)
 if not record.Flight and config then
  record.Flight=play(config,record.Part,true)
  if record.Flight then
   record.FlightConfig=config
   record.FlightEQ=equalizer(record.Flight,0,0,0)
  end
 end
 if not record.Flyby and (flybyConfig or config) then
  local settings=table.clone(flybyConfig or config)
  settings.MinDistance=Rules.FlybyMinDistance;settings.MaxDistance=Rules.FlybyRadius
  settings.Volume*=Rules.WhistleGain
  if not flybyConfig then
   -- Keep a raised high-frequency fallback when no dedicated whistle is set.
   settings.Volume*=.7;settings.PlaybackSpeed*=1.35
  end
  record.Flyby=play(settings,record.Part,true)
  if record.Flyby then
   record.Flyby.Name="RocketFlyby";record.Flyby.Volume=0
   record.FlybyVolume=settings.Volume
   record.FlybyEQ=equalizer(record.Flyby,-30,flybyConfig and 0 or -8,flybyConfig and 4 or 8)
  end
 end
end
function Audio.Update(record,listener,listenerVelocity,dt)
 if not record.Flight and not record.Flyby then return end
 local velocity=record.Velocity or Vector3.zero
 -- Native Doppler uses the emitter's velocity; don't apply a second pitch shift.
 record.Part.AssemblyLinearVelocity=velocity
 if not listener then
  if record.Flight then record.Flight.Volume=0 end
  if record.Flyby then record.Flyby.Volume=0 end
  return
 end
 local mix=Rules.Sample(record.Part.Position,velocity,listener,listenerVelocity or Vector3.zero)
 local blend=1-math.exp(-18*math.clamp(dt,0,.1))
 if record.Flight then
  record.Flight.Volume=record.FlightConfig.Volume
  local eq=record.FlightEQ
  eq.HighGain+=(mix.HighGain-eq.HighGain)*blend
  eq.MidGain+=(mix.MidGain-eq.MidGain)*blend
 end
 if record.Flyby then
  local sound=record.Flyby
  local target=record.FlybyVolume*mix.Whistle
  local rate=target>sound.Volume and Rules.WhistleAttack or Rules.WhistleRelease
  local whistleBlend=1-math.exp(-rate*math.clamp(dt,0,.1))
  sound.Volume+=(target-sound.Volume)*whistleBlend
 end
end
function Audio.Stop(record)
 local sound=record and record.Flight
 if sound then sound:Stop();sound:Destroy();record.Flight=nil end
 local flyby=record and record.Flyby
 if flyby then flyby:Stop();flyby:Destroy();record.Flyby=nil end
 if record then record.FlightConfig=nil;record.FlightEQ=nil;record.FlybyEQ=nil;record.FlybyVolume=nil end
end
function Audio.Explode(config,point)
 if not config or not config.SoundId or config.SoundId=="" then return end
 local part=Instance.new("Part")
 part.Name="RocketExplosionAudio";part.Size=Vector3.new(.02,.02,.02);part.Transparency=1
 part.Anchored=true;part.CanCollide=false;part.CanQuery=false;part.CanTouch=false;part.CastShadow=false
 part.Position=point;part.Parent=workspace
 local sound=play(config,part,false)
 sound.Ended:Once(function() part:Destroy() end)
 Debris:AddItem(part,15)
 return sound
end
return Audio
