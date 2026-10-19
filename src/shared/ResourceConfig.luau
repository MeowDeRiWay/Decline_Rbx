return {
 Tree = {
  Templates = {"Tree_1", "Tree_2", "Tree_3"}, Folder = "Trees", Zone = "Forest",
  Health = 100, Tool = "Axe", MinHarvestTier = 1, Material = "Wood",
  SpawnChance = 0.01,
  RespawnMin = 30, RespawnMax = 300,
  Loot = {TreeLog = {Min = 1, Max = 4}},
 },
 StoneVein = {
  Templates = {"StoneVein"}, Folder = "StoneVeins", Zone = "StoneYard",
  Health = 100, Tool = "Shovel", MinHarvestTier = 1, Material = "Stone", SpawnChance = 0.01,
  RespawnMin = 30, RespawnMax = 300,
  Loot = {Stone = {Min = 1, Max = 5}},
 },
 ScrapPile = {
  Templates = {"PileScrap"}, Folder = "ScrapPiles", Zone = "ScrapYard",
  Health = 100, Tool = "Shovel", MinHarvestTier = 1, Material = "Metal",
  SpawnChance = 0.01,
  RespawnMin = 30, RespawnMax = 300,
  Loot = {Scrap = {Min = 1, Max = 5}, Rags = {Min = 1, Max = 5}},
 },
}
