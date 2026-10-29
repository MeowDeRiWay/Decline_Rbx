"""Test production rig against measurements of the actual uploaded model."""
from pathlib import Path
import subprocess,sys,tempfile
root=Path(__file__).resolve().parents[1]
def module(path):return '(function()\n'+(root/path).read_text()+'\nend)()'
source=(root/'tests/rig_math.fixture.luau').read_text()
source+='\nlocal Rig='+module('src/shared/CharacterRig.luau')
source+='\nlocal Pose='+module('src/shared/CharacterPose.luau')
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
controller=(root/'src/client/CharacterAnimation.client.luau').read_text()
import re
controller=re.sub(r'local (Players|RunService|Shared|Pose|Items)\s*=.*\n','',controller)
source+='\n'+controller+'\n'+(root/'tests/character_animation_cases.fixture.luau').read_text()
with tempfile.TemporaryDirectory() as directory:
 path=Path(directory)/'rig.luau';path.write_text(source)
 subprocess.run([sys.argv[1] if len(sys.argv)>1 else 'luau',str(path)],check=True)
