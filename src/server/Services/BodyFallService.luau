local Players=game:GetService("Players")
local TweenService=game:GetService("TweenService")
local Fall=require(game:GetService("ReplicatedStorage").Shared.BodyFallPose)
local Service={}
local active=setmetatable({},{__mode="k"})
function Service.Cancel(model)
 local r=active[model]
 if r then active[model]=nil;r.Connection:Disconnect();r.Tween:Cancel();r.Value:Destroy() end
end
local function bodyJoints(model)
 local joints={}
 for _,j in ipairs(model:GetDescendants()) do
  if j:IsA("Motor6D") and j:GetAttribute("AuthoredC0") and j.Part0 and j.Part1 then table.insert(joints,j) end
 end
 return joints
end
function Service.Restore(model)
 Service.Cancel(model)
 local root=model:FindFirstChild("HumanoidRootPart")
 if not root then return end
 local joints=bodyJoints(model);local targets={}
 for _,j in ipairs(joints) do targets[j]=Fall.Rest(j);j.C0=targets[j];j.Transform=CFrame.identity end
 for part,cf in pairs(Fall.Solve(root,root.CFrame,joints,targets)) do part.CFrame=cf end
 model:SetAttribute("BodyPoseKind",nil)
 model:SetAttribute("BodyFallUprightRotation",nil)
end
function Service.Play(model,kind)
 Service.Cancel(model)
 local root=model:FindFirstChild("HumanoidRootPart")
 if not root then return end
 local wasLying=model:GetAttribute("BodyPoseKind")~=nil
 local start=root.CFrame
 local direction=model:GetAttribute("LastHitDirection")
 if typeof(direction)~="Vector3" then direction=start.LookVector end
 direction=Vector3.new(direction.X,0,direction.Z)
 if direction.Magnitude<.001 then direction=Vector3.new(0,0,-1) else direction=direction.Unit end
 local localDirection=start:VectorToObjectSpace(direction)
 local prone=localDirection.Z<=0
 local upright=model:GetAttribute("BodyFallUprightRotation") or CFrame.new(-start.Position)*start
 model:SetAttribute("BodyFallUprightRotation",upright)
 local destination=start
 if kind=="Death" then
  destination=CFrame.new(start.Position)*upright*CFrame.Angles(math.pi/2,0,0)
 elseif kind=="Knockout" then
  destination=CFrame.new(start.Position)*upright*CFrame.Angles(0,0,math.pi/2)
 elseif not wasLying then
  local axis=Vector3.new(localDirection.Z,0,-localDirection.X)
  if axis.Magnitude<.001 then axis=Vector3.xAxis else axis=axis.Unit end
  destination=start*CFrame.fromAxisAngle(axis,math.pi/2)
 end
 local joints=bodyJoints(model)
 local targets=Fall.Targets(joints,kind,prone)
 local initial={}
 for _,j in ipairs(joints) do initial[j]=j.C0 end
 local frames=Fall.Solve(root,destination,joints,targets)
 local held=model:FindFirstChild("HeldItem")
 -- Legacy parts/accessories retain their rigid offset; articulated parts use the
 -- complete final pose. Weapons never determine the body's ground height.
 local offsets={}
 for _,p in ipairs(model:GetDescendants()) do
  if p:IsA("BasePart") then
   p.Anchored=true;p.CanCollide=false
   p.AssemblyLinearVelocity=Vector3.zero;p.AssemblyAngularVelocity=Vector3.zero
   if not frames[p] then offsets[p]=start:ToObjectSpace(p.CFrame);frames[p]=destination*offsets[p] end
  end
 end
 model:SetAttribute("BodyPoseKind",kind)
 local excluded={model}
 for _,p in ipairs(Players:GetPlayers()) do if p.Character then table.insert(excluded,p.Character) end end
 for _,name in ipairs({"Creatures","PlayerCorpses","DisconnectedPlayers"}) do local f=workspace:FindFirstChild(name);if f then table.insert(excluded,f) end end
 local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude
 params.FilterDescendantsInstances=excluded;params.RespectCanCollide=true
 local softParams=RaycastParams.new();softParams.FilterType=Enum.RaycastFilterType.Exclude
 softParams.FilterDescendantsInstances=excluded;softParams.RespectCanCollide=false
 local reference=model:FindFirstChild("ZombieHome")
 local home=reference and reference:IsA("ObjectValue") and reference.Value
 local homeParams
 if home and home:IsDescendantOf(workspace) then
  homeParams=RaycastParams.new();homeParams.FilterType=Enum.RaycastFilterType.Include;homeParams.FilterDescendantsInstances={home}
 end
 local shift=-math.huge
 for p,cf in pairs(frames) do
  if p.Transparency<1 and not (held and (p==held or p:IsDescendantOf(held))) then
   local origin=Vector3.new(cf.Position.X,start.Position.Y+.15,cf.Position.Z)
   local floor=workspace:Raycast(origin,Vector3.new(0,-100,0),params)
   -- Authored Zombie_home floors may intentionally have no collision. Accept
   -- only upward-facing home surfaces, not arbitrary noncollidable decorations.
   local soft=workspace:Raycast(origin,Vector3.new(0,-100,0),softParams)
   local ancestor=soft and soft.Instance
   while ancestor and ancestor~=workspace do
    if ancestor:GetAttribute("Zombie_home")==true then
     if soft.Normal.Y>.5 and (not floor or soft.Position.Y>floor.Position.Y) then floor=soft end
     break
    end
    ancestor=ancestor.Parent
   end
   if homeParams then
    local hit=workspace:Raycast(origin,Vector3.new(0,-100,0),homeParams)
    if hit and (not floor or hit.Position.Y>floor.Position.Y) then floor=hit end
   end
   if floor then shift=math.max(shift,floor.Position.Y+.02-(cf.Position.Y-Fall.RadiusY(cf,p.Size))) end
  end
 end
 if shift>-math.huge then destination+=Vector3.new(0,shift,0) end
 local function apply(alpha)
  local pose={}
  for _,j in ipairs(joints) do pose[j]=initial[j]:Lerp(targets[j],alpha);j.C0=pose[j];j.Transform=CFrame.identity end
  local frame=start:Lerp(destination,alpha)
  for p,cf in pairs(Fall.Solve(root,frame,joints,pose)) do p.CFrame=cf end
  for p,offset in pairs(offsets) do if p.Parent then p.CFrame=frame*offset end end
 end
 local value=Instance.new("NumberValue")
 local tween=TweenService:Create(value,TweenInfo.new(kind=="Knockout" and .65 or .8,Enum.EasingStyle.Quad,Enum.EasingDirection.InOut),{Value=1})
 local lastSample=-math.huge
 local connection=value.Changed:Connect(function(a)
  if not model.Parent then Service.Cancel(model);return end
  local now=os.clock()
  if a<1 and now-lastSample<1/30 then return end
  lastSample=now;apply(a)
 end)
 local record={Connection=connection,Tween=tween,Value=value};active[model]=record
 tween.Completed:Once(function()
  if active[model]~=record then return end
  if model.Parent then apply(1) end
  active[model]=nil;connection:Disconnect();value:Destroy()
 end)
 apply(0);tween:Play()
end
return Service
