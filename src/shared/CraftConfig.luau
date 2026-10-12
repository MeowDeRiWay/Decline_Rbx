-- Item IDs must exist in ItemConfig.luau. Time applies to the entire batch.
return {
 BoilPotatoes = {
  Name = "Boil potatoes", Station = "Stove",
  Description = "Boil potatoes into a nutritious meal.",
  Ingredients = {Potato = 1}, Output = "BoiledPotato", OutputCount = 1, MaxBatch = 5, Duration = 60,
 },
 SliceSausage = {
  Name = "Slice sausage", Station = "CuttingBoard",
  Description = "Slice a sausage into five pieces using a knife.",
  Ingredients = {Sausage = 1}, Output = "SausageSlice", OutputCount = 5,
  Tool = "Knife", MaxBatch = 5, Duration = 30,
 },
 MashedPotatoesWithSausage_1 = {
  Name = "Mashed Potatoes with Sausage (Wooden Plate)", Station = "Stove",
  Description = "Prepare mashed potatoes with sausage on a wooden plate.",
  Ingredients = {BoiledPotato = 1, SausageSlice = 1, WoodenPlate = 1},
  Output = "MashedPotatoesWithSausage_1", OutputCount = 1, MaxBatch = 5, Duration = 60,
 },
 MashedPotatoesWithSausage_2 = {
  Name = "Mashed Potatoes with Sausage (Plate)", Station = "Stove",
  Description = "Prepare mashed potatoes with sausage on an ordinary plate.",
  Ingredients = {BoiledPotato = 1, SausageSlice = 1, Plate = 1},
  Output = "MashedPotatoesWithSausage_2", OutputCount = 1, MaxBatch = 5, Duration = 60,
 },
}
