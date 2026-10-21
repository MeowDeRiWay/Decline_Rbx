"""Run the actual server activity dispatcher with a clock/physics mock, not Studio."""
from pathlib import Path
import subprocess,sys,tempfile
root=Path(__file__).resolve().parents[1]
service=(root/'src/server/Services/ZombieActivity.luau').read_text()
for variable,module in [('Config','GameConfig'),('Progression','ProgressionRules'),('Rules','ZombieActivityRules')]:
 service=service.replace(f'local {variable}=require(ReplicatedStorage.Shared.{module})','')
mock='''
function cm:Inverse() local rotation=cf(Vector3.zero,-self.yaw);return cf(rotation:VectorToWorldSpace(-self.Position),-self.yaw) end
local time=0
os={clock=function() return time end}
local function signal() return {Connect=function(self,fn) self.fire=fn end} end
local heartbeat=signal()
local rootPlayer={Position=Vector3.new(0,1,0)}
local hpPlayer={Health=100}
local character={FindFirstChild=function() return rootPlayer end,FindFirstChildOfClass=function() return hpPlayer end,GetAttribute=function() end}
local player={Character=character,GetAttribute=function() return 0 end}
local players={PlayerRemoving=signal(),GetPlayers=function() return {player} end}
local replicated={}
local reporter
Instance={new=function() reporter={OnServerEvent=signal()};return reporter end}
Random={new=function() return {NextNumber=function(_,a,b) return (a+b)/2 end} end}
local serviceMap={Players=players,ReplicatedStorage=replicated,RunService={Heartbeat=heartbeat}}
game={GetService=function(_,key) return serviceMap[key] end}
local worker
local waits=0
task={spawn=function(fn) worker=coroutine.create(fn);assert(coroutine.resume(worker)) end,wait=function() waits+=1;coroutine.yield() end}
local groundCalls,overlapCalls,pivots=0,0,0
local blocked=false
workspace={Raycast=function(_,origin) groundCalls+=1;return {Position=Vector3.new(origin.X,0,origin.Z),Normal=Vector3.new(0,1,0)} end,
 GetPartBoundsInBox=function() overlapCalls+=1;return blocked and {true} or {} end}
Enum={RaycastFilterType={Exclude=1,Include=2}}
RaycastParams={new=function() return {} end};OverlapParams={new=function() return {} end}
local function actor(x)
 local root={Position=Vector3.new(x,1.02,0),Size=Vector3.new(1,2,1),CFrame=CFrame.new(Vector3.new(x,1.02,0))}
 local hp={Health=20}
 local model={root=root,attributes={},Parent=workspace}
 function model:IsDescendantOf() return self.Parent~=nil end
 function model:FindFirstChildOfClass() return hp end
 function model:FindFirstChild() end
 function model:SetAttribute(key,value) self.attributes[key]=value end
 function model:GetAttribute(key) return self.attributes[key] end
 function model:GetBoundingBox() return root.CFrame,Vector3.new(1,2,1) end
 function model:GetPivot() return root.CFrame end
 function model:PivotTo(frame) pivots+=1;root.CFrame=frame;root.Position=frame.Position end
 return model,root
end
local function tick() local ok,err=coroutine.resume(worker);assert(ok,err) end
'''
cases='''
local active,ar=actor(0)
local minimal,mr=actor(100)
local afk,fr=actor(500)
local steps={0,0,0}
Service.Register(active,ar,function() steps[1]+=1 end)
Service.Register(minimal,mr,function() steps[2]+=1 end)
Service.Register(afk,fr,function() steps[3]+=1 end)
tick()
assert(active.attributes.ActivityMode=="Active" and minimal.attributes.ActivityMode=="Minimal" and afk.attributes.ActivityMode=="AFK")
for i=1,1000 do heartbeat.fire(.016) end
assert(steps[1]==1000 and steps[2]==0 and steps[3]==0,"sleepers never execute AI heartbeat")
assert(groundCalls==0 and overlapCalls==0,"no movement/obstacle checks before teleport deadline")
time=59;tick();assert(pivots==0)
time=60;tick();assert(pivots==1 and groundCalls==1 and overlapCalls==1,"one endpoint check for minimal; AFK does no physics")
time=179;tick();assert(pivots==1)
blocked=true;time=180;tick();assert(pivots==1 and groundCalls==2 and overlapCalls==2,"120-second repeat rejects occupied endpoint")
rootPlayer.Position=Vector3.new(500,1,0);tick();heartbeat.fire(.016)
assert(afk.attributes.ActivityMode=="Active" and steps[3]==1,"nearby player wakes AFK regardless of facing")
assert(active.attributes.ActivityMode=="AFK")
hpPlayer.Health=0;tick();local before=steps[3];heartbeat.fire(.016)
assert(steps[3]==before and afk.attributes.ActivityMode=="AFK","no living observers sleeps all")
afk:SetAttribute("Attention",3)
Service.Alert(afk:GetPivot().Position+Vector3.new(8,0,0),12);assert(afk.attributes.ActivityMode=="AFK","outside hearing does not wake")
Service.Alert(afk:GetPivot().Position+Vector3.new(7,0,0),12);assert(afk.attributes.ActivityMode=="Active","actual noise wakes sleeping AI")
local heardSteps=steps[3];tick();heartbeat.fire(.016);assert(steps[3]==heardSteps+1,"noise wake survives sleep dispatcher")
time+=61;tick();assert(afk.attributes.ActivityMode=="AFK","noise interest expires")
active.Parent=nil;tick()
print("PASS: 1000 dispatcher frames -> zero sleeping AI calls; randomized first deadline, 120-second interval, endpoint-only checks, occupied destination rejected, nearest-player wake, no-player AFK, removed model cleanup")
'''
parts=[(root/'tests/city_geometry.fixture.luau').read_text()]
for variable,module in [('Config','GameConfig'),('Progression','ProgressionRules'),('Rules','ZombieActivityRules')]:
 parts.append(f'local {variable}=(function()\n'+(root/f'src/shared/{module}.luau').read_text()+'\nend)()')
parts += [mock,'local Service=(function()\n'+service+'\nend)()',cases]
with tempfile.TemporaryDirectory() as directory:
 path=Path(directory)/'activity.luau';path.write_text('\n'.join(parts))
 subprocess.run([sys.argv[1] if len(sys.argv)>1 else 'luau',str(path)],check=True)
