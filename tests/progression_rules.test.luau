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
assert(R.AddXP(s,500) and s.Level==1 and s.SkillPoints==22 and s.Points==0 and s.PerkPoints==2)
assert(R.AddXP(s,1000) and s.Level==2 and s.SkillPoints==33 and s.PerkPoints==3)
assert(not R.AddXP(s,math.huge) and not R.AddXP(s,0/0))
assert(R.SpendSkill(s,"Melee") and s.SkillPoints==32 and R.TotalSkills(s).Melee==51)
assert(not R.SpendSkill(s,"Lumberjack") and not R.SpendSkill(s,"Fake"))
s.SkillPoints=999
for _=1,400 do R.SpendSkill(s,"Melee") end
assert(R.TotalSkills(s).Melee==300)
local b=R.Bonuses(s.Stats)
assert(b.CarryLimitKg==50 and b.MaxHealth==50 and b.MeleeBonus==10)
assert(b.WalkBonus==1 and b.RunBonus==2 and b.DodgeChance==25 and b.Regeneration==5 and b.CriticalChance==.05)
assert(b.LuckChance==0 and b.ViewRange==25 and b.HearingMultiplier==1)
local v=R.TotalSkills(s)
assert(v.LightWeapons==30 and v.HeavyWeapons==45 and v.Unarmed==90 and v.Throwing==55 and v.Repair==30)
assert(R.Meets(s,{Skills={Repair=30},Attributes={Strength=10}}))
assert(not R.Meets(s,{Skills={Repair=31}}))
assert(R.Practice(s,"Miner",10) and s.Practice.Miner.Value==1)
assert(s.Practice.Lumberjack.Value==0 and not R.Practice(s,"Melee",10))
for _,bad in ipairs({0,11,5.5,0/0}) do
 local t=R.New();local d=table.clone(t.Stats);d.Strength=bad;assert(not R.Confirm(t,d))
end
local t=R.New();local d={Strength=1,Attention=10,Endurance=10,Intelligence=5,Agility=5,Luck=5}
assert(R.Confirm(t,d),"attributes may be lowered to1 to redistribute")
local outputs={Potato=5};assert(R.CraftOutputs(outputs).Potato==5 and R.CraftEffects().DurationMultiplier==1)
print("PASS: six immutable1–10 attributes,36-point budget, INT level points, all skill bonuses/caps, requirements, passive practice and locked attributes")

local minimum=R.Bonuses({Strength=1,Attention=1,Endurance=1,Intelligence=1,Agility=1,Luck=1})
assert(minimum.MaxHealth==10 and minimum.CarryLimitKg==5 and minimum.MeleeBonus==1 and minimum.DodgeChance==5)
assert(minimum.WalkBonus==.2 and minimum.RunBonus==.4 and minimum.Regeneration==1 and minimum.CriticalChance==.01)

assert(R.TotalSkills(s).FirstAid==40 and R.TotalSkills(s).Doctor==45 and R.TotalSkills(s).Cook==29)
assert(s.PerkPoints==3 and not R.SpendPerk(s,"RangedDamage"))
local perks=R.New();local all={Strength=7,Attention=7,Endurance=7,Intelligence=1,Agility=7,Luck=7}
assert(R.Confirm(perks,all));perks.PerkPoints=20
for _,id in ipairs({"RangedDamage","RangedDamage","Lifegiver","Lifegiver","StrongArm","StrongBack","Criticals","Regeneration","Medic","FieldHospital"}) do
 perks.Skills.FirstAid=150;perks.Skills.Doctor=100
 assert(R.SpendPerk(perks,id),id)
end
assert(R.PerkCount(perks)==10 and not R.SpendPerk(perks,"StrongBack"),"ten selected ranks cap")
perks.Stats.Attention=8;assert(R.SpendPerk(perks,"Observant"),"observant outside cap")
local bonus=R.Bonuses(perks.Stats,perks.Perks,3)
assert(bonus.RangedDamageBonus==4 and bonus.MaxHealth==106 and bonus.MeleeBonus==14 and bonus.CarryLimitKg==45)
assert(bonus.CriticalChance==.14 and bonus.Regeneration==14 and bonus.FirstAidMultiplier==2 and bonus.ReviveLockSeconds==300)
local high=R.Bonuses({Strength=1,Attention=10,Endurance=1,Intelligence=1,Agility=1,Luck=1},{Hearing=1})
assert(high.HearingAttention==12 and high.ViewRange==40)
assert(R.FirstAid(19)==11 and R.FirstAid(20,2)==24 and R.ReviveChance(20)==.1 and R.ReviveChance(200)==1)
assert(R.CraftExperience({},5)==250 and R.CraftExperience({OutputCount=3},1)==50 and R.CraftExperience({XP=80},2)==160)
assert(R.KillExperience(20)==50 and R.KillExperience(60)==150)
assert(R.AddXP(s,.5) and s.XP==.5,"healing grants exact actual HP including fractions")
print("PASS: initial INT skill bundle and perk point; 500*level XP; per-item practice; all nine perk requirements/rank caps/effects; medical and craft/kill XP")

local requirements={Skills={Doctor=100,FirstAid=100}}
local doctor=R.New();assert(R.Confirm(doctor,{Strength=5,Attention=5,Endurance=5,Intelligence=10,Agility=6,Luck=5}))
doctor.Skills.Doctor=35;doctor.Skills.FirstAid=39
assert(not R.Meets(doctor,requirements),"first aid99 cannot build hospital")
doctor.Skills.FirstAid=40;assert(R.Meets(doctor,requirements),"100 in BOTH qualifies")
doctor.Skills.Doctor=34;assert(not R.Meets(doctor,requirements),"doctor99 cannot build hospital")

assert(R.RequiredXP(0)==500 and R.RequiredXP(9)==5000)

for _,case in ipairs({{0,0,1},{100,0,1.5},{0,200,2},{200,200,2},{300,100,2},{50,150,1.75}}) do
 assert(R.MovementMultiplier({Unarmed=case[1],Melee=case[2]})==case[3])
end
local fast=R.Bonuses({Strength=5,Attention=5,Endurance=5,Intelligence=5,Agility=5,Luck=5},{FastFeet=1},1,{Unarmed=200,Melee=300})
assert(math.abs(fast.WalkBonus-2.4)<1e-9 and math.abs(fast.RunBonus-6.8)<1e-9,"whole movement including Fast feet doubles once")
local Z=require("../src/shared/ZombieStats")
assert(Z.Infection(6)==0,"zombie infection temporarily disabled")
Z.InfectionPerStrength=1;assert(Z.Infection(6)==6,"restore switch preserves Strength infection");Z.InfectionPerStrength=0

local capped=R.New();assert(R.Confirm(capped,{Strength=5,Attention=5,Endurance=5,Intelligence=5,Agility=6,Luck=10}))
assert(R.AddXP(capped,1e12) and capped.Level==30 and capped.XP==0 and capped.Perks.Observant==1)
local sp,pp=capped.SkillPoints,capped.PerkPoints
assert(not R.AddXP(capped,1e12) and capped.Level==30 and capped.SkillPoints==sp and capped.PerkPoints==pp and capped.XP==0)
assert(R.Bonuses(capped.Stats,{},0).MaxHealth==50 and R.Bonuses(capped.Stats,{},1).MaxHealth==54 and R.Bonuses(capped.Stats,{},30).MaxHealth==170)
assert(R.Bonuses(capped.Stats,{Lifegiver=2},30).MaxHealth==410,"base growth and both Lifegiver ranks stack")
assert(R.Practice(capped,"Miner",10) and capped.Practice.Miner.Value==1,"practice continues at max character level")
capped.Skills.Melee=100;capped.TaggedSkills={Melee=true,Unarmed=true,Doctor=true};capped.TagsConfirmed=true
local stats=table.clone(capped.Stats)
assert(R.ResetProgression(capped) and capped.Level==1 and capped.XP==0 and next(capped.Perks)==nil)
for id,v in pairs(capped.Skills) do assert(v==0) end
for id,v in pairs(capped.Practice) do assert(v.Value==0 and v.XP==0) end
for id,v in pairs(stats) do assert(capped.Stats[id]==v) end
assert(capped.SkillPoints==20 and capped.PerkPoints==2 and capped.TaggedSkills.Melee and capped.TagsConfirmed and capped.Confirmed)
assert(R.TotalSkills(capped).Melee==25,"reset retains only attribute-derived skill values")
assert(R.ResetProgression(capped) and capped.SkillPoints==20,"repeat reset cannot accumulate points")
assert(not R.ResetProgression(R.New()))
print("PASS: hard level30 cap, no surplus XP/rewards, +4 base HP per level, additive Lifegiver, complete level1 progression reset")
