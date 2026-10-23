local R=require("../src/shared/ProgressionRules")
local C=require("../src/shared/CraftRules")
local recipes=require("../src/shared/CraftConfig")
local Noise=require("../src/shared/NoiseRules")
local I=require("../src/shared/InventoryRules")
local Items=require("../src/shared/ItemConfig")
local function fresh()
 local s=R.New();s.Confirmed=true;s.PerkPoints=100;s.Practice.Farmer.Value=150
 for id in pairs(s.Stats) do s.Stats[id]=10 end
 for id in pairs(s.Skills) do s.Skills[id]=250 end
 return s
end
for _,p in ipairs(R.Perks) do
 local s=fresh()
 assert(R.SpendPerk(s,p.ID),p.ID)
 if p.Max==2 then assert(R.SpendPerk(s,p.ID)) end
 assert(not R.SpendPerk(s,p.ID),"rank cap")
 if p.Skills then
  local denied=fresh()
  for id in pairs(p.Skills) do denied.Skills[id]=0;if denied.Practice[id] then denied.Practice[id].Value=0 end;denied.Stats.Intelligence=1;denied.Stats.Attention=1 end
  assert(not R.SpendPerk(denied,p.ID),"skill requirement remains server authoritative")
 end
end
local s=fresh();s.Perks={Lifegiver=2,GoodStudent=1,Criticals=2,Armadillo=2,HardCriticals=1,DoctorFortune=1,SilentRun=1,Economist=1,CatEyes=1,Duelist=1,DroppedIt=1,WeaponPart=1,NotSoEasy=1}
local b=R.Bonuses(s.Stats,s.Perks,5)
assert(b.MaxHealth==190 and R.Bonuses(s.Stats,s.Perks,6).MaxHealth==208,"lifegiver scales every level per rank")
assert(b.Regeneration==10 and b.CriticalMin==1.5 and b.CriticalMax==2.5 and b.CriticalChance==.4)
assert(b.DoctorFortuneChance==.2 and b.PistolCriticalBonus==.1 and b.DisarmChance==.1)
assert(b.DamageAbsorption==4 and b.DamageResistance==.2 and b.LowHealthResistance==.1)
assert(b.NightAccuracyMultiplier==.9 and b.SilentRunning and b.CraftCostMultiplier==.8 and b.EquippedWeaponWeightMultiplier==0)
assert(R.AddXP(s,50) and s.XP==100)
assert(R.Practice(s,"Miner",5) and s.Practice.Miner.Value==1,"student applies to practice XP too")
s.Level=29;s.XP=14999;assert(R.AddXP(s,1) and s.Level==30 and s.Perks.Observant==1,"automatic level30 perk")
local recipe=C.Discount(recipes.MakeBandage,.8)
assert(recipe.Ingredients.Rags==4 and recipes.MakeBandage.Ingredients.Rags==5)
assert(recipe.MaxBatch==1 and recipe.Duration==20 and recipe.Requirements.Skills.Doctor==100)
assert(C.Plan({Rags=4},recipe,1).Ingredients.Rags==4 and not C.Plan({Rags=4},recipe,2))
assert(C.Discount(recipes.MakePlanks,.8).Ingredients.TreeLog==1,"no free ingredient via rounding")
assert(Noise.StepRadius(30,true,nil,true)==7 and Noise.StepRadius(30,true)==10 and Noise.StepRadius(30,false)==2)
local inv=I.New();I.Add(inv,Items.Items,"Pistol9mm",1);I.Equip(inv,Items.Items,Items.Slots,"Pistol9mm")
inv.EquipmentWeapon.Hands.Loaded=10
assert(math.abs(I.Weight(inv,Items.Items,1,0)-.08)<1e-8,"only equipped gun base weight excluded; ammo retained")
local four=R.Bonuses({Strength=5,Attention=5,Endurance=6,Intelligence=6,Agility=8,Luck=5},{SilentDeath=1,UnarmedDamage=1,LivingAnatomy=1,FastFeet=1})
assert(four.BackstabCritical and four.UnarmedDamageBonus==10 and four.ArmorBypassChance==.1)
assert(math.abs(four.WalkBonus-1.92)<1e-8 and math.abs(four.RunBonus-4.84)<1e-8)
local Combat=require("../src/shared/CombatRules")
local empty=I.New();assert(Combat.GetWeapon(empty,Items.Items)==Combat.Unarmed and Combat.Unarmed.Damage==0,"bare fists use strength damage plus unarmed perk")
local Sheet=require("../src/shared/CharacterStats")
assert(Sheet.Calculate({MeleeBonus=5,UnarmedDamageBonus=10},nil,nil,50,50).MeleeDamage==15)
assert(Sheet.Calculate({MeleeBonus=5,UnarmedDamageBonus=10},{Weapon={Damage=10}},nil,50,50).MeleeDamage==15,"unarmed perk never increases knife damage")
local latest=R.Bonuses({Strength=6,Attention=8,Endurance=7,Intelligence=6,Agility=8,Luck=6},{Dodger=1,UnarmedEvade=1,QuickRecovery=1,PiercingStrike=1,Sniper=1,Cowboy=1,Scrounger=1,KhersonMelons=1})
assert(latest.DodgeChance==60 and latest.UnarmedArmorClass==15 and latest.Regeneration==11)
assert(latest.ReviveLockReduction==180 and latest.ReviveHealthBonus==.2)
assert(latest.MeleeIgnoreAbsorption==2 and latest.MeleeIgnoreResistance==.1 and latest.SniperCriticalBonus==.1)
assert(latest.CowboyMultiplier==1.15 and latest.ScroungerMultiplier==1.25 and latest.GreenhouseYieldMultiplier==1.5)
local food=Items.Items.Ramsay_BoiledPotato
assert(food.Consume.Food==7.5 and food.Consume.Health==5 and Items.Items.BoiledPotato.Consume.Food==5)
local mixed=C.Plan({BoiledPotato=0,Ramsay_BoiledPotato=1,SausageSlice=1,Plate=1},recipes.MashedPotatoesWithSausage,1)
assert(mixed and mixed.Ingredients.Ramsay_BoiledPotato==1 and not mixed.Ingredients.BoiledPotato,"quality food usable in later recipes")
local farmer=R.New();farmer.Confirmed=true;assert(farmer.Practice.Farmer.Value==0 and R.Practice(farmer,"Farmer",10) and farmer.Practice.Farmer.Value==1)
print("PASS: new perk authority/ranks, level-scaled health, automatic perk, doubled XP, craft discount, bandage limits, stealth running and equipped weight")

assert(Combat.UnarmedDamage(10,0,0)==7.5 and Combat.UnarmedDamage(10,0,1)==12)
assert(Combat.UnarmedDamage(20,10,0)==25 and Combat.UnarmedDamage(20,10,1)==34,"Strong arm scales rolled Strength, flat perk remains additive")
