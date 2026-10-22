"""Exercise actual client distance gate with character/source positions."""
from pathlib import Path
import subprocess,sys,tempfile
root=Path(__file__).resolve().parents[1]
source=(root/'src/client/ZombieAudioRange.client.luau').read_text()
apply=source[source.index('local function apply('):source.index('local function register(')]
senses=(root/'src/shared/SensesRules.luau').read_text()
mock='''
local mt={}
mt.__sub=function(a,b) return {Magnitude=math.abs(a.X-b.X)} end
local Vector3={new=function(x) return setmetatable({X=x},mt) end}
Vector3.zero=Vector3.new(0)
local listener={Position=Vector3.zero}
local origin={Position=Vector3.new(50,0,0)}
local attention=5
local player={Character={FindFirstChild=function() return listener end},GetAttribute=function() return attention end}
local model={FindFirstChild=function() return origin end}
local sound={Volume=.3}
local r={Model=model,Volume=.3}
'''
cases='''
apply(sound,r);assert(sound.Volume==0,"distant zombie muted regardless of rolloff/camera")
origin.Position=Vector3.new(8,0,0);apply(sound,r);assert(sound.Volume==.3,"authored volume restored at boundary")
origin.Position=Vector3.new(8.01,0,0);apply(sound,r);assert(sound.Volume==0)
attention=10;apply(sound,r);assert(sound.Volume==.3,"hearing extends cutoff")
origin.Position=Vector3.new(16.01,0,0);apply(sound,r);assert(sound.Volume==0)
player.Character=nil;apply(sound,r);assert(sound.Volume==0,"no listener means silence")
print("PASS: distant mute, eight-stud boundary, volume restoration, hearing scaling and absent listener")
'''
with tempfile.TemporaryDirectory() as directory:
 p=Path(directory)/'range.luau';p.write_text('local Senses=(function()\n'+senses+'\nend)()\n'+mock+apply+cases)
 subprocess.run([sys.argv[1],str(p)],check=True)
