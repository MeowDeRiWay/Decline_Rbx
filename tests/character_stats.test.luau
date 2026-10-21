local S=require("../src/shared/CharacterStats")
local a={MeleeBonus=5,CarryLimitKg=45,WalkBonus=1.5,RunBonus=5,DodgeChance=25,Regeneration=10,CriticalChance=.05,ArmorAbsorption=3,ArmorResistance=.2}
local s=S.Calculate(a,{Weapon={Damage=20}},100,80,150)
assert(s.Health==80 and s.MaxHealth==150 and s.MeleeDamage==25)
assert(s.Carry==45 and s.WalkSpeed==1.5 and s.RunSpeed==5 and s.Regeneration==10 and s.Dodge==25 and s.CriticalChance==.05)
assert(s.Absorption==3 and s.Resistance==.2)
assert(S.Calculate(a,{Weapon={Damage=25},Firearm={}},100).MeleeDamage==5,"firearm damage excluded")
assert(S.Calculate(a,{Weapon={Damage=20}},0).MeleeDamage==0)
print("PASS: new character stats, equipment defense and melee damage, movement, regeneration and global critical chance")

local m=S.Calculate({MaxHealth=10,CarryLimitKg=5,MeleeBonus=1,DodgeChance=5,WalkBonus=.3,RunBonus=1,Regeneration=2,CriticalChance=.01},nil,nil,10,10)
assert(m.MaxHealth==10 and m.Dodge==5 and m.Carry==5 and m.MeleeDamage==1 and m.Absorption==0 and m.Resistance==0)
assert(m.WalkSpeed==.3 and m.RunSpeed==1 and m.Regeneration==2 and m.CriticalChance==.01)
