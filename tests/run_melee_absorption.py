"""Verify real damage routing applies Cook absorption only to classified melee."""
from pathlib import Path
import subprocess
import sys
import tempfile
root=Path(__file__).resolve().parents[1]
service=(root/'src/server/Services/DamageService.luau').read_text().replace('local Life = require(script.Parent.PlayerLifeService)','')
service=service.replace('require(ReplicatedStorage.Shared.DefenseRules)','(function()\n'+(root/'src/shared/DefenseRules.luau').read_text()+'\nend)()')
service=service.replace('require(ReplicatedStorage.Shared.AffiliationRules)','(function()\n'+(root/'src/shared/AffiliationRules.luau').read_text()+'\nend)()')
service=service.replace('require(ReplicatedStorage.Shared.AccuracyRules)','(function()\n'+(root/'src/shared/AccuracyRules.luau').read_text()+'\nend)()')
service=service.replace('require(ReplicatedStorage.Shared.ItemConfig).Items','{}')
setup='''
local hits=0
local chance=.1
local math=table.clone(math);math.random=function() return chance end
local Life={Damage=function(_,hp,amount) hits+=1; hp.Health-=amount; return amount end}
function Players:GetPlayerFromCharacter(character) if character==a.Character then return a end end
'''
cases='''
b:LoadCharacterAsync();a:LoadCharacterAsync();a.Character:PivotTo(CFrame.new(Vector3.zero)); a:SetAttribute("MeleeAbsorption",3)
local hp=a.Character.Humanoid
assert(Service.Apply(hp,5,"Blunt",nil,"Melee")==2 and hp.Health==98)
assert(Service.Apply(hp,5,"Piercing",nil,"Projectile")==5 and hp.Health==93)
a:SetAttribute("MeleeAbsorption",10)
assert(Service.Apply(hp,5,"Blunt",nil,"Melee")==0 and hp.Health==93 and hits==2)
a:SetAttribute("MeleeAbsorption",2);a:SetAttribute("ArmorAbsorption",3);a:SetAttribute("ArmorResistance",.2)
assert(Service.Apply(hp,20,"Blunt",nil,"Melee")==11,"20 minus20% then5 flat =11, resistance before absorption")
assert(Service.Apply(hp,20,"Bullet",nil,"Ranged")==13,"melee talent does not protect ranged hits")
a:SetAttribute("ArmorAbsorption",0);a:SetAttribute("ArmorResistance",0)
a:SetAttribute("MeleeAbsorption",0);a:SetAttribute("DodgeChance",50)
a:SetAttribute("Accuracy",75)
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
a.Character:SetAttribute("Knockout",false)
b:SetAttribute("Accuracy",100);a:SetAttribute("DodgeChance",50)
a.Character.HumanoidRootPart.Position=Vector3.new(40,0,0)
chance=.299;assert(Service.RollHit(b,hp),"100 skill -20 distance -50 dodge =30%, below threshold hits")
chance=.3;assert(not Service.RollHit(b,hp),"at30% threshold misses")
a:SetAttribute("DodgeChance",0)
chance=.799;assert(Service.RollHit(b,hp));chance=.8;assert(not Service.RollHit(b,hp),"40 studs gives80%")
a.Character.HumanoidRootPart.Position=Vector3.new(20,0,0)
chance=.899;assert(Service.RollHit(b,hp));chance=.9;assert(not Service.RollHit(b,hp),"20 studs capped90%")
a.Character.HumanoidRootPart.Position=Vector3.zero
chance=.1
a:SetAttribute("TeamID",10);b:SetAttribute("TeamID",10)
local oldHP=hp.Health;local oldReports=#report.sent
a:SetAttribute("AttributesConfirmed",false);assert(Service.Apply(hp,999,"Bullet",nil,"Ranged",{Attacker=b,HitChecked=true})==0 and hp.Health==oldHP);a:SetAttribute("AttributesConfirmed",true)
assert(Service.Apply(hp,999,"Bullet",nil,"Ranged",{Attacker=b,HitChecked=true})==0 and hp.Health==oldHP)
assert(not Service.RollHit(b,hp));Service.Miss(a.Character,b)
assert(#report.sent==oldReports,"friendly damage and misses emit no combat report")
b:SetAttribute("TeamID",20);a:SetAttribute("GroupID",7);b:SetAttribute("GroupID",7)
assert(Service.Apply(hp,999,"Blunt",nil,"Melee",{Attacker=b})==0 and hp.Health==oldHP,"same group protected")
a:SetAttribute("TeamID",nil);b:SetAttribute("TeamID",nil);a:SetAttribute("GroupID",0);b:SetAttribute("GroupID",0)
chance=.1;assert(Service.RollHit(b,hp),"unaffiliated players are not allies")
hp.Health=100;a:SetAttribute("ArmorResistance",.5);a:SetAttribute("ArmorAbsorption",100)
assert(Service.Apply(hp,10,"Bullet",nil,"Ranged",{HitChecked=true,PostDefenseDamage=2,CriticalMultiplier=4})==2,"post-defense bonus bypasses absorption and is not critical-multiplied")
assert(Service.Apply(hp,10,"Blunt",nil,"Melee",{HitChecked=true,PostDefenseDamage=2})==0,"ranged perk never affects melee")
local shield=make("ForceField","Shield",a.Character)
assert(Service.Apply(hp,10,"Bullet",nil,"Ranged",{HitChecked=true,PostDefenseDamage=2})==0,"perk cannot bypass immunity")
shield:Destroy()
local sleeper=make("Model","OfflinePlayer",workspace,{OfflineUserId=900,TeamID=10,ArmorResistance=.5,ArmorAbsorption=2})
local shp=make("Humanoid","Humanoid",sleeper);shp.Health=50;shp.MaxHealth=50
function shp:TakeDamage(n) self.Health-=n end
b:SetAttribute("TeamID",10)
assert(Service.Apply(shp,20,"Bullet",nil,"Ranged",{Attacker=b,HitChecked=true})==0,"offline same-faction player is protected")
b:SetAttribute("TeamID",20)
assert(Service.Apply(shp,20,"Bullet",nil,"Ranged",{Attacker=b,HitChecked=true})==8,"offline armor remains active")
hp.Health=100;a:SetAttribute("CriticalNegation",0);a:SetAttribute("ArmorResistance",0);a:SetAttribute("ArmorAbsorption",0);a:SetAttribute("DamageAbsorption",0);a:SetAttribute("MeleeAbsorption",0)
b:SetAttribute("CriticalDamageMultiplier",2.5)
assert(Service.Apply(hp,10,"Bullet",nil,"Ranged",{Attacker=b,HitChecked=true,CriticalMultiplier=2.5})==25,"critical upper bound applies once, without multiplying the old range")
hp.Health=20;a:SetAttribute("LowHealthResistance",.1)
assert(math.abs(Service.Apply(hp,10,"Bullet",nil,"Ranged",{HitChecked=true})-9)<1e-8,"low health adds ten percent resistance")
a:SetAttribute("LowHealthResistance",0)
print("PASS: structured actor/target reports for client visibility filtering, no overhead text")
print("PASS: melee-only absorption, non-melee unchanged, zero-damage clamp and Apron Additional slot")
'''
cases=cases.replace('requirePlaceholder','(function()\n'+(root/'src/shared/ItemConfig.luau').read_text()+'\nend)()').replace('inventoryPlaceholder','(function()\n'+(root/'src/shared/InventoryRules.luau').read_text()+'\nend)()')
parts=[(root/'tests/fixtures/town_mock.luau').read_text(),setup,'local Service=(function()\n'+service+'\nend)()',cases]
with tempfile.TemporaryDirectory(prefix='decline-absorption-') as directory:
 path=Path(directory)/'test.luau';path.write_text('\n'.join(parts))
 subprocess.run([sys.argv[1] if len(sys.argv)>1 else 'luau',str(path)],check=True)
