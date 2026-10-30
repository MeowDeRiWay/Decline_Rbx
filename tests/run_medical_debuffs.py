"""Production poisoning, treatment, consumption and the Doctor-only recipe."""
from pathlib import Path
import subprocess,sys,tempfile,re
root=Path(__file__).resolve().parents[1]
def module(p):return '(function()\n'+(root/p).read_text()+'\nend)()'
s=(root/'tests/fixtures/town_mock.luau').read_text()
s+='\nlocal MedicalConfig='+module('src/shared/MedicalConfig.luau')+'\nlocal MedicalRules='+module('src/shared/MedicalRules.luau')
debuff=(root/'src/server/Services/DebuffService.luau').read_text().replace('require(Shared.MedicalConfig)','MedicalConfig').replace('require(Shared.MedicalRules)','MedicalRules')
s+='\nlocal Debuffs=(function()\n'+debuff+'\nend)()'
s+='\nlocal Items='+module('src/shared/ItemConfig.luau')+'\nlocal Recipes='+module('src/shared/CraftConfig.luau')+'\nlocal Craft='+module('src/shared/CraftRules.luau')+'\nlocal Rules='+module('src/shared/ConsumableRules.luau')
s+='''
a:LoadCharacterAsync();a.Character:SetAttribute("Food",100);a.Character:SetAttribute("Water",100);a.Character:SetAttribute("Sick",20)
a:SetAttribute("Luck",0)
local roll=.49
local Random={new=function() return {NextNumber=function() return roll end} end}
local Journal={Send=function() end}
local stock={Antiseptic=4}
local Inventory={Remove=function(_,id,n) if (stock[id] or 0)<n then return false end;stock[id]-=n;return true end,Add=function(_,id,n) stock[id]=(stock[id] or 0)+n end}
'''
source=(root/'src/server/Services/ConsumableService.luau').read_text()
source=re.sub(r'local (Items|Rules|Inventory|Debuffs|Journal)\s*=\s*require[^\n]+\n','',source)
s+='\nlocal Consume=(function()\n'+source+'\nend)()'
s+='''
assert(Debuffs.Poison(a.Character));Debuffs.Step(a.Character,5)
assert(a.Character:GetAttribute("Sick")==25)
a.Character:SetAttribute("HospitalResting",true);Debuffs.Step(a.Character,5);assert(a.Character:GetAttribute("Sick")==25)
assert(not Debuffs.Treat(a.Character,5) and a.Character:GetAttribute("Sick")==15)
assert(Debuffs.Treat(a.Character,10) and not a.Character:GetAttribute("Poisoned") and a.Character:GetAttribute("Sick")==0)
a.Character:SetAttribute("HospitalResting",false);a.Character:SetAttribute("Sick",40)
assert(not Debuffs.ZombieHit(a.Character,{NextNumber=function() return 0 end}),"zombie infection remains switched off")
MedicalConfig.ZombiePoisonEnabled=true
assert(Debuffs.ZombieHit(a.Character,{NextNumber=function() return .049 end}))
a.Character:SetAttribute("Poisoned",false)
assert(not Debuffs.ZombieHit(a.Character,{NextNumber=function() return .05 end}),"5% boundary is exclusive")
MedicalConfig.ZombiePoisonEnabled=false
Debuffs.Poison(a.Character);roll=.5
assert(Consume.Consume(a,"Antiseptic") and a.Character:GetAttribute("Poisoned") and stock.Antiseptic==3 and stock.EmptyBottle==1)
roll=.49
assert(Consume.Consume(a,"Antiseptic") and not a.Character:GetAttribute("Poisoned") and a.Character:GetAttribute("Sick")==40)
Debuffs.Poison(a.Character);a:SetAttribute("Luck",10);roll=.999
assert(Consume.Consume(a,"Antiseptic") and not a.Character:GetAttribute("Poisoned") and stock.EmptyBottle==3)
assert(Consume.Consume(a,"Antiseptic") and not Consume.Consume(a,"Antiseptic"),"no inventory means no additional rolls")
local recipe=Recipes.MakeAntiseptic
assert(recipe.Station=="MedStation" and recipe.Requirements.Skills.Doctor==50 and not recipe.Requirements.Skills.FirstAid)
local plan=assert(Craft.Plan({CleanWater=5,MedicalAlcohol=1},recipe,1))
assert(plan.Ingredients.CleanWater==5 and plan.Ingredients.MedicalAlcohol==1 and plan.Outputs.Antiseptic==5 and plan.Outputs.EmptyBottle==1)
assert(not Craft.Plan({CleanWater=4,MedicalAlcohol=1},recipe,1))
print("PASS: poison progression/suppression/removal, disabled and exact5% toggle, luck cure boundaries, real dose consumption/bottles and exact Doctor50 recipe")
'''
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'medical.luau';p.write_text(s);subprocess.run([sys.argv[1],str(p)],check=True)
