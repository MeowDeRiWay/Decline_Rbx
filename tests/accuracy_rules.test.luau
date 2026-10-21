local Rules=require("../src/shared/AccuracyRules")
assert(Rules.Chance(100,0,20,0)==90)
assert(Rules.Chance(100,0,40,0)==80)
assert(Rules.Chance(100,0,40,50)==30)
assert(Rules.Chance(100,0,19,0)==90)
assert(Rules.Chance(25,0,100,50)==5)
assert(Rules.Chance(300,0,230,0)==90)
assert(Rules.Chance(300,50,250,0)==70,"total skill capped at300 before penalties")
assert(Rules.Chance(90,10,40,50)==30,"weapon skill bonus before penalties")
assert(Rules.Chance(100,0,40.5,0)==79.5,"no rounding in probability")
assert(Rules.Chance(nil,nil,0,nil)==25)
print("PASS: skill cap, distance grace, category bonus, dodge, final chance cap and examples")

local bonus=20
local sight={IsA=function(_,kind) return kind=="Model" end,GetAttribute=function(_,key) return key=="AccuracyBonus" and bonus end}
local held={FindFirstChild=function(_,name) return name=="Sight" and sight end}
assert(Rules.SightBonus(nil)==0 and Rules.SightBonus(held)==20)
assert(Rules.Chance(100,Rules.SightBonus(held),60,0)==80)
bonus=0/0;assert(Rules.SightBonus(held)==0)
bonus=math.huge;assert(Rules.SightBonus(held)==0)
bonus=-10;assert(Rules.SightBonus(held)==0)
bonus=400;assert(Rules.SightBonus(held)==300)
print("PASS: Sight model bonus, absent sight, finite validation and cap")
assert(Rules.WeaponSkill(nil)=="Unarmed")
assert(Rules.WeaponSkill({Weapon={}})=="Melee")
assert(Rules.WeaponSkill({Firearm={Category="Rifle"}})=="LightWeapons")
assert(Rules.WeaponSkill({Firearm={Category="MachineGun"}})=="HeavyWeapons")
local p={GetAttribute=function(_,key) return ({SkillLightWeapons=90,SkillHeavyWeapons=40,SkillUnarmed=65,SkillMelee=25})[key] end}
assert(Rules.ForWeapon(p,{Firearm={}})==90 and Rules.ForWeapon(p,{Weapon={}})==25)
