local R=require("../src/shared/ProgressionRules")
for target,required in ipairs({250,250,250,500,1000,2000,4000,8000,16000,32000}) do
 assert(R.RequiredXP(target-1)==required,"transition into level "..target)
end
for level=3,29 do assert(R.RequiredXP(level)==R.RequiredXP(level-1)*2) end
assert(R.RequiredXP(29)==33554432000,"last transition remains exact at level cap")
local state=R.New();state.Confirmed=true
assert(R.AddXP(state,249) and state.Level==0 and state.XP==249)
assert(R.AddXP(state,1) and state.Level==1 and state.XP==0)
assert(R.AddXP(state,500) and state.Level==3 and state.XP==0 and state.PerkPoints==1)
assert(R.AddXP(state,499) and state.Level==3 and state.XP==499)
assert(R.AddXP(state,1) and state.Level==4 and state.XP==0)
assert(R.AddXP(state,1001) and state.Level==5 and state.XP==1)
assert(R.AddXP(state,1999) and state.Level==6 and state.XP==0 and state.PerkPoints==2)
local fast=R.New();fast.Confirmed=true;fast.Perks.GoodStudent=1
assert(R.AddXP(fast,125) and fast.Level==1 and fast.XP==0,"XP multiplier uses the same curve")
local total=0
for level=0,29 do total+=R.RequiredXP(level) end
assert(total==67108864250)
local capped=R.New();capped.Confirmed=true
assert(R.AddXP(capped,total-1) and capped.Level==29 and capped.XP==R.RequiredXP(29)-1)
assert(R.AddXP(capped,1) and capped.Level==30 and capped.XP==0 and capped.PerkPoints==10 and capped.Perks.Observant==1)
print("PASS: 250/250/250 then doubling, exact thresholds/carryover, multi-level awards, XP multiplier and level30 cap")
