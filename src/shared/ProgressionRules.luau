local Rules={}
Rules.MaxLevel=30
local attributes={"Strength","Attention","Endurance","Intelligence","Agility","Luck"}
local skills={LightWeapons=true,HeavyWeapons=true,Unarmed=true,Melee=true,Throwing=true,FirstAid=true,Doctor=true,Sneak=true,Traps=true,Repair=true,Cook=true}
Rules.Perks={
 {ID="TunnelVision",Name="Tunnel vision",Max=1,Attributes={Attention=7},Description="Halves your vision angle and adds 10 studs of view range."},
 {ID="RangedDamage",Name="Bonus ranged damage",Max=2,Attributes={Attention=7,Luck=7},Description="+2 damage per bullet after damage resistance and absorption, per rank."},
 {ID="Regeneration",Name="Double regeneration",Max=1,Attributes={Endurance=7},Description="Doubles health regeneration."},
 {ID="Hearing",Name="Bonus awareness",Max=1,Attributes={Attention=7},Description="+2 Attention for hearing only. Can exceed 10."},
 {ID="StrongArm",Name="Strong arm",Max=1,Attributes={Strength=7},Description="Doubles the Strength damage bonus for melee and unarmed attacks."},
 {ID="StrongBack",Name="Strong back",Max=2,Attributes={Strength=6,Endurance=6},Description="+10 kg carrying capacity."},
 {ID="Lifegiver",Name="Lifegiver",Max=2,Attributes={Endurance=7},Description="+4 maximum HP per character level, per rank."},
 {ID="Criticals",Name="More criticals",Max=2,Attributes={Luck=7},Description="Doubles Luck-based critical chance per rank."},
 {ID="FieldHospital",Name="Field hospital",Max=1,Skills={Doctor=100},Description="Patients you revive can be revived again after 5 minutes instead of 10."},
 {ID="Medic",Name="Paramedic",Max=1,Skills={FirstAid=150},Description="Doubles HP restored by first aid."},
 {ID="HardCriticals",Name="Brutal criticals",Max=1,Attributes={Luck=7},Skills={Doctor=150},Description="Raises the maximum critical damage multiplier from 2 to 2.5. Criticals roll between 1.5 and 2.5."},
 {ID="DoctorFortune",Name="Fortune favors doctors",Max=1,Attributes={Luck=7},Skills={Doctor=200},Description="Luck + 10% chance on a successful revival to restore full health and remove the patient's revival lock."},
 {ID="SilentRun",Name="Silent running",Max=1,Attributes={Agility=7},Skills={Sneak=150},Description="Sneak also reduces running noise."},
 {ID="Economist",Name="Economist",Max=1,Skills={Repair=150},Description="Crafting uses 20% fewer ingredients, rounded up per ingredient."},
 {ID="GoodStudent",Name="Good student",Max=1,Attributes={Intelligence=7},Description="Doubles all experience gained."},
 {ID="CatEyes",Name="Cat eyes",Max=1,Attributes={Attention=7},Description="Night reduces accuracy by only 10% instead of 50%."},
 {ID="Observant",Name="Overly observant",Max=1,Attributes={Attention=8},FreeSlot=true,Description="Reveals target names, health and equipped weapons. Granted automatically at level 30; excluded from the ten-perk limit."},
 {ID="Armadillo",Name="Armadillo",Max=2,Attributes={Endurance=6,Luck=6},Description="+2 damage absorption and +10% damage resistance per rank."},
 {ID="NotSoEasy",Name="Not so easy",Max=1,Attributes={Endurance=8},Description="+10% damage resistance while below 25% maximum health."},
 {ID="Duelist",Name="Duelist",Max=1,Attributes={Luck=6},Skills={LightWeapons=150},Description="+10% critical chance with pistols."},
 {ID="DroppedIt",Name="Dropped something?",Max=1,Attributes={Luck=6},Skills={LightWeapons=150},Description="Bolt-action hits have a 10% chance to drop the target's held weapon. Zombie hands are excluded."},
 {ID="WeaponPart",Name="My weapon is part of me",Max=1,Attributes={Strength=6},Description="The weapon equipped in your hands weighs nothing. Ammunition retains its weight."},
 {ID="SilentDeath",Name="Silent death",Max=1,Attributes={Agility=7},Skills={Sneak=150,Melee=100},Description="Melee and unarmed hits from behind are guaranteed criticals with a fixed 2.5 multiplier."},
 {ID="UnarmedDamage",Name="Bonus unarmed damage",Max=1,Attributes={Agility=7},Skills={Unarmed=150},Description="+10 damage with unarmed attacks."},
 {ID="LivingAnatomy",Name="Living anatomy",Max=1,Attributes={Intelligence=6},Skills={Doctor=150},Description="Each damaging hit has a 10% chance to ignore armor and defensive perks. Does not bypass friendly-fire or creation protection."},
 {ID="FastFeet",Name="Fast feet",Max=1,Attributes={Agility=8,Endurance=6},Description="+20% walking and sprint speed, plus 1 stud per second sprint speed."},
 {ID="UnarmedEvade",Name="Unarmed evasion",Max=1,Attributes={Agility=8},Skills={Unarmed=150},Description="+15 armor class while your hands are empty."},
 {ID="Dodger",Name="Dodger",Max=1,Attributes={Agility=7},Description="+20 armor class."},
 {ID="QuickRecovery",Name="Quick recovery",Max=1,Attributes={Endurance=7},Description="+4 HP regeneration per minute. Your patient revival lock is 3 minutes shorter. Revivals restore an additional 20% of your maximum HP."},
 {ID="PiercingStrike",Name="Piercing strike",Max=1,Attributes={Strength=7},Skills={Melee=150},Description="Melee and unarmed attacks ignore 2 absorption and 10% resistance."},
 {ID="Sniper",Name="Sniper",Max=1,Attributes={Attention=8},Skills={LightWeapons=200},Description="+10% critical chance with bolt-action rifles after standing still for 2 seconds."},
 {ID="Cowboy",Name="Cowboy",Max=1,Attributes={Agility=6},Skills={LightWeapons=100,Melee=100},Description="+15% damage with pistols and knives."},
 {ID="Ramsay",Name="Ramsay",Max=1,Attributes={Intelligence=6},Skills={Cook=150},Description="Food you prepare restores 5 HP and provides 50% more positive nutrition. The food retains this quality when shared."},
 {ID="Scrounger",Name="Scrounger",Max=1,Attributes={Luck=7,Attention=6},Description="25% more ammunition in loot from zombies you kill, when ammunition drops."},
 {ID="KhersonMelons",Name="Kherson watermelons",Max=1,Description="Garden beds in your greenhouse yield 50% more crops."},
}
local passive={Lumberjack=true,Miner=true,Scavenger=true,Farmer=true}
function Rules.New()
 local stats={};for _,id in ipairs(attributes) do stats[id]=5 end
 local ranks={};for id in pairs(skills) do ranks[id]=0 end
 local practice={};for id in pairs(passive) do practice[id]={Value=0,XP=0} end
 return {Level=0,XP=0,Points=6,SkillPoints=0,PerkPoints=0,Confirmed=false,Stats=stats,Skills=ranks,Practice=practice,Perks={},TaggedSkills={},TagsConfirmed=false}
end
local function validTags(tags)
 if typeof(tags)~="table" or #tags~=3 then return nil end
 local result={}
 for key,id in pairs(tags) do
  if typeof(key)~="number" or key<1 or key>3 or key~=math.floor(key) or not skills[id] or result[id] then return nil end
  result[id]=true
 end
 local count=0;for _ in pairs(result) do count+=1 end
 return count==3 and result or nil
end
function Rules.SelectTags(state,tags)
 if state.TagsConfirmed then return false end
 local selected=validTags(tags)
 if not selected then return false end
 state.TaggedSkills=selected;state.TagsConfirmed=true
 return true
end
function Rules.Confirm(state,stats,tags)
 if state.Confirmed or typeof(stats)~="table" then return false end
 local selected=tags~=nil and validTags(tags) or nil
 if tags~=nil and not selected then return false end
 local sum=0
 for key in pairs(stats) do if state.Stats[key]==nil then return false end end
 for _,id in ipairs(attributes) do
  local v=stats[id]
  if typeof(v)~="number" or v~=v or v~=math.floor(v) or v<1 or v>10 then return false end
  sum+=v
 end
 if sum~=36 then return false end
 if selected then state.TaggedSkills=selected;state.TagsConfirmed=true end
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
 for id in pairs(passive) do values[id]=state.Practice[id] and state.Practice[id].Value or 0 end
 return values
end
function Rules.SkillQuote(state,id,current)
 if not skills[id] then return nil end
 current=current or Rules.TotalSkills(state)[id]
 if current>=300 then return nil end
 local gain=math.min(state.TaggedSkills and state.TaggedSkills[id] and 2 or 1,300-current)
 -- Crossing a tier uses the destination tier, including both tagged skill points.
 local cost=math.max(1,math.ceil((current+gain)/100))
 return gain,cost
end
function Rules.SpendSkill(state,id)
 if not state.Confirmed then return false end
 local gain,cost=Rules.SkillQuote(state,id)
 if not gain or state.SkillPoints<cost then return false end
 state.Skills[id]+=gain;state.SkillPoints-=cost;return true
end
function Rules.RequiredXP(level) return 500*(level+1) end
function Rules.AddXP(state,amount)
 if not state.Confirmed or typeof(amount)~="number" or amount~=amount or amount<=0 or amount==math.huge then return false end
 if state.Level>=Rules.MaxLevel then state.Level=Rules.MaxLevel;state.XP=0;state.Perks.Observant=1;return false end
 state.XP+=amount*(1+(state.Perks.GoodStudent or 0))
 while state.Level<Rules.MaxLevel and state.XP>=Rules.RequiredXP(state.Level) do
  state.XP-=Rules.RequiredXP(state.Level);state.Level+=1;state.SkillPoints+=5+state.Stats.Intelligence
  if state.Level%3==0 then state.PerkPoints+=1 end
 end
 if state.Level>=Rules.MaxLevel then state.Perks.Observant=1;state.XP=0 end
 return true
end
function Rules.ResetProgression(state)
 if not state.Confirmed then return false end
 local fresh=Rules.New()
 state.Level=1;state.XP=0;state.Skills=fresh.Skills;state.Practice=fresh.Practice;state.Perks={}
 -- The game starts at level zero: retain the creation bundle plus level one's rewards.
 state.SkillPoints=2*(5+state.Stats.Intelligence);state.PerkPoints=0
 return true
end
function Rules.Practice(state,id,amount)
 if not state.Confirmed or not passive[id] or typeof(amount)~="number" or amount<=0 or amount~=math.floor(amount) or amount==math.huge then return false end
 state.Practice[id]=state.Practice[id] or {Value=0,XP=0}
 local s=state.Practice[id];s.XP+=amount*(1+(state.Perks.GoodStudent or 0))
 while s.Value<300 and s.XP>=10*(s.Value+1) do s.XP-=10*(s.Value+1);s.Value+=1 end
 if s.Value==300 then s.XP=0 end
 return true
end
function Rules.MovementMultiplier(total)
 return 1+math.clamp(math.max(total.Unarmed or 0,total.Melee or 0),0,200)/200
end
function Rules.Bonuses(stats,perks,level,total)
 local p=perks or {}
 local movement=Rules.MovementMultiplier(total or {})
 local hearing=stats.Attention+2*(p.Hearing or 0)
 local playerLevel=math.clamp(level or 0,0,Rules.MaxLevel)
 return {CarryLimitKg=5*stats.Strength+playerLevel+10*(p.StrongBack or 0),MeleeBonus=stats.Strength*(1+(p.StrongArm or 0)),MaxHealth=10*stats.Endurance+playerLevel*(stats.Endurance+4*(p.Lifegiver or 0)),
  WalkBonus=.2*stats.Agility*((p.FastFeet or 0)>0 and 1.2 or 1)*movement,RunBonus=(.4*stats.Agility*((p.FastFeet or 0)>0 and 1.2 or 1)+(p.FastFeet or 0))*movement,CombatMovementMultiplier=movement,Regeneration=(stats.Endurance+4*(p.QuickRecovery or 0))*(1+(p.Regeneration or 0)),
  DodgeChance=5*stats.Agility+20*(p.Dodger or 0),CriticalChance=.01*stats.Luck*2^(p.Criticals or 0),
  ViewRange=10+3*stats.Attention+10*(p.TunnelVision or 0),ViewAngleMultiplier=(p.TunnelVision or 0)>0 and .5 or 1,HearingAttention=hearing,HearingMultiplier=hearing/5,ViewBonus=0,LuckChance=0,LuckAmount=0,
  UnarmedArmorClass=15*(p.UnarmedEvade or 0),ReviveLockReduction=180*(p.QuickRecovery or 0),ReviveHealthBonus=.2*(p.QuickRecovery or 0),MeleeIgnoreAbsorption=2*(p.PiercingStrike or 0),MeleeIgnoreResistance=.1*(p.PiercingStrike or 0),SniperCriticalBonus=.1*(p.Sniper or 0),CowboyMultiplier=(p.Cowboy or 0)>0 and 1.15 or 1,ScroungerMultiplier=(p.Scrounger or 0)>0 and 1.25 or 1,GreenhouseYieldMultiplier=(p.KhersonMelons or 0)>0 and 1.5 or 1,
  BackstabCritical=(p.SilentDeath or 0)>0,UnarmedDamageBonus=10*(p.UnarmedDamage or 0),ArmorBypassChance=(p.LivingAnatomy or 0)>0 and .1 or 0,
  CriticalMin=1.5,CriticalMax=(p.HardCriticals or 0)>0 and 2.5 or 2,DoctorFortuneChance=(p.DoctorFortune or 0)>0 and (.1+.01*stats.Luck) or 0,SilentRunning=(p.SilentRun or 0)>0,CraftCostMultiplier=(p.Economist or 0)>0 and .8 or 1,ExperienceMultiplier=1+(p.GoodStudent or 0),NightAccuracyMultiplier=(p.CatEyes or 0)>0 and .9 or .5,Observant=(p.Observant or 0)>0,DamageAbsorption=2*(p.Armadillo or 0),DamageResistance=.1*(p.Armadillo or 0),LowHealthResistance=(p.NotSoEasy or 0)>0 and .1 or 0,PistolCriticalBonus=(p.Duelist or 0)>0 and .1 or 0,DisarmChance=(p.DroppedIt or 0)>0 and .1 or 0,EquippedWeaponWeightMultiplier=(p.WeaponPart or 0)>0 and 0 or 1,
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
function Rules.PerkCount(state)
 local count=0
 for id,rank in pairs(state.Perks or {}) do if id~="Observant" then count+=rank end end
 return count
end
function Rules.SpendPerk(state,id)
 for _,perk in ipairs(Rules.Perks) do
  if perk.ID==id and (state.Perks[id] or 0)<perk.Max and (perk.FreeSlot or ((state.PerkPoints or 0)>0 and Rules.PerkCount(state)<10)) and Rules.Meets(state,perk) then
   state.Perks[id]=(state.Perks[id] or 0)+1
   if not perk.FreeSlot then state.PerkPoints-=1 end
   return true
  end
 end
 return false
end
function Rules.FirstAid(skill,multiplier) return (10+math.floor(math.clamp(skill or 0,0,300)/10))*(multiplier or 1) end
function Rules.ReviveChance(skill) return math.clamp((skill or 0)/200,0,1) end
function Rules.CraftExperience(recipe,count) return (recipe.XP or 50)*count end
function Rules.KillExperience(health) return math.max(0,math.floor((health or 0)*2.5+.5)) end
function Rules.CraftEffects(perks) return {DurationMultiplier=1,BonusServing=0,Ramsay=perks and (perks.Ramsay or 0)>0 or false} end
function Rules.CraftOutputs(outputs,recipe,effects)
 local result={}
 for id,count in pairs(outputs) do result[effects and effects.Ramsay and recipe and recipe.Food and not (recipe.Byproducts and recipe.Byproducts[id]) and not (recipe.FuelByproducts and recipe.FuelByproducts[id]) and ("Ramsay_"..id) or id]=count end
 return result
end
function Rules.ZoomBounds(viewBonus,height,fieldOfView) return 18,height+(viewBonus or 0)/math.tan(math.rad(fieldOfView/2)) end
return Rules
