-- Templates stay in Zombie/Sounds; playback is attached to the physical rig.
local Audio={}
local random=Random.new()
local records=setmetatable({},{__mode="k"})
local function record(model)
 if not records[model] then records[model]={NextIdle=os.clock()+random:NextNumber(8,20)} end
 return records[model]
end
function Audio.Prepare(model)
 local folder=model:FindFirstChild("Sounds")
 if not folder then return end
 for _,source in ipairs(folder:GetDescendants()) do
  if source:IsA("Sound") then
   -- A Sound in a Folder is non-positional, even inside a character model.
   source.PlayOnRemove=false
   source:Stop()
  end
 end
end
function Audio.Stop(model)
 local r=records[model]
 if r and r.Sound then r.Sound:Destroy();r.Sound=nil end
end
function Audio.Play(model,kind)
 local r=record(model)
 if r.Dead then return end
 if kind=="Die" then r.Dead=true end
 Audio.Stop(model)
 r.NextIdle=os.clock()+random:NextNumber(8,20)
 local folder=model:FindFirstChild("Sounds")
 local origin=model:FindFirstChild("Head") or model:FindFirstChild("HumanoidRootPart")
 if not folder or not origin or not origin:IsA("BasePart") then return end
 local options={}
 for _,source in ipairs(folder:GetChildren()) do
  if source:IsA("Sound") and source.Name:match("^Z"..kind.."%d+$") and source.SoundId~="" then table.insert(options,source) end
 end
 if #options==0 then return end
 local source=options[random:NextInteger(1,#options)]
 local sound=source:Clone()
 sound:Stop()
 sound.Name="ZombieVoice";sound.Looped=false;sound.PlayOnRemove=false;sound.TimePosition=0
 sound.RollOffMode=Enum.RollOffMode.LinearSquare
 sound.RollOffMaxDistance=8
 sound.RollOffMinDistance=math.min(source:GetAttribute("MinDistance") or 2,sound.RollOffMaxDistance)
 sound.Parent=origin;r.Sound=sound
 sound.Ended:Once(function() if r.Sound==sound then r.Sound=nil end;sound:Destroy() end)
 game:GetService("Debris"):AddItem(sound,30)
 sound:Play()
end
function Audio.Update(model)
 local r=record(model)
 if r.Dead or os.clock()<r.NextIdle or (r.Sound and r.Sound.Playing) then return end
 Audio.Play(model,"Idle")
end
return Audio
