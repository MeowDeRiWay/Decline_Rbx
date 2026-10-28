"""Exercise actual shared cursor queries and change-only UI writes."""
from pathlib import Path
import subprocess,sys,tempfile
root=Path(__file__).resolve().parents[1]
s=(root/'src/client/CursorQuery.luau').read_text().replace('local View=require(script.Parent.EventVisibility)','')
mock='''
function vm.__mul(a,b) return Vector3.new(a.X*b,a.Y*b,a.Z*b) end
local render
local mouse={X=50,Y=50}
local inputCalls=0
local camera={ViewportSize={X=100,Y=100},ViewportPointToRay=function() return {Origin=Vector3.zero,Direction=Vector3.new(0,0,-1)} end}
local player={Character={}}
local visible={Parent=true,GetAttribute=function() return true end}
local hidden={Parent=true,GetAttribute=function() return false end}
local View={Targets={[visible]=true,[hidden]=true,[player.Character]=true}}
local worldHit,creatureHit={Instance={}},{Instance={}}
local worldCalls,creatureCalls=0,0
local excluded
workspace={CurrentCamera=camera,Raycast=function(_,_,_,params)
 if params.FilterType==1 then
  worldCalls+=1;excluded=params.FilterDescendantsInstances;return worldHit
 end
 creatureCalls+=1
 assert(#params.FilterDescendantsInstances==1 and params.FilterDescendantsInstances[1]==visible,"hidden and own models excluded")
 return creatureHit
end}
Enum={RaycastFilterType={Exclude=1,Include=2},RenderPriority={Last={Value=10}}}
RaycastParams={new=function() return {} end}
local warnings=0;local function warn() warnings+=1 end
local debug={profilebegin=function() end,profileend=function() end,traceback=function(message) return message end}
game={GetService=function(_,name)
 return ({Players={LocalPlayer=player},RunService={BindToRenderStep=function(_,_,priority,fn) assert(priority==13);render=fn end},UserInputService={GetMouseLocation=function() inputCalls+=1;return mouse end}})[name]
end}
'''
cases='''
local order={}
Query.Subscribe("Items",1,function() table.insert(order,1);local q=Query.Get();assert(not q or q.Hit==worldHit) end)
Query.Subscribe("Doors",2,function() table.insert(order,2);Query.Get() end)
Query.Subscribe("Town",3,function() table.insert(order,3);Query.Get() end)
local remove=Query.Subscribe("Creature",4,function() table.insert(order,4);Query.CreatureHit();Query.CreatureHit() end)
for _=1,60 do render(1/60) end
assert(worldCalls==30 and creatureCalls==30 and inputCalls==30,"three world consumers share one ray; creature query cached")
for i,v in ipairs(order) do assert(v==(i-1)%4+1,"stable consumer ordering") end
assert(excluded[1]==player.Character)
player.Character={};render(1/30);assert(excluded[1]==player.Character,"respawn updates excluded character")
mouse={X=-1,Y=50};local before=worldCalls;render(1/30);assert(worldCalls==before,"outside viewport casts nothing")
mouse={X=50,Y=50};workspace.CurrentCamera=nil;render(1/30);assert(worldCalls==before)
workspace.CurrentCamera=camera;remove()
local creatures=creatureCalls;render(1/30);assert(creatureCalls==creatures,"unsubscribed consumer does not cast")
Query.Subscribe("Broken",0,function() error("expected test error") end)
render(1/30);assert(warnings==1 and worldCalls==before+2,"consumer failure cannot block other hovers")
local writes=0;local values={Text="Ready"}
local object=setmetatable({},{__index=values,__newindex=function(_,k,v) writes+=1;values[k]=v end})
for _=1,100 do UI.Set(object,"Text","Ready") end
assert(writes==0)
UI.Set(object,"Text","Done");UI.Set(object,"Text","Done");assert(writes==1)
print("PASS: shared30Hz world ray, separate visible-creature ray, ordering, respawn, viewport guards, unsubscribe, failure isolation and change-only UI")
'''
code=(root/'tests/city_geometry.fixture.luau').read_text()+'\n'+mock+'\nlocal Query=(function()\n'+s+'\nend)()\nlocal UI=(function()\n'+(root/'src/client/UIUpdates.luau').read_text().replace('local Locale=require(script.Parent.LocaleController)', 'local Locale={Set=function(o,k,v) if o[k]~=v then o[k]=v end end}')+'\nend)()\n'+cases
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'cursor.luau';p.write_text(code);subprocess.run([sys.argv[1],str(p)],check=True)
