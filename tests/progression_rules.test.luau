local Rules=require("../src/shared/ProgressionRules")
local state=Rules.New()
assert(state.Level==0 and state.XP==0 and state.Points==5)
assert(not Rules.Spend(Rules.New(0),"Strength"))
Rules.AddXP(state,99); assert(state.Level==0)
Rules.AddXP(state,1); assert(state.Level==1 and state.Points==10 and state.XP==0)
Rules.AddXP(state,200); assert(state.Level==2 and state.Points==15)
Rules.AddXP(state,4200); assert(state.Level==9 and state.XP==0 and state.Points==50)
Rules.AddXP(state,999); assert(state.Level==9)
Rules.AddXP(state,1); assert(state.Level==10 and state.Points==55 and state.XP==0)
assert(not Rules.AddXP(state,0/0) and not Rules.AddXP(state,math.huge))
assert(not Rules.Spend(state,"MadeUp"))
assert(Rules.Spend(state,"Strength") and state.Points==54)
local b=Rules.Bonuses(state.Stats)
assert(b.CarryLimitKg==21 and b.MeleeBonus==1 and b.MaxHealth==100 and b.Accuracy==.25 and b.LuckChance==0)
state.Stats.Endurance=2; state.Stats.Attention=100; state.Stats.Luck=100
b=Rules.Bonuses(state.Stats)
assert(b.MaxHealth==110 and b.RunBonus==.4 and b.Accuracy==.9 and b.ViewBonus==50 and b.LuckChance==.5)
local items={Stone=2,Scrap=4}
state.Stats.Luck=3
local lucky=Rules.BonusLoot(items,state.Stats,function() return 0 end)
assert(lucky.Stone==4 and lucky.Scrap==6 and items.Stone==2)
assert(Rules.BonusLoot(items,state.Stats,function() return 1 end).Stone==2)
local talent={Level=11,Requires={"Base"},Cost=1}
assert(not Rules.Learn(state,"Next",talent))
state.Level=11; assert(not Rules.Learn(state,"Next",talent))
state.Talents.Base=true; assert(Rules.Learn(state,"Next",talent))
state.TalentPoints=0
assert(not Rules.Learn(state,"Next",talent))
print("PASS: 0–10 XP curve, points, invalid allocations, bonuses/caps, independent bonus loot and talent level prerequisites")

local near,far=Rules.ZoomBounds(0,30,40)
assert(near==18 and far==30)
local _,expanded=Rules.ZoomBounds(20,30,40)
assert(math.abs((expanded-far)*math.tan(math.rad(20))-20)<1e-6)
local Movement=require("../src/shared/MovementRules")
local Game=require("../src/shared/GameConfig")
assert(Movement.LoadMultiplier(21,Game,21)==1)
assert(math.abs(Movement.LoadMultiplier(22,Game,21)-.95)<1e-6)
print("PASS: stable zoom limits and strength-adjusted carrying threshold")

local cook=Rules.New(); cook.Profession="Cook"
cook.Talents={SurpriseServing=true,GrandmasMethod=true,RamsayMethod=true}
local effects=Rules.CraftEffects(cook,"Stove",5)
assert(effects.DurationMultiplier==.8 and effects.BonusServing)
local recipe={Output="BoiledPotato",OutputCount=1}
local outputs=Rules.CraftOutputs({BoiledPotato=5},recipe,effects)
assert(outputs.BoiledPotato==6)
assert(Rules.CraftOutputs({BoiledPotato=4},recipe,Rules.CraftEffects(cook,"Stove",4)).BoiledPotato==4)
assert(Rules.CraftEffects(cook,"CuttingBoard",5).DurationMultiplier==.8)
assert(Rules.CraftEffects(cook,"CuttingBoard",5).BonusServing==0)
assert(Rules.CraftEffects(cook,"Workstation",5).DurationMultiplier==1)
cook.Stats.Luck=3
assert(Rules.BonusLoot(outputs,cook.Stats,function() return 0 end).BoiledPotato==8,"luck and bonus serving stack")
cook.Profession=""
assert(Rules.CraftEffects(cook,"Stove",5).BonusServing==0)
assert(Rules.CraftEffects(cook,"Stove",5).DurationMultiplier==1)
print("PASS: 5 initial points, full-batch serving, both cooking duration effects and independent luck stacking")

local ranked=Rules.New(); ranked.Profession="Cook"
assert(ranked.TalentPoints==0 and not Rules.Learn(ranked,"KnifeMaster",{Level=1}))
Rules.AddXP(ranked,5500)
assert(ranked.Level==10 and ranked.TalentPoints==10)
for i=1,10 do assert(Rules.Learn(ranked,"KnifeMaster",{Level=1})); assert(Rules.Rank(ranked,"KnifeMaster")==i) end
assert(ranked.TalentPoints==0 and not Rules.Learn(ranked,"KnifeMaster",{Level=1}))
ranked.TalentPoints=1; assert(not Rules.Learn(ranked,"KnifeMaster",{Level=1}),"max ten ranks")
local combat=Rules.CombatBonuses(ranked)
assert(combat.KnifeMultiplier==1.5 and combat.MeleeAbsorption==0)
ranked.Talents.KevlarApron=10
assert(Rules.CombatBonuses(ranked).MeleeAbsorption==10)
ranked.Profession="Worker"; ranked.Talents={Redhead=10,GoldenHands=10}
assert(Rules.CombatBonuses(ranked).KnifeMultiplier==1 and Rules.CombatBonuses(ranked).MeleeAbsorption==0)
assert(Rules.ShovelLoot(ranked,true,function() return .69 end)==1)
assert(Rules.ShovelLoot(ranked,true,function() return .71 end)==0)
assert(Rules.ShovelLoot(ranked,false,function() return 0 end)==0)
assert(math.abs(Rules.CraftEffects(ranked,"Workstation",1).DurationMultiplier-.6)<1e-6)
assert(Rules.CraftEffects(ranked,"Stove",5).DurationMultiplier==1)
print("PASS: one talent point per level, paid ranks 1–10, knife scaling, absorption, fixed-quantity shovel drops and Worker crafting speed")

local hunter=Rules.New();hunter.Profession="Hunter";hunter.Level=0;hunter.TalentPoints=100
local config=require("../src/shared/ProgressionConfig")
local defs=config.Professions.Hunter.Talents
assert(not Rules.Learn(hunter,"Automatics",defs.Automatics))
hunter.Level=1;assert(Rules.Learn(hunter,"Automatics",defs.Automatics))
assert(not Rules.Learn(hunter,"Careful",defs.Careful))
hunter.Level=5;assert(Rules.Learn(hunter,"Careful",defs.Careful))
assert(not Rules.Learn(hunter,"Bullseye",defs.Bullseye))
hunter.Level=10
for id,definition in pairs(defs) do while Rules.Rank(hunter,id)<10 do assert(Rules.Learn(hunter,id,definition)) end;assert(not Rules.Learn(hunter,id,definition)) end
local hb=Rules.CombatBonuses(hunter)
assert(hb.AutomaticAccuracyBonus==.5 and hb.AutomaticCritChance==.1)
assert(hb.PistolAccuracyBonus==.5 and hb.PistolCritChance==.5)
assert(hb.RifleAccuracyBonus==.5 and math.abs(hb.RifleCritChance-.7)<1e-6)
assert(hb.MachineGunAccuracyBonus==.5 and hb.MachineGunCritChance==.1)
assert(math.abs(hb.CriticalNegation-.9)<1e-6 and math.abs(hb.PreserveDurabilityChance-.9)<1e-6)
assert(math.abs(hb.AmmoWeightMultiplier-.2)<1e-6 and hb.DodgeChance==.5)
hunter.Profession="Cook";hb=Rules.CombatBonuses(hunter)
assert(hb.DodgeChance==0 and hb.RifleCritChance==0 and hb.AmmoWeightMultiplier==1,"Hunter effects never leak to another profession")
local inventory=require("../src/shared/InventoryRules")
local items=require("../src/shared/ItemConfig").Items
local weight=inventory.Weight({Items={Ammo223FMJ=100,TreeLog=1},Equipment={}},items,.2)
assert(math.abs(weight-2.24)<1e-6,"only ammo weight reduced")
print("PASS: Hunter levels1/5/10, ten paid ranks, all exact bonuses, rifle crit stacking, profession isolation and ammo-only weight")
