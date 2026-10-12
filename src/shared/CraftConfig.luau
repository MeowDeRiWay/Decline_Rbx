-- Item IDs must exist in ItemConfig.luau. Time applies to the entire batch.
return {
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
