"""Boundary, falloff and attribute-source regression checks."""
from pathlib import Path
import subprocess,sys,tempfile
root=Path(__file__).resolve().parents[1]
s='local Rules=(function()\n'+(root/'src/shared/ExplosionRules.luau').read_text()+'\nend)()'
s+='''
local default=Rules.Resolve(nil,{KillRadius=5,BlastRadius=20})
for _,entry in ipairs({{0,100,true},{5,100,true},{5.001,100*(20-5.001)/15,false},{10,100*2/3,false},{12.5,50,false},{19,100/15,false},{20,0,false},{21,0,false}}) do
 local damage,lethal=Rules.Sample(entry[1],default,100)
 assert(math.abs(damage-entry[2])<1e-6 and lethal==entry[3],"zone boundary "..entry[1])
end
local attrs={KillRadius=2,BlastRadius=14}
local source={GetAttribute=function(_,key) return attrs[key] end}
local custom=Rules.Resolve(source,default)
assert(custom.KillRadius==2 and custom.BlastRadius==14)
attrs.KillRadius=30;assert(Rules.Resolve(source,default).KillRadius==14)
attrs.BlastRadius=-1;attrs.KillRadius=0/0
custom=Rules.Resolve(source,default);assert(custom.KillRadius==5 and custom.BlastRadius==20)
attrs.KillRadius=0;attrs.BlastRadius=10
custom=Rules.Resolve(source,default);local amount,lethal=Rules.Sample(0,custom,100)
assert(amount==100 and not lethal,"trap can disable lethal core")
print("PASS: 5-stud lethal core, 15-stud falloff, exact boundaries, projectile/trap attributes and invalid defaults")
'''
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'explosion.luau';p.write_text(s)
 subprocess.run([sys.argv[1] if len(sys.argv)>1 else 'luau',str(p)],check=True)
