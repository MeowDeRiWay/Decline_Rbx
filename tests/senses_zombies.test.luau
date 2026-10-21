local S=require("../src/shared/SensesRules")
local Z=require("../src/shared/ZombieStats")
local P=require("../src/shared/ProgressionRules")
local D=require("../src/shared/DefenseRules")
local A=require("../src/shared/AccuracyRules")
assert(S.Range(1)==5 and S.Range(10)==50)
assert(S.Hearing(1)==.2 and S.Hearing(5)==1 and S.Hearing(10)==2)
local c=S.Curve({[0]=1,[20]=.5,[100]=0},2);assert(c[40]==.5 and c[200]==0)
assert(A.Chance(0,0,100,500)==5)
assert(math.abs(D.Resolve(100,1,0)-10)<1e-9)
local random={NextInteger=function(_,a,b) return math.random(a,b) end}
for _=1,1000 do
 local t=Z.Roll(random);local d=P.Bonuses(t);local skills=P.SkillValues(t)
 assert(t.Strength>=3 and t.Strength<=6 and t.Attention>=3 and t.Attention<=6)
 assert(t.Endurance>=3 and t.Endurance<=5 and t.Agility>=1 and t.Agility<=3 and t.Intelligence==1 and t.Luck==5)
 assert(d.MaxHealth>=30 and d.MaxHealth<=50 and d.ViewRange>=15 and d.ViewRange<=30 and d.DodgeChance>=5 and d.DodgeChance<=15)
 assert(skills.Unarmed==t.Strength*5+t.Attention*3+t.Agility*5 and d.CriticalChance==.05)
end
print("PASS: exact vision/hearing multipliers, scaled curves,5%floor,90%resistance and randomized zombie attributes/derived combat stats")
