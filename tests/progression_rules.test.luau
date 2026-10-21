local R=require("../src/shared/ProgressionRules")
local s=R.New()
for _,v in pairs(s.Stats) do assert(v==5) end
assert(s.Points==6 and s.Level==0 and not s.Confirmed)
assert(not R.AddXP(s,100) and not R.SpendSkill(s,"Melee"))
local draft=table.clone(s.Stats)
assert(not R.Confirm(s,draft),"all six bonus points must be allocated")
draft.Strength=10;draft.Intelligence=6
assert(R.Confirm(s,draft) and s.Confirmed)
draft.Strength=1;assert(s.Stats.Strength==10,"confirmation copies input")
assert(not R.Confirm(s,draft),"cannot respec")
assert(R.AddXP(s,100) and s.Level==1 and s.SkillPoints==11 and s.Points==0)
assert(R.AddXP(s,200) and s.Level==2 and s.SkillPoints==22)
assert(not R.AddXP(s,math.huge) and not R.AddXP(s,0/0))
assert(R.SpendSkill(s,"Melee") and s.SkillPoints==21 and R.TotalSkills(s).Melee==51)
assert(not R.SpendSkill(s,"Lumberjack") and not R.SpendSkill(s,"Fake"))
s.SkillPoints=999
for _=1,400 do R.SpendSkill(s,"Melee") end
assert(R.TotalSkills(s).Melee==300)
local b=R.Bonuses(s.Stats)
assert(b.CarryLimitKg==50 and b.MaxHealth==50 and b.MeleeBonus==10)
assert(b.WalkBonus==1.5 and b.RunBonus==5 and b.DodgeChance==25 and b.Regeneration==10 and b.CriticalChance==.05)
assert(b.LuckChance==0 and b.ViewBonus==0)
local v=R.TotalSkills(s)
assert(v.LightWeapons==25 and v.HeavyWeapons==65 and v.Unarmed==90 and v.Throwing==55 and v.Repair==30)
assert(R.Meets(s,{Skills={Repair=30},Attributes={Strength=10}}))
assert(not R.Meets(s,{Skills={Repair=31}}))
assert(R.Practice(s,"Miner",100) and s.Practice.Miner.Value==1)
assert(s.Practice.Lumberjack.Value==0 and not R.Practice(s,"Melee",10))
for _,bad in ipairs({0,11,5.5,0/0}) do
 local t=R.New();local d=table.clone(t.Stats);d.Strength=bad;assert(not R.Confirm(t,d))
end
local t=R.New();local d={Strength=1,Attention=10,Endurance=10,Intelligence=5,Agility=5,Luck=5}
assert(R.Confirm(t,d),"attributes may be lowered to1 to redistribute")
local outputs={Potato=5};assert(R.CraftOutputs(outputs).Potato==5 and R.CraftEffects().DurationMultiplier==1)
print("PASS: six immutable1–10 attributes,36-point budget, INT level points, all skill bonuses/caps, requirements, passive practice and no retired perks")

local minimum=R.Bonuses({Strength=1,Attention=1,Endurance=1,Intelligence=1,Agility=1,Luck=1})
assert(minimum.MaxHealth==10 and minimum.CarryLimitKg==5 and minimum.MeleeBonus==1 and minimum.DodgeChance==5)
assert(minimum.WalkBonus==.3 and minimum.RunBonus==1 and minimum.Regeneration==2 and minimum.CriticalChance==.01)
