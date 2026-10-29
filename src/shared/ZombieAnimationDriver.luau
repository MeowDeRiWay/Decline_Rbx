local Players=game:GetService("Players")
local Collection=game:GetService("CollectionService")
local RunService=game:GetService("RunService")
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Z=require(Shared:WaitForChild("ZombiePose"))
local Pose=require(Shared:WaitForChild("CharacterPose"))
local Driver={}
function Driver.Start(viewer,preview)
 local records,links={},{}
 local names={"RootJoint","Waist","Neck","LeftShoulder","RightShoulder","LeftElbow","RightElbow","LeftHip","RightHip","LeftKnee","RightKnee"}
 local function forget(model)
  for _,c in ipairs(links[model] or {}) do c:Disconnect() end
  links[model]=nil;records[model]=nil
 end
 local function added(model)
  if links[model] then return end
  local connections={};links[model]=connections
  local function rebuild()
   if links[model]~=connections then return end
   local root=model:FindFirstChild("HumanoidRootPart")
   local hp=model:FindFirstChildOfClass("Humanoid")
   if not root or not hp or model:GetAttribute("DeclineRigVersion")~=1 then records[model]=nil;return end
   local motors={}
   for _,name in ipairs(names) do
    local joint=model:FindFirstChild(name,true)
    if not joint or not joint:IsA("Motor6D") or not joint.Part0 or not joint.Part1 then records[model]=nil;return end
    motors[name]=joint
   end
   records[model]={Root=root,HP=hp,Motors=motors,Last=root.Position,Elapsed=0,Phase=model:GetAttribute("ZombieAnimationPhase") or 0,Amount=0}
  end
  local queued=false
  local function queue()
   if queued then return end;queued=true
   task.defer(function() queued=false;rebuild() end)
  end
  table.insert(connections,model.DescendantAdded:Connect(queue))
  table.insert(connections,model.DescendantRemoving:Connect(function(object)
   local record=records[model]
   if record and (object==record.Root or object==record.HP or record.Motors[object.Name]==object) then records[model]=nil end
   queue()
  end))
  table.insert(connections,model:GetAttributeChangedSignal("DeclineRigVersion"):Connect(queue))
  table.insert(connections,model.Destroying:Connect(function() forget(model) end))
  rebuild()
 end
 Collection:GetInstanceAddedSignal(Z.Tag):Connect(added)
 Collection:GetInstanceRemovedSignal(Z.Tag):Connect(forget)
 for _,model in ipairs(Collection:GetTagged(Z.Tag)) do added(model) end
 RunService.PreSimulation:Connect(function(dt)
  local observer=viewer and viewer.Character and viewer.Character:FindFirstChild("HumanoidRootPart")
  for model,r in pairs(records) do
   local root,m=r.Root,r.Motors
   -- The anchored root belongs to the existing server-driven AI; it is expected.
   if not root:IsDescendantOf(workspace) or model:GetAttribute("WorldDormant") or model:GetAttribute("ActivityMode")~="Active" or model:GetAttribute("IsDead") or r.HP.Health<=0 then
    r.Last=root.Position;r.Elapsed=0;continue
   end
   if not preview and (not observer or (root.Position-observer.Position).Magnitude>180) then r.Last=root.Position;r.Elapsed=0;continue end
   r.Elapsed+=dt
   if r.Elapsed<1/30 then continue end
   local elapsed=r.Elapsed;r.Elapsed=0
   local movement=root.Position-r.Last;r.Last=root.Position
   local speed=Vector3.new(movement.X,0,movement.Z).Magnitude/math.max(elapsed,.001)
   if speed>30 then speed=0 end
   r.Amount+=((speed>.02 and .22 or 0)-r.Amount)*(1-math.exp(-8*elapsed))
   r.Phase=(r.Phase+math.min(speed*5,8)*elapsed+.12*elapsed)%(2*math.pi)
   local kind=model:GetAttribute("ZombieAnimationType") or 1
   local side=model:GetAttribute("ZombieAttackSide") or "Right"
   local started=model:GetAttribute("ZombieAttackStartedAt")
   local attack=typeof(started)=="number" and workspace:GetServerTimeNow()-started or -1
   local sample=Z.Sample(root.Size,kind,side,r.Phase,attack)
   m.RootJoint.Transform=CFrame.identity
   m.Waist.Transform=sample.Waist;m.Neck.Transform=sample.Neck
   local lh,rh,lk,rk=Pose.Legs(r.Phase,r.Amount,1,0,.55)
   m.LeftHip.Transform=lh;m.RightHip.Transform=rh;m.LeftKnee.Transform=lk;m.RightKnee.Transform=rk
   local lower=root.CFrame*m.RootJoint.C0*m.RootJoint.C1:Inverse()
   local upper=lower*m.Waist.C0*sample.Waist*m.Waist.C1:Inverse()
   for _,name in ipairs({"Left","Right"}) do
    local shoulder,elbow=m[name.."Shoulder"],m[name.."Elbow"]
    local rest=shoulder:GetAttribute("AuthoredC0")
    local standing=shoulder:GetAttribute("StandingRotation")
    local offset=shoulder:GetAttribute("StandingOffset")
    local a,b=shoulder:GetAttribute("UpperVector"),shoulder:GetAttribute("LowerVector")
    if not rest or not standing or not offset or not a or not b then continue end
    local jointFrame=upper*rest*CFrame.new(offset)
    local target=root.CFrame:PointToWorldSpace(sample[name])
    local delta=jointFrame:VectorToObjectSpace(target-jointFrame.Position)
    local s,e=Pose.Arm(a,b,delta,Vector3.new(name=="Left" and -1 or 1,-1,.1))
    shoulder.Transform=standing:Inverse()*s;elbow.Transform=e
   end
  end
 end)
end
return Driver
