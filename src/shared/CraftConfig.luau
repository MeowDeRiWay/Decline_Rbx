-- Item IDs must exist in ItemConfig.luau. Time applies to the entire batch.
return {
 MakePlanks = {
  Name = "Make planks", Station = "Workstation",
  Description = "Cut one tree log into three planks.",
  Ingredients = {TreeLog = 1}, Output = "Plank", OutputCount = 3,
  MaxBatch = 5, Duration = 10, RequiresPresence = true,
 },
 MakeHandle = {
  Name = "Make handle", Station = "Workstation",
  Description = "Shape one plank into a tool handle.",
  Ingredients = {Plank = 1}, Output = "Handle", OutputCount = 1,
  MaxBatch = 5, Duration = 10, RequiresPresence = true,
 },
 MakeAxe = {
  Name = "Make stone axe", Station = "Workstation",
  Description = "Assemble an axe using a handle and three stones.",
  Ingredients = {Handle = 1, Stone = 3}, Output = "StoneAxe", OutputCount = 1,
  MaxBatch = 5, Duration = 20, RequiresPresence = true,
 },
 MakeShovel = {
  Name = "Make stone shovel", Station = "Workstation",
  Description = "Assemble a shovel using a handle and three stones.",
  Ingredients = {Handle = 1, Stone = 3}, Output = "StoneShowel", OutputCount = 1,
  MaxBatch = 5, Duration = 20, RequiresPresence = true,
 },
 MakeScrapAxe = {
  Name = "Make scrap axe", Station = "Workstation",
  Description = "Assemble a scrap axe using a handle and three pieces of scrap.",
  Ingredients = {Handle = 1, Scrap = 3}, Output = "ScrapAxe", OutputCount = 1,
  MaxBatch = 5, Duration = 20, RequiresPresence = true,
 },
 MakeScrapShovel = {
  Name = "Make scrap shovel", Station = "Workstation",
  Description = "Assemble a scrap shovel using a handle and three pieces of scrap.",
  Ingredients = {Handle = 1, Scrap = 3}, Output = "ScrapShowel", OutputCount = 1,
  MaxBatch = 5, Duration = 20, RequiresPresence = true,
 },
 MakeKnife = {
  Name = "Make scrap knife", Station = "Workstation",
  Description = "Shape three pieces of scrap into a knife.",
  Ingredients = {Scrap = 3}, Output = "ScrapKnife", OutputCount = 1,
  MaxBatch = 5, Duration = 15, RequiresPresence = true,
 },
 BoilPotatoes = {
  Name = "Boil potatoes", Station = "Stove",
  Description = "Boil potatoes using one bottle of clean water per potato.",
  Ingredients = {Potato = 1, CleanWater = 1}, Output = "BoiledPotato", OutputCount = 1, MaxBatch = 5, Duration = 60,
 },
 SliceSausage = {
  Name = "Slice sausage", Station = "CuttingBoard",
  Description = "Slice a sausage into five pieces using a knife.",
  Ingredients = {Sausage = 1}, Output = "SausageSlice", OutputCount = 5,
  Tool = "Knife", MaxBatch = 1, Duration = 10, RequiresPresence = true,
 },
 MashedPotatoesWithSausage = {
  Name = "Mashed Potatoes with Sausage", Station = "CuttingBoard",
  Description = "Prepare mashed potatoes with sausage using either type of plate.",
  Ingredients = {BoiledPotato = 1, SausageSlice = 1},
  Variants = {
   {Ingredient = "WoodenPlate", Output = "MashedPotatoesWithSausage_1"},
   {Ingredient = "Plate", Output = "MashedPotatoesWithSausage_2"},
  },
  OutputCount = 1, MaxBatch = 1, Duration = 20, RequiresPresence = true,
 },
}
