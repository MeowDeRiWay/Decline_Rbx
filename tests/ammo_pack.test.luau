local I=require('../src/shared/ItemConfig')
local R=require('../src/shared/InventoryRules')
for _,caliber in ipairs({'9mm','223','308'}) do for _,kind in ipairs({'FMJ','AP'}) do
 local id='Ammo'..caliber..kind;local packed='AmmoPack'..caliber..kind
 local s=R.New();assert(R.Add(s,I.Items,id,59))
 local weight=R.Weight(s,I.Items)
 assert(R.PackageAmmo(s,I.Items,id,false))
 assert(s.Items[id]==29 and s.Items[packed]==1)
 assert(math.abs(R.Weight(s,I.Items)-weight-.1)<1e-8)
 assert(not R.PackageAmmo(s,I.Items,id,false))
 assert(R.PackageAmmo(s,I.Items,packed,true))
 assert(s.Items[id]==59 and not s.Items[packed] and math.abs(R.Weight(s,I.Items)-weight)<1e-8)
 assert(not R.PackageAmmo(s,I.Items,packed,true))
 assert(not I.Items[packed].AmmoBox and I.Items[packed].TemplateID=='AmmoBox'..caliber..kind)
end end
local s=R.New();assert(not R.PackageAmmo(s,I.Items,'Scrap',false));assert(not R.PackageAmmo(s,I.Items,{},true))
print('PASS: all six exact 30-round conversions, round-trip weight, caliber/type isolation, insufficient stock and duplicate unpack rejection')

local defs=require("../src/shared/ItemConfig").Items
local rules=require("../src/shared/InventoryRules")
defs.AmmoPack223FMJ.PackedAmmo.Count=45
local state=rules.New();rules.Add(state,defs,"Ammo223FMJ",45)
assert(rules.PackageAmmo(state,defs,"Ammo223FMJ",false))
assert(rules.PackageAmmo(state,defs,"AmmoPack223FMJ",true))
assert(state.Items.Ammo223FMJ==45,"configured capacity survives packing and unpacking")
