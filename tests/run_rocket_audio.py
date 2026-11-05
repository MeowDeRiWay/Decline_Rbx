"""Exercise production rocket sound lifecycle independently of visual flash lifetime."""
from pathlib import Path
import subprocess,sys,tempfile
root=Path(__file__).resolve().parents[1]
source='''
local created,expires={},{}
workspace={}
Vector3={new=function(x,y,z) return {X=x,Y=y,Z=z} end}
Enum={RollOffMode={InverseTapered=1}}
game={GetService=function() return {AddItem=function(_,item,t) expires[item]=t end} end}
Instance={new=function(kind)
 local o={ClassName=kind,Ended={}}
 function o.Ended:Once(fn) o.OnEnded=fn end
 function o:Play() self.Playing=true end
 function o:Stop() self.Playing=false end
 function o:Destroy() self.Destroyed=true end
 table.insert(created,o);return o
end}
'''
source+='\nlocal Audio=(function()\n'+(root/'src/client/RocketAudio.luau').read_text()+'\nend)()'
source+='''
local config={SoundId="rbxassetid://123",Volume=.8,PlaybackSpeed=1.1,MinDistance=3,MaxDistance=150}
local record={Part={}}
Audio.Start(record,nil);assert(not record.Flight and #created==0)
Audio.Start(record,config)
local flight=record.Flight
assert(flight.Playing and flight.Looped and flight.Parent==record.Part)
assert(flight.Volume==.8 and flight.PlaybackSpeed==1.1 and flight.RollOffMaxDistance==150)
for i=1,120 do Audio.Start(record,config) end
assert(#created==1,"trace updates never restart or duplicate the loop")
local other={Part={}};Audio.Start(other,config)
assert(other.Flight~=flight,"each airborne rocket has its own loop")
Audio.Stop(record);assert(flight.Destroyed and not flight.Playing and record.Flight==nil)
assert(other.Flight.Playing,"stopping one rocket does not stop another")
Audio.Stop(record);Audio.Stop(nil)
local point={X=10,Y=3,Z=20}
local blast=Audio.Explode(config,point)
assert(blast.Playing and not blast.Looped and blast.Parent.Position==point)
assert(blast.Parent.Anchored and not blast.Parent.CanQuery and blast.Parent.Parent==workspace)
assert(expires[blast.Parent]==15,"blast survives .4-second visual cleanup")
blast.OnEnded();assert(blast.Parent.Destroyed,"completed blast cleans its anchor")
local before=#created;assert(Audio.Explode(nil,point)==nil and #created==before)
print("PASS: one spatial loop per rocket, no restart on trace updates, independent stop, full-length positional blast and end/timeout cleanup")
'''
with tempfile.TemporaryDirectory() as directory:
 path=Path(directory)/'rocket_audio.luau';path.write_text(source)
 subprocess.run([sys.argv[1] if len(sys.argv)>1 else 'luau',str(path)],check=True)
