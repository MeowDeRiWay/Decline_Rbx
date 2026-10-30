"""Run real interaction phases, corpse sessions and shared pose driver on uploaded geometry."""
from pathlib import Path
import re, subprocess, sys, tempfile
root=Path(__file__).resolve().parents[1]
def module(path): return '(function()\n'+(root/path).read_text()+'\nend)()'
helpers=(root/'tests/run_character_rig.py').read_text().split("source+=r'''")[1].split('local function test(frame)')[0]
s=(root/'tests/rig_math.fixture.luau').read_text()+helpers
for alias,path in [('Pose','src/shared/CharacterPose.luau'),('Rig','src/shared/CharacterRig.luau'),('Foot','src/shared/FootPlant.luau'),('Punch','src/shared/UnarmedPose.luau'),('geometry','tests/character_geometry.fixture.luau')]: s+='\nlocal '+alias+'='+module(path)
s+='\nlocal Interact='+module('src/shared/InteractionPose.luau').replace('local IK=require(script.Parent.CharacterPose)','local IK=Pose')
s+='\nlocal HandPose='+module('src/shared/HandActionPose.luau').replace('local IK=require(script.Parent.CharacterPose)','local IK=Pose')
s+='\n'+(root/'tests/character_animation.fixture.luau').read_text()
s+=r'''
function CFrame.lookAt(position,target)
 local back=-(target-position).Unit;local right=Vector3.yAxis:Cross(back).Unit;local up=back:Cross(right)
 return cf(position,{right.X,up.X,back.X,right.Y,up.Y,back.Y,right.Z,up.Z,back.Z})
end
function cm.__sub(frame,v) return cf(frame.Position-v,frame.R) end
function cm:Lerp(other,t)
 if t==0 then return self elseif t==1 then return other end
 local relative=self:Inverse()*other
 local angle=math.acos(math.clamp((relative.R[1]+relative.R[5]+relative.R[9]-1)/2,-1,1))
 local axis=Vector3.new(relative.R[8]-relative.R[6],relative.R[3]-relative.R[7],relative.R[4]-relative.R[2])
 local rotation=CFrame.identity
 if angle>.000001 then assert(axis.Magnitude>.000001);rotation=CFrame.fromAxisAngle(axis.Unit,angle*t) end
 return CFrame.new(self.Position+(other.Position-self.Position)*t)*(CFrame.new(-self.Position)*self)*rotation
end
local originalSet=methods.SetAttribute
function methods:SetAttribute(k,v)
 local before=self:GetAttribute(k);originalSet(self,k,v)
 if before~=v and self.Signals and self.Signals[k] then self.Signals[k]:Fire() end
end
local new=Instance.new
Instance.new=function(class,parent)
 local o=new(class,parent)
 if class=="BindableEvent" then o.Event=signal();function o:Fire(...) self.Event:Fire(...) end end
 return o
end
local typeof=function(v) if type(v)=="table" and v.ClassName then return "Instance" end;return type(v) end
local jobs={}
function task.delay(seconds,fn) table.insert(jobs,{At=serverTime+seconds,Run=fn}) end
local function advance(dt)
 serverTime+=dt
 local ready={}
 for _,j in ipairs(jobs) do if not j.Done and j.At<=serverTime+.000001 then j.Done=true;table.insert(ready,j) end end
 table.sort(ready,function(a,b) return a.At<b.At end)
 for _,j in ipairs(ready) do j.Run() end
 RunService.PreSimulation:Fire(1/30)
end
local Hands={}
local Motion={Cancel=function() end}
local Interaction={NearestPoint=function(target) return target.CFrame.Position end}
local function reset()
 c:SetAttribute("Knockout",nil);c:SetAttribute("IsDead",nil);root.Anchored=false;hp.Health=100;hp.PlatformStand=false;hp.AutoRotate=true;hp.WalkSpeed=3
 c.Destroying=signal()
 local old=c:FindFirstChild("HeldItem");if old then old:Destroy() end
 root.CFrame=CFrame.identity
 owner.CharacterAdded:Fire(c)
 return Instance.new("Part",workspace)
end
local function heldWeapon()
 local held=Instance.new("Part",c);held.Name="HeldItem";held.CFrame=root.CFrame;held.Size=Vector3.new(.1,.1,.8)
 local motor=Instance.new("Motor6D",held);motor.Name="WeaponGrip";motor.Part0=root;motor.Part1=held;motor.C0=CFrame.new(.24,.28,-.25);motor.C1=CFrame.identity
 motor:SetAttribute("RestC0",motor.C0);motor.Transform=CFrame.identity
 local grip=Instance.new("Attachment",held);grip.Name="_HandGrip";grip.CFrame=CFrame.identity
 c:SetAttribute("HandsItem","Gun");c.DescendantAdded:Fire(held);flush()
 return held,motor
end
local function target()
 local p=reset();p.Name="Target";p.CFrame=CFrame.new(0,-.1,-.6)
 return p
end
local function poseMotors()
 local m={}
 for _,j in ipairs(c:GetDescendants()) do if j:IsA("Motor6D") and j:GetAttribute("AuthoredC0") then m[j.Name]=j end end
 return m
end
local function wrist(side)
 local m=poseMotors()
 local lower=root.CFrame*m.RootJoint.C0*m.RootJoint.Transform*m.RootJoint.C1:Inverse()
 local upper=lower*m.Waist.C0*m.Waist.Transform*m.Waist.C1:Inverse()
 local sh,el=m[side.."Shoulder"],m[side.."Elbow"]
 local f=upper*sh:GetAttribute("AuthoredC0")*CFrame.new(sh:GetAttribute("StandingOffset"))
 local s=sh:GetAttribute("StandingRotation")*sh.Transform
 local d=s:VectorToWorldSpace(sh:GetAttribute("UpperVector"))+(s*el.Transform):VectorToWorldSpace(sh:GetAttribute("LowerVector"))
 return f:PointToWorldSpace(d)
end
'''
service=(root/'src/server/Services/InteractionAnimationService.luau').read_text()
service=re.sub(r'local (Shared|Pose|Interaction|Motion)=.*\n','',service)
s+='\nlocal Animation=(function()\nlocal Pose=Interact\n'+service+'\nend)()'
controller=(root/'src/shared/CharacterAnimationDriver.luau').read_text()
controller=re.sub(r'local (Players|RunService|Shared|Pose|Foot|Punch|Items|Interact|Motion|HandPose)\s*=.*\n','',controller)
s+='\nlocal Driver=(function()\n'+controller+'\nend)()\nDriver.Start(owner,false)'
s+=r'''
local object=target();local contacts=0
assert(Animation.Reach(owner,object,1,function() contacts+=1 end))
assert(c:GetAttribute("InteractionHand")=="Right" and root.Anchored and hp.WalkSpeed==0)
assert(not Animation.Reach(owner,object,1,function() error("overlapping action") end))
advance(.29);assert(contacts==0)
advance(.01);assert(contacts==1 and c:GetAttribute("InteractionLocked"))
assert((wrist("Right")-object.Position).Magnitude<(wrist("Left")-object.Position).Magnitude,"empty hands reach with right")
advance(.35);assert(not c:GetAttribute("InteractionLocked") and not root.Anchored and hp.WalkSpeed==3)
object=target();local held,motor=heldWeapon()
assert(Animation.Reach(owner,object,1,function() contacts+=1 end));advance(.3)
assert(c:GetAttribute("InteractionHand")=="Left")
assert((wrist("Left")-object.Position).Magnitude<(wrist("Right")-object.Position).Magnitude,"armed interaction uses left hand")
assert((motor.C0*motor.Transform).Position.Y<-.2,"weapon lowers with right hand")
assert(held.Parent==c,"held weapon is never placed in WorldItems")
advance(.35);near(motor.Transform.Position,Vector3.zero)
object=target();assert(Animation.Reach(owner,object,1,function() contacts+=10 end))
Animation.Cancel(c);c:SetAttribute("Knockout",true);advance(1)
assert(contacts==2,"knockout cancels pending activation")
object=target();object.CFrame=CFrame.new(0,0,-20)
assert(not Animation.Reach(owner,object,1,function() error("too far") end) and not root.Anchored)
object=target();held,motor=heldWeapon()
local opened=0
assert(Animation.BeginLoot(owner,object,1,function() opened+=1;return true end))
advance(.45);assert(opened==0 and c:GetAttribute("InteractionLocked"))
assert(poseMotors().RootJoint.Transform.Position.Y<-.2,"knees bend and pelvis descends")
advance(.45);assert(opened==1 and c:GetAttribute("InteractionMode")=="Loot")
assert((motor.C0*motor.Transform).Position.Y<-.9,"weapon is beside player near ground")
assert(held.Parent==c and not held.CanQuery,"weapon retains character ownership")
advance(4);assert(c:GetAttribute("InteractionLocked") and root.Anchored)
Animation.EndLoot(owner);local upAt=c:GetAttribute("InteractionStartedAt")
Animation.EndLoot(owner);assert(c:GetAttribute("InteractionStartedAt")==upAt,"duplicate close cannot restart rise")
advance(.6)
assert((motor.C0*motor.Transform).Position.Y>-.5 and poseMotors().RootJoint.Transform.Position.Y<-.3,"pick weapon up before standing")
assert(root.Anchored and c:GetAttribute("InteractionLocked"))
advance(.54);assert(c:GetAttribute("InteractionLocked"),"cannot move/fire before rise completes")
advance(.01);assert(not root.Anchored and not c:GetAttribute("InteractionLocked"))
-- Close in the middle of crouching: keep the current crouch/weapon blend.
object=target();held,motor=heldWeapon()
assert(Animation.BeginLoot(owner,object,1,function() opened+=1 end));advance(.3)
local down=poseMotors().RootJoint.Transform.Position.Y
Animation.EndLoot(owner);RunService.PreSimulation:Fire(1/30)
assert(math.abs(poseMotors().RootJoint.Transform.Position.Y-down)<.0001)
advance(1.15);assert(not root.Anchored and opened==1,"old down timer cannot reopen inventory")
object=target();assert(Animation.BeginLoot(owner,object,1,function() error("stale dead loot") end))
Animation.Cancel(c);assert(not root.Anchored,"life cancels before recording KO anchoring")
c:SetAttribute("Knockout",true);root.Anchored=true;advance(2)
assert(root.Anchored,"old timers cannot unfreeze KO/death")
object=target();assert(Animation.BeginLoot(owner,object,1,function() return true end))
owner.CharacterRemoving:Fire(c);advance(2);assert(not c:GetAttribute("InteractionLocked"))
-- Close corpses must not pull hands back into the player's lap. Check real
-- wrist positions on the authored rig at both near and farther search points.
for _,z in ipairs({-.1,-.8}) do
 local body=target();body.CFrame=CFrame.new(0,-.85,z)
 heldWeapon()
 assert(Animation.BeginLoot(owner,body,2,function() return true end));advance(.9)
 for _,side in ipairs({"Left","Right"}) do
  local localHand=root.CFrame:PointToObjectSpace(wrist(side))
  assert(localHand.Z<-.35 and localHand.Y<-.6,"search wrists remain forward and low even beside a very close corpse")
  for step=0,20 do
   local point=Interact.SearchPoint(root,body.Position,side,step*.1,.9,.9)
   local p=root.CFrame:PointToObjectSpace(point)
   assert(p.Z<=-.55 and p.Y<=-.93+.0001,"search target stays in front and near corpse height throughout the sweep")
  end
 end
 assert(poseMotors().Waist.Transform.LookVector.Y<-.6,"torso leans over the corpse")
 Animation.Cancel(c)
end
local body=target();body:Destroy()
body=Instance.new("Model",workspace);body.CFrame=CFrame.new(0,-.2,-.4)
local torso=Instance.new("Part",body);torso.Name="UpperTorso";torso.CFrame=CFrame.new(.15,-.95,-.8)
assert(Animation.BeginLoot(owner,body,1,function() return true end))
near(c:GetAttribute("InteractionPoint"),torso.Position)
Animation.Cancel(c)
print("PASS: delayed single contact, handedness, weapon lowering, anchored crouch/search, owned ground weapon, pickup-before-rise, full lock deadline, early close, KO and character removal")
'''
# Actual corpse session opens after crouching and starts recovery on Close/TakeAll.
chest=(root/'src/server/Services/ChestService.luau').read_text()
chest=re.sub(r'local (Players|ReplicatedStorage|Inventory|Rules|Items|Interaction|Animation)\s*=.*\n','',chest)
s+=r'''
local Rules={New=function() return {Items={Stone=1}} end,Stacks=function() return {} end}
local Items={PickupDistance=1,Items={Stone={}}}
local transfers=0
local Inventory={Transfer=function(_,storage,id) transfers+=1;storage.Items[id]=nil;return true end}
local RaycastParams={new=function() return {} end}
local Enum={RaycastFilterType={Exclude=1}}
function methods:FindFirstChildWhichIsA(kind) for _,p in ipairs(self:GetDescendants()) do if p:IsA(kind) then return p end end end
function workspace:Raycast() return nil end
'''
s+='\nlocal Chests=(function()\n'+chest+'\nend)()'
s+=r'''
local corpse=Instance.new("Model",workspace);corpse.Name="Zombie";corpse.CFrame=CFrame.new(0,-.2,-.5);corpse:SetAttribute("IsCorpse",true)
Instance.new("Part",corpse)
reset();heldWeapon()
assert(Chests.Open(owner,corpse));assert(not Chests.Snapshot(owner).ChestOpen)
advance(.9);assert(Chests.Snapshot(owner).Chest==corpse and c:GetAttribute("InteractionMode")=="Loot")
assert(Chests.TakeAll(owner) and transfers==1)
assert(not Chests.Snapshot(owner).ChestOpen and c:GetAttribute("InteractionMode")=="LootUp" and root.Anchored)
advance(1.15);assert(not c:GetAttribute("InteractionLocked") and not root.Anchored)
print("PASS: real corpse chest session opens after crouch; TakeAll closes UI then completes weapon pickup and rise before unlock")
'''

handler=(root/'src/server/Inventory.server.luau').read_text()
handler=handler[handler.index('action.OnServerEvent:Connect(function(player, command, value, amount)')+len('action.OnServerEvent:Connect(function(player, command, value, amount)'):handler.rindex('end)')]
s+=r'''
local dispatched=0
local Crafting={Close=function() end}
local Service={Equip=function() dispatched+=1 end,ToggleHolster=function() dispatched+=1 end,Unequip=function() dispatched+=1 end}
local ItemConfig={PickupDistance=1}
local lastAction={}
local os={clock=function() return serverTime end}
function owner:GetAttribute(k) if k=="AttributesConfirmed" then return true end end
local pickupContacts=0
local WorldItems={Pickup=function() pickupContacts+=1 end}
'''
s+='\nlocal function inventoryAction(player,command,value,amount)\n'+handler+'\nend'
s+=r'''
local item=target();inventoryAction(owner,"Pickup",item)
assert(pickupContacts==0);advance(.3);assert(pickupContacts==1);advance(.35)
inventoryAction(owner,"OpenChest",corpse);advance(.9)
assert(c:GetAttribute("InteractionMode")=="Loot")
inventoryAction(owner,"Equip","Gun");advance(.11)
inventoryAction(owner,"Holster");advance(.11)
inventoryAction(owner,"Unequip","Hands");assert(dispatched==0,"cannot replace/holster the weapon visually lying beside the player")
inventoryAction(owner,"CloseChest");assert(c:GetAttribute("InteractionMode")=="LootUp")
advance(1.15);inventoryAction(owner,"Equip","Gun");assert(dispatched==1)
print("PASS: real inventory dispatch delays pickup until hand contact and blocks equipment changes through loot/recovery")
'''
life=(root/'src/server/Services/PlayerLifeService.luau').read_text().replace('require(script.Parent.HandActionService).Cancel(player)','')
freeze=life[life.index('local function freeze(character)'):life.index('function Service.Finish')]
knockout=life[life.index('function Service.Knockout'):life.index('function Service.Revive')]
damage=life[life.index('function Service.Damage'):life.rindex('return Service')]
s+=r'''
local BodyFall={Play=function(_,kind) assert(kind=="Knockout") end}
local Beds={Leave=function() end}
local Defense={}
local knocked,finished={},{}
'''
s+='\nlocal Life=(function()\nlocal Service={}\n'+freeze+knockout+damage+'\nreturn Service\nend)()'
s+=r'''
local corpseTarget=target();c.CFrame=root.CFrame
assert(Animation.BeginLoot(owner,corpseTarget,1,function() error("dead player must not open loot") end))
assert(Life.Damage(owner,hp,200,true,true)==100,"interaction grants no damage immunity")
assert(c:GetAttribute("Knockout") and hp.Health==1 and root.Anchored and not c:GetAttribute("InteractionLocked"))
assert(knocked[c].Parts[root].Anchored==false,"KO records the original movable root, so revival can stand up")
advance(2);assert(root.Anchored and c:GetAttribute("Knockout"),"pending interaction callbacks cannot undo KO")
local zeroTarget=target();c.CFrame=root.CFrame
assert(Animation.BeginLoot(owner,zeroTarget,1,function() error("dead") end))
hp.Health=0;Life.Knockout(owner,c)
assert(knocked[c].Parts[root].Anchored==false,"HealthChanged at zero HP also restores ownership before the KO snapshot")
print("PASS: actual lethal Life.Damage and zero-HP HealthChanged during looting enter KO with correct revival anchoring")
'''
s+=r'''
reset();local held,motor=heldWeapon();local m=poseMotors()
for _,slot in ipairs({"PrimaryWeapon","SecondaryWeapon","Medicine"}) do
 c:SetAttribute("HandActionSlot",slot);c:SetAttribute("HandActionStartedAt",serverTime)
 c:SetAttribute("HandAction","Stow")
 assert(HandPose.Apply(c,root,m,serverTime+HandPose.StowContact))
 local final=root.CFrame*motor.C0*motor.Transform
 near(final.Position,HandPose.StorageFrame(c,root,slot).Position)
 c:SetAttribute("HandAction","Draw")
 HandPose.Apply(c,root,m,serverTime+HandPose.DrawDuration)
 near((motor.C0*motor.Transform).Position,motor.C0.Position)
end
local selfFrame
for _,mode in ipairs({"TreatSelf","TreatOther"}) do
 c:SetAttribute("HandAction",mode);c:SetAttribute("HandTreatmentPoint",root.CFrame:PointToWorldSpace(Vector3.new(0,-.3,-.7)))
 HandPose.Apply(c,root,m,serverTime+.5)
 local f=motor.C0*motor.Transform
 if mode=="TreatSelf" then selfFrame=f else assert((f.Position-selfFrame.Position).Magnitude>.15,"other treatment reaches the patient rather than actor chest") end
 for _,side in ipairs({"Left","Right"}) do
  local transform=m[side.."Shoulder"].Transform
  assert(transform.R[1]==transform.R[1],"both treatment hands remain finite")
 end
end
c:SetAttribute("HandAction",nil);assert(not HandPose.Apply(c,root,m,serverTime))
print("PASS: actual hand poses stow/draw at spine/hip/pouch pivots and distinct self/other two-hand treatment")
'''
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'interaction.luau';p.write_text(s)
 subprocess.run([sys.argv[1],str(p)],check=True)
