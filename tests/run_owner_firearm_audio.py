"""Run the owner-only firearm mixer and verify clean local/remote separation."""
from pathlib import Path
import subprocess,sys,tempfile
root=Path(__file__).resolve().parents[1]
source=(root/'src/client/OwnerFirearmAudio.client.luau').read_text()
setup='''
local function signal()
 local handlers={}
 return {Connect=function(_,fn) table.insert(handlers,fn);return {Disconnect=function() local i=table.find(handlers,fn);if i then table.remove(handlers,i) end end} end,Fire=function(_,...) for _,fn in ipairs(table.clone(handlers)) do fn(...) end end}
end
local copies={}
local SoundService={}
local expirations={}
local Debris={AddItem=function(_,copy,time) expirations[copy]=time end}
local function sound(name,volume)
 local value={Name=name,Volume=volume or .7,PlaybackSpeed=1.2,TimePosition=.1,Looped=false,PlayOnRemove=false,Ended=signal(),Destroying=signal(),VolumeChanged=signal()}
 function value:IsA(kind) return kind=="Sound" end
 function value:GetPropertyChangedSignal(key) assert(key=="Volume");return self.VolumeChanged end
 function value:Play() self.Played=true end
 function value:Stop() self.Stopped=true end
 function value:Destroy() if self.Destroyed then return end;self.Destroyed=true;self.Destroying:Fire();self.Parent=nil end
 function value:Clone() local copy=sound(self.Name,self.Volume);copy.PlaybackSpeed=self.PlaybackSpeed;copy.TimePosition=self.TimePosition;table.insert(copies,copy);return copy end
 return value
end
local initial=sound("PlayingReloadSound",.4)
local character={DescendantAdded=signal(),DescendantRemoving=signal(),GetDescendants=function() return {initial} end}
local player={Character=character,CharacterAdded=signal(),CharacterRemoving=signal()}
local services={Players={LocalPlayer=player},SoundService=SoundService,Debris=Debris}
local game={GetService=function(_,name) return services[name] end}
'''
cases='''
assert(#copies==1 and initial.Volume==0)
assert(copies[1].Parent==SoundService and copies[1].Volume==.4 and copies[1].Played)
assert(copies[1].PlaybackSpeed==1.2 and not copies[1].Looped and not copies[1].PlayOnRemove)
assert(expirations[copies[1]]==15)
local template=sound("ShotSound")
character.DescendantAdded:Fire(template);assert(#copies==1,"authored templates are not played")
local footstep=sound("Running")
character.DescendantAdded:Fire(footstep);assert(#copies==1 and footstep.Volume==.7,"footsteps untouched")
local shot=sound("PlayingShotSound")
character.DescendantAdded:Fire(shot);assert(#copies==2 and shot.Volume==0 and copies[2].Volume==.7 and copies[2].Parent==SoundService)
character.DescendantAdded:Fire(shot);assert(#copies==2,"same source never duplicated")
shot.Volume=.9;shot.VolumeChanged:Fire();assert(shot.Volume==0,"replication cannot unmute owner's spatial copy")
local second=sound("PlayingShotSound")
character.DescendantAdded:Fire(second);assert(#copies==3 and not copies[2].Destroyed,"rapid shots overlap")
local remoteShot=sound("PlayingShotSound")
assert(remoteShot.Volume==.7 and not remoteShot.Played,"other players are not watched or modified")
initial:Destroy();assert(copies[1].Stopped and copies[1].Destroyed,"cancelled reload stops local sound")
copies[2].Ended:Fire();assert(copies[2].Destroyed)
character.DescendantRemoving:Fire(second);assert(copies[3].Stopped and copies[3].Destroyed,"holster removes remaining own audio")
local pending=sound("PlayingReloadSound")
character.DescendantAdded:Fire(pending)
player.CharacterRemoving:Fire();assert(copies[4].Destroyed,"respawn clears local copies")
character.DescendantAdded:Fire(sound("PlayingShotSound"));assert(#copies==4,"old character disconnected")
local replacement={DescendantAdded=signal(),DescendantRemoving=signal(),GetDescendants=function() return {} end}
player.CharacterAdded:Fire(replacement)
replacement.DescendantAdded:Fire(sound("PlayingShotSound"));assert(#copies==5 and copies[5].Played)
print("PASS: centered owner copies, preserved authored sound, no owner spatial double-play, overlapping shots, untouched remote/template/footsteps, reload cancellation, holster, cleanup and respawn")
'''
with tempfile.TemporaryDirectory() as folder:
 path=Path(folder)/'owner_audio.luau';path.write_text(setup+source+cases);subprocess.run([sys.argv[1] if len(sys.argv)>1 else 'luau',str(path)],check=True)
