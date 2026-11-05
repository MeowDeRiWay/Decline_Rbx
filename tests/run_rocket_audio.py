"""Exercise production rocket sound lifecycle independently of visual flash lifetime."""
from pathlib import Path
import subprocess,sys,tempfile
root=Path(__file__).resolve().parents[1]
source=(root/'tests/rig_math.fixture.luau').read_text()
source+='\nlocal Rules=(function()\n'+(root/'src/shared/ProjectileAudioRules.luau').read_text()+'\nend)()'
source+='''
local created,expires={},{}
workspace={}
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
source+='\nlocal Audio=(function()\n'+(root/'src/client/RocketAudio.luau').read_text().replace('local Rules=require(game:GetService("ReplicatedStorage").Shared.ProjectileAudioRules)','')+'\nend)()'
source+='''
local config={SoundId="rbxassetid://123",Volume=.8,PlaybackSpeed=1.1,MinDistance=3,MaxDistance=150}
local record={Part={Position=Vector3.new(0,0,0)},Velocity=Vector3.new(100,0,0)}
Audio.Start(record,nil);assert(not record.Flight and #created==0)
Audio.Start(record,config)
local flight=record.Flight
assert(flight.Playing and flight.Looped and flight.Parent==record.Part)
assert(flight.Volume==.8 and flight.PlaybackSpeed==1.1 and flight.RollOffMaxDistance==150)
for i=1,120 do Audio.Start(record,config) end
assert(#created==4,"trace updates never restart or duplicate the two loops/equalizers")
local other={Part={Position=Vector3.zero}};Audio.Start(other,config)
assert(other.Flight~=flight,"each airborne rocket has its own loop")
local whistle=record.Flyby
assert(whistle and whistle.Volume==0 and whistle.Looped)
Audio.Update(record,Vector3.new(8,1,0),Vector3.zero,.1)
assert(record.Part.AssemblyLinearVelocity.X==100,"native Doppler receives real source velocity")
assert(whistle.Volume>0 and flight.PlaybackSpeed==config.PlaybackSpeed,"close flyby adds a layer without doubling Doppler")
Audio.Update(record,Vector3.new(-8,1,0),Vector3.zero,.1)
assert(record.FlightEQ.HighGain<0,"receding sound is duller")
for i=1,60 do Audio.Update(record,Vector3.new(80,0,0),Vector3.zero,1/60) end
assert(whistle.Volume<.001,"whistle tail fades after the pass")
Audio.Update(record,nil,Vector3.zero,.1);assert(flight.Volume==0 and whistle.Volume==0)
Audio.Update(record,Vector3.new(8,0,0),Vector3.zero,.1);assert(flight.Volume==config.Volume)
local custom={Part={Position=Vector3.zero}}
Audio.Start(custom,nil,config);assert(custom.Flyby and not custom.Flight,"optional whistle works independently")
assert(custom.Flyby.RollOffMinDistance==16 and custom.Flyby.RollOffMaxDistance==48)
assert(math.abs(custom.FlybyVolume-config.Volume*1.7)<1e-8,"dedicated whistle gain is boosted")
custom.Velocity=Vector3.new(100,0,0)
Audio.Update(custom,Vector3.new(30,0,0),Vector3.zero,.1)
assert(custom.Flyby.Volume>.35,"whistle builds on approach, not only during a point-blank pass")
local peak=custom.Flyby.Volume
Audio.Update(custom,Vector3.new(80,0,0),Vector3.zero,.1)
assert(custom.Flyby.Volume>peak*.4 and custom.Flyby.Volume<peak,"retreat has a short smooth tail")
Audio.Stop(custom)
local sweep={Part={Position=Vector3.new(-80,0,8)},Velocity=Vector3.new(100,0,0)}
Audio.Start(sweep,config,config)
local strongTime=0
for i=1,96 do
 sweep.Part.Position=Vector3.new(-80+i*100/60,0,8)
 Audio.Update(sweep,Vector3.zero,Vector3.zero,1/60)
 if sweep.Flyby.Volume>.2 then strongTime+=1/60 end
 assert(sweep.Flight.Volume==config.Volume,"flight noise keeps its original volume")
end
assert(strongTime>=.4,"100-stud/s close pass sustains whistle instead of a split-second chirp")
Audio.Stop(sweep)
Audio.Stop(record);assert(whistle.Destroyed and not whistle.Playing)
assert(flight.Destroyed and not flight.Playing and record.Flight==nil)
assert(other.Flight.Playing,"stopping one rocket does not stop another")
Audio.Stop(record);Audio.Stop(nil)
local approaching=Rules.Sample(Vector3.new(-30,0,0),Vector3.new(100,0,0),Vector3.zero,Vector3.zero)
local receding=Rules.Sample(Vector3.new(30,0,0),Vector3.new(100,0,0),Vector3.zero,Vector3.zero)
assert(approaching.Radial>0 and receding.Radial<0)
assert(receding.HighGain<approaching.HighGain)
assert(approaching.Whistle>=.25,"approaching rocket has a strong whistle already at 30 studs")
assert(approaching.Whistle>receding.Whistle,"approach is more pronounced than retreat")
local outside=Rules.Sample(Vector3.new(-60,0,0),Vector3.new(100,0,0),Vector3.zero,Vector3.zero)
assert(outside.Whistle==0,"distant flight stays noise-only")
local parallel=Rules.Sample(Vector3.new(0,0,5),Vector3.new(100,0,0),Vector3.zero,Vector3.new(100,0,0))
assert(parallel.Whistle==0 and parallel.Radial==0,"co-moving listener does not get fake flybys")
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
