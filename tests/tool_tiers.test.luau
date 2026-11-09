local Items=require("../src/shared/ItemConfig").Items
local Rules=require("../src/shared/ResourceRules")
local Config=require("../src/shared/ResourceConfig")
local Recipes=require("../src/shared/CraftConfig")
local Craft=require("../src/shared/CraftRules")
local Inventory=require("../src/shared/InventoryRules")
local Categories=require("../src/shared/CraftCategories")
local Stations=require("../src/shared/CraftStations")
assert(not Items.StoneAxe and not Items.StoneShovel and not Items.StoneShowel)
assert(not Recipes.MakeAxe and not Recipes.MakeShovel)
for tier,material in ipairs({"Scrap","Iron","Steel"}) do
 for _,tool in ipairs({"Axe","Shovel"}) do
  if tier>1 then
   assert(not Items[material..tool] and not Recipes["Make"..material..tool])
   continue
  end
  local item=assert(Items[material..tool])
  assert(item.Name==tool)
  local node=tool=="Axe" and Config.Tree or Config.ScrapPile
  assert(item.Weapon.Damage==5 and item.HarvestTier==tier and item.HarvestMultiplier==tier)
  assert(Rules.HarvestDamage(node,item)==5*tier)
  assert(not Rules.CanDamage({Tool=node.Tool,MinHarvestTier=tier+1},item))
  local recipe=assert(Recipes["Make"..material..tool])
  assert(recipe.Requirements.Skills.Repair==tier*50)
  assert(recipe.Ingredients[material]==3 and recipe.Ingredients.Handle==1)
  assert(Categories.Kind(recipe,Items)=="Tools")
 end
 local knife=Items[material.."Knife"]
 assert(knife.Weapon.Damage==tier*10 and knife.CraftTool=="Knife")
 local recipe=Recipes[material=="Scrap" and "MakeKnife" or "Make"..material.."Knife"]
 assert(recipe.Requirements.Skills.Repair==tier*50 and recipe.Ingredients[material]==3)
end
for _,recipe in pairs(Recipes) do
 for id in pairs(recipe.Ingredients) do assert(Items[id],id) end
 assert(table.find(Categories.Order,Categories.Kind(recipe,Items)))
end
local smelt=Recipes.SmeltSteel
assert(smelt.WorkshopLevel==2 and smelt.Requirements.Skills.Repair==150)
local plan=assert(Craft.Plan({Iron=5,Coal=1},smelt,1))
assert(plan.Ingredients.Iron==5 and plan.Ingredients.Coal==1 and plan.Outputs.Steel==5)
assert(not Craft.Plan({Iron=5,Coal=1},smelt,2))
local tabs=Categories.Available(Recipes,Items,Stations,"Workstation","Wood")
for _,kind in ipairs({"All","Armor","Weapons","Ammunition","Tools","Materials","Equipment"}) do assert(table.find(tabs,kind),kind) end
assert(not table.find(tabs,"Medicine") and not table.find(tabs,"Food"))
assert(Categories.Kind(Recipes.MakeAmmo9mm,Items)=="Ammunition")
assert(Categories.Kind(Recipes.MakeBandage,Items)=="Medicine")
assert(Categories.Kind(Recipes.MakeCloth,Items)=="Materials")
assert(Categories.Kind(Recipes.MakePistol9mm,Items)=="Weapons")
assert(Categories.Kind(Recipes.MakeLeatherArmor,Items)=="Armor")
assert(Categories.Kind(Recipes.MakeBackpack1,Items)=="Equipment")
assert(Categories.Kind(Recipes.BoilWater,Items)=="Food")
local wood=Categories.Available(Recipes,Items,Stations,"Stove","Wood")
assert(table.find(wood,"Food") and table.find(wood,"Materials"))
local med=Categories.Available(Recipes,Items,Stations,"MedStation","Wood")
assert(table.find(med,"Medicine") and table.find(med,"Materials") and not table.find(med,"Weapons"))
local state=Inventory.New()
state.Items.StoneAxe=2;state.Conditions.StoneAxe={9,10}
state.Equipment.PrimaryWeapon="StoneShovel";state.EquipmentCondition.PrimaryWeapon=50;state.ActiveWeaponSlot="PrimaryWeapon"
Inventory.ReconcileEquipment(state,Items,require("../src/shared/ItemConfig").Slots)
assert(not state.Items.StoneAxe and not state.Conditions.StoneAxe and not state.Equipment.PrimaryWeapon and not state.ActiveWeaponSlot)
assert(Inventory.Weight(state,Items)==0)
print("PASS: retired stone cleanup, single axe/shovel recipes and material knife tiers, steel batch, complete station categories and fuel filters")
