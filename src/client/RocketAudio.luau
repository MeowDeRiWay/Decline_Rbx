-- Flight stays on the moving projectile; blast owns an independent sound anchor.
local Debris=game:GetService("Debris")
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
function Audio.Start(record,config)
 if not record.Flight then record.Flight=play(config,record.Part,true) end
end
function Audio.Stop(record)
 local sound=record and record.Flight
 if sound then sound:Stop();sound:Destroy();record.Flight=nil end
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
