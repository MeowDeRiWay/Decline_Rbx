return {
 Tree = {
  Templates = {"Tree_1", "Tree_2", "Tree_3"}, Zone = "Forest",
  Health = 100, Tool = "Axe", Material = "Wood",
  MinCount = 1, MaxCount = 20, Spacing = 8, EdgeMargin = 3,
  RespawnMin = 30, RespawnMax = 300,
  Loot = {TreeLog = {Min = 1, Max = 4}},
 },
 ScrapPile = {
  Templates = {"PileScrap"}, Zone = "ScrapYard",
  Health = 100, Tool = "Shovel", Material = "Metal",
  MinCount = 1, MaxCount = 20, Spacing = 1, EdgeMargin = 3,
  RespawnMin = 30, RespawnMax = 300,
  Loot = {Scrap = {Min = 1, Max = 5}, Rags = {Min = 1, Max = 5}},
 },
}
