"""Exercise the actual small-rig path planner against narrow doorway geometry."""
from pathlib import Path
import subprocess
import sys
import tempfile
root=Path(__file__).resolve().parents[1]
mock=(root/'tests/city_geometry.fixture.luau').read_text()
source=(root/'src/server/Services/ZombieNavigation.luau').read_text()
fixture='''
local RaycastParams={new=function() return {} end}
local OverlapParams={new=function() return {} end}
local Enum={RaycastFilterType={Exclude=1,Include=2}}
local workspace={}
local opening=1.04
local groundY=0
local function intersects(position,size)
 return math.abs(position.Z)<.08+size.Z/2 and math.abs(position.X)+size.X/2>opening/2+.000001
end
function workspace:GetDescendants() return {} end
function workspace:Raycast(origin,delta)
 if origin.Y < groundY or origin.Y+delta.Y > groundY then return nil end
 return {Position=Vector3.new(origin.X,groundY,origin.Z),Normal=Vector3.new(0,1,0)}
end
function workspace:GetPartBoundsInBox(frame,size)
 return intersects(frame.Position,size) and {{}} or {}
end
function workspace:Blockcast(frame,size,delta)
 for i=0,40 do
  local t=i/40
  local point=frame.Position+Vector3.new(delta.X*t,delta.Y*t,delta.Z*t)
  if intersects(point,size) then return {Distance=0} end
 end
 return nil
end
local model={FindFirstChild=function() return nil end}
local body={Position=Vector3.new(.27,.52,-2),Size=Vector3.new(1,1,1)}
'''
cases='''
local nav=Navigation.New(model,body)
assert(nav.Cell<=.35,"doorway grid must be finer than body width")
local goal=Vector3.new(.27,.52,2)
assert(not nav:Clear(body.Position,goal,{}),"off-center direct route must hit jamb")
assert(nav:Plan(goal),"body must find and center through opening that fits real width")
local previous=body.Position
for _,point in ipairs(nav.Route) do assert(nav:Clear(previous,point,{})); previous=point end
opening=.8
assert(not nav:Plan(goal),"opening narrower than body must remain blocked")
opening=1.04
body.Position=Vector3.new(0,.52,-2)
assert(nav:Clear(body.Position,Vector3.new(0,.52,2),{}),"centered body must fit without inflated diagonal radius")
groundY=.3
assert(nav:Ground(body.Position,{}),"small floor threshold is a valid step")
groundY=1.3
assert(not nav:Ground(body.Position,{}),"door lintel must not be treated as floor")
print("PASS: real body-sized doorway clearance, fine-grid centering, collision-checked route segments, undersized door rejection")
'''
with tempfile.TemporaryDirectory(prefix='decline-door-') as directory:
    path=Path(directory)/'test.luau'
    path.write_text(mock+'\n'+fixture+'\nlocal Navigation=(function()\n'+source+'\nend)()\n'+cases)
    subprocess.run([sys.argv[1] if len(sys.argv)>1 else 'luau',str(path)],check=True)
