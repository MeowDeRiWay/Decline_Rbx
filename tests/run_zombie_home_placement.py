"""Actual placement search yields every eight attempts and aborts when players leave."""
from pathlib import Path
import re,subprocess,sys,tempfile
root=Path(__file__).resolve().parents[1]
source=(root/'src/server/Services/ZombieHomeService.luau').read_text()
source=re.sub(r'local (Area|Rules|HomeRules)\s*=\s*require[^\n]+\n','',source)
setup='''
local Random={new=function() return {NextNumber=function(_,minimum) return minimum end} end}
function methods:GetPropertyChangedSignal(key) return event() end
local baseNew=Instance.new
function Instance.new(class) local o=baseNew(class);o.DescendantAdded=event();o.DescendantRemoving=event();return o end
workspace.DescendantAdded=event();workspace.DescendantRemoving=event()
local original=cfmeta.__index
function cfmeta.__index(t,k)
 if k=="PointToObjectSpace" then return function(self,v) return v-self.Position end end
 if k=="PointToWorldSpace" then return function(self,v) return v+self.Position end end
 return original(t,k)
end
local OverlapParams={new=function() return {} end}
Enum.RaycastFilterType.Include=2
local home=make("Model","FloorMarker",workspace,{Zombie_home=true})
home.Size=Vector3.new(20,1,20)
local floor=make("Part","Floor",home);floor.Size=home.Size
local sources=make("Folder","Creatures",ServerStorage)
local zombie=make("Model","Zombie",sources)
make("Part","HumanoidRootPart",zombie);make("Part","Head",zombie)
local hp=make("Humanoid","Humanoid",zombie);hp.MaxHealth=20;hp.Health=20
local rays=0
function workspace:Raycast() rays+=1;return nil end
a:LoadCharacterAsync();a.Character.HumanoidRootPart.Position=Vector3.new(30,1,0)
'''
cases='''
local subject={Root=a.Character.HumanoidRootPart,Humanoid=a.Character.Humanoid}
subject.Root.Position=Vector3.new(0,1,0)
assert(Area.Occupied(home,{floor},{subject}),"cached surfaces/subjects preserve occupancy")
subject.Root.Position=Vector3.new(0,3,0)
assert(not Area.Occupied(home,{floor},{subject}),"different floor height does not occupy marker")
subject.Root.Position=Vector3.new(30,1,0)
Service.Start()
clock=1001
local co=coroutine.create(function() Service.Step(clock) end)
local before=0;local frames=0
repeat
 local ok,err=coroutine.resume(co);assert(ok,err)
 assert(rays-before<=8,"placement physics must yield after eight candidates")
 before=rays;frames+=1
until coroutine.status(co)=="dead"
assert(rays==40 and frames>=5,"full placement search retained across frames")
clock=1002;rays=0
co=coroutine.create(function() Service.Step(clock) end)
local ok,err=coroutine.resume(co);assert(ok,err);assert(rays==8)
subject.Root.Position=Vector3.new(10000,1,0)
repeat local ok,err=coroutine.resume(co);assert(ok,err) until coroutine.status(co)=="dead"
assert(rays==8,"sleeping district cancels in-flight placement before further physics")
print("PASS: cached occupancy/altitude, full 40-candidate placement, eight attempts per frame, immediate cancellation after player leaves")
'''
parts=[(root/'tests/fixtures/town_mock.luau').read_text(),setup]
for name,path in [('HomeRules','src/shared/ZombieHomeRules.luau'),('Rules','src/shared/ResourceRules.luau'),('Area','src/server/Services/AreaService.luau')]:parts.append('local '+name+'=(function()\n'+(root/path).read_text()+'\nend)()')
parts+=['local Service=(function()\n'+source+'\nend)()',cases]
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'placement.luau';p.write_text('\n'.join(parts));subprocess.run([sys.argv[1],str(p)],check=True)
