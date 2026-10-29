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
local function event()
 local listeners={}
 return {Connect=function(_,fn) table.insert(listeners,fn);return {Disconnect=function() end} end,
 Fire=function(_,...) for _,fn in ipairs(listeners) do fn(...) end end}
end
local workspace={DescendantAdded=event(),DescendantRemoving=event()}
local scans=0
local opening=1.04
local groundY=0
local function intersects(position,size)
 return math.abs(position.Z)<.08+size.Z/2 and math.abs(position.X)+size.X/2>opening/2+.000001
end
function workspace:GetDescendants() scans+=1;return {} end
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
local rigHeight=0
local model={FindFirstChild=function() return nil end,GetAttribute=function() return rigHeight end}
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
-- A solid window sill blocks the direct route at X=0; the usable door is X=3.
groundY=0
local doorFrame=cf(Vector3.new(3,1.5,0),0)
local door={Name="DoorWay (brick)"}
function door:IsA(class) return class=="Model" end
function door:GetAttribute() return nil end
function door:FindFirstChildWhichIsA() return {} end
function door:GetBoundingBox() return doorFrame,Vector3.new(1.04,.2,.16) end
local attributeSignal,nameSignal=event(),event()
function door:GetAttributeChangedSignal() return attributeSignal end
function door:GetPropertyChangedSignal() return nameSignal end
workspace.DescendantAdded:Fire(door)
function vm.__mul(a,b)
 if type(a)=="number" then a,b=b,a end
 return Vector3.new(a.X*b,a.Y*b,a.Z*b)
end
local previousIndex=cm.__index
function cm.__index(a,key)
 if key=="LookVector" then return a:VectorToWorldSpace(Vector3.new(0,0,-1)) end
 if key=="RightVector" then return a:VectorToWorldSpace(Vector3.new(1,0,0)) end
 return previousIndex(a,key)
end
function workspace:GetPartBoundsInBox(frame,size)
 local p=frame.Position
 return math.abs(p.Z)<.08+size.Z/2 and math.abs(p.X-3)+size.X/2>1.04/2+.000001 and {{}} or {}
end
function workspace:Blockcast(frame,size,delta)
 for index=0,80 do
  local point=frame.Position+delta*(index/80)
  if #self:GetPartBoundsInBox(CFrame.new(point),size)>0 then return {Distance=0} end
 end
 return nil
end
body.Position=Vector3.new(0,.52,-2)
local destination=Vector3.new(0,.52,2)
assert(not nav:Clear(body.Position,destination,{}),"window sill is physically blocking")
assert(nav:Plan(destination),"visible target behind window must be reachable through side door")
local usedDoor=false
local from=body.Position
for _,point in ipairs(nav.Route) do
 if point.X>2.5 then usedDoor=true end
 assert(nav:Clear(from,point,{}),"door detour must never cross the window sill")
 from=point
end
assert(usedDoor,"route must actually go to the door instead of the visible window")
-- The target hugs the exterior window wall: their center is not a valid zombie standing point.
local closeTarget=Vector3.new(0,.52,.3)
function workspace:Raycast(origin,delta)
 if math.abs(delta.Y)<.000001 then
  for index=0,80 do
   local p=origin+delta*(index/80)
   if math.abs(p.Z)<.08 and math.abs(p.X-3)>.52 then return {Instance={}} end
  end
  return nil
 end
 if origin.Y < groundY or origin.Y+delta.Y > groundY then return nil end
 return {Position=Vector3.new(origin.X,groundY,origin.Z),Normal=Vector3.new(0,1,0)}
end
assert(#workspace:GetPartBoundsInBox(CFrame.new(closeTarget),nav:BodySize())>0,"test target must hug wall")
assert(nav:Plan(closeTarget),"target beside wall must produce reachable nearby endpoint")
local endpoint=nav.Route[#nav.Route]
assert(endpoint.Z>.5,"endpoint must stay on player's side of window wall")
assert(not workspace:Raycast(endpoint,closeTarget-endpoint,{}),"endpoint must have no wall separating it from target")
-- A horde must enqueue work without doing physics in the movement callback.
local calls=0
local originalBlockcast=workspace.Blockcast
function workspace:Blockcast(...) calls+=1; return originalBlockcast(self,...) end
local queued={}
for i=1,100 do
 local agent=Navigation.New(model,body)
 assert(agent:Waypoint(closeTarget)==nil)
 assert(agent.Pending,"search should be queued")
 table.insert(queued,agent)
end
assert(calls==0,"Waypoint must never synchronously plan the horde")
local steps=Navigation.Update()
assert(steps<=128,"one global budget, not a budget per zombie")
assert(queued[100].Pending,"horde must not finish in a single frame")
for _,agent in ipairs(queued) do agent:Cancel() end
assert(Navigation.Update()==0,"cancelled searches must not consume planning work")
local hunter=Navigation.New(model,body)
hunter:Waypoint(closeTarget)
assert(hunter.Pending)
local victim={}
local clearGoal=body.Position+Vector3.new(0,0,-1)
assert(hunter:Waypoint(clearGoal,victim),"visible prey in clear corridor must move without waiting for queue")
assert(not hunter.Pending,"direct pursuit cancels stale investigation search")
local agent=Navigation.New(model,body)
agent:Waypoint(closeTarget)
for _=1,10000 do
 Navigation.Update()
 if not agent.Pending then break end
end
assert(not agent.Pending and #agent.Route>0,"cooperative search must eventually produce the same reachable route")
assert(scans==1,"navigation does only one full-world discovery across all direct/cooperative plans")
local list=nav:Parameters()
workspace.DescendantRemoving:Fire(door)
local extra={Name="Wall",Parent={IsA=function() return true end}}
local marker=false
function extra:IsA(class) return class=="Model" end
function extra:GetAttribute() return marker end
local attr,rename=event(),event()
function extra:GetAttributeChangedSignal() return attr end
function extra:GetPropertyChangedSignal() return rename end
workspace.DescendantAdded:Fire(extra)
marker=true;attr:Fire();nav:Parameters()
marker=false;attr:Fire();extra.Name="DoorWay";rename:Fire();nav:Parameters()
workspace.DescendantRemoving:Fire(extra);nav:Parameters()
assert(scans==1,"dynamic doors, renames and removals must not trigger a world rescan")
local bodyModel={IsA=function(_,class) return class=="Model" end}
local human={Parent=bodyModel,IsA=function(_,class) return class=="Humanoid" end}
workspace.DescendantAdded:Fire(human)
local exclusions=nav:Parameters();assert(table.find(exclusions.FilterDescendantsInstances,bodyModel),"new humanoid enters collision exclusion index")
workspace.DescendantRemoving:Fire(human)
exclusions=nav:Parameters();assert(not table.find(exclusions.FilterDescendantsInstances,bodyModel),"removed humanoid leaves collision exclusion index")
groundY=0;rigHeight=.9
local raised=nav:Ground(Vector3.new(0,1.42,-2),{})
assert(raised and math.abs(raised.Y-1.42)<.00001,"articulated zombie ground follows feet, not the torso bottom")
print("PASS: event-driven navigation index, one startup scan, runtime marker/name updates and removals")
print("PASS: wall-hugging target and reachable endpoint on correct side; window-to-side-door detour, collision-safe portal route; real body-sized doorway clearance, fine-grid centering, collision-checked route segments, undersized door rejection")
'''
with tempfile.TemporaryDirectory(prefix='decline-door-') as directory:
    path=Path(directory)/'test.luau'
    path.write_text(mock+'\n'+fixture+'\nlocal Navigation=(function()\n'+source+'\nend)()\n'+cases)
    subprocess.run([sys.argv[1] if len(sys.argv)>1 else 'luau',str(path)],check=True)
