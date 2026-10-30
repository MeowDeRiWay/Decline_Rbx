local Needs=require("../src/shared/NeedsRules")
local Config=require("../src/shared/GameConfig")
local Medical=require("../src/shared/MedicalRules")
local M=require("../src/shared/MedicalConfig")
local Sprint=require("../src/shared/SprintRules")
assert(M.ZombiePoisonEnabled==false and M.PoisonChance==.05)
assert(Medical.CureChance(0,M)==.25 and Medical.CureChance(5,M)==.5 and Medical.CureChance(10,M)==.75 and Medical.CureChance(50,M)==1)
for _,maxHP in ipairs({50,100,200}) do
 local _,_,_,hunger=Needs.Step(0,100,0,0,3,Config,maxHP)
 local _,_,_,thirst=Needs.Step(100,0,0,0,3,Config,maxHP)
 local _,_,_,sick=Needs.Step(100,100,100,0,3,Config,maxHP)
 local _,_,_,all=Needs.Step(0,0,100,0,3,Config,maxHP)
 assert(hunger==maxHP*.005 and thirst==hunger and sick==maxHP*.01 and all==maxHP*.02)
end
assert(Medical.Harmful(0,100,0) and Medical.Harmful(100,0,0) and Medical.Harmful(100,100,100) and not Medical.Harmful(1,1,99))
local value=Sprint.Step(10,10,false,true,true,true,1,2);assert(value==8)
value=Sprint.Step(10,10,false,true,true,true,1);assert(value==9)
local _,_,sick=Needs.Step(100,100,75,0,5,Config,100,true);assert(sick==75,"hospital suppresses sickness progression")
local _,_,poisonSick=Needs.Step(100,100,60,0,5,Config,100,false,true);assert(poisonSick==60,"poisoning must not also add the background sickness growth")
print("PASS: max-HP survival rates, additive hazards, regeneration gates, cure chance/Luck cap, disabled zombie poison and double sprint cost")

for _,value in ipairs({0,19,20,100,300}) do
 local steps=math.floor(value/20)
 assert(Medical.SickReduction("Antiseptic",value,true)==20+steps)
 assert(Medical.SickReduction("SterileBandage",value,false)==20+2*steps)
 assert(Medical.SickReduction("SterileBandage",value,true)==30+2*steps)
end
local _,_,sick,damage=Needs.Step(0,0,80,0,100,Config,100,false,false,true)
assert(sick==80 and damage==0,"KO preserves Sick80 and accumulated HP despite starvation/thirst")
local _,_,sick=Needs.Step(100,100,80,0,5,Config,100,false,false,false)
assert(sick>80,"progression resumes when conscious")
local Rules=require("../src/shared/ProgressionRules")
local examination
for _,perk in ipairs(Rules.Perks) do if perk.ID=="QuickExamination" then examination=perk end end
assert(examination.Skills.Doctor==150 and examination.Max==1)
local state=Rules.New();state.Perks.QuickExamination=1
assert(Rules.Bonuses(state.Stats,state.Perks,0).QuickExamination)
