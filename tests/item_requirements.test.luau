local Items=require("../src/shared/ItemConfig").Items
local P=require("../src/shared/ProgressionRules")
local C=require("../src/shared/CraftConfig")
local R=require("../src/shared/CraftRules")
local state=P.New();state.Confirmed=true
for id,minimum in pairs({Pistol9mm=3,SMG9mm=4,PipePistol9mm=3,PipeRifle9mm=4,Rifle223=4,Rifle308=4,ServiceRifle223=4,AssaultRifle223=5,LSW223=6}) do
 local req=Items[id].Requirements
 assert(req.Attributes.Strength==minimum,id)
 state.Stats.Strength=minimum-1;assert(not P.Meets(state,req),id.." must reject below Strength threshold")
 state.Stats.Strength=minimum;assert(P.Meets(state,req),id.." must accept exact Strength threshold")
end
local armor=Items.MiliArmor1
assert(armor.Slot=="Body" and armor.Weight==5 and armor.Armor.Absorption==6 and armor.Armor.Resistance==.3)
local kevlar=C.MakeKevlar
assert(kevlar.Station=="ArmsBench" and kevlar.Ingredients.Cloth==5 and kevlar.Ingredients.Chemicals==1 and kevlar.OutputCount==5)
local plan=assert(R.Plan({Cloth=5,Chemicals=1},kevlar,1));assert(plan.Outputs.Kevlar==5)
assert(not R.Plan({Cloth=4,Chemicals=1},kevlar,1))
local military=C.MakeMiliArmor1
assert(military.Station=="ArmsBench" and military.Requirements.Skills.Repair==175 and military.Duration==60)
assert(R.Plan({Kevlar=6,Iron=3},military,1).Outputs.MiliArmor1==1)
local improved=Items.MiliArmor2
assert(improved.Slot=="Body" and improved.Weight==6 and improved.Armor.Absorption==8 and improved.Armor.Resistance==.4)
local upgrade=C.MakeMiliArmor2
assert(upgrade.Station=="ArmsBench" and upgrade.Requirements.Skills.Repair==200 and upgrade.Duration==60 and upgrade.Tool=="SewingKit")
assert(not R.Plan({Kevlar=2,Iron=3},upgrade,1),"upgrading requires the original armor")
local upgraded=assert(R.Plan({MiliArmor1=1,Kevlar=2,Iron=3},upgrade,1))
assert(upgraded.Ingredients.MiliArmor1==1 and upgraded.Outputs.MiliArmor2==1)
print("PASS: exact weapon attribute boundaries and military armor/Kevlar recipe metadata")
