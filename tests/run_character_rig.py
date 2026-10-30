"""Test production rig against measurements of the actual uploaded model."""
from pathlib import Path
import subprocess,sys,tempfile
root=Path(__file__).resolve().parents[1]
def module(path):return '(function()\n'+(root/path).read_text()+'\nend)()'
source=(root/'tests/rig_math.fixture.luau').read_text()
source+='\nlocal Rig='+module('src/shared/CharacterRig.luau')
source+='\nlocal Pose='+module('src/shared/CharacterPose.luau')
source+='\nlocal Foot='+module('src/shared/FootPlant.luau')
source+='\nlocal Punch='+module('src/shared/UnarmedPose.luau')
source+='\nlocal geometry='+module('tests/character_geometry.fixture.luau')
source+=r'''
local objects={}
local methods={}
function methods:IsA(kind) return self.ClassName==kind or (kind=="BasePart" and self.ClassName=="Part") or (kind=="JointInstance" and self.ClassName=="Motor6D") end
function methods:GetAttribute(key) return self.Attributes[key] end
function methods:SetAttribute(key,value) self.Attributes[key]=value end
function methods:FindFirstChild(name) for _,v in ipairs(objects) do if not v.Deleted and v.Parent==self and v.Name==name then return v end end end
function methods:FindFirstChildOfClass(kind) for _,v in ipairs(objects) do if not v.Deleted and v.Parent==self and v.ClassName==kind then return v end end end
function methods:GetDescendants() local result={} for _,v in ipairs(objects) do if not v.Deleted then local p=v.Parent while p do if p==self then table.insert(result,v);break end;p=p.Parent end end end return result end
function methods:Destroy() self.Deleted=true;self.Parent=nil end
Instance={new=function(kind,parent) local o=setmetatable({ClassName=kind,Parent=parent,Attributes={}}, {__index=function(self,key) if key=="Position" and self.CFrame then return self.CFrame.Position end;return methods[key] end});table.insert(objects,o);return o end}
local function near(a,b) assert((a-b).Magnitude<.0001) end
local function test(frame)
 objects={}
 local c=Instance.new("Model")
 for _,g in ipairs(geometry) do local p=Instance.new("Part",c);p.Name=g.Name;p.Size=g.Size;p.CFrame=frame*g.CFrame end
 local root=c:FindFirstChild("Body");local hp=Instance.new("Humanoid",c)
 local original={};for _,p in ipairs(c:GetDescendants()) do if p:IsA("Part") then original[p]=p.CFrame end end
 assert(Rig.Prepare(c,root,hp))
 assert(math.abs(hp.HipHeight-.90003)<.0001,"standing feet match author height")
 local count=0
 for _,j in ipairs(c:GetDescendants()) do if j:IsA("Motor6D") then
  count+=1
  local authored=j:GetAttribute("AuthoredC0")
  near((j.Part0.CFrame*authored).Position,(j.Part1.CFrame*j.C1).Position)
  local a=(j.Part0.CFrame*authored).RightVector;local b=(j.Part1.CFrame*j.C1).RightVector;near(a,b)
 end end
 assert(count==11)
 for p,cf in pairs(original) do near(p.CFrame.Position,cf.Position) end
 local left,right=c:FindFirstChild("LeftLowerLeg"),c:FindFirstChild("RightLowerLeg")
 local delta=root.CFrame:VectorToObjectSpace(right.CFrame.Position-left.CFrame.Position)
 assert(math.abs(delta.X-.26019287)<.00001,"authored leg gap preserved")
 assert(root.Transparency==1 and root.RootPriority==127)
 assert(left.Massless and not left.CanCollide and not left.CanQuery)
 hp.HipHeight=0;assert(Rig.Prepare(c,root,hp));assert(hp.HipHeight>.9)
 assert(#c:GetDescendants()==25,"second preparation adds no duplicate joints or animators")
 -- Solve the whole standing chain, not merely individual neutral joints.
 local posed={[root]=root.CFrame}
 for pass=1,12 do
  for _,j in ipairs(c:GetDescendants()) do
   if j:IsA("Motor6D") and posed[j.Part0] and not posed[j.Part1] then
    posed[j.Part1]=posed[j.Part0]*j.C0*j.C1:Inverse()
   end
  end
 end
 for _,side in ipairs({"Left","Right"}) do
  local arm=c:FindFirstChild(side.."UpperArm")
  local forearm=c:FindFirstChild(side.."LowerArm")
  local a=root.CFrame:ToObjectSpace(posed[arm])
  local b=root.CFrame:ToObjectSpace(posed[forearm])
  -- A hanging arm keeps its thickness, lies outside the chest and extends down.
  local width=math.abs(a.RightVector.X)*arm.Size.X+math.abs(a.UpVector.X)*arm.Size.Y
  assert(math.abs(width-.2)<.0001,"arm thickness survives standing rotation")
  assert(math.abs(a.Position.X)-width/2>.2,"standing shoulder must clear torso")
  assert(b.Position.Y<a.Position.Y-.4,"forearm extends from elbow, not into upper arm")
  assert(math.abs(a.Position.X-b.Position.X)<.03,"idle arm sections stay aligned")
 end
 local neutral={Left=Vector3.new(-.1,0,0),Right=Vector3.new(.1,0,0)}
 local feet,targets=Foot.Step(nil,neutral,Vector3.zero,.03,false,.9)
 feet.Next="Left"
 local planted=targets.Right
 neutral={Left=neutral.Left+Vector3.new(0,0,-.2),Right=neutral.Right+Vector3.new(0,0,-.2)}
 feet,targets=Foot.Step(feet,neutral,Vector3.new(0,0,-1),.03,false,.9)
 near(targets.Right,planted)
 assert(targets.Left.Y>0,"swing foot lifts while support foot stays in world")
 for step=1,20 do feet,targets=Foot.Step(feet,neutral,Vector3.zero,.03,false,.9) end
 assert(targets.Left.Y==0 and targets.Right.Y==0,"stopping settles both feet")
 local walkAngle,walkHz=Pose.Gait(8,false)
 local runAngle,runHz=Pose.Gait(8,true)
 assert(walkHz<=1.05 and runHz>walkHz and walkAngle<runAngle*.5,"walking is capped and visibly gentler than running")
 local _,idleHz=Pose.Gait(0,false);assert(idleHz==0)
 local upper=Vector3.new(-.4,0,0);local lower=Vector3.new(-.5,0,0)
 for _,target in ipairs({Vector3.new(.1,-.4,-.4),Vector3.new(0,-2,0),Vector3.zero}) do
  local s,e=Pose.Arm(upper,lower,target,Vector3.new(-1,-1,.2))
  local endpoint=s:VectorToWorldSpace(upper)+(s*e):VectorToWorldSpace(lower)
  local d=math.clamp(target.Magnitude,.1001,.8999)
  assert(math.abs(endpoint.Magnitude-d)<.0001,"IK preserves lengths and clamps reach")
 end
end
-- Translate and rotate the entire authored model: joint placement is root-local.
test(CFrame.identity)
test(CFrame.new(-400,20,60)*CFrame.Angles(0,1.3,0))
objects={};local legacy=Instance.new("Model");local hp=Instance.new("Humanoid",legacy)
assert(not Rig.Prepare(legacy,Instance.new("Part",legacy),hp))
assert(#legacy:GetDescendants()==2,"legacy/incomplete model is untouched")
print("PASS: actual model, 11 joints, authored orientations/gap, height, repeated prepare, rotated origin, IK and legacy fallback")
'''
source+='\n'+(root/'tests/character_animation.fixture.luau').read_text()
controller=(root/'src/shared/CharacterAnimationDriver.luau').read_text()
import re
controller=re.sub(r'local (Players|RunService|Shared|Pose|Foot|Punch|Items|Interact|Motion|HandPose|CarryPose)\s*=.*\n','',controller)
controller=controller.replace('return Driver','Driver.Start(Players.LocalPlayer,false)')
source+='\nlocal CarryPose='+module('src/shared/CarryPose.luau')+'\nlocal HandPose={Apply=function() end}\nlocal Motion={Cancel=function() end}\nlocal Interact='+module('src/shared/InteractionPose.luau').replace('local IK=require(script.Parent.CharacterPose)','local IK=Pose')+'\n'+controller+'\n'+(root/'tests/character_animation_cases.fixture.luau').read_text()
source+='\n'+(root/'tests/equipment_pose_cases.fixture.luau').read_text()
service=(root/'src/server/Services/EquipmentVisuals.luau').read_text()
service=re.sub(r'local (ServerStorage|ReplicatedStorage|Items) = [^\n]+\n','',service)
source+='\nfunction methods:FindFirstChildWhichIsA(kind,recurse) for _,part in ipairs(recurse and self:GetDescendants() or self:GetChildren()) do if part:IsA(kind) then return part end end end\ndo\nlocal ServerStorage=serverStorage\nlocal Items='+module('src/shared/ItemConfig.luau')+'\nlocal Visuals=(function()\n'+service+'\nend)()\n'
source+='\nlocal StoragePose='+module('src/shared/HandActionPose.luau').replace('local IK=require(script.Parent.CharacterPose)','local IK=Pose')+'\nlocal Holsters='+module('src/server/Services/HolsterVisuals.luau').replace('require(game:GetService("ReplicatedStorage").Shared.HandActionPose)','StoragePose')
source+=r'''
for _,id in ipairs({"Pistol9mm","PipePistol9mm","Rifle223","IronAxe","IronShovel","IronKnife"}) do
 Visuals.Apply(c,id)
 local held=c:FindFirstChild("HeldItem")
 local localPose=root.CFrame:ToObjectSpace(held.CFrame)
 if id:find("Pistol") then
  assert(math.abs(localPose.Position.X)<.0001 and localPose.Position.Z<-.76,"actual pistol equipment is forward with extended arms")
 elseif id=="Rifle223" then
  assert(math.abs(localPose.Position.Z+.2575)<.0001 and math.abs(localPose.Position.X-.24)<.0001,"rifle keeps forward distance while staying inward toward chest")
 end
 local grip=held:FindFirstChild("_HandGrip",true)
 assert(grip and grip.Parent==held,"moving grip follows the weapon part, even without Model.PrimaryPart")
 local point=(held.CFrame*grip.CFrame).Position
 near(point,held.CFrame.Position)
end
print("PASS: actual equipment positions for both pistols, closer rifle grip, knife/axe/shovel and movable grip")
for _,entry in ipairs({{"PrimaryWeapon","Rifle223"},{"SecondaryWeapon","Pistol9mm"}}) do
 local slot,id=entry[1],entry[2]
 assert(Holsters.Apply(c,slot,id,Visuals.Template))
 local model=c:FindFirstChild("Holstered"..slot);local part=model:FindFirstChildWhichIsA("BasePart",true)
 assert(part and not part.Anchored and part.Massless and not part.CanCollide and not part.CanTouch and not part.CanQuery)
 near(part.CFrame.Position,StoragePose.StorageFrame(c,root,slot).Position)
 local weld=part:FindFirstChild("HolsterWeld");assert(weld and weld.Part1==part and weld.Part0~=root)
 assert(Holsters.Apply(c,slot,id,Visuals.Template) and c:FindFirstChild("Holstered"..slot)==model,"refresh does not clone another visible weapon")
 assert(Holsters.Apply(c,slot,nil,Visuals.Template) and not c:FindFirstChild("Holstered"..slot))
end
print("PASS: holstered weapon template pivots, torso anchors, massless non-query parts, idempotence and removal")
end
'''
with tempfile.TemporaryDirectory() as directory:
 path=Path(directory)/'rig.luau';path.write_text(source)
 subprocess.run([sys.argv[1] if len(sys.argv)>1 else 'luau',str(path)],check=True)
