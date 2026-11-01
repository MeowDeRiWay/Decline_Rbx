local R=require("../src/shared/ProgressionRules")

local repairRecipe={Requirements={Skills={Repair=25}}}
assert(R.CraftEffects({PracticedHands=1},repairRecipe).DurationMultiplier==.5)
assert(R.CraftEffects({},repairRecipe).DurationMultiplier==1)
assert(R.CraftEffects({PracticedHands=1},{Requirements={Skills={Cook=50}}}).DurationMultiplier==1)
assert(R.CraftEffects({PracticedHands=1},{}).DurationMultiplier==1)

local state=R.New();state.PerkPoints=1;state.Confirmed=true
local perk
for _,entry in ipairs(R.Perks) do if entry.ID=="PracticedHands" then perk=entry end end
assert(perk and perk.Skills.Repair==200 and perk.Max==1)
local base=R.TotalSkills(state).Repair
state.Skills.Repair=199-base
assert(not R.SpendPerk(state,"PracticedHands"))
state.Skills.Repair+=1
assert(R.SpendPerk(state,"PracticedHands") and state.PerkPoints==0)
state.PerkPoints=1;assert(not R.SpendPerk(state,"PracticedHands"))
print("PASS: Repair 200 prerequisite, one rank and half duration only for Repair recipes")
