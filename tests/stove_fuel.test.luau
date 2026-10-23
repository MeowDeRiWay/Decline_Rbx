local Recipes=require("../src/shared/CraftConfig")
local Rules=require("../src/shared/CraftRules")
local Progression=require("../src/shared/ProgressionRules")
assert(not Recipes.BoilPotatoesWithLogs,"old five-log duplicate removed")
for id,recipe in pairs(Recipes) do
 if recipe.Station=="Stove" and recipe.Food and recipe.FuelTab=="Wood" then
  local coal=Recipes[id.."Coal"]
  assert(recipe.Fuel.ID=="TreeLog" and recipe.Fuel.Count==1 and recipe.FuelByproducts.Coal==1)
  assert(coal and coal.Fuel.ID=="Coal" and coal.Fuel.Count==1 and coal.Duration==recipe.Duration/2)
  assert(coal.MaxBatch==recipe.MaxBatch and coal.OutputCount==recipe.OutputCount and not coal.FuelByproducts)
  for count=1,recipe.MaxBatch do
   local stock={TreeLog=1,Coal=1}
   for item,amount in pairs(recipe.Ingredients) do stock[item]=amount*count end
   local wood=assert(Rules.Plan(stock,recipe,count))
   local charcoal=assert(Rules.Plan(stock,coal,count))
   assert(wood.Ingredients.TreeLog==1 and wood.Outputs.Coal==1 and charcoal.Ingredients.Coal==1 and not charcoal.Outputs.Coal)
   assert(wood.Outputs[recipe.Output]==charcoal.Outputs[recipe.Output])
   stock.TreeLog=0;assert(not Rules.Plan(stock,recipe,count))
   stock.Coal=0;assert(not Rules.Plan(stock,coal,count))
   local quality=Progression.CraftOutputs(wood.Outputs,recipe,{Ramsay=true})
   assert(quality.Coal==1 and not quality.Ramsay_Coal)
  end
 end
end
assert(Recipes.BurnLogs.Ingredients.TreeLog==5 and Recipes.BurnLogs.OutputCount==5 and Recipes.BurnLogs.Duration==60)
assert(Recipes.BurnLogsWithCoal.Ingredients.TreeLog==5 and Recipes.BurnLogsWithCoal.Ingredients.Coal==1 and Recipes.BurnLogsWithCoal.Duration==30)
print("PASS: automatic stove fuel variants, one fuel per batch1..5, same food yield, charcoal2x speed, no fuel bypass, independent five-log processing")
