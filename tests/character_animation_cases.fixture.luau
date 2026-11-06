local tick=RunService.PreSimulation.Fire
local waistBreath=c:FindFirstChild("Waist",true)
local savedTime=serverTime
serverTime=101;RunService.PreSimulation:Fire(1/30)
local inhale=waistBreath.Transform.Position.Y
serverTime=103;RunService.PreSimulation:Fire(1/30)
assert(inhale>0 and waistBreath.Transform.Position.Y<0,"viewer actually animates chest breathing")
c:SetAttribute("Reloading",true);RunService.PreSimulation:Fire(1/30)
near(waistBreath.Transform.Position,Vector3.zero)
c:SetAttribute("Reloading",false);serverTime=savedTime
print("PASS: viewer breathing raises/lowers chest and suppresses during reload")
RunService.PreSimulation:Fire(1/30)
local hip=c:FindFirstChild("LeftHip",true)
assert(hip.Transform)
root.CFrame=CFrame.new(.01,0,0)*root.CFrame
RunService.PreSimulation:Fire(1/30)
assert(math.abs(hip.Transform.R[3])+math.abs(hip.Transform.R[6])+math.abs(hip.Transform.R[2])>0,"actual movement poses hips")
local held=Instance.new("Part",c);held.Name="HeldItem";held.CFrame=root.CFrame*CFrame.new(.3,.2,-.3)
c:SetAttribute("HandsItem","Gun")
c.DescendantAdded:Fire(held);flush();RunService.PreSimulation:Fire(1/30)
local shoulder=c:FindFirstChild("RightShoulder",true)
assert(shoulder.Transform and shoulder.Transform.R[1]==shoulder.Transform.R[1],"late firearm poses arms without NaN")
local before=shoulder.Transform
c:SetAttribute("Knockout",true);RunService.PreSimulation:Fire(1/30)
assert(shoulder.Transform==before,"knockout pose left untouched")
c:SetAttribute("Knockout",false)
local remoteHip=oc:FindFirstChild("LeftHip",true)
assert(remoteHip.Transform,"other player is animated on this viewer")
-- Animator/native updates may reset Transform before PreSimulation. Remote
-- pose calculation is intentionally throttled, but presentation must not be.
local remoteHeld=Instance.new("Part",oc);remoteHeld.Name="HeldItem";remoteHeld.CFrame=otherRoot.CFrame*CFrame.new(.3,.2,-.3)
oc:SetAttribute("HandsItem","Gun");oc.DescendantAdded:Fire(remoteHeld);flush()
local remoteRootJoint=oc:FindFirstChild("RootJoint",true)
local remoteShoulder=oc:FindFirstChild("RightShoulder",true)
RunService.PreSimulation:Fire(1/30)
local footStep=Foot.Step
local remoteCalculations,remoteInitializations=0,0
Foot.Step=function(state,neutral,...)
 if neutral.Left.X>.5 then remoteCalculations+=1;if not state then remoteInitializations+=1 end end
 return footStep(state,neutral,...)
end
for _,fps in ipairs({60,120,144}) do
 for frame=1,24 do
  for _,joint in ipairs(oc:GetDescendants()) do if joint:IsA("Motor6D") then joint.Transform=CFrame.identity end end
  serverTime+=1/fps;RunService.PreSimulation:Fire(1/fps)
  assert(remoteRootJoint.Transform.Position.Y<-.001,"remote crouch/legs must survive engine resets on every simulation frame")
  local rotation=remoteShoulder.Transform.R
  assert(math.abs(rotation[6])+math.abs(rotation[8])+math.abs(rotation[3])>.01,"remote firearm pose cannot alternate with authored neutral arms")
 end
end
assert(remoteCalculations<50,"replaying poses must retain the remote IK calculation budget")
local oldInitializations=remoteInitializations
local shotSound=Instance.new("Sound",remoteHeld);shotSound.Name="ShotSound"
oc.DescendantAdded:Fire(shotSound);flush();RunService.PreSimulation:Fire(1/30)
assert(remoteInitializations==oldInitializations,"a shot sound must not reset planted feet and gait state")
Foot.Step=footStep
local frozen=CFrame.new(0,-.25,0)
oc:SetAttribute("Knockout",true);remoteRootJoint.Transform=frozen
RunService.PreSimulation:Fire(1/120)
assert(remoteRootJoint.Transform==frozen,"a cached living pose must never overwrite remote KO")
oc:SetAttribute("Knockout",false);RunService.PreSimulation:Fire(1/120)
assert(remoteRootJoint.Transform~=frozen and remoteRootJoint.Transform.Position.Y<0,"revival recomputes fresh feet immediately")
print("PASS: remote poses reapplied at60/120/144Hz despite per-frame engine resets, throttled IK retained and cosmetic descendants preserve planted feet")
-- A moving axe must sample its clock and both-hand IK on every viewer frame,
-- despite native Transform resets and the normal 30Hz idle-player IK budget.
local axeGrip=Instance.new("Motor6D",remoteHeld);axeGrip.Name="WeaponGrip"
axeGrip.Part0=otherRoot;axeGrip.Part1=remoteHeld;axeGrip.C0=CFrame.new(.3,.2,-.3);axeGrip.C1=CFrame.identity
axeGrip:SetAttribute("RestC0",axeGrip.C0)
oc:SetAttribute("HandsItem","Axe");oc.DescendantAdded:Fire(axeGrip);flush()
Motion.Play(axeGrip,{Animation="Chop",AttacksPerMinute=40},serverTime,1)
local previousSupport
for frame=1,60 do
 serverTime+=1/120
 for _,joint in ipairs(oc:GetDescendants()) do if joint:IsA("Motor6D") then joint.Transform=CFrame.identity end end
 RunService.PreSimulation:Fire(1/120)
 local support=oc:FindFirstChild("LeftShoulder",true).Transform
 if previousSupport then assert((support.LookVector-previousSupport.LookVector).Magnitude>1e-7,"axe hand IK advances every frame, not cached previous-frame weapon geometry") end
 previousSupport=support
 assert((axeGrip.C0.Position-Vector3.new(.3,.2,-.3)).Magnitude<1e-7,"cosmetic swing never animates replicated C0")
end
serverTime+=1.1;RunService.PreSimulation:Fire(1/120)
assert((axeGrip.Transform.LookVector-CFrame.identity.LookVector).Magnitude<1e-7,"finish presents rest pose immediately")
Motion.Cancel(axeGrip);axeGrip.Parent=nil;oc:SetAttribute("HandsItem","Gun")
print("PASS: real axe motion and remote two-hand IK advance at120Hz without C0 replication or stale held-part feedback")
-- Reload is rendered by the same viewer driver and releases its motor on cancel.
local reloadMotor=Instance.new("Motor6D",held);reloadMotor.Name="WeaponGrip"
reloadMotor.Part0=root;reloadMotor.Part1=held;reloadMotor.C0=CFrame.new(.3,.6,0);reloadMotor.C1=CFrame.identity
reloadMotor:SetAttribute("RestC0",reloadMotor.C0)
held:SetAttribute("Item_ID","Gun");held:SetAttribute("AnimationSet","Launcher")
c:SetAttribute("ReloadItemID","Gun");c:SetAttribute("ReloadStartedAt",serverTime)
c:SetAttribute("ReloadDuration",4);c:SetAttribute("ReloadVisualType","Rocket");c:SetAttribute("ReloadRoundCount",1)
c:SetAttribute("Reloading",true);c.DescendantAdded:Fire(reloadMotor);flush()
serverTime+=2;RunService.PreSimulation:Fire(1/30)
assert(reloadMotor.Transform.Position.Magnitude>.1,"viewer actually lowers rocket tube during reload")
c:SetAttribute("WeaponCombatUntil",serverTime+4)
c:SetAttribute("Reloading",false);c:GetAttributeChangedSignal("Reloading"):Fire()
RunService.PreSimulation:Fire(1/30)
assert(reloadMotor.Transform.Position.Magnitude<1e-7,"cancel restores weapon grip")
c:SetAttribute("Reloading",true);c:SetAttribute("ReloadStartedAt",serverTime-5)
RunService.PreSimulation:Fire(1/30)
assert(reloadMotor.Transform.Position.Magnitude<1e-7,"expired pose cannot stick while completion packet is delayed")
c:SetAttribute("Reloading",false)
serverTime+=5
for _=1,60 do RunService.PreSimulation:Fire(1/60) end
assert(reloadMotor.Transform.Position.Magnitude<1e-7,"launcher remains on shoulder after combat expires")
assert(c:FindFirstChild("LeftElbow",true).Transform==CFrame.identity,"relaxed launcher frees left arm")
c:SetAttribute("WeaponCombatUntil",serverTime+4)
for _=1,60 do RunService.PreSimulation:Fire(1/60) end
assert(reloadMotor.Transform.Position.Magnitude<.001,"combat returns weapon to ready")
held:SetAttribute("AnimationSet","Pistol");c:SetAttribute("WeaponCombatUntil",0)
for _=1,120 do RunService.PreSimulation:Fire(1/60) end
local rightShoulder=c:FindFirstChild("RightShoulder",true)
local rightElbow=c:FindFirstChild("RightElbow",true)
local standing=rightShoulder:GetAttribute("StandingRotation")
local upper,lower=rightShoulder:GetAttribute("UpperVector"),rightShoulder:GetAttribute("LowerVector")
local arm=standing*rightShoulder.Transform
local hand=arm:VectorToWorldSpace(upper)+(arm*rightElbow.Transform):VectorToWorldSpace(lower)
assert(hand.Unit:Dot(standing:VectorToWorldSpace(upper+lower).Unit)>.999,"resting pistol hand hangs straight down")
assert(c:FindFirstChild("LeftElbow",true).Transform==CFrame.identity,"pistol support hand stays free")
reloadMotor.Parent=nil;held:SetAttribute("AnimationSet",nil)
print("PASS: real viewer reload lowers launcher, cancellation and expiry restore held motor")
otherRoot.CFrame=CFrame.new(300,0,0)*otherRoot.CFrame
local previous=remoteHip.Transform
RunService.PreSimulation:Fire(1/30);assert(remoteHip.Transform==previous,"distant rigs do no pose work")
local removed=c:FindFirstChild("LeftKnee",true)
c.DescendantRemoving:Fire(removed);removed.Parent=nil;flush()
RunService.PreSimulation:Fire(1/30)
removed.Parent=c:FindFirstChild("LeftUpperLeg");c.DescendantAdded:Fire(removed);flush()
RunService.PreSimulation:Fire(1/30)
Players.PlayerRemoving:Fire(other);owner.CharacterRemoving:Fire()
RunService.PreSimulation:Fire(1/30)
print("PASS: viewer controller movement, late weapon, other players, distance cull, knockout, partial streaming and cleanup")

-- Reuse precisely the client pose implementation in Studio's server viewport.
Driver.Start(nil,true)
for _,id in ipairs({"Pistol","Knife","Axe","Shovel","Pliers"}) do
 c:SetAttribute("HandsItem",id);RunService.PreSimulation:Fire(1/30)
 assert(shoulder.Transform.R[1]==shoulder.Transform.R[1],"all equipment poses stay finite")
end
c:SetAttribute("HandsItem","Knife");RunService.PreSimulation:Fire(1/30)
local guard=c:FindFirstChild("LeftShoulder",true)
local guardElbow=c:FindFirstChild("LeftElbow",true)
local s=guard:GetAttribute("StandingRotation")*guard.Transform
local endpoint=s:VectorToWorldSpace(guard:GetAttribute("UpperVector"))+(s*guardElbow.Transform):VectorToWorldSpace(guard:GetAttribute("LowerVector"))
local anchor=(guard.Part0.CFrame*guard:GetAttribute("AuthoredC0")*CFrame.new(guard:GetAttribute("StandingOffset"))).Position
local hand=root.CFrame:PointToObjectSpace(anchor+root.CFrame:VectorToWorldSpace(endpoint))
assert(hand.Z<-.4 and hand.Y>.1,"knife free hand is raised in front of the body")
c:SetAttribute("HandsItem","Shovel");RunService.PreSimulation:Fire(1/30)
local lastRemote=remoteHip.Transform
RunService.PreSimulation:Fire(1/30)
assert(remoteHip.Transform~=lastRemote,"Studio preview poses players without a local viewer or distance cull")
print("PASS: pistol, knife, two-handed axe/shovel and shared Studio server preview")
local oldHeld=c:FindFirstChild("HeldItem");if oldHeld then oldHeld.Parent=nil end
c:SetAttribute("HandsItem",nil)
local function wrist(side)
 local shoulder=c:FindFirstChild(side.."Shoulder",true)
 local elbow=c:FindFirstChild(side.."Elbow",true)
 local rotation=shoulder:GetAttribute("StandingRotation")*shoulder.Transform
 local delta=rotation:VectorToWorldSpace(shoulder:GetAttribute("UpperVector"))+(rotation*elbow.Transform):VectorToWorldSpace(shoulder:GetAttribute("LowerVector"))
 local anchor=(shoulder.Part0.CFrame*shoulder:GetAttribute("AuthoredC0")*CFrame.new(shoulder:GetAttribute("StandingOffset"))).Position
 return root.CFrame:PointToObjectSpace(anchor+root.CFrame:VectorToWorldSpace(delta))
end
Punch.Begin(c,serverTime);serverTime+=Punch.Contact;RunService.PreSimulation:Fire(1/30)
assert(wrist("Right").Z<-.7 and wrist("Left").Z>-.4 and wrist("Left").Y>.1,"right punch reaches contact while left hand guards")
serverTime+=1-Punch.Contact;Punch.Begin(c,serverTime);serverTime+=Punch.Contact;RunService.PreSimulation:Fire(1/30)
assert(wrist("Left").Z<-.7 and wrist("Right").Z>-.4,"next accepted punch uses the left hand")
serverTime+=2;RunService.PreSimulation:Fire(1/30)
assert(wrist("Left").Y<-.3 and wrist("Right").Y<-.3,"both arms return to idle after combat")
print("PASS: alternating unarmed punches, opposite-hand guard, synchronized contact and idle recovery")

c:SetAttribute("CarryingUserId",123);RunService.PreSimulation:Fire(1/30)
local supporting,free=wrist("Left"),wrist("Right")
assert(supporting.X<-root.Size.X/2 and supporting.Y>0,"left arm supports the patient on the left shoulder")
assert(free.Y<-.3,"right arm stays free instead of cradling the patient in both arms")
c:SetAttribute("CarryingUserId",nil)
print("PASS: carrier left-arm shoulder support and free right arm")

c:SetAttribute("HandsItem","Pliers");held:SetAttribute("AnimationSet",nil)
RunService.PreSimulation:Fire(1/30)
local right=c:FindFirstChild("RightShoulder",true)
local left=c:FindFirstChild("LeftShoulder",true)
local leftElbow=c:FindFirstChild("LeftElbow",true)
assert(right.Transform~=CFrame.identity,"utility tool engages right-hand IK without a Weapon definition")
assert(leftElbow.Transform==CFrame.identity,"tool free hand does not enter a two-hand support pose")
print("PASS: utility tool grip IK and free left hand in the shared viewer/server driver")
