from pathlib import Path
import re,subprocess,sys,tempfile
root=Path(__file__).resolve().parents[1]
s=(root/'src/client/ZombieFootsteps.client.luau').read_text();s=re.sub(r'local Config=require[^\n]+\n','',s)
mock='''
local function signal() return {Connect=function(self,fn) self.fire=fn end} end
local heartbeat=signal()
local copies={}
local source={SoundId="test"}
function source:GetAttribute() end
function source:IsA(c) return c=="Sound" end
function source:Clone()
 local copy={Playing=false,Volume=.4}
 function copy:Play() self.Playing=true end
 function copy:Stop() self.Playing=false end
 function copy:Destroy() self.Destroyed=true;self.Parent=nil end
 table.insert(copies,copy);return copy
end
local zombieRoot={Position=Vector3.new(2,0,0)}
local hp={Health=30}
local zombie={Name="Zombie",Parent=true,Mode="Active"}
function zombie:IsA(c) return c=="Model" end
function zombie:IsDescendantOf() return self.Parent end
function zombie:GetAttribute(k) return k=="ActivityMode" and self.Mode or k=="MoveSpeed" and 2 end
function zombie:FindFirstChild(k) return k=="HumanoidRootPart" and zombieRoot end
function zombie:FindFirstChildOfClass() return hp end
local workspace={GetDescendants=function() return {zombie} end,DescendantAdded=signal()}
local character={FindFirstChild=function() return {Position=Vector3.zero} end}
local player={Character=character,GetAttribute=function() return 1 end}
local Players={LocalPlayer=player}
local storage={FindFirstChild=function() return {FindFirstChild=function() return source end} end}
local Config={FootstepMaxDistance=12,FootstepMinDistance=2}
local Enum={RollOffMode={InverseTapered=1}}
local game={GetService=function(_,k) return ({Players=Players,ReplicatedStorage=storage,RunService={Heartbeat=heartbeat}})[k] end}
'''
cases='''
heartbeat.fire(.1);assert(#copies==0,"stationary zombie has no sound")
zombieRoot.Position=Vector3.new(2.1,0,0);heartbeat.fire(.1)
assert(#copies==1 and copies[1].Playing and copies[1].Looped and copies[1].Parent==zombieRoot)
assert(copies[1].Volume==.4 and copies[1].RollOffMaxDistance==12)
heartbeat.fire(.1);assert(not copies[1].Playing,"standing stops loop")
zombieRoot.Position=Vector3.new(2.2,0,0);heartbeat.fire(.1);assert(copies[1].Playing and #copies==1,"reuse same sound")
zombie.Mode="Minimal";zombieRoot.Position=Vector3.new(100,0,0);heartbeat.fire(.1);assert(not copies[1].Playing,"sleep teleport silent")
zombie.Mode="Active";zombieRoot.Position=Vector3.new(2,0,0);heartbeat.fire(.1);assert(not copies[1].Playing,"active teleport silent")
zombieRoot.Position=Vector3.new(2.1,0,0);hp.Health=0;heartbeat.fire(.1);assert(not copies[1].Playing,"dead zombie silent")
zombie.Parent=false;heartbeat.fire(.1);assert(copies[1].Destroyed,"removed model cleanup")
print("PASS: actual anchored zombie walk loop, authored volume/range, reuse, idle/dead/teleport suppression and cleanup")
'''
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'test.luau';p.write_text((root/'tests/city_geometry.fixture.luau').read_text()+'\n'+mock+s+'\n'+cases);subprocess.run([sys.argv[1],str(p)],check=True)
