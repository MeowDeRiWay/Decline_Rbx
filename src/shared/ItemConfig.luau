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
 Knife = {
  Name = "Knife", Weight = 0.3, Slot = "Hands", CraftTool = "Knife", CraftSpeed = 1,
  Description = "A knife from some store. Its sharp blade is good for slicing meat products.",
  Weapon = {Damage = 10, AttacksPerMinute = 40, DamageType = "Piercing", MaxUses = 500, CanDamageStructures = false, Range = 1.2, Width = 0.7, Thrust = 0.5},
  -- Optional HeldOffset = CFrame.new(x, y, z) * CFrame.Angles(rx, ry, rz),
  -- An Attachment named HandsGrip inside the character Body overrides this offset.
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
 MashedPotatoesWithSausage = {
  Name = "Mashed Potatoes with Sausage", Weight = 0.4,
  Description = "Mashed potatoes with sausage, served on a wooden plate.",
  Consume = {Food = 6, Water = -1, Sick = 0},
  ReturnItems = {WoodenPlate = 1},
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
