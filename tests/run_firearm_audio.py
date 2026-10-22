from pathlib import Path
import subprocess,sys,tempfile
root=Path(__file__).resolve().parents[1]
source=(root/'src/server/Services/FirearmAudio.luau').read_text()
mock='''
local expirations={}
local Debris={AddItem=function(_,sound,seconds) expirations[sound]=seconds end}
game={GetService=function() return Debris end}
Enum={RollOffMode={InverseTapered=1}}
local origin={}
local sound={SoundId="rbxassetid://123",Volume=.7,PlaybackSpeed=1.2,attributes={}}
function sound:IsA(kind) return kind=="Sound" end
function sound:GetAttribute(key) return self.attributes[key] end
function sound:Clone()
 local copy=table.clone(self)
 copy.Ended={Once=function(_,fn) copy.finish=fn end}
 function copy:Play() self.played=true end
 function copy:Stop() self.stopped=true end
 function copy:Destroy() self.destroyed=true end
 return copy
end
local sounds={FindFirstChild=function(_,name) return (name=="ShotSound" or name=="ReloadSound") and sound end}
local held={FindFirstChild=function(_,name) return name=="Sounds" and sounds or name=="_ShotOrigin" and origin end}
local character={FindFirstChild=function(_,name) return name=="HeldItem" and held or origin end}
'''
cases='''
local shot=Audio.Play(character,"ShotSound")
assert(shot.played and shot.Parent==origin and shot.Volume==.7 and shot.PlaybackSpeed==1.2)
assert(shot.RollOffMaxDistance==150 and shot.RollOffMinDistance==3 and not shot.Looped and not shot.PlayOnRemove and expirations[shot]==15)
local reload=Audio.Play(character,"ReloadSound")
assert(reload.RollOffMaxDistance==5)
Audio.Stop(reload);assert(reload.stopped and reload.destroyed)
shot.finish();assert(shot.destroyed)
sound.attributes.MaxDistance=90
assert(Audio.Play(character,"ShotSound").RollOffMaxDistance==90)
assert(Audio.Play(character,"ShotSound",100).RollOffMaxDistance==100,"caliber range overrides authored sound")
assert(Audio.Play(character,"Missing")==nil)
sound.SoundId="";assert(Audio.Play(character,"ShotSound")==nil)
Audio.Stop(nil)
print("PASS: authored volume/speed, spatial attachment, shot/reload ranges, custom range, expiry/end/cancel cleanup and missing optional audio")
'''
with tempfile.TemporaryDirectory() as directory:
 path=Path(directory)/'audio.luau';path.write_text(mock+'\nlocal Audio=(function()\n'+source+'\nend)()\n'+cases)
 subprocess.run([sys.argv[1] if len(sys.argv)>1 else 'luau',str(path)],check=True)
