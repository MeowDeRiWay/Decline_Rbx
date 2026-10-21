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
assert(R.AddXP(s,1000) and s.Level==1 and s.SkillPoints==22 and s.Points==0)
assert(R.AddXP(s,2000) and s.Level==2 and s.SkillPoints==33)
assert(not R.AddXP(s,math.huge) and not R.AddXP(s,0/0))
assert(R.SpendSkill(s,"Melee") and s.SkillPoints==32 and R.TotalSkills(s).Melee==51)
assert(not R.SpendSkill(s,"Lumberjack") and not R.SpendSkill(s,"Fake"))
s.SkillPoints=999
for _=1,400 do R.SpendSkill(s,"Melee") end
assert(R.TotalSkills(s).Melee==300)
local b=R.Bonuses(s.Stats)
assert(b.CarryLimitKg==50 and b.MaxHealth==50 and b.MeleeBonus==10)
assert(b.WalkBonus==1 and b.RunBonus==4 and b.DodgeChance==25 and b.Regeneration==10 and b.CriticalChance==.05)
assert(b.LuckChance==0 and b.ViewRange==15 and b.HearingMultiplier==1)
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
assert(minimum.WalkBonus==.2 and minimum.RunBonus==.8 and minimum.Regeneration==2 and minimum.CriticalChance==.01)

assert(R.TotalSkills(s).FirstAid==40 and R.TotalSkills(s).Doctor==45 and R.TotalSkills(s).Cook==29)
assert(s.PerkPoints==1 and not R.SpendPerk(s,"RangedDamage"))
local perks=R.New();local all={Strength=7,Attention=7,Endurance=7,Intelligence=1,Agility=7,Luck=7}
assert(R.Confirm(perks,all));perks.PerkPoints=20
for _,perk in ipairs(R.Perks) do
 if not perk.Skills then
  assert(R.SpendPerk(perks,perk.ID))
  if perk.Max==2 then assert(R.SpendPerk(perks,perk.ID)) end
  assert(not R.SpendPerk(perks,perk.ID),"rank cap enforced")
 end
end
assert(not R.SpendPerk(perks,"Medic") and not R.SpendPerk(perks,"FieldHospital"))
perks.Skills.FirstAid=150;perks.Skills.Doctor=100
assert(R.SpendPerk(perks,"Medic") and R.SpendPerk(perks,"FieldHospital"))
local bonus=R.Bonuses(perks.Stats,perks.Perks)
assert(bonus.RangedDamageBonus==4 and bonus.MaxHealth==140 and bonus.MeleeBonus==14 and bonus.CarryLimitKg==45)
assert(bonus.CriticalChance==.14 and bonus.Regeneration==28 and bonus.FirstAidMultiplier==2 and bonus.ReviveLockSeconds==300)
assert(bonus.ViewRange==21 and bonus.HearingAttention==9)
local high=R.Bonuses({Strength=1,Attention=10,Endurance=1,Intelligence=1,Agility=1,Luck=1},{Hearing=1})
assert(high.HearingAttention==12 and high.ViewRange==30)
assert(R.FirstAid(19)==11 and R.FirstAid(20,2)==24 and R.ReviveChance(20)==.1 and R.ReviveChance(200)==1)
assert(R.CraftExperience({},5)==250 and R.CraftExperience({OutputCount=3},1)==50 and R.CraftExperience({XP=80},2)==160)
assert(R.KillExperience(20)==50 and R.KillExperience(60)==150)
assert(R.AddXP(s,.5) and s.XP==.5,"healing grants exact actual HP including fractions")
print("PASS: initial INT skill bundle and perk point; 1000*level XP; per-item practice; all nine perk requirements/rank caps/effects; medical and craft/kill XP")
