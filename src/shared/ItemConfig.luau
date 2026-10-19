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
 Apron = {Name = "Apron", Weight = 0.5, Slot = "Additional", Description = "An apron worn over clothing."},
 Cloth = {Name = "Cloth", Weight = 0.05, Description = "A piece of cloth recovered from a creature."},
 Rags = {
  Name = "Rags", Weight = 0.05,
  Description = "Pieces of old fabric salvaged from scrap piles.",
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
-- Tier is progression/access; HarvestMultiplier scales damage only to resource nodes.
for tier,material in ipairs({"Stone","Scrap","Iron"}) do
 for _,tool in ipairs({"Axe","Showel"}) do
  local axe=tool=="Axe"
  ItemConfig.Items[material..tool]={
   Name=material..(axe and " Axe" or " Shovel"), Weight=axe and 1.5 or 2,
   Slot="Hands", HarvestTool=axe and "Axe" or "Shovel", HarvestTier=tier, HarvestMultiplier=tier,
   Description=axe and "An axe for chopping trees into logs." or "A shovel for digging resource deposits.",
   Weapon={Damage=5, AttacksPerMinute=25, DamageType=axe and "Slashing" or "Blunt", MaxUses=1000,
    CanDamageStructures=false, Range=1, Width=1, Animation="SwingLeft"},
  }
 end
end
for _,material in ipairs({"Scrap","Iron"}) do
 ItemConfig.Items[material.."Knife"]={
  Name=material.." Knife", Weight=.3, Slot="Hands", CraftTool="Knife", CraftSpeed=1,
  Description="A sharp knife for combat and slicing food.",
  Weapon={Damage=material=="Iron" and 20 or 10, AttacksPerMinute=40, DamageType="Piercing", MaxUses=500,
   CanDamageStructures=false, Range=1.2, Width=.7, Thrust=.5},
 }
end
-- Compatibility for already placed legacy models; new recipes use explicit material IDs.
ItemConfig.Items.Axe=ItemConfig.Items.StoneAxe
ItemConfig.Items.Showel=ItemConfig.Items.StoneShowel
ItemConfig.Items.Knife=ItemConfig.Items.ScrapKnife
return ItemConfig

