local Items=require("../src/shared/ItemConfig").Items
local Rules=require("../src/shared/ResourceRules")
local Config=require("../src/shared/ResourceConfig")
local Recipes=require("../src/shared/CraftConfig")
local Craft=require("../src/shared/CraftRules")
for tier,material in ipairs({"Stone","Scrap","Iron"}) do
 for _,tool in ipairs({"Axe","Showel"}) do
  local item=assert(Items[material..tool])
  local node=tool=="Axe" and Config.Tree or Config.ScrapPile
  assert(item.Weapon.Damage==5 and item.HarvestTier==tier)
  assert(Rules.HarvestDamage(node,item)==5*tier)
  assert(not Rules.CanDamage({Tool=node.Tool,MinHarvestTier=tier+1},item))
 end
end
assert(not Rules.CanDamage(Config.ScrapPile,{HarvestTool="Shovel"}),"unranked tools cannot mine scrap")
local ironDeposit={Tool="Shovel",MinHarvestTier=2}
assert(not Rules.CanDamage(ironDeposit,Items.StoneShowel))
assert(Rules.CanDamage(ironDeposit,Items.ScrapShowel) and Rules.CanDamage(ironDeposit,Items.IronShowel))
assert(Rules.HarvestDamage(Config.Tree,Items.ScrapShowel)==0,"wrong tool type still rejected")
assert(Items.ScrapKnife.Weapon.Damage==10 and Items.IronKnife.Weapon.Damage==20)
assert(Craft.Speed({[Items.ScrapKnife.CraftTool]=Items.ScrapKnife.CraftSpeed},Recipes.SliceSausage)==1)
assert(Craft.Speed({[Items.IronKnife.CraftTool]=Items.IronKnife.CraftSpeed},Recipes.SliceSausage)==1)
for _,recipe in pairs(Recipes) do
 for id in pairs(recipe.Ingredients) do assert(Items[id],id) end
 for _,id in ipairs(Craft.Outputs(recipe)) do assert(Items[id],id) end
end
assert(Recipes.MakeAxe.Output=="StoneAxe" and Recipes.MakeShovel.Output=="StoneShowel")
for _,id in ipairs({"MakeScrapAxe","MakeScrapShovel","MakeKnife"}) do
 local recipe=Recipes[id]
 local plan=assert(Craft.Plan({Scrap=3,Handle=1},recipe,1))
 assert(plan.Ingredients.Scrap==3 and plan.Outputs[recipe.Output]==1)
 assert(Craft.Plan({Scrap=2,Handle=1},recipe,1)==nil)
end
for _,recipe in pairs(Recipes) do
 if recipe.Station=="Workstation" then
  assert(recipe.MaxBatch==1)
  local items={TreeLog=100,Plank=100,Handle=100,Stone=100,Scrap=100}
  assert(Craft.Batch(Craft.Available(items,recipe),"All",recipe.MaxBatch)==1)
  assert(Craft.Plan(items,recipe,2)==nil,"server must reject multi-item workstation batches")
 end
end
assert(Recipes.MakeAxe.Ingredients.Stone==1 and Recipes.MakeShovel.Ingredients.Stone==1)
assert(Recipes.MakeAxe.Ingredients.Handle==1 and Recipes.MakeShovel.Ingredients.Handle==1)
assert(Recipes.MakePlanks.OutputCount==3,"one crafting operation still produces three planks per log")
local boil=Recipes.BoilPotatoes
assert(boil.MaxBatch==5)
local plan=assert(Craft.Plan({Potato=5,CleanWater=5},boil,5))
assert(plan.Ingredients.Potato==5 and plan.Ingredients.CleanWater==5 and plan.Outputs.BoiledPotato==5)
assert(Craft.Plan({Potato=6,CleanWater=6},boil,6)==nil)
print("PASS: 8 material tools/weapons, 5/10/15 resource damage, access tiers, knife damage/cooking and recipe costs")
