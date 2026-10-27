from pathlib import Path
import subprocess,sys,tempfile
root=Path(__file__).resolve().parents[1]
s=(root/'src/shared/ProgressionPresentation.luau').read_text()
cases='''
for _,id in ipairs({"Strength","Attention","Endurance","Intelligence","Agility","Luck"}) do assert(P.Attribute(id)) end
assert(P.Attribute("Charisma")==nil)
assert(P.Attribute("Luck"):find("critical",1,true))
assert(P.Attribute("Endurance"):find("+1 HP regeneration",1,true) and P.Attribute("Endurance"):find("+4 base HP",1,true))
assert(P.Attribute("Strength"):find("+2 base HP",1,true))
assert(P.Attribute("Agility"):find("+0.4 sprint speed",1,true))
assert(P.Attribute("Attention"):find("10 base",1,true) and P.Attribute("Attention"):find("hearing range",1,true))
print("PASS: six compact attribute descriptions, no retired talents or charisma")
'''
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'test.luau';p.write_text('local P=(function()\n'+s+'\nend)()\n'+cases);subprocess.run([sys.argv[1],str(p)],check=True)
