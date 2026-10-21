-- Anchored zombie rigs move with PivotTo, so Humanoid.Running cannot drive audio.
local Players=game:GetService("Players")
local Storage=game:GetService("ReplicatedStorage")
local Run=game:GetService("RunService")
local Config=require(Storage.Shared.GameConfig)
local player=Players.LocalPlayer
local records={}
local function register(object)
 if object:IsA("Model") and (object.Name=="Zombie" or object:GetAttribute("CreatureType")=="Zombie") then records[object]=records[object] or {} end
end
for _,object in ipairs(workspace:GetDescendants()) do register(object) end
workspace.DescendantAdded:Connect(register)
local function stop(r) if r.Sound and r.Sound.Playing then r.Sound:Stop() end end
local elapsed=0
Run.Heartbeat:Connect(function(dt)
 elapsed+=dt;if elapsed<.1 then return end
 local step=elapsed;elapsed=0
 local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
 local sounds=Storage:FindFirstChild("Sounds")
 local source=sounds and sounds:FindFirstChild("ZombieFootstepSound")
 for model,r in pairs(records) do
  if not model:IsDescendantOf(workspace) then if r.Sound then r.Sound:Destroy() end;records[model]=nil;continue end
  local part=model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Body")
  local hp=model:FindFirstChildOfClass("Humanoid")
  local position=part and part.Position
  local moved=position and r.Position and (position-r.Position).Magnitude or 0
  r.Position=position
  local radius=source and source:GetAttribute("MaxDistance") or Config.FootstepMaxDistance
  local near=root and position and (root.Position-position).Magnitude<=radius*(player:GetAttribute("HearingMultiplier") or 1)+4
  local moving=model:GetAttribute("ActivityMode")=="Active" and hp and hp.Health>0 and moved>.005 and moved<=math.max(1,(model:GetAttribute("MoveSpeed") or 3)*step*2)
  if not near or not moving or not source or not source:IsA("Sound") or source.SoundId=="" then stop(r);continue end
  if r.Sound and (r.Sound.Parent~=part or r.Source~=source) then r.Sound:Destroy();r.Sound=nil end
  if not r.Sound then
   local sound=source:Clone();sound.Name="ZombieWalkingSound";sound.Looped=true;sound.PlayOnRemove=false
   sound.RollOffMode=Enum.RollOffMode.InverseTapered
   sound.RollOffMinDistance=source:GetAttribute("MinDistance") or Config.FootstepMinDistance
   sound.RollOffMaxDistance=radius;sound.TimePosition=0;sound.Parent=part
   r.Sound=sound;r.Source=source
  end
  if not r.Sound.Playing then r.Sound:Play() end
 end
end)
