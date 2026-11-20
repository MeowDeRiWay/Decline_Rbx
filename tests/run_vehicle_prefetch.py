"""Exercise shared look-ahead for scripted anchored cars and ordinary walkers."""
from pathlib import Path
import subprocess,sys,tempfile
r=Path(__file__).resolve().parents[1]
source=(r/'tests/rig_math.fixture.luau').read_text()
source+='\nlocal Rules=(function()\n'+(r/'src/shared/WorldPrefetchRules.luau').read_text()+'\nend)()\n'
source+=r"""
workspace={}
local car={PrimaryPart={CFrame=CFrame.new()}}
local speed=40
function car:GetAttribute(name) if name=="Vehicle" then return true elseif name=="Speed" then return speed end end
car.Parent=workspace
local mount={Parent=car,GetAttribute=function() return nil end}
local seat={Parent=mount}
local root={AssemblyLinearVelocity=Vector3.zero}
local humanoid={SeatPart=seat,MoveDirection=Vector3.zero,WalkSpeed=0}
assert((Rules.Velocity(root,humanoid)-Vector3.new(0,0,-40)).Magnitude<.001,"anchored scripted car uses replicated speed")
speed=-4
assert((Rules.Velocity(root,humanoid)-Vector3.new(0,0,4)).Magnitude<.001,"reverse prefetch follows actual travel")
car.PrimaryPart.CFrame=CFrame.Angles(0,math.pi/2,0);speed=40
assert((Rules.Velocity(root,humanoid)-car.PrimaryPart.CFrame.LookVector*40).Magnitude<.001,"turns update lookahead direction")
speed=0/0
assert(Rules.Velocity(root,humanoid).Magnitude==0,"invalid speed cannot poison positions")
humanoid.SeatPart=nil;humanoid.MoveDirection=Vector3.new(0,0,-1);humanoid.WalkSpeed=14
assert(Rules.Velocity(root,humanoid).Magnitude==14,"walking fallback still works")
root.AssemblyLinearVelocity=Vector3.new(2,100,0)
assert((Rules.Velocity(root,humanoid)-Vector3.new(2,0,0)).Magnitude==0,"ordinary physics velocity stays horizontal")
local points={};Rules.Append(points,Vector3.zero,Vector3.new(0,0,-40),{PrefetchSeconds=8,MaxPrefetchDistance=160})
assert(#points==5 and points[#points].Z==-160,"lookahead remains bounded and samples intermediate street cells")
print("PASS: anchored cars, reverse, turning, invalid inputs, walking, horizontal physics and bounded lookahead")
"""
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'prefetch.luau';p.write_text(source);subprocess.run([sys.argv[1],str(p)],check=True)
