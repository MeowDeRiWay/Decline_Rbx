local Rules={}
local attributes={"Strength","Attention","Endurance","Intelligence","Agility","Luck"}
local skills={LightWeapons=true,HeavyWeapons=true,Unarmed=true,Melee=true,Throwing=true,FirstAid=true,Doctor=true,Sneak=true,Traps=true,Repair=true,Cook=true}
Rules.Perks={
 {ID="TunnelVision",Name="Tunnel vision",Max=1,Attributes={Attention=7},Description="Halves your vision angle and adds 10 studs of view range."},
 {ID="RangedDamage",Name="Bonus ranged damage",Max=2,Attributes={Attention=7,Luck=7},Description="+2 damage per bullet after damage resistance and absorption, per rank."},
 {ID="Regeneration",Name="Double regeneration",Max=1,Attributes={Endurance=7},Description="Doubles health regeneration."},
 {ID="Hearing",Name="Bonus awareness",Max=1,Attributes={Attention=7},Description="+2 Attention for hearing only. Can exceed 10."},
 {ID="StrongArm",Name="Strong arm",Max=1,Attributes={Strength=7},Description="Doubles the Strength damage bonus for melee and unarmed attacks."},
 {ID="StrongBack",Name="Strong back",Max=1,Attributes={Strength=7},Description="+10 kg carrying capacity."},
 {ID="Lifegiver",Name="Lifegiver",Max=2,Attributes={Endurance=7},Description="+5 maximum HP per Endurance, per rank."},
 {ID="Criticals",Name="More criticals",Max=1,Attributes={Luck=7},Description="Doubles critical chance from Luck."},
 {ID="FieldHospital",Name="Field hospital",Max=1,Skills={Doctor=100},Description="Patients you revive can be revived again after 5 minutes instead of 10."},
 {ID="Medic",Name="Paramedic",Max=1,Skills={FirstAid=150},Description="Doubles HP restored by first aid."},
}
local passive={Lumberjack=true,Miner=true,Scavenger=true}
function Rules.New()
 local stats={};for _,id in ipairs(attributes) do stats[id]=5 end
 local ranks={};for id in pairs(skills) do ranks[id]=0 end
 local practice={};for id in pairs(passive) do practice[id]={Value=0,XP=0} end
 return {Level=0,XP=0,Points=6,SkillPoints=0,PerkPoints=1,Confirmed=false,Stats=stats,Skills=ranks,Practice=practice,Perks={}}
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
 state.Stats=table.clone(stats);state.Points=0;state.Confirmed=true;state.SkillPoints=5+stats.Intelligence
 return true
end
function Rules.SkillValues(stats)
 return {LightWeapons=5*stats.Attention+stats.Agility,HeavyWeapons=3*stats.Strength+3*stats.Attention,
  Unarmed=5*stats.Strength+3*stats.Attention+5*stats.Agility,Melee=5*stats.Strength,
  Throwing=3*stats.Strength+5*stats.Agility,FirstAid=5*stats.Intelligence+2*stats.Attention,Doctor=5*stats.Intelligence+3*stats.Attention,
  Sneak=5*stats.Agility,Traps=5*stats.Attention,Repair=5*stats.Intelligence,Cook=4*stats.Intelligence+stats.Attention}
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
 if not state.Confirmed or typeof(amount)~="number" or amount~=amount or amount<=0 or amount==math.huge then return false end
 state.XP+=amount
 while state.XP>=1000*(state.Level+1) do
  state.XP-=1000*(state.Level+1);state.Level+=1;state.SkillPoints+=5+state.Stats.Intelligence;state.PerkPoints+=1
 end
 return true
end
function Rules.Practice(state,id,amount)
 if not state.Confirmed or not passive[id] or typeof(amount)~="number" or amount<=0 or amount~=math.floor(amount) or amount==math.huge then return false end
 local s=state.Practice[id];s.XP+=amount
 while s.Value<300 and s.XP>=10*(s.Value+1) do s.XP-=10*(s.Value+1);s.Value+=1 end
 if s.Value==300 then s.XP=0 end
 return true
end
function Rules.Bonuses(stats,perks)
 local p=perks or {}
 local hearing=stats.Attention+2*(p.Hearing or 0)
 return {CarryLimitKg=5*stats.Strength+10*(p.StrongBack or 0),MeleeBonus=stats.Strength*(1+(p.StrongArm or 0)),MaxHealth=(10+5*(p.Lifegiver or 0))*stats.Endurance,
  WalkBonus=.2*stats.Agility,RunBonus=.4*stats.Agility,Regeneration=2*stats.Endurance*(1+(p.Regeneration or 0)),
  DodgeChance=5*stats.Agility,CriticalChance=.01*stats.Luck*(1+(p.Criticals or 0)),
  ViewRange=10+3*stats.Attention+10*(p.TunnelVision or 0),ViewAngleMultiplier=(p.TunnelVision or 0)>0 and .5 or 1,HearingAttention=hearing,HearingMultiplier=hearing/5,ViewBonus=0,LuckChance=0,LuckAmount=0,
  RangedDamageBonus=2*(p.RangedDamage or 0),FirstAidMultiplier=1+(p.Medic or 0),ReviveLockSeconds=(p.FieldHospital or 0)>0 and 300 or 600}
end
function Rules.Meets(state,requirements)
 if not state.Confirmed then return false end
 if not requirements then return true end
 local total=Rules.TotalSkills(state)
 for id,value in pairs(requirements.Skills or {}) do if (total[id] or 0)<value then return false end end
 for id,value in pairs(requirements.Attributes or {}) do if (state.Stats[id] or 0)<value then return false end end
 return true
end
function Rules.SpendPerk(state,id)
 if (state.PerkPoints or 0)<1 then return false end
 for _,perk in ipairs(Rules.Perks) do
  if perk.ID==id and (state.Perks[id] or 0)<perk.Max and Rules.Meets(state,perk) then
   state.Perks[id]=(state.Perks[id] or 0)+1;state.PerkPoints-=1;return true
  end
 end
 return false
end
function Rules.FirstAid(skill,multiplier) return (10+math.floor(math.clamp(skill or 0,0,300)/10))*(multiplier or 1) end
function Rules.ReviveChance(skill) return math.clamp((skill or 0)/200,0,1) end
function Rules.CraftExperience(recipe,count) return (recipe.XP or 50)*count end
function Rules.KillExperience(health) return math.max(0,math.floor((health or 0)*2.5+.5)) end
function Rules.CraftEffects() return {DurationMultiplier=1,BonusServing=0} end
function Rules.CraftOutputs(outputs) return table.clone(outputs) end
function Rules.ZoomBounds(viewBonus,height,fieldOfView) return 18,height+(viewBonus or 0)/math.tan(math.rad(fieldOfView/2)) end
return Rules
