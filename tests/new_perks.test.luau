local R=require("../src/shared/ProgressionRules")
local C=require("../src/shared/CraftRules")
local recipes=require("../src/shared/CraftConfig")
local Noise=require("../src/shared/NoiseRules")
local I=require("../src/shared/InventoryRules")
local Items=require("../src/shared/ItemConfig")
local function fresh()
 local s=R.New();s.Confirmed=true;s.PerkPoints=100
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
  for id in pairs(p.Skills) do denied.Skills[id]=0;denied.Stats.Intelligence=1;denied.Stats.Attention=1 end
  assert(not R.SpendPerk(denied,p.ID),"skill requirement remains server authoritative")
 end
end
local s=fresh();s.Perks={Lifegiver=2,GoodStudent=1,Criticals=2,Armadillo=2,HardCriticals=1,DoctorFortune=1,SilentRun=1,Economist=1,CatEyes=1,Duelist=1,DroppedIt=1,WeaponPart=1,NotSoEasy=1}
local b=R.Bonuses(s.Stats,s.Perks,5)
assert(b.MaxHealth==140 and R.Bonuses(s.Stats,s.Perks,6).MaxHealth==148,"lifegiver scales every level per rank")
assert(b.Regeneration==10 and b.CriticalDamageMultiplier==2.5 and b.CriticalChance==.4)
assert(b.DoctorFortuneChance==.2 and b.PistolCriticalBonus==.1 and b.DisarmChance==.1)
assert(b.DamageAbsorption==4 and b.DamageResistance==.2 and b.LowHealthResistance==.1)
assert(b.NightAccuracyMultiplier==.9 and b.SilentRunning and b.CraftCostMultiplier==.8 and b.EquippedWeaponWeightMultiplier==0)
assert(R.AddXP(s,50) and s.XP==100)
assert(R.Practice(s,"Miner",5) and s.Practice.Miner.Value==1,"student applies to practice XP too")
s.Level=29;s.XP=29999;assert(R.AddXP(s,1) and s.Level==30 and s.Perks.Observant==1,"automatic level30 perk")
local recipe=C.Discount(recipes.MakeBandage,.8)
assert(recipe.Ingredients.Rags==4 and recipes.MakeBandage.Ingredients.Rags==5)
assert(recipe.MaxBatch==1 and recipe.Duration==20 and recipe.Requirements.Skills.Doctor==100)
assert(C.Plan({Rags=4},recipe,1).Ingredients.Rags==4 and not C.Plan({Rags=4},recipe,2))
assert(C.Discount(recipes.MakePlanks,.8).Ingredients.TreeLog==1,"no free ingredient via rounding")
assert(Noise.StepRadius(30,true,nil,true)==7 and Noise.StepRadius(30,true)==10 and Noise.StepRadius(30,false)==2)
local inv=I.New();I.Add(inv,Items.Items,"Pistol9mm",1);I.Equip(inv,Items.Items,Items.Slots,"Pistol9mm")
inv.EquipmentWeapon.Hands.Loaded=10
assert(math.abs(I.Weight(inv,Items.Items,1,0)-.08)<1e-8,"only equipped gun base weight excluded; ammo retained")
print("PASS: new perk authority/ranks, level-scaled health, automatic perk, doubled XP, craft discount, bandage limits, stealth running and equipped weight")
