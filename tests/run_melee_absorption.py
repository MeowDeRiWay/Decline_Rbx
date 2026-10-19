"""Verify real damage routing applies Cook absorption only to classified melee."""
from pathlib import Path
import subprocess
import sys
import tempfile
root=Path(__file__).resolve().parents[1]
service=(root/'src/server/Services/DamageService.luau').read_text().replace('local Life = require(script.Parent.PlayerLifeService)','')
a=service.index('local function popup('); b=service.index('function Service.Miss',a)
service=service[:a]+'local function popup() end\n'+service[b:]
setup='''
local hits=0
local Life={Damage=function(_,hp,amount) hits+=1; hp.Health-=amount; return amount end}
function Players:GetPlayerFromCharacter(character) if character==a.Character then return a end end
'''
cases='''
a:LoadCharacterAsync(); a:SetAttribute("MeleeAbsorption",3)
local hp=a.Character.Humanoid
assert(Service.Apply(hp,5,"Blunt",nil,"Melee")==2 and hp.Health==98)
assert(Service.Apply(hp,5,"Piercing",nil,"Projectile")==5 and hp.Health==93)
a:SetAttribute("MeleeAbsorption",10)
assert(Service.Apply(hp,5,"Blunt",nil,"Melee")==0 and hp.Health==93 and hits==2)
local Items=requirePlaceholder
local InventoryRules=inventoryPlaceholder
local state=InventoryRules.New()
assert(InventoryRules.Add(state,Items.Items,"Apron",1))
assert(InventoryRules.Equip(state,Items.Items,Items.Slots,"Apron"))
assert(state.Equipment.Additional=="Apron")
print("PASS: melee-only absorption, non-melee unchanged, zero-damage clamp and Apron Additional slot")
'''
cases=cases.replace('requirePlaceholder','(function()\n'+(root/'src/shared/ItemConfig.luau').read_text()+'\nend)()').replace('inventoryPlaceholder','(function()\n'+(root/'src/shared/InventoryRules.luau').read_text()+'\nend)()')
parts=[(root/'tests/fixtures/town_mock.luau').read_text(),setup,'local Service=(function()\n'+service+'\nend)()',cases]
with tempfile.TemporaryDirectory(prefix='decline-absorption-') as directory:
 path=Path(directory)/'test.luau';path.write_text('\n'.join(parts))
 subprocess.run([sys.argv[1] if len(sys.argv)>1 else 'luau',str(path)],check=True)
