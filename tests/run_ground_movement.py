"""Exercise anti-step clearance, wall sliding and incapacitation with the actual controller."""
from pathlib import Path
import subprocess,sys,tempfile
root=Path(__file__).resolve().parents[1]
mock='''
local callback,obstacle,casts,lastSize,lastFrame
local c={attrs={}}
local root={Size=Vector3.new(.4,.7,.315),Position=Vector3.new(0,1,0),CFrame=CFrame.new(),AssemblyLinearVelocity=Vector3.new(2,-1,1)}
root.CFrame.Rotation=CFrame.new()
local hp={Health=100,WalkSpeed=2,HipHeight=.65,FloorMaterial="Grass",MoveDirection=Vector3.xAxis}
function hp:Move(value) self.MoveDirection=value end
function c:FindFirstChild() return root end
function c:FindFirstChildOfClass() return hp end
function c:GetAttribute(k) return self.attrs[k] end
local Players={LocalPlayer={Character=c}}
game={GetService=function(_,name) if name=="Players" then return Players else return {PreSimulation={Connect=function(_,fn) callback=fn end}} end end}
Enum={Material={Air="Air"},RaycastFilterType={Exclude=1}}
RaycastParams={new=function() return {} end}
local workspace={}
function workspace:Blockcast(frame,size,direction,params)
 casts=(casts or 0)+1;lastFrame=frame;lastSize=size
 assert(params.RespectCanCollide and params.FilterDescendantsInstances[1]==c)
 if not obstacle or obstacle.Top<=frame.Position.Y-size.Y/2 then return nil end
 if obstacle.Left>frame.Position.X+size.X/2+direction.X then return nil end
 return {Normal=obstacle.Normal or -Vector3.xAxis}
end
'''
cases='''
obstacle={Top=.6,Left=.24};callback(1/60)
assert(hp.MoveDirection.Magnitude==0 and root.AssemblyLinearVelocity.X==0 and root.AssemblyLinearVelocity.Z==1 and root.AssemblyLinearVelocity.Y==-1,"cabinet blocks climbing, retains wall slide and gravity")
assert(math.abs(lastFrame.Position.Y-lastSize.Y/2-.15)<1e-9,"sweep reaches feet plus shallow-step clearance")
hp.MoveDirection=Vector3.xAxis;obstacle.Top=.1;callback(1/60);assert(hp.MoveDirection.X==1,"shallow steps remain traversable")
obstacle.Top=.6;obstacle.Normal=Vector3.new(-.1,.9,0);callback(1/60);assert(hp.MoveDirection.X==1,"walkable slopes remain traversable")
obstacle.Normal=nil;obstacle.Left=10;callback(1/60);assert(hp.MoveDirection.X==1,"distant furniture does not block")
for _,state in ipairs({"air","knockout","dead","sit","platform","anchored"}) do
 hp.MoveDirection=Vector3.xAxis;hp.Health=state=="dead" and 0 or 100;hp.Sit=state=="sit";hp.PlatformStand=state=="platform";root.Anchored=state=="anchored"
 hp.FloorMaterial=state=="air" and "Air" or "Grass";c.attrs.Knockout=state=="knockout"
 local before=casts;callback(1/60);assert(casts==before and hp.MoveDirection.X==1,state)
end
print("PASS: foot-level furniture barrier, shallow steps/slopes, wall sliding/gravity, distance and KO/bed/air guards")
'''
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'movement.luau';p.write_text((root/'tests/rig_math.fixture.luau').read_text()+mock+(root/'src/client/GroundMovement.client.luau').read_text()+cases)
 subprocess.run([sys.argv[1],str(p)],check=True)
