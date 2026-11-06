"""Exercise terminal poses and server grounding against the authored limb geometry."""
from pathlib import Path
import re, subprocess, sys, tempfile
root=Path(__file__).resolve().parents[1]
def module(path): return '(function()\n'+(root/path).read_text()+'\nend)()'
helpers=(root/'tests/run_character_rig.py').read_text().split("source+=r'''")[1].split('local function test(frame)')[0]
s=(root/'tests/rig_math.fixture.luau').read_text()+helpers
s+='\nlocal Pose='+module('src/shared/CharacterPose.luau')
s+='\nlocal Rig='+module('src/shared/CharacterRig.luau')
s+='\nlocal Fall='+module('src/shared/BodyFallPose.luau').replace('local Pose=require(script.Parent.CharacterPose)','')
s+='\nlocal geometry='+module('tests/character_geometry.fixture.luau')
s+='\nlocal CarryPose='+module('src/shared/CarryPose.luau')
s+=r'''
-- Tween endpoint integration; interpolation itself is Roblox's CFrame:Lerp.
function cm:Lerp(other,a) assert(a==0 or a==1);return a==0 and self or other end
function methods:IsDescendantOf(other) local p=self.Parent;while p do if p==other then return true end;p=p.Parent end;return false end
local function signal()
 local callbacks={}
 return {Connect=function(_,fn) callbacks[fn]=true;return {Disconnect=function() callbacks[fn]=nil end} end,
 Once=function(self,fn) return self:Connect(fn) end,Fire=function(_,...) for fn in pairs(callbacks) do fn(...) end end}
end
local new=Instance.new
Instance.new=function(kind,parent)
 local o=new(kind,parent)
 if kind=="NumberValue" then o.Changed=signal() end
 return o
end
local Players={GetPlayers=function() return {} end}
local floorY=0
local blockers={}
local noGround=false
workspace=new("Model");workspace.Name="Workspace"
workspace.Terrain=new("Terrain",workspace)
local ground=new("Part",workspace);ground:SetAttribute("BodyGround",true)
function workspace:Raycast(origin,delta,params)
 assert(params.RespectCanCollide==false,"marked noncollidable ground must be queryable")
 for _,entry in ipairs(blockers) do
  if not table.find(params.FilterDescendantsInstances,entry.Part) then
   return {Position=Vector3.new(origin.X,entry.Y,origin.Z),Instance=entry.Part,Normal=entry.Normal or Vector3.yAxis}
  end
 end
 if noGround then return nil end
 return {Position=Vector3.new(origin.X,floorY,origin.Z),Instance=ground,Normal=Vector3.yAxis}
end
local TweenService={};local tweens={}
function TweenService:Create(value,info,goal)
 local t={Completed=signal(),Value=value,Duration=info.Duration,Goal=goal}
 function t:Play() end
 function t:Cancel() self.Cancelled=true;self.Completed:Fire() end
 function t:Finish() if not self.Cancelled then self.Value.Changed:Fire(1);self.Completed:Fire() end end
 table.insert(tweens,t);return t
end
local Enum={RaycastFilterType={Exclude=1,Include=2},EasingStyle={Quad=1},EasingDirection={InOut=1}}
local RaycastParams={new=function() return {} end}
local TweenInfo={new=function(duration) return {Duration=duration} end}
local typeof=function(v) if getmetatable(v)==vm then return "Vector3" end;return type(v) end
'''
service=(root/'src/server/Services/BodyFallService.luau').read_text()
service=re.sub(r'local (Players|TweenService|Fall)=[^\n]+\n','',service)
s+='\nlocal Service=(function()\n'+service+'\nend)()'
s+=r'''
local function build(yaw)
 local c=new("Model",workspace)
 for _,g in ipairs(geometry) do local p=new("Part",c);p.Name=g.Name;p.CFrame=CFrame.new(10,3,20)*CFrame.Angles(0,yaw,0)*g.CFrame;p.Size=g.Size;p.Transparency=0 end
 local root=c:FindFirstChild("Body");root.Name="HumanoidRootPart"
 local hp=new("Humanoid",c);assert(Rig.Prepare(c,root,hp))
 local joints={};local rest={}
 for _,j in ipairs(c:GetDescendants()) do if j:IsA("Motor6D") then table.insert(joints,j);rest[j]=Fall.Rest(j);j.Transform=CFrame.identity end end
 for p,cf in pairs(Fall.Solve(root,root.CFrame,joints,rest)) do p.CFrame=cf end
 return c,root,joints
end
local function grounded(c)
 local bottom=math.huge
 for _,p in ipairs(c:GetDescendants()) do if p:IsA("Part") and p.Transparency<1 then bottom=math.min(bottom,p.Position.Y-Fall.RadiusY(p.CFrame,p.Size)) end end
 assert(math.abs(bottom-floorY-.02)<.00001,"posed geometry touches the floor, not standing HipHeight")
 for _,p in ipairs(c:GetDescendants()) do if p:IsA("Part") then assert(p.Anchored and not p.CanCollide) end end
end
for _,yaw in ipairs({0,1.3}) do
 local c,root,joints=build(yaw)
 local original=root.CFrame
 Service.Play(c,"Knockout");local ko=tweens[#tweens];assert(ko.Duration==.65);ko:Finish();grounded(c)
 assert(math.abs(root.CFrame.UpVector.Y)<.00001,"KO lies on its side")
 local knees={}
 for _,j in ipairs(joints) do if j.Name:find("Knee") then assert(j.C0.LookVector:Dot(Fall.Rest(j).LookVector)<-.6,"knees fold into fetal position") end end
 local curled=c:FindFirstChild("LeftLowerLeg").Position
 Service.Play(c,"Death");tweens[#tweens]:Finish();grounded(c)
 assert(root.CFrame.LookVector.Y>.99,"death rolls out of fetal position onto back")
 assert((c:FindFirstChild("LeftLowerLeg").Position-curled).Magnitude>.3,"death relaxes the folded legs")
 Service.Restore(c)
 assert(not c:GetAttribute("BodyPoseKind"))
 for _,j in ipairs(joints) do near(j.C0.Position,Fall.Rest(j).Position);near(j.C0.LookVector,Fall.Rest(j).LookVector) end
 -- Revive/cancel during a transition cannot be overwritten by a stale callback.
 Service.Play(c,"Knockout");local interrupted=tweens[#tweens];Service.Restore(c);interrupted:Finish()
 assert(interrupted.Cancelled and c:GetAttribute("BodyPoseKind")==nil)
 for _,direction in ipairs({Vector3.new(0,0,-1),Vector3.new(0,0,1),Vector3.new(1,0,0),Vector3.new(-1,0,0),Vector3.new(.6,0,-.8)}) do
  local z,r,js=build(yaw)
  local worldDirection=r.CFrame:VectorToWorldSpace(direction)
  z:SetAttribute("LastHitDirection",worldDirection)
  floorY=1.75
  Service.Play(z,"Zombie");tweens[#tweens]:Finish();grounded(z)
  assert(r.CFrame.UpVector:Dot(worldDirection)>.999,"fall follows impact direction without turning the whole character towards the attacker")
  local prone=direction.Z<=0
  for _,j in ipairs(js) do if j.Name:find("Shoulder") then
   local a=j:GetAttribute("UpperVector")
   local localArm=(j:GetAttribute("AuthoredC0")*CFrame.new(j:GetAttribute("StandingOffset"))):Inverse()*j.C0
   local aim=localArm:VectorToWorldSpace(a.Unit)
   assert((prone and aim.Y>.95) or (not prone and aim.Y<-.95),"zombie arms point towards head when prone, feet when supine")
  end end
  floorY=0
 end
end
-- Furniture, walls, and authored home floors must never lift a body above
-- the actual marked ground, even if their top faces are horizontal.
local home=new("Model",workspace);home:SetAttribute("Zombie_home",true)
local shelf=new("Part",home)
local wall=new("Part",home)
local shopFloor=new("Part",home)
blockers={{Part=shelf,Y=2.5},{Part=wall,Y=2},{Part=shopFloor,Y=1.8}}
floorY=0
local indoor=build(0)
Service.Play(indoor,"Knockout");tweens[#tweens]:Finish();grounded(indoor)
Service.Play(indoor,"Death");tweens[#tweens]:Finish();grounded(indoor)
local zombie=build(0)
local ref=new("ObjectValue",zombie);ref.Name="ZombieHome";ref.Value=home
Service.Play(zombie,"Zombie");tweens[#tweens]:Finish();grounded(zombie)
-- Explicitly marked raised floors can still be used if the author wants them.
shopFloor:SetAttribute("BodyGround",true);floorY=1.8
local raised=build(0)
Service.Play(raised,"Death");tweens[#tweens]:Finish();grounded(raised)
shopFloor:SetAttribute("BodyGround",nil)
-- Ground attributes on a container never mark all its shelves/walls as ground.
home:SetAttribute("BodyGround",true);floorY=0
local container=build(0)
Service.Play(container,"Zombie");tweens[#tweens]:Finish();grounded(container)
-- Terrain is accepted without an attribute; vertical marked faces are skipped.
ground=workspace.Terrain
wall:SetAttribute("BodyGround",true);blockers={{Part=wall,Y=2,Normal=Vector3.xAxis}}
local terrain=build(0)
Service.Play(terrain,"Knockout");tweens[#tweens]:Finish();grounded(terrain)
-- Missing ground has no fallback to a shelf or wall.
noGround=true
local missing,r=build(0);local y=r.Position.Y
Service.Play(missing,"Death");tweens[#tweens]:Finish()
assert(math.abs(r.Position.Y-y)<.0001,"no accepted ground means no invented furniture support")
noGround=false;blockers={};floorY=0
local armored,aroot=build(0)
local limb=armored:FindFirstChild("LeftLowerArm")
local sleeve=new("Part",armored);sleeve.Name="Sleeve";sleeve.Transparency=0;sleeve.Size=Vector3.new(.2,.2,.2)
local offset=CFrame.new(.01,0,.02);sleeve.CFrame=limb.CFrame*offset
local weld=new("WeldConstraint",sleeve);weld.Name="ArmorWeld";weld.Part0=limb;weld.Part1=sleeve
local torso=armored:FindFirstChild("UpperTorso")
local backpack=new("Part",armored);backpack.Name="Backpack";backpack.Transparency=0;backpack.Size=Vector3.new(.2,.4,.2)
local backOffset=CFrame.new(0,0,.25);backpack.CFrame=torso.CFrame*backOffset
local backWeld=new("WeldConstraint",backpack);backWeld.Name="BackWeld";backWeld.Part0=torso;backWeld.Part1=backpack
for _,kind in ipairs({"Knockout","Death"}) do
 Service.Play(armored,kind);tweens[#tweens]:Finish();grounded(armored)
 near(limb.CFrame:ToObjectSpace(sleeve.CFrame).Position,offset.Position)
 near(torso.CFrame:ToObjectSpace(backpack.CFrame).Position,backOffset.Position)
end
local carrier,carrierRoot=build(.7)
local patient,patientRoot,patientJoints=build(.7)
Service.Play(patient,"Knockout");local stale=tweens[#tweens]
local shoulderFrame=CarryPose.Frame(carrier,patientRoot,carrierRoot)
assert(Service.Carry(patient,shoulderFrame) and stale.Cancelled)
stale:Finish()
near(patientRoot.CFrame.Position,shoulderFrame.Position)
assert(patient:GetAttribute("BodyPoseKind")=="Carried" and patientRoot.CFrame.LookVector.Y<-.99,"patient is prone over shoulder, never curled on side")
local localPoint=carrierRoot.CFrame:PointToObjectSpace(patientRoot.Position)
assert(localPoint.X<-.2 and localPoint.Y>.4,"patient is on the left shoulder above carrier torso")
for _,j in ipairs(patientJoints) do if j.Name:find("Knee") then assert(j.C0.LookVector:Dot(Fall.Rest(j).LookVector)>.8,"carried knees are relaxed, not fetal") end end
assert(patient:FindFirstChild("LeftLowerArm").Position.Y<patientRoot.Position.Y-.15 and patient:FindFirstChild("RightLowerArm").Position.Y<patientRoot.Position.Y-.15,"both unconscious arms hang down")
assert(patient:FindFirstChild("LeftLowerLeg").Position.Y<patientRoot.Position.Y-.2,"unconscious legs hang behind the shoulder")
Service.Restore(patient);assert(not patient:GetAttribute("BodyPoseKind"))
Service.Play(patient,"Knockout");tweens[#tweens]:Finish();grounded(patient)
Service.Carry(armored,CarryPose.Frame(carrier,aroot,carrierRoot))
near(limb.CFrame:ToObjectSpace(sleeve.CFrame).Position,offset.Position)
near(torso.CFrame:ToObjectSpace(backpack.CFrame).Position,backOffset.Position)
Service.Restore(armored)
near(limb.CFrame:ToObjectSpace(sleeve.CFrame).Position,offset.Position)
near(torso.CFrame:ToObjectSpace(backpack.CFrame).Position,backOffset.Position)
local resting,rroot,rjoints=build(.2)
local surface=CFrame.new(20,2,30)*CFrame.Angles(0,.8,0)
assert(Service.RestOnBed(resting,surface,false) and resting:GetAttribute("BodyPoseKind")=="Resting")
assert(rroot.CFrame.LookVector:Dot(surface.UpVector)>.99,"resting body faces up")
assert(rroot.CFrame.UpVector:Dot(surface.LookVector)>.99,"head faces bed head end")
local bottom=math.huge
for _,p in ipairs(resting:GetDescendants()) do
 if p:IsA("Part") then
  local localFrame=surface:ToObjectSpace(p.CFrame)
  bottom=math.min(bottom,localFrame.Position.Y-Fall.RadiusY(localFrame,p.Size))
 end
end
assert(math.abs(bottom-.03)<1e-5,"body rests above mattress without sinking or hovering")
for _,side in ipairs({"Left","Right"}) do
 local arm=resting:FindFirstChild(side.."LowerArm")
 assert((arm.Position-resting:FindFirstChild("UpperTorso").Position):Dot(surface.LookVector)<-.1,"resting forearms lie toward feet, not a T or weapon pose")
end
for _,j in ipairs(rjoints) do if j.Name:find("Knee") then assert(j.C0.LookVector:Dot(Fall.Rest(j).LookVector)>.99,"resting legs are straight") end end
assert(Service.RestOnBed(resting,surface,true) and resting:GetAttribute("BodyPoseKind")=="Knockout")
for _,j in ipairs(rjoints) do if j.Name:find("Knee") then assert(j.C0.LookVector:Dot(Fall.Rest(j).LookVector)<-.6,"KO on bed remains fetal") end end
assert(math.abs(rroot.CFrame.LookVector:Dot(surface.UpVector))<.01,"unconscious body lies on side")
Service.Restore(resting);assert(not resting:GetAttribute("BodyPoseKind"))
for _,j in ipairs(rjoints) do near(j.C0.Position,Fall.Rest(j).Position) end
local rising,risingRoot,risingJoints=build(.4)
local upright=risingRoot.CFrame
Service.Play(rising,"Knockout");tweens[#tweens]:Finish()
local completed=0
Service.Play(rising,"Rise",upright,function() completed+=1 end)
local rise=tweens[#tweens]
assert(rise.Duration==1.15 and completed==0 and rising:GetAttribute("BodyPoseKind")=="Rise")
rise:Finish()
near(risingRoot.Position,upright.Position)
assert(risingRoot.CFrame.UpVector.Y>.99 and completed==1 and not rising:GetAttribute("BodyPoseKind"))
for _,joint in ipairs(risingJoints) do near(joint.C0.Position,Fall.Rest(joint).Position) end
Service.Play(rising,"Knockout");tweens[#tweens]:Finish()
Service.Play(rising,"Rise",upright,function() completed+=1 end)
local staleRise=tweens[#tweens]
Service.Play(rising,"Death");staleRise:Finish()
assert(completed==1,"interrupted rise cannot invoke a stale restoration callback")
print("PASS: replicated KO-to-standing transition, saved upright destination and interrupted rise cleanup")
print("PASS: bed face-up rest, straight legs, arms beside torso, mattress clearance, fetal unconscious patients and upright joint restoration")
print("PASS: left shoulder prone carry, hanging arms/legs, relaxed knees, interrupted KO cancellation, ground drop and attached armor/backpack preservation")
print("PASS: fetal KO, relaxed death, restore/cancellation, directional zombie falls, head/feet arm poses and final ground contact on authored rig, marked plates, Terrain, ignored walls/furniture/home floors and missing-ground guard")
'''
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'body_fall.luau';p.write_text(s)
 result=subprocess.run([sys.argv[1],str(p)],capture_output=True,text=True)
 print(result.stdout,end='');print(result.stderr,end='');sys.exit(result.returncode)
