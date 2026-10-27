local C=require("../src/shared/CraftConfig")
local R=require("../src/shared/CraftRules")
local P=require("../src/shared/ProgressionRules")
for id,xp in pairs({MakePlanks=75,MakeHandle=25,MakeAxe=50,MakeShovel=50,MakeScrapAxe=100,MakeScrapShovel=100,MakeKnife=100,MakeIronAxe=200,MakeIronShovel=200,MakeIronKnife=200,MakeBucket=100,MakeCloth=25,MakeBandage=50,MakeGreatBandage=100}) do
 assert(P.CraftExperience(C[id],1)==xp,id)
end
for _,id in ipairs({"MakeRifle223","MakeAssaultRifle223","MakeLSW223","MakeServiceRifle223"}) do
 local recipe=C[id]
 assert(recipe.Ingredients.Iron==10 and recipe.Ingredients.Plank==2 and recipe.Requirements.Skills.Repair==150)
end
assert(C.MakeSewingKit.Ingredients.Scrap==5 and C.MakeSewingKit.Requirements.Skills.Repair==80)
assert(C.MakeBandage.Requirements.Skills.FirstAid==50 and C.MakeGreatBandage.Requirements.Skills.FirstAid==100)
for _,recipe in pairs(C) do
 if recipe.Ingredients.Cloth or recipe.Ingredients.Rags then
  assert(recipe.Tool=="SewingKit" and R.Speed({},recipe)==nil and R.Speed({SewingKit=1},recipe)==1)
 end
end
for _,count in ipairs({1,2,3,4,5}) do
 local burn=assert(R.Plan({TreeLog=count},C.BurnLogs,count))
 assert(burn.Ingredients.TreeLog==count and burn.Outputs.Coal==count)
 local fast=assert(R.Plan({TreeLog=count,Coal=1},C.BurnLogsWithCoal,count))
 assert(fast.Ingredients.TreeLog==count and fast.Ingredients.Coal==1 and fast.Outputs.Coal==count)
 local iron=assert(R.Plan({Scrap=count*5,Coal=1},C.SmeltIron,count))
 assert(iron.Ingredients.Scrap==count*5 and iron.Ingredients.Coal==1 and iron.Outputs.Iron==count)
end
assert(not R.Plan({Scrap=100,Coal=1},C.SmeltIron,6))
assert(not R.Plan({Scrap=5},C.SmeltIron,1))
assert(C.BoilPotatoesCoal.Duration==C.BoilPotatoes.Duration/2 and C.BoilPotatoesCoal.OutputCount==C.BoilPotatoes.OutputCount)
assert(P.FirstAid(19,1,7)==7 and P.FirstAid(20,1,7)==8)
assert(P.FirstAid(100,1,7,"GreatBandage")==24 and P.FirstAid(100,2,7,"GreatBandage")==48)
local stats={Strength=5,Attention=5,Endurance=7,Intelligence=5,Agility=5,Luck=7}
local medic=P.Bonuses(stats,{Medic=1,HardCriticals=1},1,{})
assert(medic.FirstAidMultiplier==1 and medic.MedicalHealingBonus==10)
assert(medic.CriticalMin==2.5 and medic.CriticalMax==2.5)
assert(P.FirstAid(100,medic.FirstAidMultiplier,7,"Bandage",medic.MedicalHealingBonus)==22)
assert(P.FirstAid(100,medic.FirstAidMultiplier,7,"GreatBandage",medic.MedicalHealingBonus)==34)
print("PASS: per-result XP, weapon costs, reusable sewing tool, first aid thresholds/formulas and all 1-5 smelting/burning batches")

for _,id in ipairs({"BoilWater","BoilWaterCoal"}) do
 local recipe=C[id]
 assert(recipe.XP==0 and not recipe.Food and not recipe.RequiresPresence)
 for count=1,5 do
  local items={DirtyWater=count};items[recipe.Fuel.ID]=1
  local plan=assert(R.Plan(items,recipe,count))
  assert(plan.Ingredients.DirtyWater==count and plan.Ingredients[recipe.Fuel.ID]==1 and plan.Outputs.CleanWater==count)
  assert(P.CraftExperience(recipe,count)==0)
  assert(P.CraftOutputs(plan.Outputs,recipe,{Ramsay=true}).CleanWater==count,"water keeps ordinary ID even for master cooks")
 end
 assert(not R.Plan({DirtyWater=5},recipe,1),"fuel is required")
end
assert(C.BoilWater.Duration==60 and C.BoilWaterCoal.Duration==30)
print("PASS: boil 1-5 water bottles, one fuel, no XP or Ramsay water alias, coal twice as fast")
