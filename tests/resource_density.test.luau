local Rules=require("../src/shared/ResourceRules")
local Recipes=require("../src/shared/CraftConfig")
local Items=require("../src/shared/ItemConfig").Items
local Craft=require("../src/shared/CraftRules")
local function count(width,depth,roll,chance)
 local n,calls=0,0
 local random={NextNumber=function() calls+=1; return roll end}
 Rules.RollCells(width,depth,chance or .1,random,function(x,z)
  assert(x>=-width/2 and x<=width/2 and z>=-depth/2 and z<=depth/2)
  n+=1
 end)
 return n,calls
end
local n,calls=count(10,10,.9)
assert(n==0 and calls==100,"100 independent trials, no forced minimum")
n,calls=count(10,10,.05)
assert(n==100 and calls==300,"all 100 cells may succeed, without old 20-object cap")
assert(count(10,10,.1)==0,"strict ten percent threshold")
assert(count(0,10,0)==0)
assert(count(.5,.5,.024)==1 and count(.5,.5,.026)==0,"fractional area scales probability")
local rng={state=81273}
function rng:NextNumber()
 self.state=(self.state*48271)%2147483647
 return self.state/2147483647
end
local total=0
for _=1,1000 do Rules.RollCells(10,10,.1,rng,function() total+=1 end) end
assert(total>9500 and total<10500,"density approximately .1 per square stud")
for _,id in ipairs({"MakeAxe","MakeShovel"}) do
 local recipe=Recipes[id]
 assert(recipe.Station=="Workstation" and recipe.Ingredients.Stone==1 and recipe.Ingredients.Scrap==nil)
 local plan=assert(Craft.Plan({Stone=1,Handle=1},recipe,1))
 assert(plan.Outputs[recipe.Output]==1 and Items[recipe.Output])
 assert(Craft.Plan({Stone=0,Handle=1},recipe,1)==nil)
end
assert(Items.Stone.Weight==.2)
print("PASS: area trials, 0–100 range, fractional cells, ten-percent density and stone tool recipe costs")

local Config=require("../src/shared/ResourceConfig")
local candidates=0
for _=1,100 do Rules.RollCells(40,100,Config.Tree.SpawnChance,rng,function() candidates+=1 end) end
assert(candidates>3700 and candidates<4300,"40x100 at 1 percent averages about 40 candidates")
for _,definition in pairs(Config) do assert(definition.SpawnChance==.01) end
print("PASS: all resource types use one-percent density; 40x100 averages forty candidates")

local checkpoints,trials=0,0
Rules.RollCells(400,500,0,{NextNumber=function() trials+=1;return .5 end},function() error("zero chance") end,function() checkpoints+=1 end)
assert(trials==200000 and checkpoints==math.floor(200000/128),"large empty areas still offer cooperative scheduling checkpoints")
print("PASS: empty area rolls retain frame-budget checkpoints")
