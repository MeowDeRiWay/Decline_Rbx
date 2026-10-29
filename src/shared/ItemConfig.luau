-- Every new item must be registered here before any system grants it.
-- IDs are stable internal keys; Name is the English name shown in the UI.
local ItemConfig = {}
ItemConfig.PickupDistance = 2
ItemConfig.Slots = {"Body", "Hands", "Back", "Additional", "Medicine"}
ItemConfig.Items = {
 Money = {Name="Banknote",Weight=0,Currency=true,Description="Money is credited directly to your protected account when picked up."},
 ZombieHand = {
  Name = "Zombie hand", Weight = 0, Slot = "Hands", Lootable = false,
  Description = "A zombie's right hand.",
  Weapon = {Damage = 5, AttacksPerMinute = 10, DamageType = "Blunt", MaxUses = 1000, CanDamageStructures = false, Range = 1, Width = 1, Animation = "SwingLeft"},
 },
 TreeLog = {
  Name = "Tree log", Weight = 2,
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
 Coal = {Name="Charcoal",Weight=.2,Description="Charcoal made by burning tree logs. Used for smelting and ammunition."},
 Chemicals = {Name="Chemicals",Weight=.2,Description="Scavenged chemical compounds used to produce ammunition."},
 Iron = {Name="Iron",Weight=1,ResourceMaterial="Iron",Description="Smelted iron used for industrial firearms and ammunition."},
 LeatherArmor2={Name="Reinforced leather jacket",Weight=3,Slot="Body",Armor={Absorption=4,Resistance=.15},Description="A leather jacket reinforced with scrap plates: 4 damage absorption and 15% damage resistance."},
 LeatherArmor={Name="Leather jacket",Weight=2,Slot="Body",Armor={Absorption=2,Resistance=.1},Description="A leather jacket offering light protection: 2 damage absorption and 10% damage resistance."},
 Apron = {Name = "Apron", Weight = 0.5, Slot = "Additional", Description = "An apron worn over clothing."},
 SewingKit={Name="Sewing kit",Weight=0.2,CraftTool="SewingKit",CraftSpeed=1,Description="A reusable tool required to craft items from cloth and rags. Keep it in your inventory."},
 Cloth = {
  Name = "Cloth", Weight = 0.2,
  Description = "Fabric used for construction and crafting.",
 },
 Rags = {
  Name = "Rags", Weight = 0.05,
  Description = "Pieces of old fabric salvaged from scrap piles.",
 },
 EmptyBottle = {
  Name = "Empty bottle", Weight = 0.1,
  Description = "An empty half-litre bottle.",
 },
 DirtyWater = {
  Name = "Dirty water", Weight = 0.6, ConsumeAction = "Drink", EmptyContainer="EmptyBottle",
  Description = "A bottle of dirty water. Quenches thirst but increases sickness.",
  Consume = {Water = 30, Sick = 20},
  ReturnItems = {EmptyBottle = 1},
 },
 CleanWater = {
  Name = "Clean water", Weight = 0.6, ConsumeAction = "Drink", EmptyContainer="EmptyBottle",
  Description = "A bottle of clean water. Can be drunk or used to boil potatoes.",
  Consume = {Water = 50},
  ReturnItems = {EmptyBottle = 1},
 },
 Plate = {
  Name = "Plate", Weight = 0.2,
  Description = "An ordinary plate for serving meals.",
 },
 WoodenPlate = {
  Name = "Wooden plate", Weight = 0.1,
  Description = "A wooden plate for serving meals.",
 },
 Sausage = {
  Name = "Sausage", Weight = 0.5,
  Description = "A whole sausage. It can be sliced on a cutting board.",
  Consume = {Food = 5, Water = -5, Sick = 0},
 },
 SausageSlice = {
  Name = "Sausage slice", Weight = 0.1,
  Description = "One of five slices from a sausage.",
  Consume = {Food = 1, Water = -1, Sick = 0},
 },
 MashedPotatoesWithSausage_1 = {
  Name = "Mashed potatoes with sausage (wooden plate)", Weight = 0.4,
  Description = "Mashed potatoes with sausage, served on a wooden plate.",
  Consume = {Food = 6, Water = -1, Sick = 0},
  ReturnItems = {WoodenPlate = 1},
 },
 MashedPotatoesWithSausage_2 = {
  Name = "Mashed potatoes with sausage (plate)", Weight = 0.5,
  Description = "Mashed potatoes with sausage, served on an ordinary plate.",
  Consume = {Food = 6, Water = -1, Sick = 0},
  ReturnItems = {Plate = 1},
 },
 BoiledPotato = {
  Name = "Boiled potato", Weight = 0.2,
  Description = "A tasty boiled potato. Maybe I could make something else with it?",
  Consume = {Food = 5, Sick = 0},
 },
 Potato = {
  Name = "Potato", Weight = 0.2,
  Description = "An ordinary raw potato. I recommend cooking it before eating.",
  Consume = {Food = 1, Sick = 5},
 },
 -- Example (remove the comment when you have this item):
 -- SmallBackpack = {Name = "Small backpack", Weight = 1.5, Slot = "Back"},
 -- Metal = {Name = "Metal", Weight = 0.2},
}
-- Tier is progression/access; HarvestMultiplier scales damage only to resource nodes.
for tier,material in ipairs({"Stone","Scrap","Iron"}) do
 for _,tool in ipairs({"Axe","Showel"}) do
  local axe=tool=="Axe"
  ItemConfig.Items[material..tool]={
   Name=material..(axe and " axe" or " shovel"), Weight=axe and 1.5 or 2,
   Slot="Hands", HarvestTool=axe and "Axe" or "Shovel", HarvestTier=tier, HarvestMultiplier=tier,
   Description=axe and "An axe for chopping trees into logs." or "A shovel for digging resource deposits.",
   Weapon={Damage=5, AttacksPerMinute=25, DamageType=axe and "Slashing" or "Blunt", MaxUses=1000,
    CanDamageStructures=false, Range=1, Width=1, Animation=axe and "Chop" or "Thrust"},
  }
 end
end
for _,material in ipairs({"Scrap","Iron"}) do
 ItemConfig.Items[material.."Knife"]={
  Name=material.." knife", Weight=.3, Slot="Hands", CraftTool="Knife", CraftSpeed=1,
  Description="A sharp knife for combat and slicing food.",
  Weapon={Damage=material=="Iron" and 20 or 10, AttacksPerMinute=40, DamageType="Piercing", MaxUses=500,
   CanDamageStructures=false, Range=1.2, Width=.7, Thrust=.5},
 }
end
-- Correct shovel spelling while retaining old inventory IDs and authored templates.
for _,material in ipairs({"Stone","Scrap","Iron"}) do
 local shovel=ItemConfig.Items[material.."Showel"]
 shovel.TemplateID=material.."Shovel"
 ItemConfig.Items[material.."Shovel"]=shovel
end
-- Compatibility for already placed legacy models; new recipes use explicit material IDs.
ItemConfig.Items.Axe=ItemConfig.Items.StoneAxe
ItemConfig.Items.Showel=ItemConfig.Items.StoneShowel
ItemConfig.Items.Knife=ItemConfig.Items.ScrapKnife
ItemConfig.Items.AssaultRifle223={Name=".223 assault rifle",Weight=3.2,Slot="Hands",Description="Automatic rifle. R reloads available ammo; B selects FMJ/AP; V switches fire mode.",
 Firearm={Category="Automatic",Skill="LightWeapons",HoldHeightRatio=.4,Caliber="223",ShotDistance=80,Magazine=24,ReloadTime=2.5,Speed=750,Range=350,Damage=23,DamageMin=19,DamageMax=23,RPM=600},
 Weapon={Damage=23,DamageMin=19,DamageMax=23,DamageType="Bullet",MaxUses=3000,AttacksPerMinute=600}}
ItemConfig.Items.ServiceRifle223={Name=".223 service rifle",Weight=3.2,Slot="Hands",Description="Semi-automatic service rifle. R reloads available ammo; B selects FMJ/AP.",
 Firearm={Category="Rifle",Skill="LightWeapons",SingleOnly=true,BoltAction=false,HoldHeightRatio=.4,Caliber="223",ShotDistance=80,Magazine=20,ReloadTime=2.5,Speed=750,Range=350,Damage=25,DamageMin=21,DamageMax=25,RPM=300},
 Weapon={Damage=25,DamageMin=21,DamageMax=25,DamageType="Bullet",MaxUses=3000,AttacksPerMinute=300}}
ItemConfig.Items.LSW223={Name=".223 light support weapon",Weight=6,Slot="Hands",Description="Automatic light support weapon. R reloads available ammo; B selects FMJ/AP; V switches fire mode.",
 Firearm={Category="MachineGun",Skill="HeavyWeapons",HoldHeightRatio=.4,Caliber="223",ShotDistance=80,Magazine=30,ReloadTime=2.5,Speed=750,Range=350,Damage=22,DamageMin=18,DamageMax=22,RPM=700},
 Weapon={Damage=22,DamageMin=18,DamageMax=22,DamageType="Bullet",MaxUses=3000,AttacksPerMinute=700}}
ItemConfig.Items.Rifle223={Name=".223 bolt-action rifle",Weight=3.2,Slot="Hands",
 Description="Bolt-action rifle. R reloads available ammo; B selects FMJ/AP.",
 Firearm={Category="Rifle",Skill="LightWeapons",SingleOnly=true,BoltAction=true,HoldHeightRatio=.4,Caliber="223",ShotDistance=80,Magazine=5,ReloadTime=2.5,Speed=750,Range=350,Damage=27,DamageMin=23,DamageMax=27,RPM=40},
 Weapon={Damage=27,DamageMin=23,DamageMax=27,DamageType="Bullet",MaxUses=3000,AttacksPerMinute=40}}
ItemConfig.Items.Rifle308={Name=".308 bolt-action rifle",Weight=3.2,Slot="Hands",
 Description="Bolt-action rifle. R reloads available ammo; B selects FMJ/AP.",
 Firearm={Category="Rifle",SingleOnly=true,HoldHeightRatio=.4,Caliber="308",ShotDistance=100,Magazine=5,ReloadTime=2.5,Speed=750,Range=350,Damage=40,DamageMin=35,DamageMax=40,RPM=40},
 Weapon={Damage=40,DamageMin=35,DamageMax=40,DamageType="Bullet",MaxUses=3000,AttacksPerMinute=40}}
-- Initial game balance; independent of the authored weapon models.
ItemConfig.Items.Pistol9mm={Name="9 mm pistol",Weight=.9,Slot="Hands",
 Description="Semi-automatic pistol. R reloads available ammo; B selects FMJ/AP.",
 Firearm={Category="Pistol",Skill="LightWeapons",SingleOnly=true,HoldHeightRatio=.4,Caliber="9mm",ShotDistance=60,Magazine=15,ReloadTime=1.8,Speed=350,Range=180,Damage=15,DamageMin=10,DamageMax=15,RPM=300},
 Weapon={Damage=15,DamageMin=10,DamageMax=15,DamageType="Bullet",MaxUses=3000,AttacksPerMinute=300}}
ItemConfig.Items.PipePistol9mm={Name="9 mm pipe pistol",Weight=1,Slot="Hands",
 Description="Single-shot improvised pistol. R manually reloads one 9 mm round; B selects FMJ/AP.",
 Firearm={Category="Pistol",Skill="LightWeapons",SingleOnly=true,ManualReload=true,HoldHeightRatio=.4,Caliber="9mm",ShotDistance=60,Magazine=1,ReloadTime=2,Speed=350,Range=180,Damage=16,DamageMin=12,DamageMax=16,RPM=60},
 Weapon={Damage=16,DamageMin=12,DamageMax=16,DamageType="Bullet",MaxUses=1000,AttacksPerMinute=60}}
ItemConfig.Items.PipeRifle9mm={Name="9 mm pipe rifle",Weight=2,Slot="Hands",
 Description="Single-shot improvised rifle. R manually reloads one 9 mm round; B selects FMJ/AP.",
 Firearm={Category="Rifle",Skill="LightWeapons",SingleOnly=true,ManualReload=true,BoltAction=false,HoldHeightRatio=.4,Caliber="9mm",ShotDistance=60,Magazine=1,ReloadTime=3,Speed=350,Range=200,Damage=22,DamageMin=18,DamageMax=22,RPM=60},
 Weapon={Damage=22,DamageMin=18,DamageMax=22,DamageType="Bullet",MaxUses=1000,AttacksPerMinute=60}}
ItemConfig.Items.SMG9mm={Name="9 mm submachine gun",Weight=2.5,Slot="Hands",
 Description="Submachine gun. R reloads available ammo; B selects FMJ/AP; V switches fire mode.",
 Firearm={Category="Automatic",Skill="LightWeapons",HoldHeightRatio=.4,Caliber="9mm",ShotDistance=60,Magazine=30,ReloadTime=2.2,Speed=350,Range=200,Damage=15,DamageMin=10,DamageMax=15,RPM=750},
 Weapon={Damage=15,DamageMin=10,DamageMax=15,DamageType="Bullet",MaxUses=3000,AttacksPerMinute=750}}
ItemConfig.Items.MachineGun308={Name=".308 machine gun",Weight=9,Slot="Hands",
 Description="Heavy machine gun. Uses Heavy weapons. R reloads available ammo; B selects FMJ/AP; V switches fire mode.",
 Firearm={Category="MachineGun",Skill="HeavyWeapons",HoldHeightRatio=.4,Caliber="308",ShotDistance=100,Magazine=60,ReloadTime=5,Speed=750,Range=450,Damage=30,DamageMin=25,DamageMax=30,RPM=600},
 Weapon={Damage=30,DamageMin=25,DamageMax=30,DamageType="Bullet",MaxUses=5000,AttacksPerMinute=600}}
ItemConfig.Items.GreatBandage={Name="Great bandage",Weight=.1,Slot="Medicine",Description="Restores twice the target Endurance plus 2 HP per 20 First Aid of the healer. Equip in Medicine."}
ItemConfig.Items.Bandage={Name="Bandage",Weight=.1,Slot="Medicine",Description="Restores target Endurance plus 1 HP per 20 First Aid of the healer. Equip in Medicine. H, then click yourself or a nearby player."}
for _,kind in ipairs({"FMJ","AP"}) do
 local role=if kind=="FMJ" then "Full metal jacket: a standard round for everyday firefights." else "Armor-piercing: ignores target armor according to caliber. Wall penetration is identical to FMJ."
 for _,ammo in ipairs({{ID="223",Name=".223",Weight=.012,Use="rifles"},{ID="9mm",Name="9 mm",Weight=.008,Use="pistols and submachine guns"},{ID="308",Name=".308",Weight=.024,Use="rifles and machine guns"}}) do
  local armorText=({["223FMJ"]=" Ignores 2 absorption and 10 percentage points of resistance.",["223AP"]=" Ignores 3 absorption and 15 percentage points of resistance.",["308FMJ"]=" Ignores 5 absorption and 20 percentage points of resistance.",["308AP"]=" Ignores 5 absorption and 40 percentage points of resistance."})[ammo.ID..kind] or ""
  local description=ammo.Name.." ammunition for compatible "..ammo.Use..". "..role..armorText
  ItemConfig.Items["Ammo"..ammo.ID..kind]={Name=ammo.Name.." "..kind,Weight=ammo.Weight,Description=description,Ammo={Caliber=ammo.ID,Type=kind}}
  ItemConfig.Items["AmmoBox"..ammo.ID..kind]={Name=ammo.Name.." "..kind.." ammo box",Weight=.1,Description="A box of "..ammo.Name.." "..kind.." rounds. Collect it to unpack the ammunition. "..role..armorText,AmmoBox={Caliber=ammo.ID,Type=kind,Maximum=50}}
 end
end
-- Prepared-food quality is an item variant, so it survives sharing, chests and drops.
for _,id in ipairs({"BoiledPotato","SausageSlice","MashedPotatoesWithSausage_1","MashedPotatoesWithSausage_2"}) do
 local base=ItemConfig.Items[id];local food=table.clone(base);food.Consume=table.clone(base.Consume)
 food.Name=base.Name.." (Ramsay)";food.TemplateID=id
 for _,stat in ipairs({"Food","Water"}) do if (food.Consume[stat] or 0)>0 then food.Consume[stat]*=1.5 end end
 food.Consume.Health=5;food.Description=base.Description.." Prepared by a master cook: 50% more positive nutrition and restores 5 HP."
 ItemConfig.Items["Ramsay_"..id]=food
end
ItemConfig.Items.EmptyBucket={Name="Empty bucket",Weight=1,Slot="Hands",Description="Fill at a well, then water a garden bed."}
ItemConfig.Items.DirtyWaterBucket={Name="Bucket of dirty water",Weight=6,ConsumeAction="Drink",EmptyContainer="EmptyBucket",Slot="Hands",TemplateID="EmptyBucket",Consume={Water=100,Sick=80},ReturnItems={EmptyBucket=1},Description="Enough water to irrigate a garden bed. Drinking restores 100 water but adds 80 infection. Returns an empty bucket."}
return ItemConfig

