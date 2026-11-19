"""Exercise the actual curb step-up controller with blocked/clear probe paths."""
from pathlib import Path
import subprocess,sys,tempfile
root=Path(__file__).resolve().parents[1]
mock=r"""
workspace={}
local callback
local part={Name="Curb",GetAttribute=function(_,key) return key=="Road" and true or nil end}
local root={Size=Vector3.new(.4,.6,.3),CFrame=CFrame.new(0,1,0),AssemblyLinearVelocity=Vector3.new(0,0,-2)}
local move=Vector3.new(0,0,-1)
local hp={Health=100,HipHeight=.7,FloorMaterial="Ground",MoveDirection=move,WalkSpeed=2}
local slid
function hp:Move(value) slid=value end
local character={GetAttribute=function() return nil end,FindFirstChild=function(_,name) return name=="HumanoidRootPart" and root end,FindFirstChildOfClass=function() return hp end}
local player={Character=character}
game={GetService=function(_,name)
 if name=="Players" then return {LocalPlayer=player} end
 return {PreSimulation={Connect=function(_,fn) callback=fn end}}
end}
Enum={RaycastFilterType={Exclude=1},Material={Air="Air"}}
RaycastParams={new=function() return {} end}
local rise=.2
local blocked=false
local casts=0
function workspace:Blockcast(frame,size,direction,params)
 casts+=1
 if casts==1 or blocked then return {Instance=part,Normal=Vector3.new(0,0,1)} end
 return nil
end
function workspace:Raycast() return {Instance=part,Position=Vector3.new(0,rise,-.3),Normal=Vector3.yAxis} end
"""
cases=r"""
local function reset()
 root.CFrame=CFrame.new(0,1,0);root.Position=root.CFrame.Position
 root.AssemblyLinearVelocity=Vector3.new(0,0,-2)
 hp.MoveDirection=move;hp.Sit=false;hp.FloorMaterial="Ground";root.Anchored=false
 casts=0;slid=nil;blocked=false;rise=.2
end
reset();callback(1/60)
assert(root.CFrame.Position.Y>1.2 and not slid,"low road curb steps straight forward")
reset();move=Vector3.new(1,0,0);hp.MoveDirection=move;callback(1/60)
assert(root.CFrame.Position.Y>1.2,"curb step works sideways too")
reset();rise=.5;callback(1/60)
assert(root.CFrame.Position.Y==1 and slid,"high obstacles remain blocking")
reset();blocked=true;callback(1/60)
assert(root.CFrame.Position.Y==1 and slid,"ceiling or raised obstruction prevents step")
reset();part.GetAttribute=function() return nil end;callback(1/60)
assert(root.CFrame.Position.Y==1 and slid,"furniture is never climbed")
part.GetAttribute=function(_,key) return key=="Road" and true or nil end
reset();hp.Sit=true;callback(1/60);assert(casts==0,"seated players are untouched")
reset();hp.FloorMaterial="Air";callback(1/60);assert(casts==0,"airborne players are untouched")
print("PASS: straight/sideways curb steps, height limit, clearance, furniture exclusion, seated and airborne guards")
"""
source=(root/'tests/rig_math.fixture.luau').read_text()+'\n'+mock+'\n'
# The fixture exposes Rotation through matrix subtraction, while Roblox has .Rotation.
controller=(root/'src/client/GroundMovement.client.luau').read_text().replace('root.CFrame.Rotation','(root.CFrame-root.CFrame.Position)')
source+='\n(function()\n'+controller+'\nend)()\n'+cases
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'ground.luau';p.write_text(source);subprocess.run([sys.argv[1],str(p)],check=True)
