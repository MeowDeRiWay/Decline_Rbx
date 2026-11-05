local Debris=game:GetService("Debris")
local Audio={}
-- Snapshot at launch: flight/impact audio must survive stowing the launcher.
function Audio.Describe(character,name)
 local held=character and character:FindFirstChild("HeldItem")
 local folder=held and held:FindFirstChild("Sounds")
 local source=folder and folder:FindFirstChild(name)
 if not source or not source:IsA("Sound") or source.SoundId=="" then return nil end
 local minimum=source:GetAttribute("MinDistance") or 3
 if name=="FlightSound" then minimum=math.max(40,minimum) end
 local maximum=source:GetAttribute("MaxDistance") or (name=="ExplosionSound" and 150 or 100)
 maximum=math.max(maximum,minimum+1)
 return {SoundId=source.SoundId,Volume=source.Volume,PlaybackSpeed=source.PlaybackSpeed,
  MinDistance=minimum,MaxDistance=maximum}
end
function Audio.Play(character,name,maxDistance)
 local held=character and character:FindFirstChild("HeldItem")
 local sounds=held and held:FindFirstChild("Sounds")
 local source=sounds and sounds:FindFirstChild(name)
 if not source or not source:IsA("Sound") or source.SoundId=="" then return nil end
 local root=character:FindFirstChild("HumanoidRootPart")
 local origin=held:FindFirstChild("_ShotOrigin",true) or root
 if not origin then return nil end
 local sound=source:Clone()
 sound.Name="Playing"..name
 sound.Looped=false; sound.PlayOnRemove=false; sound.TimePosition=0
 sound.RollOffMode=Enum.RollOffMode.InverseTapered
 sound.RollOffMinDistance=source:GetAttribute("MinDistance") or 3
 sound.RollOffMaxDistance=source:GetAttribute("MaxDistance") or (name=="ShotSound" and 150 or 5)
 if name=="ReloadSound" then sound.RollOffMaxDistance=5 end
 if maxDistance then sound.RollOffMaxDistance=maxDistance end
 sound.RollOffMinDistance=math.min(sound.RollOffMinDistance,sound.RollOffMaxDistance)
 sound.Parent=origin
 sound.Ended:Once(function() sound:Destroy() end)
 Debris:AddItem(sound,15)
 sound:Play()
 return sound
end
function Audio.Stop(sound)
 if sound then sound:Stop();sound:Destroy() end
end
return Audio
