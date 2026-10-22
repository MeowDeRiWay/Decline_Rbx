-- Independent category rolls. Water chooses exactly one bottle type on success.
-- Chance is a fraction; item IDs must match ItemConfig.luau.
return {
 Water = {Chance = .05, Min = 1, Max = 1, Choices = {"CleanWater", "DirtyWater"}},
 Ammo9mmFMJ = {Chance = .05, Min = 1, Max = 50},
 Sausage = {Chance = .01, Min = 1, Max = 1},
 Rags = {Chance = .15, Min = 1, Max = 3},
 Stone = {Chance = .10, Min = 1, Max = 3},
}
