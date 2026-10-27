local R=require("../src/shared/ProgressionRules")
local function fresh()
 local s=R.New()
 local attrs=table.clone(s.Stats);attrs.Intelligence=10;attrs.Endurance=6
 return s,attrs
end
local main={"LightWeapons","Doctor","Repair"}
for _,invalid in ipairs({{}, {"Doctor","Repair"},{"Doctor","Doctor","Repair"},{"Doctor","Repair","Miner"},{"Doctor","Repair","Farmer"},{"Doctor","Repair","Fake"},{"Doctor","Repair","LightWeapons","Cook"}}) do
 local s,attrs=fresh();assert(not R.Confirm(s,attrs,invalid) and not s.Confirmed and not s.TagsConfirmed)
end
local s,attrs=fresh();assert(R.Confirm(s,attrs,main));assert(s.TagsConfirmed and s.TaggedSkills.Doctor)
main[1]="Cook";assert(s.TaggedSkills.LightWeapons and not s.TaggedSkills.Cook,"copied selection")
assert(not R.SelectTags(s,{"Cook","Melee","Doctor"}),"selection is immutable")
local baseline=R.TotalSkills(s).Repair;s.SkillPoints=10
assert(R.SpendSkill(s,"Repair") and R.TotalSkills(s).Repair==baseline+2 and s.SkillPoints==9,"tagged: +2 per purchase, no doubled starting attribute bonus")
local plain=R.TotalSkills(s).Cook
assert(R.SpendSkill(s,"Cook") and R.TotalSkills(s).Cook==plain+1 and s.SkillPoints==8)
local function at(value,tagged)
 local t=R.New();t.Confirmed=true;t.Stats={Strength=1,Attention=1,Endurance=1,Intelligence=1,Agility=1,Luck=1}
 t.Skills.Repair=value-3;t.SkillPoints=100;t.TaggedSkills=tagged and {Repair=true} or {}
 return t
end
for _,case in ipairs({{0,1},{99,1},{100,2},{199,2},{200,3},{299,3}}) do
 local t=at(case[1],false);local gain,cost=R.SkillQuote(t,"Repair")
 assert(gain==1 and cost==case[2]);assert(R.SpendSkill(t,"Repair") and t.SkillPoints==100-cost and R.TotalSkills(t).Repair==case[1]+1)
end
for _,case in ipairs({{98,2,1},{99,2,2},{100,2,2},{198,2,2},{199,2,3},{200,2,3},{298,2,3},{299,1,3}}) do
 local t=at(case[1],true);local gain,cost=R.SkillQuote(t,"Repair")
 assert(gain==case[2] and cost==case[3],"tagged destination tier")
 t.SkillPoints=cost-1;local before=t.Skills.Repair
 assert(not R.SpendSkill(t,"Repair") and t.Skills.Repair==before and t.SkillPoints==cost-1,"atomic affordability")
 t.SkillPoints=cost;assert(R.SpendSkill(t,"Repair") and t.SkillPoints==0 and R.TotalSkills(t).Repair==case[1]+gain)
end
local capped=at(300,true);assert(not R.SkillQuote(capped,"Repair") and not R.SpendSkill(capped,"Repair"))
assert(not R.SkillQuote(s,"Miner") and not R.SpendSkill(s,"Miner"),"passive skills are XP-only")
local legacy=at(100,false);local attrsBefore=table.clone(legacy.Stats)
assert(R.SelectTags(legacy,{"Cook","Melee","Doctor"}))
for id,value in pairs(attrsBefore) do assert(legacy.Stats[id]==value) end
assert(not R.SelectTags(legacy,{"Repair","Melee","Doctor"}))
print("PASS: exactly three immutable tags, legacy selection, +2 gains, base skills unchanged, all tier boundaries, affordability, cap300 and passive exclusion")
