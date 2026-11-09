local Items=require("../src/shared/ItemConfig")
local C=require("../src/shared/CraftConfig")
local R=require("../src/shared/CraftRules")
local P=require("../src/shared/ProgressionRules")
for id,xp in pairs({MakePlanks=75,MakeHandle=25,MakeScrapAxe=100,MakeScrapShovel=100,MakeKnife=100,MakeIronKnife=200,MakeBucket=100,MakeCloth=25,MakeBandage=50,MakeGreatBandage=100}) do
 assert(P.CraftExperience(C[id],1)==xp,id)
end
for _,id in ipairs({"MakeRifle223","MakeAssaultRifle223","MakeLSW223","MakeServiceRifle223","MakeMarksmanRifle223"}) do
 local recipe=C[id]
 assert(recipe.Ingredients.Iron==((id=="MakeLSW223" or id=="MakeMarksmanRifle223") and 7 or 5) and recipe.Ingredients.Plank==2 and recipe.Requirements.Skills.Repair==({MakeRifle223=100,MakeAssaultRifle223=120,MakeLSW223=140,MakeServiceRifle223=110,MakeMarksmanRifle223=130})[id])
end
assert(C.MakeSewingKit.Ingredients.Scrap==5 and C.MakeSewingKit.Requirements.Skills.Repair==50)
assert(C.MakeBandage.Requirements.Skills.FirstAid==50 and C.MakeGreatBandage.Requirements.Skills.FirstAid==75)
for _,recipe in pairs(C) do
 if recipe.Ingredients.Cloth or recipe.Ingredients.Rags then
  assert(recipe.Tool=="SewingKit" and R.Speed({},recipe)==nil and R.Speed({SewingKit=1},recipe)==1)
 end
end
local burn=assert(R.Plan({TreeLog=1},C.BurnLogs,1))
assert(burn.Ingredients.TreeLog==1 and burn.Outputs.Coal==1 and C.BurnLogs.Duration==10 and C.BurnLogs.XP==15)
assert(not C.BurnLogsWithCoal)
for _,stock in ipairs({{Plank=3},{Handle=3},{Plank=2,Handle=1},{Plank=1,Handle=2}}) do
 local plan=assert(R.Plan(stock,C.BurnWoodParts,1))
 assert((plan.Ingredients.Plank or 0)+(plan.Ingredients.Handle or 0)==3 and plan.Outputs.Coal==1)
end
assert(not R.Plan({Plank=1,Handle=1},C.BurnWoodParts,1))
assert(C.BurnWoodParts.Duration==10 and C.BurnWoodParts.XP==15)
assert(C.MakeSurgicalKit.Ingredients.Iron==1 and C.MakeSurgicalKit.Requirements.Skills.Repair==100)
assert(C.MakePlate.Ingredients.Plank==1 and C.MakePlate.Requirements.Skills.Repair==25)
local mash=C.MashedPotatoesWithSausage
assert(not mash.Variants and mash.Ingredients.Plate==1 and mash.Output=="MashedPotatoesWithSausage_2")
local iron=assert(R.Plan({Scrap=25,Coal=1},C.SmeltIron,1))
assert(iron.Ingredients.Scrap==10 and iron.Ingredients.Coal==1 and iron.Outputs.Iron==5)
assert(not R.Plan({Scrap=100,Coal=1},C.SmeltIron,2))
assert(not R.Plan({Scrap=25},C.SmeltIron,1))
assert(C.BoilPotatoesCoal.Duration==C.BoilPotatoes.Duration/2 and C.BoilPotatoesCoal.OutputCount==C.BoilPotatoes.OutputCount)
assert(P.FirstAid(19,1,7)==7 and P.FirstAid(20,1,7)==8)
assert(P.FirstAid(100,1,7,"GreatBandage")==24 and P.FirstAid(100,2,7,"GreatBandage")==48)
local stats={Strength=5,Attention=5,Endurance=7,Intelligence=5,Agility=5,Luck=7}
local medic=P.Bonuses(stats,{Medic=1,HardCriticals=1},1,{})
assert(medic.FirstAidMultiplier==1 and medic.MedicalHealingBonus==10)
assert(medic.CriticalMin==2.5 and medic.CriticalMax==2.5)
assert(P.FirstAid(100,medic.FirstAidMultiplier,7,"Bandage",medic.MedicalHealingBonus)==22)
assert(P.FirstAid(100,medic.FirstAidMultiplier,7,"GreatBandage",medic.MedicalHealingBonus)==34)
print("PASS: per-result XP, weapon costs, reusable sewing tool, first aid thresholds/formulas and fixed smelting/burning batches")

do
 local recipe=C.BoilWater
 assert(recipe.Name=="Boil water" and recipe.Requirements.Skills.Cook==50)
 assert(recipe.XP==0 and not recipe.Food and not recipe.RequiresPresence and recipe.Automated and recipe.FixedBatch)
 assert(not C.BoilWaterCoal and not recipe.Fuel and recipe.FuelTab=="Coal","coal recipe has no extra fuel charge")
 local plan=assert(R.Plan({DirtyWater=5,Coal=1},recipe,1))
 assert(plan.Ingredients.DirtyWater==5 and plan.Ingredients.Coal==1 and plan.Outputs.CleanWater==5 and not plan.Outputs.Coal)
 assert(P.CraftExperience(recipe,1)==0 and P.CraftOutputs(plan.Outputs,recipe,{Ramsay=true}).CleanWater==5)
 assert(not R.Plan({DirtyWater=5,TreeLog=1},recipe,1),"logs cannot replace charcoal")
 assert(not R.Plan({DirtyWater=4,Coal=1},recipe,1),"the full batch is mandatory")
 assert(#R.QueuePlan({DirtyWater=10,Coal=2},recipe,{Batch=1,Repeats=2},2)==2,"two stove processes allowed")
 assert(recipe.Duration==60)
end
assert(C.MakeBandage.Ingredients.Rags==2 and C.MakeGreatBandage.Ingredients.Cloth==2)
assert(C.MakeBandage.Tool=="SewingKit" and C.MakeGreatBandage.Tool=="SewingKit")
for _,id in ipairs({"MakeAmmo9mm","MakeAmmo223"}) do
 local recipe=C[id]
 assert(recipe.OutputCount==30 and recipe.Duration==30 and recipe.MaxBatch==1)
 local stock={};for item,n in pairs(recipe.Ingredients) do stock[item]=n*2 end
 local plans=assert(R.QueuePlan(stock,recipe,{Batch=1,Repeats=2}))
 assert(#plans==2 and plans[1].Outputs[recipe.Output]==30 and plans[2].Outputs[recipe.Output]==30)
end
print("PASS: charcoal-only water purification, Doctor 50, fixed manual batch; two-material bandages; 30 ammunition per 30-second process")

assert(C.MakeAmmo223.Station=="Workstation" and C.MakeRifle223.Station=="Workstation")

assert(not Items.Items.WoodenPlate and Items.RetiredItems.WoodenPlate)
for _,recipe in pairs(C) do
 assert(not recipe.Ingredients.WoodenPlate)
 for _,variant in ipairs(recipe.Variants or {}) do assert(variant.Ingredient~="WoodenPlate") end
end
for _,id in ipairs({"MashedPotatoesWithSausage_1","MashedPotatoesWithSausage_2","Ramsay_MashedPotatoesWithSausage_1","Ramsay_MashedPotatoesWithSausage_2"}) do
 assert(Items.Items[id].ReturnItems.Plate==1 and not Items.Items[id].ReturnItems.WoodenPlate,"legacy meals also return ordinary plates")
end

local wood=assert(R.Plan({DirtyWater=5,TreeLog=1},C.BoilWaterWood,1))
assert(wood.Outputs.CleanWater==5 and not wood.Outputs.Coal and C.BoilWaterWood.Duration==60)
assert(C.MakeAntiseptic.Ingredients.CleanWater==1 and C.MakeAntiseptic.Ingredients.MedicalAlcohol==1 and C.MakeAntiseptic.OutputCount==5)
assert(C.BoilPotatoes.Requirements.Skills.Cook==50 and C.MashedPotatoesWithSausage.Requirements.Skills.Cook==60)
for _,perk in ipairs(P.Perks) do if perk.ID=="Ramsay" then assert(not perk.Attributes and perk.Skills.Cook==200) end end

local stations=require("../src/shared/CraftStations")
assert(stations.Matches(C.FilterWater,"MedStation") and not stations.Matches(C.FilterWater,"Stove"))
for _,id in ipairs({"BoilWater","BoilWaterWood"}) do
 assert(stations.Matches(C[id],"Stove") and not stations.Matches(C[id],"MedStation"))
end
local filtered=assert(R.Plan({DirtyWater=5,Coal=1},C.FilterWater,1))
assert(filtered.Outputs.CleanWater==5 and filtered.Ingredients.Coal==1 and not C.FilterWater.Fuel)
assert(not R.Plan({DirtyWater=5,TreeLog=1},C.FilterWater,1))

assert(C.FilterWater.Requirements.Skills.Doctor==50 and not C.FilterWater.Requirements.Skills.Cook)
for _,id in ipairs({"BoilWater","BoilWaterWood"}) do assert(C[id].Requirements.Skills.Cook==50 and not C[id].Requirements.Skills.Doctor) end
