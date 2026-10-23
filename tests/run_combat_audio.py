"""Exercise real combat sound selection, physical parenting and hard range defaults."""
from pathlib import Path
import subprocess,sys,tempfile
root=Path(__file__).resolve().parents[1]
setup='''
local starter=make("Folder","StarterPlayer")
local template=make("Model","StarterCharacter",starter)
local original=game.GetService
function game:GetService(name)
 if name=="StarterPlayer" then return starter end
 if name=="Debris" then return {AddItem=function() end} end
 return original(self,name)
end
local Random={new=function() return {NextInteger=function() return 1 end} end}
function methods:Stop() self.Playing=false end
function methods:Play() self.Playing=true end
local clone=methods.Clone
function methods:Clone()
 local c=clone(self);c.SoundId=self.SoundId;c.Volume=self.Volume;c.Ended={Once=function() end};return c
end
for _,name in ipairs({"Miss1","Miss2","Miss3","Punch1","Punch2","ShotEvade1"}) do
 local sound=make("Sound",name,template);sound.SoundId="rbxassetid://test";sound.Volume=.4;sound.Playing=true
end
Enum.RollOffMode={LinearSquare="LinearSquare"}
local target=make("Model","Target",workspace);make("Part","Head",target)
'''
cases='''
Audio.Prepare(template)
for _,s in ipairs(template:GetChildren()) do assert(not s.Playing and s.Volume==.4 and not s.PlayOnRemove) end
for _,kind in ipairs({"Punch","Miss","ShotEvade"}) do
 local s=Audio.Play(target,kind,123)
 assert(s:GetAttribute("CombatOwnerUserId")==123)
 assert(s.Parent==target.Head and s.Playing and s.Name=="Combat"..kind)
 assert(s.RollOffMaxDistance==8 and s.RollOffMinDistance==1 and not s.Looped and not s.PlayOnRemove)
end
assert(not Audio.Play(nil,"Punch") and not Audio.Play(target,"Wall"))
assert(not Audio.Play(make("Model","NoPhysicalOrigin",workspace),"Miss"))
print("PASS: combat templates stopped, variants selected, physical emission,8stud cutoff, no loop and missing-asset guards")
'''
parts=[(root/'tests/fixtures/town_mock.luau').read_text(),setup,'local Audio=(function()\n'+(root/'src/server/Services/CombatAudio.luau').read_text()+'\nend)()',cases]
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'test.luau';p.write_text('\n'.join(parts));subprocess.run([sys.argv[1],str(p)],check=True)
