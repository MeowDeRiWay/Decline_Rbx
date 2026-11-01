-- Item IDs must exist in ItemConfig.luau. Time applies to the entire batch.
local recipes = {
 MakeExosuit={Name="Make exoskeleton",Station="ArmsBench",Description="Assemble an exoskeleton from four steel and four Kevlar. Requires Repair 175.",Ingredients={Steel=4,Kevlar=4},Output="Exosuit",OutputCount=1,MaxBatch=1,Duration=120,RequiresPresence=true,Requirements={Skills={Repair=175}}},
 MakeSterileBandage={Name="Make sterile bandage",Station="MedStation",Description="Sterilize one great bandage with one antiseptic. Requires First Aid 100.",Ingredients={GreatBandage=1,Antiseptic=1},Output="SterileBandage",OutputCount=1,Byproducts={EmptyBottle=1},MaxBatch=1,Duration=20,RequiresPresence=true,XP=100,Requirements={Skills={FirstAid=100}}},
 MakeAntiseptic={Name="Make antiseptic",Station="MedStation",Description="Prepare five antiseptic bottles from one clean water and one medical alcohol. Requires Doctor 50.",Ingredients={CleanWater=1,MedicalAlcohol=1},Output="Antiseptic",OutputCount=5,Byproducts={EmptyBottle=1},MaxBatch=1,Duration=60,RequiresPresence=true,XP=100,Requirements={Skills={Doctor=50}}},
 MakeBackpack1={Name="Make simple backpack",Station="Workstation",Description="Sew a simple backpack from three cloth. Requires Repair 50 and a reusable sewing kit in your inventory.",Ingredients={Cloth=3},Output="Backpack1",OutputCount=1,MaxBatch=1,Duration=60,RequiresPresence=true,Tool="SewingKit",Requirements={Skills={Repair=50}}},
 MakeLeatherArmor2={Name="Reinforce leather jacket",Station="Workstation",Description="Sew scrap plates into a leather jacket. Requires one leather jacket, five scrap, Repair 80 and a reusable sewing kit in your inventory.",Ingredients={LeatherArmor=1,Scrap=5},Output="LeatherArmor2",OutputCount=1,MaxBatch=1,Duration=60,RequiresPresence=true,Tool="SewingKit",Requirements={Skills={Repair=80}}},
 MakeLeatherArmor={Name="Make leather jacket",Station="Workstation",Description="Sew a leather jacket from six cloth. Requires Repair 60 and a reusable sewing kit in your inventory.",Ingredients={Cloth=6},Output="LeatherArmor",OutputCount=1,MaxBatch=1,Duration=60,RequiresPresence=true,Tool="SewingKit",Requirements={Skills={Repair=60}}},
 MakeKevlar={Name="Make Kevlar",Station="ArmsBench",Description="Treat five cloth with one chemical to produce five Kevlar. Requires Repair 100 and a reusable sewing kit in your inventory.",Ingredients={Cloth=5,Chemicals=1},Output="Kevlar",OutputCount=5,MaxBatch=1,Duration=60,RequiresPresence=true,Tool="SewingKit",Requirements={Skills={Repair=100}}},
 MakeMiliArmor1={Name="Make military armor",Station="ArmsBench",Description="Assemble military armor from six Kevlar and three iron. Requires Repair 100 and a reusable sewing kit in your inventory.",Ingredients={Kevlar=6,Iron=3},Output="MiliArmor1",OutputCount=1,MaxBatch=1,Duration=60,RequiresPresence=true,Tool="SewingKit",Requirements={Skills={Repair=100}}},
 MakeMiliArmor2={Name="Reinforce military armor",Station="ArmsBench",Description="Reinforce military armor with two Kevlar and three iron. Requires Repair 130 and a reusable sewing kit in your inventory.",Ingredients={MiliArmor1=1,Kevlar=2,Iron=3},Output="MiliArmor2",OutputCount=1,MaxBatch=1,Duration=60,RequiresPresence=true,Tool="SewingKit",Requirements={Skills={Repair=130}}},
 BoilWater={Name="Water purification",Station="Stove",Description="Boil one to five bottles of dirty water into clean water. One fuel per batch; no experience. You may leave.",Ingredients={DirtyWater=1},Output="CleanWater",OutputCount=1,MaxBatch=5,Duration=60,XP=0},
 MakePipePistol9mm={Name="Make 9 mm pipe pistol",Station="Workstation",Description="Assemble a single-shot pipe pistol. Requires Repair 50.",Ingredients={TreeLog=1,Scrap=3},Output="PipePistol9mm",OutputCount=1,MaxBatch=1,Duration=20,RequiresPresence=true,XP=100,Requirements={Skills={Repair=50}}},
 MakePipeRifle9mm={Name="Make 9 mm pipe rifle",Station="Workstation",Description="Assemble a single-shot pipe rifle. Requires Repair 50.",Ingredients={TreeLog=1,Scrap=5},Output="PipeRifle9mm",OutputCount=1,MaxBatch=1,Duration=30,RequiresPresence=true,XP=100,Requirements={Skills={Repair=50}}},
 MakePistol9mm={Name="Make 9 mm pistol",Station="Workstation",Description="Assemble a 9 mm pistol. Requires Repair 75.",Ingredients={Plank=1,Scrap=3},Output="Pistol9mm",OutputCount=1,MaxBatch=1,Duration=60,RequiresPresence=true,XP=200,Requirements={Skills={Repair=75}}},
 MakeSMG9mm={Name="Make 9 mm submachine gun",Station="Workstation",Description="Assemble a 9 mm submachine gun. Requires Repair 90.",Ingredients={Plank=1,Scrap=5},Output="SMG9mm",OutputCount=1,MaxBatch=1,Duration=90,RequiresPresence=true,XP=200,Requirements={Skills={Repair=90}}},
 MakeAmmo9mm={Name="Make 9 mm FMJ ammunition",Station="Workstation",Description="Produce 30 standard 9 mm rounds in 30 seconds. Requires Repair 50.",Ingredients={Coal=1,Chemicals=1,Scrap=1},Output="Ammo9mmFMJ",OutputCount=30,MaxBatch=1,Duration=30,RequiresPresence=true,XP=100,Requirements={Skills={Repair=50}}},
 BurnLogs={FuelTab="Wood",Name="Burn logs into charcoal",Station="Stove",Stations={"Stove","Furnace"},Description="Burn one log into one charcoal in 10 seconds. Collect the finished batch before starting again.",Ingredients={TreeLog=1},Output="Coal",OutputCount=1,MaxBatch=1,Duration=10,XP=15},
 BurnWoodParts={FuelTab="Wood",Name="Burn planks or handles into charcoal",Station="Stove",Stations={"Stove","Furnace"},Description="Burn any combination of three planks or handles into one charcoal in 10 seconds. Collect the finished batch before starting again.",Ingredients={},IngredientGroups={{IDs={"Plank","Handle"},Count=3}},Output="Coal",OutputCount=1,MaxBatch=1,Duration=10,XP=15},
 MakeSurgicalKit={Name="Make surgical kit",Station="Workstation",Category="Tools",Description="Make a reusable surgical kit from one iron. Requires Repair 100.",Ingredients={Iron=1},Output="SurgicalKit",OutputCount=1,MaxBatch=1,Duration=20,RequiresPresence=true,XP=100,Requirements={Skills={Repair=100}}},
 MakePlate={Name="Make plate",Station="Workstation",Description="Make an ordinary plate from one plank. Requires Repair 25.",Ingredients={Plank=1},Output="Plate",OutputCount=1,MaxBatch=1,Duration=20,RequiresPresence=true,XP=25,Requirements={Skills={Repair=25}}},
 SmeltIron={Name="Smelt iron",Station="Furnace",WorkshopLevel=2,Description="Smelt 25 scrap with one charcoal into five iron. Requires a Workshop T2 furnace; you may leave.",Ingredients={Scrap=2},Fuel={ID="Coal",Count=1},Output="Iron",OutputCount=1,MaxBatch=5,Duration=120},
 MakeAmmo223={Name="Make .223 FMJ ammunition",Station="Workstation",Description="Produce 30 standard .223 rounds in 30 seconds. Requires Repair 100.",Ingredients={Iron=1,Coal=1,Chemicals=1},Output="Ammo223FMJ",OutputCount=30,MaxBatch=1,Duration=30,RequiresPresence=true,XP=200,Requirements={Skills={Repair=100}}},
 MakeRifle223={Name="Make .223 bolt-action rifle",Station="Workstation",Description="Assemble a .223 bolt-action rifle. Requires Repair 100.",Ingredients={Iron=5,Plank=2},Output="Rifle223",OutputCount=1,MaxBatch=1,Duration=120,RequiresPresence=true,XP=500,Requirements={Skills={Repair=100}}},
 MakeAssaultRifle223={Name="Make .223 assault rifle",Station="ArmsBench",Description="Assemble a .223 assault rifle. Requires Repair 120.",Ingredients={Iron=5,Plank=2},Output="AssaultRifle223",OutputCount=1,MaxBatch=1,Duration=120,RequiresPresence=true,XP=500,Requirements={Skills={Repair=120}}},
 MakeLSW223={Name="Make .223 light support weapon",Station="ArmsBench",Description="Assemble a .223 light support weapon. Requires Repair 140.",Ingredients={Iron=7,Plank=2},Output="LSW223",OutputCount=1,MaxBatch=1,Duration=120,RequiresPresence=true,XP=500,Requirements={Skills={Repair=140}}},
 MakeServiceRifle223={Name="Make .223 service rifle",Station="ArmsBench",Description="Assemble a .223 service rifle. Requires Repair 110.",Ingredients={Iron=5,Plank=2},Output="ServiceRifle223",OutputCount=1,MaxBatch=1,Duration=120,RequiresPresence=true,XP=500,Requirements={Skills={Repair=110}}},
 MakeMarksmanRifle223={Name="Make Enfild X7",Station="ArmsBench",Description="Assemble a Enfild X7. Requires Repair 130.",Ingredients={Iron=7,Plank=2},Output="MarksmanRifle223",OutputCount=1,MaxBatch=1,Duration=120,RequiresPresence=true,XP=500,Requirements={Skills={Repair=130}}},
 MakeBucket={Name="Make empty bucket",Station="Workstation",Description="Shape scrap into a watering bucket. Requires Repair 50.",Ingredients={Scrap=3},Output="EmptyBucket",OutputCount=1,MaxBatch=1,Duration=20,RequiresPresence=true,Requirements={Skills={Repair=50}}},
 MakeBandage={Name="Make bandage",Station="MedStation",Description="Prepare a bandage from two rags at a medical station. Requires First Aid 50.",Ingredients={Rags=2},Output="Bandage",OutputCount=1,MaxBatch=1,Duration=20,RequiresPresence=true,XP=50,Requirements={Skills={FirstAid=50}}},
 MakeSewingKit={Name="Make sewing kit",Station="Workstation",Description="Make a reusable sewing kit from five scrap. Requires Repair 50.",Ingredients={Scrap=5},Output="SewingKit",OutputCount=1,MaxBatch=1,Duration=20,RequiresPresence=true,Requirements={Skills={Repair=50}}},
 MakeCloth={Name="Make cloth",Station="MedStation",Description="Sew two rags into one cloth using a sewing kit.",Ingredients={Rags=2},Output="Cloth",OutputCount=1,MaxBatch=1,Duration=20,RequiresPresence=true,XP=25},
 MakeGreatBandage={Name="Make great bandage",Station="MedStation",Description="Prepare a great bandage from two cloth. Requires First Aid 75.",Ingredients={Cloth=2},Output="GreatBandage",OutputCount=1,MaxBatch=1,Duration=20,RequiresPresence=true,XP=100,Requirements={Skills={FirstAid=75}}},
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
 MakeSteelAxe={Name="Make steel axe",Station="Workstation",Description="Assemble a steel axe using a handle and three steel.",Ingredients={Handle=1,Steel=3},Output="SteelAxe",OutputCount=1,MaxBatch=1,Duration=20,RequiresPresence=true,XP=200},
 MakeSteelShovel={Name="Make steel shovel",Station="Workstation",Description="Assemble a steel shovel using a handle and three steel.",Ingredients={Handle=1,Steel=3},Output="SteelShovel",OutputCount=1,MaxBatch=1,Duration=20,RequiresPresence=true,XP=200},
 MakeSteelKnife={Name="Make steel knife",Station="Workstation",Description="Shape three steel into a knife.",Ingredients={Steel=3},Output="SteelKnife",OutputCount=1,MaxBatch=1,Duration=15,RequiresPresence=true,XP=200},
 SmeltSteel={Name="Smelt steel",Station="Furnace",WorkshopLevel=2,Description="Refine one iron per steel, up to five steel per batch, using one charcoal. Requires Repair 150 and a Workshop T2 furnace; you may leave.",Ingredients={Iron=1},Fuel={ID="Coal",Count=1},Output="Steel",OutputCount=1,MaxBatch=5,Duration=60,XP=100,Requirements={Skills={Repair=150}}},
 BoilPotatoes = {
  Name = "Boil potatoes", Food=true, Station = "Stove",
  Description = "Boil potatoes using one bottle of clean water per potato. Requires Cook 50.",
  Ingredients = {Potato = 1, CleanWater = 1}, Output = "BoiledPotato", OutputCount = 1, MaxBatch = 5, Duration = 60,
  Requirements = {Skills = {Cook = 50}},
 },
 SliceSausage = {
  Name = "Slice sausage", Food=true, Station = "CuttingBoard",
  Description = "Slice a sausage into five pieces using a knife. Requires Cook 50.",
  Ingredients = {Sausage = 1}, Output = "SausageSlice", OutputCount = 5,
  Tool = "Knife", MaxBatch = 1, Duration = 10, RequiresPresence = true,
  Requirements = {Skills = {Cook = 50}},
 },
 MashedPotatoesWithSausage = {
  Name = "Mashed potatoes with sausage", Food=true, Station = "CuttingBoard",
  Description = "Prepare mashed potatoes with sausage on an ordinary plate. Requires Cook 60.",
  Ingredients = {BoiledPotato = 1, SausageSlice = 1, Plate = 1},
  Output = "MashedPotatoesWithSausage_2",
  OutputCount = 1, MaxBatch = 1, Duration = 20, RequiresPresence = true,
  Requirements = {Skills = {Cook = 60}},
 },
}

-- Repair gates for tool tiers and workshop components, including iron recipes.
local repairByOutput={ScrapAxe=50,ScrapShovel=50,ScrapKnife=50,
 IronAxe=100,IronShovel=100,IronKnife=100,SteelAxe=150,SteelShovel=150,SteelKnife=150,EmptyBucket=50,Handle=50,Plank=50}
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
local outputXP={Plank=75,Handle=25,ScrapAxe=100,ScrapShovel=100,ScrapKnife=100,IronAxe=200,IronShovel=200,IronKnife=200,EmptyBucket=100}
for _,recipe in pairs(recipes) do
 if outputXP[recipe.Output] then recipe.XP=outputXP[recipe.Output] end
 if recipe.Ingredients.Cloth or recipe.Ingredients.Rags then recipe.Tool="SewingKit" end
end
recipes.SmeltIron.Description="Smelt five scrap per iron, up to five iron per batch, using one charcoal. Requires a Workshop T2 furnace; you may leave."

-- Stove/furnace processes always use one complete, manually collected batch.
for _,recipe in pairs(recipes) do
 if recipe.Station=="Stove" or recipe.Station=="Furnace" then
  local batch=recipe.MaxBatch or 1
  for id,count in pairs(recipe.Ingredients) do recipe.Ingredients[id]=count*batch end
  recipe.OutputCount=(recipe.OutputCount or 1)*batch
  recipe.XP=(recipe.XP or 50)*batch
  recipe.MaxBatch=1;recipe.ManualBatch=true
 end
end
recipes.BoilPotatoes.Ingredients={Potato=5,CleanWater=1}
recipes.BoilPotatoes.Description="Boil five potatoes with one bottle of clean water. One fuel per process; collect the finished batch before starting again. Requires Cook 50."
-- One charcoal-only purification recipe: no log variant or coal byproduct.
recipes.BoilWater.Ingredients={DirtyWater=5,Coal=1}
recipes.BoilWater.FuelTab="Coal"
recipes.BoilWater.Requirements={Skills={Doctor=50}}
recipes.BoilWater.Description="Purify five bottles of dirty water with one charcoal into five bottles of clean water. Requires Doctor 50. Collect the finished batch before starting again."
recipes.SmeltIron.Description="Smelt 10 scrap into five iron using one charcoal. Requires a Workshop T2 furnace. Collect the finished batch before starting again."
recipes.SmeltSteel.Description="Refine five iron into five steel using one charcoal. Requires Repair 150 and a Workshop T2 furnace. Collect the finished batch before starting again."

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
-- Separate medical filtration from stove boiling; coal is charged once.
local filtered=table.clone(recipes.BoilWater)
filtered.Name="Filter water";filtered.Station="MedStation";filtered.FuelTab=nil
filtered.Description="Filter five bottles of dirty water with one charcoal into five bottles of clean water. Requires Doctor 50. Collect the finished batch before starting again."
recipes.FilterWater=filtered
recipes.BoilWater.Requirements={Skills={Cook=50}}
recipes.BoilWater.Name="Boil water"
recipes.BoilWater.Description="Boil five bottles of dirty water with one charcoal into five bottles of clean water. Requires Cook 50. Collect the finished batch before starting again."
local woodWater=table.clone(recipes.BoilWater)
woodWater.Ingredients={DirtyWater=5,TreeLog=1};woodWater.FuelTab="Wood"
woodWater.Description="Boil five bottles of dirty water with one log into five bottles of clean water. Requires Cook 50. Collect the finished batch before starting again."
recipes.BoilWaterWood=woodWater
-- Heat-processing stations run unattended queues with automatic delivery.
for _,recipe in pairs(recipes) do
 if recipe.Station=="Stove" or recipe.Station=="Furnace" then
  recipe.ManualBatch=nil;recipe.FixedBatch=true;recipe.Automated=true
  recipe.Description=recipe.Description:gsub("Collect the finished batch before starting again%.","Results are delivered automatically.")
  recipe.Description=recipe.Description:gsub("collect the finished batch before starting again%.","results are delivered automatically.")
 end
end
return recipes
