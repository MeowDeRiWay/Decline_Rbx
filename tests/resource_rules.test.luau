local Rules = require("../src/shared/ResourceRules")
local Config = require("../src/shared/ResourceConfig")
local Items = require("../src/shared/ItemConfig").Items
local Inventory = require("../src/shared/InventoryRules")
local Combat = require("../src/shared/CombatRules")
local axe, shovel = Items.Axe, Items.Showel
assert(axe.Weapon.AttacksPerMinute == 25 and shovel.Weapon.AttacksPerMinute == 25)
assert(axe.Weapon.Animation == shovel.Weapon.Animation and axe.Weapon.Damage == shovel.Weapon.Damage)
assert(Rules.CanDamage(Config.Tree,axe) and not Rules.CanDamage(Config.Tree,shovel))
assert(Rules.CanDamage(Config.Tree,{HarvestTool="Axe"}),"Future axes use the same harvest category")
assert(Rules.CanDamage(Config.ScrapPile,shovel) and not Rules.CanDamage(Config.ScrapPile,axe))
assert(not Rules.CanDamage(Config.Tree,Items.Knife))
local health = Config.Tree.Health
for hit=1,5 do
 health = Rules.Damage(health,axe.Weapon.Damage)
 assert(health == 100-hit*20)
end
assert(Rules.Damage(5,20) == 0)
assert(Rules.Spaced({{X=0,Z=0}},8,0,8))
assert(not Rules.Spaced({{X=0,Z=0}},7.99,0,8))
assert(Rules.Spaced({{X=0,Z=0}},1,0,1))
assert(not Rules.Spaced({{X=0,Z=0}},.7,.7,1))
for _,resource in pairs(Config) do
 assert(resource.MinCount == 1 and resource.MaxCount == 20)
 assert(resource.EdgeMargin == 3)
 assert(resource.RespawnMin == 30 and resource.RespawnMax == 300)
 for id,range in pairs(resource.Loot) do
  assert(Items[id] and range.Min >= 1 and range.Max >= range.Min)
 end
end
assert(Items.TreeLog.Weight == 2 and Items.Scrap.Weight == .2 and Items.Rags.Weight == .05)
local state = Inventory.New()
assert(Inventory.Add(state,Items,"Axe",1,{5}))
assert(Inventory.Equip(state,Items,{"Hands"},"Axe"))
for hit=1,5 do assert(Combat.Use(state,Items)); assert(state.EquipmentCondition.Hands==5-hit) end
assert(Combat.Use(state,Items)==nil,"Broken tools cannot hit")
assert(Inventory.Add(state,Items,"TreeLog",4))
assert(Inventory.Weight(state,Items) == 9.5)
local occupancy = {}
assert(Rules.Occupancy(occupancy,false,0,180),"Initial empty home may spawn")
assert(not Rules.Occupancy(occupancy,true,1,180))
assert(not Rules.Occupancy(occupancy,true,1000,180),"No spawn while occupied")
assert(not Rules.Occupancy(occupancy,false,1001,180),"Exit starts a full delay")
assert(not Rules.Occupancy(occupancy,false,1180.99,180))
assert(Rules.Occupancy(occupancy,false,1181,180))
assert(not Rules.Occupancy(occupancy,true,1182,180),"Re-entry blocks spawning again")
assert(not Rules.Occupancy(occupancy,false,1183,180))
assert(not Rules.Occupancy(occupancy,false,1362.99,180))
assert(Rules.Occupancy(occupancy,false,1363,180))
print("PASS: tool attacks and wear, valid resource tools, five-hit tree, loot weights, spacing boundaries, respawn ranges and occupied-home delay")
