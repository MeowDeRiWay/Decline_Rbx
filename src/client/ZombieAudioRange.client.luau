-- Explicit listener-side cutoff in addition to Roblox's spatial attenuation.
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local Storage=game:GetService("ReplicatedStorage")
local Senses=require(Storage.Shared.SensesRules)
local player=Players.LocalPlayer
local records={}
local function zombieOf(sound)
 local model=sound.Parent
 while model and model~=workspace do
  if model:IsA("Model") and (model.Name=="Zombie" or model:GetAttribute("CreatureType")=="Zombie") then return model end
  model=model.Parent
 end
end
local function apply(sound,r)
 if r.Busy then return end
 local character=player.Character
 local listener=character and character:FindFirstChild("HumanoidRootPart")
 local origin=r.Model:FindFirstChild("HumanoidRootPart") or r.Model:FindFirstChild("Body")
 local radius=8*Senses.Hearing(player:GetAttribute("HearingAttention") or player:GetAttribute("Attention"))
 local audible=listener and origin and (listener.Position-origin.Position).Magnitude<=radius
 r.Busy=true
 sound.Volume=if audible then r.Volume else 0
 r.Busy=false
end
local function register(sound)
 if not sound:IsA("Sound") or records[sound] then return end
 local model=zombieOf(sound)
 if not model then return end
 if sound.Name:match("^ZIdle%d+$") or sound.Name:match("^ZAttack%d+$") or sound.Name:match("^ZDie%d+$") then
  -- Library templates are never audible, even if another script starts one.
  sound.Volume=0
  sound.PlayOnRemove=false
  sound:Stop()
  return
 end
 if sound.Name~="ZombieVoice" and sound.Name~="ZombieWalkingSound" then return end
 local r={Model=model,Volume=sound.Volume};records[sound]=r
 sound:GetPropertyChangedSignal("Volume"):Connect(function()
  if not r.Busy then r.Volume=sound.Volume;apply(sound,r) end
 end)
 sound.Destroying:Once(function() records[sound]=nil end)
 apply(sound,r)
end
for _,object in ipairs(workspace:GetDescendants()) do register(object) end
workspace.DescendantAdded:Connect(register)
local elapsed=0
RunService.Heartbeat:Connect(function(dt)
 elapsed+=dt;if elapsed<.05 then return end;elapsed=0
 for sound,r in pairs(records) do
  if not sound:IsDescendantOf(workspace) then records[sound]=nil else apply(sound,r) end
 end
end)
