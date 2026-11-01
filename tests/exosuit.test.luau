local I=require("../src/shared/ItemConfig")
local R=require("../src/shared/InventoryRules")
local C=require("../src/shared/CraftConfig")
local s=R.New()
local function equip(id) assert(R.Add(s,I.Items,id,1));assert(R.Equip(s,I.Items,I.Slots,id)) end
local function close(value,expected) assert(math.abs(value-expected)<1e-8,tostring(value).." != "..expected) end
local exo=I.Items.Exosuit
assert(exo.Weight==20 and exo.Armor.Absorption==12 and exo.Armor.Resistance==.5)
local recipe=C.MakeExosuit
assert(recipe.Ingredients.Steel==4 and recipe.Ingredients.Kevlar==4 and recipe.Requirements.Skills.Repair==175 and recipe.Duration==120 and not recipe.Tool and recipe.Station=="ArmsBench")
equip("Backpack1");equip("Exosuit")
assert(not s.Equipment.Back and s.Items.Backpack1==1 and R.SlotBlocked(s,I.Items,"Back"))
assert(not R.Equip(s,I.Items,I.Slots,"Backpack1") and s.Items.Backpack1==1)
close(R.Weight(s,I.Items),7) -- 6kg worn suit + full 1kg pocket backpack
assert(R.Add(s,I.Items,"Scrap",10));close(R.Weight(s,I.Items),9)
equip("SurgicalKit");close(R.Weight(s,I.Items),9.15)
equip("Pistol9mm")
local gun=I.Items.Pistol9mm
local data=s.EquipmentWeapon.SecondaryWeapon;data.Loaded=5
local ammo=I.Items.Ammo9mmFMJ
close(R.Weight(s,I.Items),9.15+.3*(gun.Weight+5*ammo.Weight))
s.ActiveWeaponSlot="SecondaryWeapon"
close(R.Weight(s,I.Items,1,0),9.15+.3*5*ammo.Weight)
assert(R.Unequip(s,I.Items,I.Slots,"Body"));assert(not R.SlotBlocked(s,I.Items,"Back"))
assert(R.Equip(s,I.Items,I.Slots,"Backpack1"))
close(R.EquippedWeightMultiplier(s,I.Items),1)
-- Restored incompatible combinations return the backpack exactly once.
s.Equipment.Body="Exosuit";s.Items.Exosuit=nil
R.ReconcileEquipment(s,I.Items,I.Slots)
assert(not s.Equipment.Back and s.Items.Backpack1==1)
R.ReconcileEquipment(s,I.Items,I.Slots);assert(s.Items.Backpack1==1)
print("PASS: exosuit stats/craft, atomic backpack removal/blocking, full pocket weight, worn gear/ammo discount, perk compatibility and restoration")
