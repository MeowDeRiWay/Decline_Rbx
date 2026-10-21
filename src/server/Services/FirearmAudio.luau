local Debris=game:GetService("Debris")
local Audio={}
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
 sound.RollOffMaxDistance=source:GetAttribute("MaxDistance") or (name=="ShotSound" and 150 or 25)
 if maxDistance then sound.RollOffMaxDistance=maxDistance end
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
