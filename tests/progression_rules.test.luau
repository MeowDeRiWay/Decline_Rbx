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
assert(R.AddXP(s,500) and s.Level==1 and s.SkillPoints==22 and s.Points==0 and s.PerkPoints==0)
assert(R.AddXP(s,1000) and s.Level==2 and s.SkillPoints==33 and s.PerkPoints==0)
assert(not R.AddXP(s,math.huge) and not R.AddXP(s,0/0))
assert(R.SpendSkill(s,"Melee") and s.SkillPoints==32 and R.TotalSkills(s).Melee==31)
assert(not R.SpendSkill(s,"Lumberjack") and not R.SpendSkill(s,"Fake"))
s.SkillPoints=999
for _=1,400 do R.SpendSkill(s,"Melee") end
assert(R.TotalSkills(s).Melee==300)
local b=R.Bonuses(s.Stats)
assert(b.CarryLimitKg==50 and b.MaxHealth==40 and b.MeleeBonus==10)
assert(b.WalkBonus==1 and b.RunBonus==3 and b.DodgeChance==15 and b.Regeneration==5 and b.CriticalChance==.05)
assert(b.LuckChance==0 and b.ViewRange==25 and b.HearingMultiplier==1)
local v=R.TotalSkills(s)
assert(v.LightWeapons==15 and v.HeavyWeapons==30 and v.Unarmed==30 and v.Throwing==30 and v.Repair==18)
assert(R.Meets(s,{Skills={Repair=18},Attributes={Strength=10}}))
assert(not R.Meets(s,{Skills={Repair=19}}))
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
assert(minimum.MaxHealth==6 and minimum.CarryLimitKg==5 and minimum.MeleeBonus==1 and minimum.DodgeChance==3)
assert(minimum.WalkBonus==.2 and minimum.RunBonus==.6 and minimum.Regeneration==1 and minimum.CriticalChance==.01)

assert(R.TotalSkills(s).FirstAid==23 and R.TotalSkills(s).Doctor==18 and R.TotalSkills(s).Cook==23)
assert(s.PerkPoints==0 and not R.SpendPerk(s,"RangedDamage"))
local perks=R.New();local all={Strength=7,Attention=7,Endurance=7,Intelligence=1,Agility=7,Luck=7}
assert(R.Confirm(perks,all));perks.PerkPoints=10
for _,id in ipairs({"RangedDamage","RangedDamage","Lifegiver","Lifegiver","StrongArm","StrongBack","Criticals","Regeneration","Medic","FieldHospital"}) do
 perks.Skills.FirstAid=150;perks.Skills.Doctor=100
 assert(R.SpendPerk(perks,id),id)
end
assert(R.PerkCount(perks)==10 and not R.SpendPerk(perks,"StrongBack"),"ten selected ranks cap")
assert(perks.PerkPoints==0 and not R.SpendPerk(perks,"Observant"),"Attention7 cannot select free perk")
perks.Stats.Attention=8;assert(R.SpendPerk(perks,"Observant") and perks.PerkPoints==0 and R.PerkCount(perks)==10,"observant free outside cap at zero points")
assert(not R.SpendPerk(perks,"Observant") and perks.PerkPoints==0,"free perk cannot be taken twice")
local bonus=R.Bonuses(perks.Stats,perks.Perks,3)
assert(bonus.RangedDamageBonus==4 and bonus.MaxHealth==60 and bonus.MeleeBonus==14 and bonus.CarryLimitKg==48)
assert(bonus.CriticalChance==.14 and bonus.Regeneration==14 and bonus.FirstAidMultiplier==2 and bonus.ReviveLockSeconds==300)
local high=R.Bonuses({Strength=1,Attention=10,Endurance=1,Intelligence=1,Agility=1,Luck=1},{Hearing=1})
assert(high.HearingAttention==12 and high.ViewRange==40)
assert(R.FirstAid(19)==11 and R.FirstAid(20,2)==24 and R.ReviveChance(20)==.1 and R.ReviveChance(200)==1)
assert(R.CraftExperience({},5)==250 and R.CraftExperience({OutputCount=3},1)==50 and R.CraftExperience({XP=80},2)==160)
assert(R.KillExperience(20)==50 and R.KillExperience(60)==150)
assert(R.AddXP(s,.5) and s.XP==.5,"healing grants exact actual HP including fractions")
print("PASS: initial INT skill bundle; perk points every3levels; 500*level XP; per-item practice; all nine perk requirements/rank caps/effects; medical and craft/kill XP")

local requirements={Skills={Doctor=100,FirstAid=100}}
local doctor=R.New();assert(R.Confirm(doctor,{Strength=5,Attention=5,Endurance=5,Intelligence=10,Agility=6,Luck=5}))
doctor.Skills.Doctor=70;doctor.Skills.FirstAid=64
assert(not R.Meets(doctor,requirements),"first aid99 cannot build hospital")
doctor.Skills.FirstAid=65;assert(R.Meets(doctor,requirements),"100 in BOTH qualifies")
doctor.Skills.Doctor=69;assert(not R.Meets(doctor,requirements),"doctor99 cannot build hospital")
local either={AnySkills={Doctor=100,FirstAid=100}}
doctor.Skills.FirstAid=64
assert(not R.Meets(doctor,either),"both medical skills at99 fail the OR requirement")
doctor.Skills.FirstAid=65;assert(R.Meets(doctor,either),"FirstAid100 alone satisfies OR")
doctor.Skills.FirstAid=64;doctor.Skills.Doctor=70
assert(R.Meets(doctor,either),"Doctor100 alone satisfies OR")

assert(R.RequiredXP(0)==500 and R.RequiredXP(9)==5000)

for _,case in ipairs({{0,0,1},{100,0,1.5},{0,200,2},{200,200,2},{300,100,2},{50,150,1.75}}) do
 assert(R.MovementMultiplier({Unarmed=case[1],Melee=case[2]})==case[3])
end
local fast=R.Bonuses({Strength=5,Attention=5,Endurance=5,Intelligence=5,Agility=5,Luck=5},{FastFeet=1},1,{Unarmed=200,Melee=300})
assert(math.abs(fast.WalkBonus-2.4)<1e-9 and math.abs(fast.RunBonus-9.2)<1e-9,"whole movement including Fast feet doubles once")
local Z=require("../src/shared/ZombieStats")
assert(Z.Infection(6)==0,"zombie infection temporarily disabled")
Z.InfectionPerStrength=1;assert(Z.Infection(6)==6,"restore switch preserves Strength infection");Z.InfectionPerStrength=0

local capped=R.New();assert(R.Confirm(capped,{Strength=5,Attention=5,Endurance=5,Intelligence=5,Agility=6,Luck=10}))
assert(R.AddXP(capped,1e12) and capped.Level==30 and capped.XP==0 and capped.Perks.Observant==1)
local sp,pp=capped.SkillPoints,capped.PerkPoints
assert(not R.AddXP(capped,1e12) and capped.Level==30 and capped.SkillPoints==sp and capped.PerkPoints==pp and capped.XP==0)
assert(R.Bonuses(capped.Stats,{},0).MaxHealth==30 and R.Bonuses(capped.Stats,{},1).MaxHealth==34 and R.Bonuses(capped.Stats,{},30).MaxHealth==150)
assert(R.Bonuses(capped.Stats,{Lifegiver=2},30).MaxHealth==210,"base growth and both Lifegiver ranks stack")
assert(R.Bonuses(capped.Stats,{},0).CarryLimitKg==25 and R.Bonuses(capped.Stats,{},1).CarryLimitKg==26 and R.Bonuses(capped.Stats,{},30).CarryLimitKg==55)
assert(R.Bonuses(capped.Stats,{StrongBack=2},30).CarryLimitKg==75,"level carry bonus adds to Strength and Strong back")
assert(R.Practice(capped,"Miner",10) and capped.Practice.Miner.Value==1,"practice continues at max character level")
capped.Skills.Melee=100;capped.TaggedSkills={Melee=true,Unarmed=true,Doctor=true};capped.TagsConfirmed=true
local stats=table.clone(capped.Stats)
assert(R.ResetProgression(capped) and capped.Level==1 and capped.XP==0 and next(capped.Perks)==nil)
for id,v in pairs(capped.Skills) do assert(v==0) end
for id,v in pairs(capped.Practice) do assert(v.Value==0 and v.XP==0) end
for id,v in pairs(stats) do assert(capped.Stats[id]==v) end
assert(capped.SkillPoints==20 and capped.PerkPoints==0 and capped.TaggedSkills.Melee and capped.TagsConfirmed and capped.Confirmed)
assert(R.TotalSkills(capped).Melee==15,"reset retains only attribute-derived skill values")
assert(R.ResetProgression(capped) and capped.SkillPoints==20,"repeat reset cannot accumulate points")
assert(not R.ResetProgression(R.New()))
print("PASS: hard level30 cap, no surplus XP/rewards, fixed HP per level, additive Lifegiver, complete level1 progression reset")

for endurance=1,10 do
 local stats={Strength=5,Attention=5,Endurance=endurance,Intelligence=5,Agility=5,Luck=5}
 for rank=0,2 do
  for level=0,30 do
   local hp=R.Bonuses(stats,{Lifegiver=rank},level).MaxHealth
   assert(hp==4*endurance+10+level*(4+rank))
   if level>0 then assert(hp-R.Bonuses(stats,{Lifegiver=rank},level-1).MaxHealth==4+rank) end
  end
 end
end
for strength=1,10 do
 local stats={Strength=strength,Attention=5,Endurance=7,Intelligence=5,Agility=5,Luck=5}
 assert(R.Bonuses(stats,{},0).MaxHealth==28+2*strength,"each creation Strength point gives two HP")
 assert(R.Bonuses(stats,{Lifegiver=2},30).MaxHealth==208+2*strength,"Strength contribution does not scale with level")
end
local seven={Strength=5,Attention=5,Endurance=7,Intelligence=5,Agility=5,Luck=5}
assert(R.Bonuses(seven,{},0).MaxHealth==38 and R.Bonuses(seven,{},1).MaxHealth==42 and R.Bonuses(seven,{},30).MaxHealth==158)
print("PASS: END gives4 base HP, STR gives2 base HP, levels give4 HP, Lifegiver gives1 per level per rank")

local schedule=R.New();schedule.Confirmed=true
assert(schedule.PerkPoints==0)
for level=1,30 do
 assert(R.AddXP(schedule,R.RequiredXP(schedule.Level)))
 assert(schedule.Level==level and schedule.PerkPoints==math.floor(level/3),"one perk point per third level")
end
assert(schedule.PerkPoints==10 and schedule.Perks.Observant==1 and R.PerkCount(schedule)==0)
assert(not R.AddXP(schedule,1e12) and schedule.PerkPoints==10)
assert(R.ResetProgression(schedule) and schedule.Level==1 and schedule.PerkPoints==0)
assert(R.AddXP(schedule,1000) and schedule.Level==2 and schedule.PerkPoints==0)
assert(R.AddXP(schedule,1500) and schedule.Level==3 and schedule.PerkPoints==1)
local free=R.New();free.Confirmed=true;free.Stats.Attention=8
assert(R.SpendPerk(free,"Observant") and free.PerkPoints==0 and R.PerkCount(free)==0)
assert(R.AddXP(free,1e12) and free.Perks.Observant==1 and free.PerkPoints==10,"automatic award never duplicates or charges free perk")
print("PASS: perk point milestones3..30 total10, none at creation/reset1, free Attention8 perk outside budget, automatic award at30")

do
 local farmer=R.New()
 farmer.PerkPoints=1;farmer.Confirmed=true
 assert(R.SpendPerk(farmer,"Botanist"))
 assert(R.Bonuses(farmer.Stats,farmer.Perks,1,R.TotalSkills(farmer)).PlantKnowledge==true)
 assert(not R.SpendPerk(farmer,"Botanist"))
 assert(R.Bonuses(farmer.Stats,{},1,R.TotalSkills(farmer)).PlantKnowledge==false)
 print("PASS: Botanist uses one perk point and enables plant knowledge only while selected")
end

local baseline={Strength=5,Attention=5,Endurance=5,Intelligence=5,Agility=5,Luck=5}
local baseSkills=R.SkillValues(baseline)
local deltas={Strength={HeavyWeapons=3,Unarmed=3,Melee=3,Throwing=3},Attention={LightWeapons=3,Traps=2},Endurance={FirstAid=1,Cook=1},Intelligence={FirstAid=3,Doctor=3,Repair=3,Cook=3},Agility={Sneak=3},Luck={}}
for attribute,expected in pairs(deltas) do
 local changed=table.clone(baseline);changed[attribute]+=1
 for skill,value in pairs(R.SkillValues(changed)) do
  assert(value-baseSkills[skill]==(expected[skill] or 0),attribute.." must only grant the configured "..skill.." bonus")
 end
end
print("PASS: every attribute skill delta matches new balance; removed cross-attribute bonuses remain zero")
