local Rules=require("../src/shared/ProgressionRules")
local state=Rules.New()
assert(state.Level==0 and state.XP==0 and state.Points==0)
assert(not Rules.Spend(state,"Strength"))
Rules.AddXP(state,99); assert(state.Level==0)
Rules.AddXP(state,1); assert(state.Level==1 and state.Points==5 and state.XP==0)
Rules.AddXP(state,200); assert(state.Level==2 and state.Points==10)
Rules.AddXP(state,4200); assert(state.Level==9 and state.XP==0 and state.Points==45)
Rules.AddXP(state,999); assert(state.Level==9)
Rules.AddXP(state,1); assert(state.Level==10 and state.Points==50 and state.XP==0)
assert(not Rules.AddXP(state,0/0) and not Rules.AddXP(state,math.huge))
assert(not Rules.Spend(state,"MadeUp"))
assert(Rules.Spend(state,"Strength") and state.Points==49)
local b=Rules.Bonuses(state.Stats)
assert(b.CarryLimitKg==21 and b.MeleeBonus==1 and b.MaxHealth==100 and b.Accuracy==.25 and b.LuckChance==0)
state.Stats.Endurance=2; state.Stats.Attention=100; state.Stats.Luck=100
b=Rules.Bonuses(state.Stats)
assert(b.MaxHealth==110 and b.RunBonus==.4 and b.Accuracy==.9 and b.ViewBonus==500 and b.LuckChance==.5)
local items={Stone=2,Scrap=4}
state.Stats.Luck=3
local lucky=Rules.BonusLoot(items,state.Stats,function() return 0 end)
assert(lucky.Stone==4 and lucky.Scrap==6 and items.Stone==2)
assert(Rules.BonusLoot(items,state.Stats,function() return 1 end).Stone==2)
local talent={Level=11,Requires={"Base"},Cost=1}
assert(not Rules.Learn(state,"Next",talent))
state.Level=11; assert(not Rules.Learn(state,"Next",talent))
state.Talents.Base=true; assert(Rules.Learn(state,"Next",talent))
assert(not Rules.Learn(state,"Next",talent))
print("PASS: 0–10 XP curve, points, invalid allocations, bonuses/caps, independent bonus loot and talent level prerequisites")

for _,direction in ipairs({{X=1,Y=0,Z=0},{X=0,Y=.98,Z=-.16},{X=0,Y=-.98,Z=.16}}) do
 local origin={X=0,Y=0,Z=-30}
 local scale,extent=Rules.ViewScale(origin,direction,math.tan(math.rad(20)),1.77,15)
 local _,expanded=Rules.ViewScale({X=0,Y=0,Z=-30*scale},direction,math.tan(math.rad(20)),1.77,0)
 assert(math.abs(expanded-extent-15)<1e-6,"three Attention adds exactly 15 studs ahead regardless of facing")
end
local Movement=require("../src/shared/MovementRules")
local Game=require("../src/shared/GameConfig")
assert(Movement.LoadMultiplier(21,Game,21)==1)
assert(math.abs(Movement.LoadMultiplier(22,Game,21)-.95)<1e-6)
print("PASS: forward camera extent and strength-adjusted carrying threshold")
