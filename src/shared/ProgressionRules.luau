local Rules = {}
function Rules.New()
 return {Level=0, XP=0, Points=0, Profession="", Stats={Strength=0,Endurance=0,Attention=0,Luck=0}, Talents={}}
end
function Rules.AddXP(state,amount)
 if typeof(amount)~="number" or amount~=amount or amount<=0 or amount==math.huge or amount~=math.floor(amount) then return false end
 state.XP+=amount
 while state.XP>=100*(state.Level+1) do
  state.XP-=100*(state.Level+1); state.Level+=1; state.Points+=5
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
  ViewBonus=5*stats.Attention, LuckChance=math.min(.5,.03*stats.Luck), LuckAmount=1+math.floor(stats.Luck/3)}
end
function Rules.BonusLoot(items,stats,roll)
 local result=table.clone(items)
 local bonus=Rules.Bonuses(stats)
 for id,count in pairs(items) do
  if count>0 and bonus.LuckChance>0 and roll()<bonus.LuckChance then result[id]=count+bonus.LuckAmount end
 end
 return result
end
-- A talent is available only for the selected profession and after its prerequisites.
function Rules.Learn(state,id,definition)
 if not definition or state.Talents[id] or state.Level<(definition.Level or 0) then return false end
 for _,parent in ipairs(definition.Requires or {}) do if not state.Talents[parent] then return false end end
 state.Talents[id]=true
 return true
end
-- Forward ground distance to the perspective frustum edge, in camera-local coordinates.
function Rules.ViewScale(origin,direction,tangent,aspect,bonus)
 local extent=math.huge
 for _,axis in ipairs({{origin.X,direction.X,tangent*aspect},{origin.Y,direction.Y,tangent}}) do
  for _,sign in ipairs({-1,1}) do
   local denominator=sign*axis[2]+direction.Z*axis[3]
   if denominator>1e-6 then extent=math.min(extent,(-origin.Z*axis[3]-sign*axis[1])/denominator) end
  end
 end
 return extent>0 and extent<math.huge and 1+bonus/extent or 1,extent
end
return Rules
