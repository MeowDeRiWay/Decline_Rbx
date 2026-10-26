"""Exercise the actual vision update gate for movement, idle blockers and view changes."""
from pathlib import Path
import subprocess,sys,tempfile
root=Path(__file__).resolve().parents[1]
s=(root/'src/client/VisionShade.client.luau').read_text()
gate=s[s.index(' elapsed += dt;'):s.index(' local width,height =')]
mock='''
local vectorIndex=vm.__index
function vm.__index(a,k) if k=="Dot" then return function(v,b) return v.X*b.X+v.Y*b.Y+v.Z*b.Z end end;return vectorIndex(a,k) end
local Config=(function() CONFIG end)()
local attrs={ViewRange=25,ViewAngleMultiplier=1}
local player={GetAttribute=function(_,k) return attrs[k] end}
local knockout=false
local character={GetAttribute=function() return knockout end}
local root={Position=Vector3.zero,CFrame={LookVector=Vector3.new(0,0,1)}}
local camera={CFrame={Position=Vector3.new(0,30,5),LookVector=Vector3.new(0,-1,0),UpVector=Vector3.new(0,0,1)},ViewportSize={X=1280,Y=720},FieldOfView=40}
local elapsed=Config.VisionShadeInterval;local idleElapsed=Config.VisionShadeIdleInterval;local lastView
local draws=0
local function update(dt)
 GATE
 draws+=1
end
update(1/60)
for _=1,60 do update(1/60) end
assert(draws<=11 and draws>=8,"stationary view refreshes moving blockers around10Hz")
local before=draws
for _=1,60 do root.Position=root.Position+Vector3.new(.01,0,0);update(1/60) end
assert(draws-before==30,"movement runs at30Hz, not60")
local function invalidate(change)
 local previous=draws;change();update(1/30);assert(draws==previous+1)
end
invalidate(function() attrs.ViewRange=30 end)
invalidate(function() attrs.ViewAngleMultiplier=.5 end)
invalidate(function() camera.FieldOfView=50 end)
invalidate(function() camera.CFrame.UpVector=Vector3.new(1,0,0) end)
invalidate(function() camera.CFrame.Position=Vector3.new(1,30,5) end)
invalidate(function() knockout=true end)
invalidate(function() knockout=false end)
assert(math.ceil(Config.CreatureViewAngle*Config.VisionRaysPerDegree)+1==241)
print("PASS:30Hz moving/10Hz idle vision gate, range/angle/FOV/camera/KO invalidation and241-ray budget")
'''
code=(root/'tests/city_geometry.fixture.luau').read_text()+'\n'+mock.replace('CONFIG',(root/'src/shared/GameConfig.luau').read_text()).replace('GATE',gate)
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'vision.luau';p.write_text(code);subprocess.run([sys.argv[1],str(p)],check=True)
