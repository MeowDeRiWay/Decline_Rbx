"""Verify real damage routing applies Cook absorption only to classified melee."""
from pathlib import Path
import subprocess
import sys
import tempfile
root=Path(__file__).resolve().parents[1]
service=(root/'src/server/Services/DamageService.luau').read_text().replace('local Life = require(script.Parent.PlayerLifeService)','')
setup='''
local hits=0
local chance=.1
local math=table.clone(math);math.random=function() return chance end
local Life={Damage=function(_,hp,amount) hits+=1; hp.Health-=amount; return amount end}
function Players:GetPlayerFromCharacter(character) if character==a.Character then return a end end
'''
cases='''
a:LoadCharacterAsync();a.Character:PivotTo(CFrame.new(Vector3.zero)); a:SetAttribute("MeleeAbsorption",3)
local hp=a.Character.Humanoid
assert(Service.Apply(hp,5,"Blunt",nil,"Melee")==2 and hp.Health==98)
assert(Service.Apply(hp,5,"Piercing",nil,"Projectile")==5 and hp.Health==93)
a:SetAttribute("MeleeAbsorption",10)
assert(Service.Apply(hp,5,"Blunt",nil,"Melee")==0 and hp.Health==93 and hits==2)
a:SetAttribute("MeleeAbsorption",0);a:SetAttribute("DodgeChance",.5)
a:SetAttribute("Accuracy",.75)
assert(Service.RollHit(a,hp)==true,"75%-50%=25%, roll10% hits")
chance=.3;assert(Service.RollHit(a,hp)==false,"one subtraction, not independent dodge rolls")
chance=.1
assert(Service.Apply(hp,5,"Bullet",nil,"Ranged")==0,"unrolled incoming damage can be dodged")
assert(Service.Apply(hp,5,"Bullet",nil,"Ranged",{HitChecked=true})==5,"prechecked hits do not roll dodge twice")
a:SetAttribute("DodgeChance",0);a:SetAttribute("CriticalNegation",.9)
assert(Service.Apply(hp,5,"Bullet",nil,"Ranged",{HitChecked=true,CriticalMultiplier=4})==5,"critical negation restores normal damage")
chance=.95
assert(Service.Apply(hp,5,"Bullet",nil,"Ranged",{HitChecked=true,CriticalMultiplier=4})==20,"unnegated critical multiplier")
local Items=requirePlaceholder
local InventoryRules=inventoryPlaceholder
local state=InventoryRules.New()
assert(InventoryRules.Add(state,Items.Items,"Apron",1))
assert(InventoryRules.Equip(state,Items.Items,Items.Slots,"Apron"))
assert(state.Equipment.Additional=="Apron")
local report=ReplicatedStorage:FindFirstChild("CombatReport")
assert(report and #report.sent>0,"nearby observers receive structured events for visual filtering")
table.clear(report.sent)
local target=make("Model","Zombie",workspace)
Service.Miss(target,a)
assert(#report.sent>0 and report.sent[1].data.Kind=="Miss" and report.sent[1].data.Actor==a.Character and report.sent[1].data.Target==target)
assert(not target:FindFirstChild("DamagePopup",true),"no overhead popup")
table.clear(report.sent)
local targetHP=make("Humanoid","Humanoid",target);targetHP.Health=7;targetHP.MaxHealth=7
function targetHP:TakeDamage(amount) self.Health=math.max(0,self.Health-amount) end
Service.Apply(targetHP,10,"Bullet",nil,"Ranged",{Attacker=a,HitChecked=true})
assert(report.sent[1].data.Killed and report.sent[1].data.Damage==7,"lethal report records actual damage and death")
table.clear(report.sent)
local priorDamage=Life.Damage
Life.Damage=function(_,hp,amount) hp.Parent:SetAttribute("Knockout",true);return math.min(hp.Health,amount) end
Service.Apply(hp,10,"Blunt",nil,"Melee",{Attacker=target,HitChecked=true})
assert(report.sent[1].data.Knockout and report.sent[1].data.Actor==target,"AI attacker and new knockout survive report formatting")
Life.Damage=priorDamage
print("PASS: structured actor/target reports for client visibility filtering, no overhead text")
print("PASS: melee-only absorption, non-melee unchanged, zero-damage clamp and Apron Additional slot")
'''
cases=cases.replace('requirePlaceholder','(function()\n'+(root/'src/shared/ItemConfig.luau').read_text()+'\nend)()').replace('inventoryPlaceholder','(function()\n'+(root/'src/shared/InventoryRules.luau').read_text()+'\nend)()')
parts=[(root/'tests/fixtures/town_mock.luau').read_text(),setup,'local Service=(function()\n'+service+'\nend)()',cases]
with tempfile.TemporaryDirectory(prefix='decline-absorption-') as directory:
 path=Path(directory)/'test.luau';path.write_text('\n'.join(parts))
 subprocess.run([sys.argv[1] if len(sys.argv)>1 else 'luau',str(path)],check=True)
