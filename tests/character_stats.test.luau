local Stats=require("../src/shared/CharacterStats")
local Defense=require("../src/shared/DefenseRules")
local a={MaxHealth=130,Endurance=6,Accuracy=45,MeleeBonus=4,KnifeMultiplier=1.5,MeleeAbsorption=2,ArmorAbsorption=3,ArmorResistance=.2,DodgeChance=10,LuckChance=.3,AutomaticAccuracyBonus=20,AutomaticCritChance=.04}
local knife={Weapon={Damage=10},CraftTool="Knife"}
local s=Stats.Calculate(a,knife,100,80,130)
assert(s.MeleeDamage==19 and s.MeleeEquipped)
assert(s.Health==80 and s.MaxHealth==130 and s.Sprint==26)
assert(s.MeleeAbsorption==5 and s.Absorption==3 and s.Resistance==.2)
assert(s.Accuracy==45 and s.CriticalChance==0 and s.Dodge==10 and s.Luck==.3)
local rifle={Weapon={Damage=25},Firearm={Category="Automatic"}}
s=Stats.Calculate(a,rifle,100,80,130)
assert(s.MeleeDamage==4 and not s.MeleeEquipped,"ranged base damage never added to melee")
assert(math.abs(s.Accuracy-65)<1e-10 and s.CriticalChance==.04)
a.Accuracy=290;assert(Stats.Calculate(a,rifle,1).Accuracy==300,"accuracy cap includes category talent")
assert(Stats.Calculate(a,knife,0).MeleeDamage==0,"broken melee weapon cannot deal damage")
assert(Defense.Resolve(20,.2,5)==11,"resistance first then absorption")
assert(Defense.Resolve(5,0,10)==0 and Defense.Resolve(10,2,0)==0,"defense cannot heal")
print("PASS: actual totals, weapon/category talents, melee-only damage, health/sprint, defenses and accuracy cap")
