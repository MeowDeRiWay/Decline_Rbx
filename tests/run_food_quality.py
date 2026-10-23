"""Actual consumption of quality food; effects stay attached to the item, not eater perks."""
from pathlib import Path
import re,subprocess,sys,tempfile
root=Path(__file__).resolve().parents[1]
s=(root/'src/server/Services/ConsumableService.luau').read_text()
s=re.sub(r'local (Items|Rules|Inventory)\s*=\s*require[^\n]+\n','',s)
mock='''
a:LoadCharacterAsync();local hp=a.Character.Humanoid;hp.Health=90
local stock={Ramsay_BoiledPotato=1,Ramsay_MashedPotatoesWithSausage_2=1}
local Inventory={Remove=function(_,id,n) if (stock[id] or 0)<n then return false end;stock[id]-=n;return true end,Add=function(_,id,n) stock[id]=(stock[id] or 0)+n;return true end}
a.Character:SetAttribute("Food",10);a.Character:SetAttribute("Water",50);a.Character:SetAttribute("Sick",2)
'''
cases='''
assert(Service.Eat(a,"Ramsay_BoiledPotato") and a.Character:GetAttribute("Food")==17.5 and hp.Health==95)
assert(a.Character:GetAttribute("Sick")==2 and a.Character:GetAttribute("Water")==50)
hp.Health=98
assert(Service.Eat(a,"Ramsay_MashedPotatoesWithSausage_2") and hp.Health==100 and stock.Plate==1)
assert(a.Character:GetAttribute("Food")==26.5 and a.Character:GetAttribute("Water")==49,"negative nutrition not amplified")
assert(not Service.Eat(a,"Ramsay_Potato"),"uncooked food never inherits cook quality")
assert(Items.Items.Ramsay_BoiledPotato.TemplateID=="BoiledPotato")
print("PASS: persistent quality food heals5, positive nutrition x1.5, negatives unchanged, HP cap and plate return")
'''
parts=[(root/'tests/fixtures/town_mock.luau').read_text()]
for var,module in [('Items','ItemConfig'),('Rules','ConsumableRules')]:parts.append('local '+var+'=(function()\n'+(root/f'src/shared/{module}.luau').read_text()+'\nend)()')
parts +=[mock,'local Service=(function()\n'+s+'\nend)()',cases]
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'food.luau';p.write_text('\n'.join(parts));subprocess.run([sys.argv[1],str(p)],check=True)
