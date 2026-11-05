-- Acoustic emitters outlive visual projectiles until their last sound arrives.
local Debris=game:GetService("Debris")
local Rules=require(game:GetService("ReplicatedStorage").Shared.ProjectileAudioRules)
local Audio={}
local function play(config,parent,looped,paused)
 if not config or not config.SoundId or config.SoundId=="" then return end
 local sound=Instance.new("Sound")
 sound.Name=looped and "RocketFlight" or "RocketExplosion"
 sound.SoundId=config.SoundId;sound.Volume=config.Volume;sound.PlaybackSpeed=config.PlaybackSpeed
 sound.RollOffMode=Enum.RollOffMode.InverseTapered
 sound.RollOffMinDistance=config.MinDistance;sound.RollOffMaxDistance=config.MaxDistance
 sound.Looped=looped;sound.PlayOnRemove=false;sound.Parent=parent
 if not paused then sound:Play() end
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
local streams={}
local function anchor(point,name)
 local part=Instance.new("Part")
 part.Name=name;part.Size=Vector3.new(.02,.02,.02);part.Transparency=1
 part.Anchored=true;part.CanCollide=false;part.CanQuery=false;part.CanTouch=false;part.CastShadow=false
 part.Position=point;part.Parent=workspace
 return part
end
function Audio.ListenerPosition()
 local player=game:GetService("Players").LocalPlayer
 local character=player and player.Character
 local head=character and (character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart"))
 return head and head.Position or workspace.CurrentCamera and workspace.CurrentCamera.CFrame.Position
end
local function serverTime() return workspace:GetServerTimeNow() end
function Audio.Trace(id,point,velocity,config,flybyConfig,emittedAt)
 if not config and not flybyConfig then return end
 local record=streams[id]
 if not record then
  record={Part=anchor(point,"RocketFlightAudio"),Samples={},First=1,Config=config,FlybyConfig=flybyConfig}
  streams[id]=record
 end
 local now=serverTime()
 local time=emittedAt or now
 local samples=record.Samples
 if #samples>0 and time<=samples[#samples].Time then return end
 table.insert(samples,{Time=time,Position=point,Velocity=velocity or Vector3.zero})
 record.LastReceived=now
 -- Retain only history the listener can still hear; memory stays bounded.
 if record.First>64 or #samples>256 then
  local first=math.max(record.First,#samples-255)
  local kept={};for i=first,#samples do table.insert(kept,samples[i]) end
  record.Samples=kept;record.First=1
 end
end
function Audio.Finish(id)
 local record=streams[id];if record then record.Ended=true end
end
function Audio.Step(listener,listenerVelocity,dt,now)
 now=now or serverTime()
 for id,record in pairs(streams) do
  if now-(record.LastReceived or now)>.5 then record.Ended=true end
  local position,velocity,first,done
  if listener then position,velocity,first,done=Rules.Heard(record.Samples,record.First,listener,now,record.Ended)
  else done=now-(record.LastReceived or now)>3 end
  record.First=first or record.First
  if done then
   Audio.Stop(record);record.Part:Destroy();streams[id]=nil
  elseif position then
   record.Part.Position=position;record.Velocity=velocity
   Audio.Start(record,record.Config,record.FlybyConfig)
   Audio.Update(record,listener,listenerVelocity,dt)
  else Audio.Update(record,nil,Vector3.zero,dt) end
 end
end
function Audio.OneShot(config,point,emittedAt,name,listener)
 if not config or not config.SoundId or config.SoundId=="" then return end
 local now=serverTime()
 listener=listener or Audio.ListenerPosition()
 local delay=listener and math.max(0,Rules.Arrival(emittedAt or now,point,listener)-now) or 0
 local part=anchor(point,name or "RocketExplosionAudio")
 local sound=play(config,part,false,true)
 sound.Ended:Once(function() part:Destroy() end)
 local function begin() if part.Parent then sound:Play() end end
 if delay>0 then task.delay(delay,begin) else begin() end
 Debris:AddItem(part,15+delay)
 return sound
end
function Audio.Explode(config,point,emittedAt)
 return Audio.OneShot(config,point,emittedAt,"RocketExplosionAudio")
end
function Audio.Launch(config,point,emittedAt)
 return Audio.OneShot(config,point,emittedAt,"RocketLaunchAudio")
end
return Audio
