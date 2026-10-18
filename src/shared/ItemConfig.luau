-- Every new item must be registered here before any system grants it.
-- IDs are stable internal keys; Name is the English name shown in the UI.
local ItemConfig = {}
ItemConfig.PickupDistance = 1
ItemConfig.Slots = {"Head", "Body", "Hands", "Back", "Additional"}
ItemConfig.Items = {
 ZombieHand = {
  Name = "Zombie Hand", Weight = 0, Slot = "Hands", Lootable = false,
  Description = "A zombie's right hand.",
  Weapon = {Damage = 5, AttacksPerMinute = 10, DamageType = "Blunt", MaxUses = 1000, CanDamageStructures = false, Range = 1, Width = 1, Animation = "SwingLeft"},
 },
 Axe = {
  Name = "Axe", Weight = 1.5, Slot = "Hands", HarvestTool = "Axe",
  Description = "A stone axe for chopping trees into logs.",
  Weapon = {Damage = 20, AttacksPerMinute = 25, DamageType = "Slashing", MaxUses = 1000, CanDamageStructures = false, Range = 1, Width = 1, Animation = "SwingLeft"},
 },
 Showel = {
  Name = "Shovel", Weight = 2, Slot = "Hands", HarvestTool = "Shovel",
  Description = "A stone shovel for digging stone veins and collecting scrap and rags.",
  Weapon = {Damage = 20, AttacksPerMinute = 25, DamageType = "Blunt", MaxUses = 1000, CanDamageStructures = false, Range = 1, Width = 1, Animation = "SwingLeft"},
 },
 TreeLog = {
  Name = "Tree Log", Weight = 2,
  Description = "A heavy wooden log cut from a tree.",
  ResourceMaterial = "Wood",
 },
 Plank = {
  Name = "Plank", Weight = 0.6, ResourceMaterial = "Wood",
  Description = "A wooden plank cut from a log. Used for construction and crafting.",
 },
 Handle = {
  Name = "Handle", Weight = 0.3, ResourceMaterial = "Wood",
  Description = "A wooden handle for crafting tools.",
 },
 Stone = {
  Name = "Stone", Weight = 0.2, ResourceMaterial = "Stone",
  Description = "Stone dug from a stone vein. Used for crafting stone tools.",
 },
 Scrap = {
  Name = "Scrap", Weight = 0.2,
  Description = "Salvaged scrap metal.",
 },
 Rags = {
  Name = "Rags", Weight = 0.05,
  Description = "Pieces of old fabric salvaged from scrap piles.",
 },
 Knife = {
  Name = "Knife", Weight = 0.3, Slot = "Hands", CraftTool = "Knife", CraftSpeed = 1,
  Description = "A stone knife with a sharp edge for slicing meat products.",
  Weapon = {Damage = 10, AttacksPerMinute = 40, DamageType = "Piercing", MaxUses = 500, CanDamageStructures = false, Range = 1.2, Width = 0.7, Thrust = 0.5},
  -- Optional HeldOffset = CFrame.new(x, y, z) * CFrame.Angles(rx, ry, rz),
  -- An Attachment named HandsGrip inside the character Body overrides this offset.
 },
 EmptyBottle = {
  Name = "Empty Bottle", Weight = 0.1,
  Description = "An empty half-litre bottle.",
 },
 DirtyWater = {
  Name = "Dirty Water", Weight = 0.6, ConsumeAction = "Drink",
  Description = "A bottle of dirty water. Quenches thirst but increases sickness.",
  Consume = {Water = 30, Sick = 20},
  ReturnItems = {EmptyBottle = 1},
 },
 CleanWater = {
  Name = "Clean Water", Weight = 0.6, ConsumeAction = "Drink",
  Description = "A bottle of clean water. Can be drunk or used to boil potatoes.",
  Consume = {Water = 50},
  ReturnItems = {EmptyBottle = 1},
 },
 Plate = {
  Name = "Plate", Weight = 0.2,
  Description = "An ordinary plate for serving meals.",
 },
 WoodenPlate = {
  Name = "Wooden Plate", Weight = 0.1,
  Description = "A wooden plate for serving meals.",
 },
 Sausage = {
  Name = "Sausage", Weight = 0.5,
  Description = "A whole sausage. It can be sliced on a cutting board.",
  Consume = {Food = 5, Water = -5, Sick = 0},
 },
 SausageSlice = {
  Name = "Sausage Slice", Weight = 0.1,
  Description = "One of five slices from a sausage.",
  Consume = {Food = 1, Water = -1, Sick = 0},
 },
 MashedPotatoesWithSausage_1 = {
  Name = "Mashed Potatoes with Sausage (Wooden Plate)", Weight = 0.4,
  Description = "Mashed potatoes with sausage, served on a wooden plate.",
  Consume = {Food = 6, Water = -1, Sick = 0},
  ReturnItems = {WoodenPlate = 1},
 },
 MashedPotatoesWithSausage_2 = {
  Name = "Mashed Potatoes with Sausage (Plate)", Weight = 0.5,
  Description = "Mashed potatoes with sausage, served on an ordinary plate.",
  Consume = {Food = 6, Water = -1, Sick = 0},
  ReturnItems = {Plate = 1},
 },
 BoiledPotato = {
  Name = "Boiled Potato", Weight = 0.2,
  Description = "A tasty boiled potato. Maybe I could make something else with it?",
  Consume = {Food = 5, Sick = 0},
 },
 Potato = {
  Name = "Potato", Weight = 0.2,
  Description = "An ordinary raw potato. I recommend cooking it before eating.",
  Consume = {Food = 1, Sick = 5},
 },
 -- Example (remove the comment when you have this item):
 -- SmallBackpack = {Name = "Small Backpack", Weight = 1.5, Slot = "Back"},
 -- Metal = {Name = "Metal", Weight = 0.2},
}
return ItemConfig

