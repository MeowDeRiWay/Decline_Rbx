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
print("PASS: per-result XP, weapon costs, reusable sewing tool, first aid thresholds/formulas and all 1-5 smelting/burning batches")
