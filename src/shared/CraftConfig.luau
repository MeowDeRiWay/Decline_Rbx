-- Item IDs must exist in ItemConfig.luau. Time applies to the entire batch.
local recipes = {
 MakeLeatherArmor2={Name="Reinforce leather jacket",Station="Workstation",Description="Sew scrap plates into a leather jacket. Requires one leather jacket, five scrap, Repair 140 and a reusable sewing kit in your inventory.",Ingredients={LeatherArmor=1,Scrap=5},Output="LeatherArmor2",OutputCount=1,MaxBatch=1,Duration=60,RequiresPresence=true,Tool="SewingKit",Requirements={Skills={Repair=140}}},
 MakeLeatherArmor={Name="Make leather jacket",Station="Workstation",Description="Sew a leather jacket from six cloth. Requires Repair 100 and a reusable sewing kit in your inventory.",Ingredients={Cloth=6},Output="LeatherArmor",OutputCount=1,MaxBatch=1,Duration=60,RequiresPresence=true,Tool="SewingKit",Requirements={Skills={Repair=100}}},
 BoilWater={Name="Boil water",Station="Stove",Boiled=true,Description="Boil one to five bottles of dirty water into clean water. One fuel per batch; no experience. You may leave.",Ingredients={DirtyWater=1},Output="CleanWater",OutputCount=1,MaxBatch=5,Duration=60,XP=0},
 MakePipePistol9mm={Name="Make 9 mm pipe pistol",Station="Workstation",Description="Assemble a single-shot pipe pistol. Requires Repair 60.",Ingredients={Plank=1,Scrap=3},Output="PipePistol9mm",OutputCount=1,MaxBatch=1,Duration=20,RequiresPresence=true,XP=100,Requirements={Skills={Repair=60}}},
 MakePipeRifle9mm={Name="Make 9 mm pipe rifle",Station="Workstation",Description="Assemble a single-shot pipe rifle. Requires Repair 60.",Ingredients={Plank=2,Scrap=5},Output="PipeRifle9mm",OutputCount=1,MaxBatch=1,Duration=30,RequiresPresence=true,XP=100,Requirements={Skills={Repair=60}}},
 MakeAmmo9mm={Name="Make 9 mm FMJ ammunition",Station="Workstation",Description="Produce 50 standard 9 mm rounds. Requires Repair 100.",Ingredients={Coal=1,Chemicals=1,Scrap=1},Output="Ammo9mmFMJ",OutputCount=50,MaxBatch=1,Duration=30,RequiresPresence=true,XP=100,Requirements={Skills={Repair=100}}},
 BurnLogs={FuelTab="Wood",Name="Burn logs into charcoal",Station="Stove",Stations={"Stove","Furnace"},Description="Burn five logs into five charcoal. No matches needed yet; you may leave.",Ingredients={TreeLog=1},Output="Coal",OutputCount=1,MaxBatch=5,Duration=60},
 BurnLogsWithCoal={FuelTab="Coal",Name="Burn logs with charcoal",Station="Stove",Stations={"Stove","Furnace"},Description="Use one charcoal to burn five logs faster. You may leave.",Ingredients={TreeLog=1},Fuel={ID="Coal",Count=1},Output="Coal",OutputCount=1,MaxBatch=5,Duration=30},
 SmeltIron={Name="Smelt iron",Station="Furnace",WorkshopLevel=2,Description="Smelt 25 scrap with one charcoal into five iron. Requires a Workshop T2 furnace; you may leave.",Ingredients={Scrap=5},Fuel={ID="Coal",Count=1},Output="Iron",OutputCount=1,MaxBatch=5,Duration=120},
 MakeAmmo223={Name="Make .223 FMJ ammunition",Station="ArmsBench",Description="Produce 50 standard .223 rounds. Requires Repair 170.",Ingredients={Iron=1,Coal=1,Chemicals=1},Output="Ammo223FMJ",OutputCount=50,MaxBatch=1,Duration=60,RequiresPresence=true,XP=200,Requirements={Skills={Repair=170}}},
 MakeRifle223={Name="Make .223 bolt-action rifle",Station="ArmsBench",Description="Assemble a .223 bolt-action rifle. Requires Repair 150.",Ingredients={Iron=10,Plank=2},Output="Rifle223",OutputCount=1,MaxBatch=1,Duration=120,RequiresPresence=true,XP=500,Requirements={Skills={Repair=150}}},
 MakeAssaultRifle223={Name="Make .223 assault rifle",Station="ArmsBench",Description="Assemble a .223 assault rifle. Requires Repair 150.",Ingredients={Iron=10,Plank=2},Output="AssaultRifle223",OutputCount=1,MaxBatch=1,Duration=120,RequiresPresence=true,XP=500,Requirements={Skills={Repair=150}}},
 MakeLSW223={Name="Make .223 light support weapon",Station="ArmsBench",Description="Assemble a .223 light support weapon. Requires Repair 150.",Ingredients={Iron=10,Plank=2},Output="LSW223",OutputCount=1,MaxBatch=1,Duration=120,RequiresPresence=true,XP=500,Requirements={Skills={Repair=150}}},
 MakeServiceRifle223={Name="Make .223 service rifle",Station="ArmsBench",Description="Assemble a .223 service rifle. Requires Repair 150.",Ingredients={Iron=10,Plank=2},Output="ServiceRifle223",OutputCount=1,MaxBatch=1,Duration=120,RequiresPresence=true,XP=500,Requirements={Skills={Repair=150}}},
 MakeBucket={Name="Make empty bucket",Station="Workstation",Description="Shape scrap into a watering bucket. Requires Repair 100.",Ingredients={Scrap=3},Output="EmptyBucket",OutputCount=1,MaxBatch=1,Duration=20,RequiresPresence=true,Requirements={Skills={Repair=100}}},
 MakeBandage={Name="Make bandage",Station="MedStation",Description="Prepare a bandage from five rags at a medical station. Requires First Aid 50.",Ingredients={Rags=5},Output="Bandage",OutputCount=1,MaxBatch=1,Duration=20,RequiresPresence=true,XP=50,Requirements={Skills={FirstAid=50}}},
 MakeSewingKit={Name="Make sewing kit",Station="Workstation",Description="Make a reusable sewing kit from five scrap. Requires Repair 80.",Ingredients={Scrap=5},Output="SewingKit",OutputCount=1,MaxBatch=1,Duration=20,RequiresPresence=true,Requirements={Skills={Repair=80}}},
 MakeCloth={Name="Make cloth",Station="MedStation",Description="Sew two rags into one cloth using a sewing kit.",Ingredients={Rags=2},Output="Cloth",OutputCount=1,MaxBatch=1,Duration=20,RequiresPresence=true,XP=25},
 MakeGreatBandage={Name="Make great bandage",Station="MedStation",Description="Prepare a great bandage from five cloth. Requires First Aid 100.",Ingredients={Cloth=5},Output="GreatBandage",OutputCount=1,MaxBatch=1,Duration=20,RequiresPresence=true,XP=100,Requirements={Skills={FirstAid=100}}},
 MakePlanks = {
  Name = "Make planks", Station = "Workstation",
  Description = "Cut one tree log into three planks.",
  Ingredients = {TreeLog = 1}, Output = "Plank", OutputCount = 3,
  MaxBatch = 1, Duration = 10, RequiresPresence = true,
 },
 MakeHandle = {
  Name = "Make handle", Station = "Workstation",
  Description = "Shape one plank into a tool handle.",
  Ingredients = {Plank = 1}, Output = "Handle", OutputCount = 1,
  MaxBatch = 1, Duration = 10, RequiresPresence = true,
 },
 MakeAxe = {
  Name = "Make stone axe", Station = "Workstation",
  Description = "Assemble an axe using a handle and one stone.",
  Ingredients = {Handle = 1, Stone = 1}, Output = "StoneAxe", OutputCount = 1,
  MaxBatch = 1, Duration = 20, RequiresPresence = true,
 },
 MakeShovel = {
  Name = "Make stone shovel", Station = "Workstation",
  Description = "Assemble a shovel using a handle and one stone.",
  Ingredients = {Handle = 1, Stone = 1}, Output = "StoneShovel", OutputCount = 1,
  MaxBatch = 1, Duration = 20, RequiresPresence = true,
 },
 MakeScrapAxe = {
  Name = "Make scrap axe", Station = "Workstation",
  Description = "Assemble a scrap axe using a handle and three pieces of scrap.",
  Ingredients = {Handle = 1, Scrap = 3}, Output = "ScrapAxe", OutputCount = 1,
  MaxBatch = 1, Duration = 20, RequiresPresence = true,
 },
 MakeScrapShovel = {
  Name = "Make scrap shovel", Station = "Workstation",
  Description = "Assemble a scrap shovel using a handle and three pieces of scrap.",
  Ingredients = {Handle = 1, Scrap = 3}, Output = "ScrapShovel", OutputCount = 1,
  MaxBatch = 1, Duration = 20, RequiresPresence = true,
 },
 MakeKnife = {
  Name = "Make scrap knife", Station = "Workstation",
  Description = "Shape three pieces of scrap into a knife.",
  Ingredients = {Scrap = 3}, Output = "ScrapKnife", OutputCount = 1,
  MaxBatch = 1, Duration = 15, RequiresPresence = true,
 },
 MakeIronAxe = {
  Name = "Make iron axe", Station = "Workstation",
  Description = "Assemble an iron axe using a handle and three iron.",
  Ingredients = {Handle = 1, Iron = 3}, Output = "IronAxe", OutputCount = 1,
  MaxBatch = 1, Duration = 20, RequiresPresence = true,
 },
 MakeIronShovel = {
  Name = "Make iron shovel", Station = "Workstation",
  Description = "Assemble an iron shovel using a handle and three iron.",
  Ingredients = {Handle = 1, Iron = 3}, Output = "IronShovel", OutputCount = 1,
  MaxBatch = 1, Duration = 20, RequiresPresence = true,
 },
 MakeIronKnife = {
  Name = "Make iron knife", Station = "Workstation",
  Description = "Shape three iron into a knife.",
  Ingredients = {Iron = 3}, Output = "IronKnife", OutputCount = 1,
  MaxBatch = 1, Duration = 15, RequiresPresence = true,
 },
 BoilPotatoes = {
  Name = "Boil potatoes", Food=true, Station = "Stove",
  Description = "Boil potatoes using one bottle of clean water per potato.",
  Ingredients = {Potato = 1, CleanWater = 1}, Output = "BoiledPotato", OutputCount = 1, MaxBatch = 5, Duration = 60,
 },
 SliceSausage = {
  Name = "Slice sausage", Food=true, Station = "CuttingBoard",
  Description = "Slice a sausage into five pieces using a knife.",
  Ingredients = {Sausage = 1}, Output = "SausageSlice", OutputCount = 5,
  Tool = "Knife", MaxBatch = 1, Duration = 10, RequiresPresence = true,
 },
 MashedPotatoesWithSausage = {
  Name = "Mashed potatoes with sausage", Food=true, Station = "CuttingBoard",
  Description = "Prepare mashed potatoes with sausage using either type of plate.",
  Ingredients = {BoiledPotato = 1, SausageSlice = 1},
  Variants = {
   {Ingredient = "WoodenPlate", Output = "MashedPotatoesWithSausage_1"},
   {Ingredient = "Plate", Output = "MashedPotatoesWithSausage_2"},
  },
  OutputCount = 1, MaxBatch = 1, Duration = 20, RequiresPresence = true,
 },
}

-- Repair gates for tool tiers and workshop components, including iron recipes.
local repairByOutput={StoneAxe=60,StoneShovel=60,ScrapAxe=100,ScrapShovel=100,ScrapKnife=100,
 IronAxe=150,IronShovel=150,IronKnife=150,EmptyBucket=100,Handle=60,Plank=60}
for _,recipe in pairs(recipes) do
 local repair=repairByOutput[recipe.Output]
 if repair then
  recipe.Requirements=recipe.Requirements or {}
  recipe.Requirements.Skills=recipe.Requirements.Skills or {}
  recipe.Requirements.Skills.Repair=repair
  recipe.Description=recipe.Description:gsub(" Requires Repair %d+%.","").." Requires Repair "..repair.."."
 end
end

-- Character XP per finished result; sewing tools are reusable inventory requirements.
local outputXP={Plank=75,Handle=25,StoneAxe=50,StoneShovel=50,ScrapAxe=100,ScrapShovel=100,ScrapKnife=100,IronAxe=200,IronShovel=200,IronKnife=200,EmptyBucket=100}
for _,recipe in pairs(recipes) do
 if outputXP[recipe.Output] then recipe.XP=outputXP[recipe.Output] end
 if recipe.Ingredients.Cloth or recipe.Ingredients.Rags then recipe.Tool="SewingKit" end
end
recipes.BurnLogs.Description="Burn one to five logs into the same amount of charcoal. You may leave."
recipes.BurnLogsWithCoal.Description="Use one charcoal per batch to burn one to five logs faster. You may leave."
recipes.SmeltIron.Description="Smelt five scrap per iron, up to five iron per batch, using one charcoal. Requires a Workshop T2 furnace; you may leave."

-- Stove food is exclusively boiled; frying/baking belongs at another station.
-- Fuel is per queued batch, not per serving.
local charcoalVariants={}
for id,recipe in pairs(recipes) do
 if recipe.Station=="Stove" and (recipe.Food or recipe.Boiled) then
  recipe.Fuel={ID="TreeLog",Count=1};recipe.FuelTab="Wood";recipe.FuelByproducts={Coal=1}
  local coal=table.clone(recipe)
  coal.Fuel={ID="Coal",Count=1};coal.FuelTab="Coal";coal.FuelByproducts=nil;coal.Duration=recipe.Duration/2
  charcoalVariants[id.."Coal"]=coal
 end
end
for id,recipe in pairs(charcoalVariants) do recipes[id]=recipe end
return recipes
