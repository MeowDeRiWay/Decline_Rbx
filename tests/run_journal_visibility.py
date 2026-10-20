"""Run the actual combat-journal visibility gate for hidden/out-of-screen/dead/KO events."""
from pathlib import Path
import subprocess,sys,tempfile
root=Path(__file__).resolve().parents[1]
source=(root/'src/client/EventVisibility.luau').read_text()
setup='''
local workspace={}
local function model()
 return {IsDescendantOf=function() return true end,GetAttribute=function(self) return self.Knockout end,FindFirstChild=function() return {} end}
end
local character,actor,target=model(),model(),model()
local camera={}
local visible={[actor]=true,[target]=true}
'''
cases='''
Visibility.Check=function(model) return visible[model]==true end
local event={Actor=actor,Target=target}
assert(Visibility.Witnessed(event,character,camera))
visible[target]=false;assert(not Visibility.Witnessed(event,character,camera),"hidden target produces no event")
visible[target]=true;visible[actor]=false;assert(not Visibility.Witnessed(event,character,camera),"unseen attacker identity is not revealed")
visible[actor]=true;event.Target=character;event.Knockout=true;character.Knockout=true
assert(Visibility.Witnessed(event,character,camera),"victim can read the hit that knocked them out")
event.Knockout=false;assert(not Visibility.Witnessed(event,character,camera),"unconscious player cannot witness later events")
assert(not Visibility.Witnessed(event,nil,camera))
print("PASS: visible participants only, hidden target/attacker suppression, own knockout and incapacitation")
'''
with tempfile.TemporaryDirectory() as folder:
 path=Path(folder)/'visibility.luau';path.write_text(setup+'\nlocal Visibility=(function()\n'+source+'\nend)()\n'+cases)
 subprocess.run([sys.argv[1] if len(sys.argv)>1 else 'luau',str(path)],check=True)
