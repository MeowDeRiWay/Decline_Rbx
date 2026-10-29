"""Real proximity scheduler with a large far-away city and deterministic time."""
from pathlib import Path
import re,subprocess,sys,tempfile
root=Path(__file__).resolve().parents[1]
s=(root/'src/server/Services/ZombieHomeService.luau').read_text().replace('local WorldActivity=require(script.Parent.WorldActivityService)', 'local WorldActivity={Register=function() end,IsDormant=function() return false end,Ensure=function() end,DormantNPCs=function() return {} end,Raycast=function() return nil end}')
s=re.sub(r'local (Area|Rules|HomeRules|Rig)\s*=\s*require[^\n]+\n','',s)
a=s.index('local function spawn(home,valid)');b=s.index('local function clearBuckets',a)
s=s[:a]+'''local function spawn(home,valid)
 assert(valid());spawned[home]=(spawned[home] or 0)+1
 return true
end
'''+s[b:]
setup='''
local Service
local randomCalls=0
local Random={new=function() return {NextNumber=function(_,minimum) randomCalls+=1;return minimum end} end}
function methods:GetPropertyChangedSignal(key)
 self.properties=self.properties or {};self.properties[key]=self.properties[key] or event();return self.properties[key]
end
local baseNew=Instance.new
function Instance.new(class)
 local object=baseNew(class);object.DescendantAdded=event();object.DescendantRemoving=event();return object
end
workspace.DescendantAdded=event();workspace.DescendantRemoving=event()
local oldIndex=cfmeta.__index
function cfmeta.__index(t,k)
 if k=="PointToObjectSpace" then return function(self,v) return v-self.Position end end
 if k=="LookVector" then return Vector3.new(0,0,-1) end
 return oldIndex(t,k)
end
local scans=0;local originalDesc=workspace.GetDescendants
function workspace:GetDescendants() scans+=1;return originalDesc(self) end
local occupiedCalls,partScans,boxes,spawned={},{},{},{}
local Area={Parts=function(home)
 partScans[home]=(partScans[home] or 0)+1;return home:GetDescendants()
end,Occupied=function(home,parts,subjects)
 occupiedCalls[home]=(occupiedCalls[home] or 0)+1
 assert(parts,"scheduler must reuse cached marker parts")
 if subjects then assert(#subjects==1,"one shared player snapshot per update") end
 return home.Occupied==true
end}
local function homeAt(x)
 local home=make("Model","Home",workspace,{Zombie_home=true})
 home.CFrame=CFrame.new(Vector3.new(x,0,0));home.Size=Vector3.new(20,1,20)
 local part=make("Part","Floor",home)
 function home:GetBoundingBox() boxes[self]=(boxes[self] or 0)+1;return self.CFrame,self.Size end
 return home
end
local near=homeAt(0)
local far={};for i=1,1000 do far[i]=homeAt(10000+i*25) end
a:LoadCharacterAsync();a.Character.HumanoidRootPart.Position=Vector3.new(0,1,0)
local function step(now)
 clock=now
 local co=coroutine.create(function() Service.Step(now) end)
 repeat local ok,err=coroutine.resume(co);assert(ok,err) until coroutine.status(co)=="dead"
end
'''
cases='''
Service.Start()
assert(#loops==1,"one scheduler coroutine, not one per house")
assert(scans==1,"only one startup discovery")
local cached=partScans[far[1]]
for now=1001,1010 do step(now) end
assert((occupiedCalls[near] or 0)>0 and (spawned[near] or 0)>0)
for _,home in ipairs(far) do assert(not occupiedCalls[home] and not spawned[home],"far city must not run occupancy/spawn") end
assert(partScans[far[1]]==cached and boxes[far[1]]==1,"far home geometry not polled")
near.Occupied=true;step(1011);local before=spawned[near]
step(1100);assert(spawned[near]==before,"no spawn inside occupied home")
near.Occupied=false;step(1101);step(1280);assert(spawned[near]==before,"three-minute post-exit lock retained")
step(1281);assert(spawned[near]==before+1)
a.Character.HumanoidRootPart.Position=Vector3.new(10025,1,0)
local beforeNear=occupiedCalls[near];step(1282)
assert(occupiedCalls[near]==beforeNear,"sleep transition does not poll occupancy")
assert(not spawned[far[1]],"wake does not immediately catch up overdue spawns")
step(1283);local total=0;for _,home in ipairs(far) do total+=(spawned[home] or 0) end;assert(total>=1,"newly approached city wakes")
local calls=occupiedCalls[far[1]] or 0
far[1]:SetAttribute("Zombie_home",false);step(1284)
assert((occupiedCalls[far[1]] or 0)==calls,"disabled home is not polled")
local added=homeAt(10025);workspace.DescendantAdded:Fire(added);step(1285);step(1286)
assert((occupiedCalls[added] or 0)>0,"runtime-generated homes wake through events")
local removedCount=occupiedCalls[added];workspace.DescendantRemoving:Fire(added);added.Parent=nil;step(1287)
assert(occupiedCalls[added]==removedCount)
assert(scans==1,"no recurring full-world scans")
print("PASS: 1000 distant homes asleep, one loop, cached geometry, proximity wake, randomized deadlines, 180s occupancy lock, disabled/generated/removed homes")
'''
parts=[(root/'tests/fixtures/town_mock.luau').read_text(),setup]
for name,file in [('HomeRules','ZombieHomeRules'),('Rules','ResourceRules')]:parts.append('local '+name+'=(function()\n'+(root/f'src/shared/{file}.luau').read_text()+'\nend)()')
parts+=['Service=(function()\n'+s+'\nend)()',cases]
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'homes.luau';p.write_text('\n'.join(parts));subprocess.run([sys.argv[1],str(p)],check=True)
