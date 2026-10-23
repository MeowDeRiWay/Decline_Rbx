-- Authored Sounds in StarterCharacter are templates, never world-space emitters.
local StarterPlayer=game:GetService("StarterPlayer")
local Debris=game:GetService("Debris")
local Audio={}
local random=Random.new()
local patterns={Punch="^Punch%d+$",Miss="^Miss%d+$",ShotEvade="^ShotEvade%d+$"}
function Audio.Prepare(model)
 for _,source in ipairs(model:GetDescendants()) do
  if source:IsA("Sound") then
   for _,pattern in pairs(patterns) do
    if source.Name:match(pattern) then source:Stop();source.PlayOnRemove=false;break end
   end
  end
 end
end
function Audio.Play(model,kind,ownerUserId)
 local pattern=patterns[kind]
 if not model or not pattern then return end
 local origin=model:FindFirstChild("Head") or model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Body")
 if not origin or not origin:IsA("BasePart") then return end
 local templates=StarterPlayer:FindFirstChild("StarterCharacter")
 local options={}
 for _,source in ipairs((templates or model):GetDescendants()) do
  if source:IsA("Sound") and source.Name:match(pattern) and source.SoundId~="" then table.insert(options,source) end
 end
 if #options==0 then return end
 local sound=options[random:NextInteger(1,#options)]:Clone()
 sound:Stop();sound.Name="Combat"..kind;sound.Looped=false;sound.PlayOnRemove=false;sound.TimePosition=0
 sound.RollOffMode=Enum.RollOffMode.LinearSquare;sound.RollOffMinDistance=1;sound.RollOffMaxDistance=8
 sound:SetAttribute("CombatOwnerUserId",ownerUserId or 0)
 sound.Parent=origin
 sound.Ended:Once(function() sound:Destroy() end);Debris:AddItem(sound,10);sound:Play()
 return sound
end
return Audio
