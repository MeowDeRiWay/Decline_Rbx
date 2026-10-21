"""Verify real visibility rejects off-screen creatures before casting, plus viewport ray clipping."""
from pathlib import Path
import subprocess,sys,tempfile
root=Path(__file__).resolve().parents[1]
source=(root/'src/client/CreatureVisibility.client.luau').read_text()
visible=source[source.index('local function visible('):source.index('View.Check=visible')]
rules=(root/'src/shared/VisibilityRules.luau').read_text()
cases='''
assert(Rules.OnScreen(0,0,1,100,100))
assert(Rules.OnScreen(100,100,1,100,100))
for _,p in ipairs({{-1,50,1},{101,50,1},{50,-1,1},{50,101,1},{50,50,-1},{50,50,0}}) do
 assert(not Rules.OnScreen(p[1],p[2],p[3],100,100))
end
local corners={{X=-10,Z=-5},{X=10,Z=-5},{X=10,Z=5},{X=-10,Z=5}}
assert(Rules.ScreenRayDistance(0,0,1,0,corners,100)==10)
assert(Rules.ScreenRayDistance(0,0,-1,0,corners,100)==10)
assert(Rules.ScreenRayDistance(0,0,0,1,corners,100)==5)
assert(Rules.ScreenRayDistance(0,0,0,-1,corners,100)==5)
local diagonal=Rules.ScreenRayDistance(0,0,2/math.sqrt(5),1/math.sqrt(5),corners,100)
assert(math.abs(diagonal-math.sqrt(125))<.00001)
assert(Rules.ScreenRayDistance(0,0,1,0,corners,3)==3)
local calls=0
local Sight={Cast=function() calls+=1;return nil end}
local Config={CreatureViewAngle=160}
local viewRange=25
local player={GetAttribute=function(_,key) if key=="ViewRange" then return viewRange end end}
local target={Position=Vector3.new(200,0,5),IsA=function() return true end}
local model={FindFirstChild=function(_,name) return name=="HumanoidRootPart" and target or nil end}
local character={FindFirstChild=function() end}
local root={Position=Vector3.new(0,0,0),CFrame={LookVector=Vector3.new(0,0,1)}}
local camera={ViewportSize={X=100,Y=100},WorldToViewportPoint=function(_,p) return {X=p.X+50,Y=50,Z=1} end}
VISIBLE
for i=1,1000 do assert(not visible(model,root,character,camera)) end
assert(calls==0,"off-screen creatures must not cast any visibility rays")
target.Position=Vector3.new(0,0,5)
assert(visible(model,root,character,camera) and calls==1,"visible creature still tests line of sight")
viewRange=4;assert(not visible(model,root,character,camera) and calls==1,"outside Attention range casts no rays")
viewRange=5;assert(visible(model,root,character,camera) and calls==2,"at5 studs visible with1 attention")
target.Position=Vector3.new(0,0,-5)
assert(not visible(model,root,character,camera) and calls==2,"rear sector still hidden")
print("PASS: viewport edges, behind camera, four ground edges, diagonal and max range; 1000 off-screen checks cast zero rays; on-screen sector/occlusion preserved")
'''.replace('VISIBLE',visible)
with tempfile.TemporaryDirectory() as directory:
 p=Path(directory)/'visibility.luau'
 p.write_text((root/'tests/city_geometry.fixture.luau').read_text()+'\nlocal Rules=(function()\n'+rules+'\nend)()\n'+cases)
 subprocess.run([sys.argv[1] if len(sys.argv)>1 else 'luau',str(p)],check=True)
