local Rules = {}
function Rules.New(startingPoints)
 return {Level=0, XP=0, Points=startingPoints or 5, Profession="", TalentPoints=0, Stats={Strength=0,Endurance=0,Attention=0,Luck=0}, Talents={}}
end
function Rules.AddXP(state,amount)
 if typeof(amount)~="number" or amount~=amount or amount<=0 or amount==math.huge or amount~=math.floor(amount) then return false end
 state.XP+=amount
 while state.XP>=100*(state.Level+1) do
  state.XP-=100*(state.Level+1); state.Level+=1; state.Points+=5; state.TalentPoints+=1
 end
 return true
end
function Rules.Spend(state,stat)
 if state.Stats[stat]==nil or state.Points<1 then return false end
 state.Stats[stat]+=1; state.Points-=1
 return true
end
function Rules.Bonuses(stats)
 return {CarryLimitKg=20+stats.Strength, MeleeBonus=stats.Strength, RunBonus=.2*stats.Endurance,
  MaxHealth=100+5*stats.Endurance, Accuracy=math.min(.9,.25+.02*stats.Attention),
  ViewBonus=2*stats.Attention, LuckChance=math.min(.5,.03*stats.Luck), LuckAmount=1+math.floor(stats.Luck/3)}
end
function Rules.BonusLoot(items,stats,roll)
 local result=table.clone(items)
 local bonus=Rules.Bonuses(stats)
 for id,count in pairs(items) do
  if count>0 and bonus.LuckChance>0 and roll()<bonus.LuckChance then result[id]=count+bonus.LuckAmount end
 end
 return result
end
function Rules.Rank(state,id)
 local value=state.Talents[id]
 return value==true and 1 or typeof(value)=="number" and value or 0
end
function Rules.CanLearn(state,id,definition)
 if not definition or Rules.Rank(state,id)>=10 or (state.TalentPoints or 0)<1 or state.Level<(definition.Level or 1) then return false end
 for _,parent in ipairs(definition.Requires or {}) do if Rules.Rank(state,parent)<1 then return false end end
 return true
end
function Rules.Learn(state,id,definition)
 if not Rules.CanLearn(state,id,definition) then return false end
 state.Talents[id]=Rules.Rank(state,id)+1; state.TalentPoints-=1
 return true
end
function Rules.CombatBonuses(state)
 local cook=state.Profession=="Cook"
 local knife=cook and Rules.Rank(state,"KnifeMaster") or 0
 return {KnifeMultiplier=1+.05*knife,MeleeAbsorption=cook and Rules.Rank(state,"KevlarApron") or 0}
end
function Rules.ShovelLoot(state,isShovel,roll)
 local chance=state.Profession=="Worker" and .07*Rules.Rank(state,"Redhead") or 0
 return isShovel and chance>0 and roll()<chance and 1 or 0
end
-- Effects are captured when work starts, independently from luck.
function Rules.CraftEffects(state,station,count)
 local effects={DurationMultiplier=1,BonusServing=0}
 if state.Profession=="Cook" then
  if station=="Stove" then
   effects.DurationMultiplier=.8^Rules.Rank(state,"GrandmasMethod")
   effects.BonusServing=count==5 and Rules.Rank(state,"SurpriseServing") or 0
  elseif station=="CuttingBoard" then effects.DurationMultiplier=.8^Rules.Rank(state,"RamsayMethod") end
 elseif state.Profession=="Worker" and station=="Workstation" then
  effects.DurationMultiplier=1-.04*Rules.Rank(state,"GoldenHands")
 end
 return effects
end
function Rules.CraftOutputs(outputs,recipe,effects)
 local result=table.clone(outputs)
 if effects.BonusServing>0 and recipe.Output and result[recipe.Output] then
  result[recipe.Output]+=(recipe.OutputCount or 1)*effects.BonusServing
 end
 return result
end
-- Zoom bounds are independent of facing/mouse position; Attention expands only the far limit.
function Rules.ZoomBounds(viewBonus,height,fieldOfView)
 return 18,height+viewBonus/math.tan(math.rad(fieldOfView/2))
end
return Rules
