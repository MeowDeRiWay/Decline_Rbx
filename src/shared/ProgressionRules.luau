local Rules={}
local attributes={"Strength","Attention","Endurance","Intelligence","Agility","Luck"}
local skills={LightWeapons=true,HeavyWeapons=true,Unarmed=true,Melee=true,Throwing=true,FirstAid=true,Doctor=true,Sneak=true,Traps=true,Repair=true}
local passive={Lumberjack=true,Miner=true,Scavenger=true}
function Rules.New()
 local stats={};for _,id in ipairs(attributes) do stats[id]=5 end
 local ranks={};for id in pairs(skills) do ranks[id]=0 end
 local practice={};for id in pairs(passive) do practice[id]={Value=0,XP=0} end
 return {Level=0,XP=0,Points=6,SkillPoints=0,Confirmed=false,Stats=stats,Skills=ranks,Practice=practice,Perks={}}
end
function Rules.Confirm(state,stats)
 if state.Confirmed or typeof(stats)~="table" then return false end
 local sum=0
 for key in pairs(stats) do if state.Stats[key]==nil then return false end end
 for _,id in ipairs(attributes) do
  local v=stats[id]
  if typeof(v)~="number" or v~=v or v~=math.floor(v) or v<1 or v>10 then return false end
  sum+=v
 end
 if sum~=36 then return false end
 state.Stats=table.clone(stats);state.Points=0;state.Confirmed=true
 return true
end
function Rules.SkillValues(stats)
 return {LightWeapons=5*stats.Attention,HeavyWeapons=5*stats.Strength+3*stats.Attention,
  Unarmed=5*stats.Strength+3*stats.Attention+5*stats.Agility,Melee=5*stats.Strength,
  Throwing=3*stats.Strength+5*stats.Agility,FirstAid=5*stats.Intelligence,Doctor=5*stats.Intelligence,
  Sneak=5*stats.Agility,Traps=5*stats.Attention,Repair=5*stats.Intelligence}
end
function Rules.TotalSkills(state)
 local values=Rules.SkillValues(state.Stats)
 for id in pairs(skills) do values[id]=math.min(300,values[id]+(state.Skills[id] or 0)) end
 for id in pairs(passive) do values[id]=state.Practice[id].Value end
 return values
end
function Rules.SpendSkill(state,id)
 if not state.Confirmed or not skills[id] or state.SkillPoints<1 or Rules.TotalSkills(state)[id]>=300 then return false end
 state.Skills[id]+=1;state.SkillPoints-=1;return true
end
function Rules.AddXP(state,amount)
 if not state.Confirmed or typeof(amount)~="number" or amount~=amount or amount<=0 or amount==math.huge or amount~=math.floor(amount) then return false end
 state.XP+=amount
 while state.XP>=100*(state.Level+1) do
  state.XP-=100*(state.Level+1);state.Level+=1;state.SkillPoints+=5+state.Stats.Intelligence
 end
 return true
end
function Rules.Practice(state,id,amount)
 if not state.Confirmed or not passive[id] or typeof(amount)~="number" or amount<=0 or amount~=math.floor(amount) or amount==math.huge then return false end
 local s=state.Practice[id];s.XP+=amount
 while s.Value<300 and s.XP>=100*(s.Value+1) do s.XP-=100*(s.Value+1);s.Value+=1 end
 if s.Value==300 then s.XP=0 end
 return true
end
function Rules.Bonuses(stats)
 return {CarryLimitKg=20+5*stats.Strength,MeleeBonus=stats.Strength,MaxHealth=100+10*stats.Endurance,
  WalkBonus=.3*stats.Agility,RunBonus=stats.Agility,Regeneration=2*stats.Endurance,
  DodgeChance=5*stats.Agility,CriticalChance=.01*stats.Luck,
  ViewBonus=0,LuckChance=0,LuckAmount=0}
end
function Rules.Meets(state,requirements)
 if not state.Confirmed then return false end
 if not requirements then return true end
 local total=Rules.TotalSkills(state)
 for id,value in pairs(requirements.Skills or {}) do if (total[id] or 0)<value then return false end end
 for id,value in pairs(requirements.Attributes or {}) do if (state.Stats[id] or 0)<value then return false end end
 return true
end
function Rules.CraftEffects() return {DurationMultiplier=1,BonusServing=0} end
function Rules.CraftOutputs(outputs) return table.clone(outputs) end
function Rules.ZoomBounds(viewBonus,height,fieldOfView) return 18,height+(viewBonus or 0)/math.tan(math.rad(fieldOfView/2)) end
return Rules
