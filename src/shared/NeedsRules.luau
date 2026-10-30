local Rules = {}
local function emptyDuration(value, rate, dt)
 if value <= 0 then return dt end
 if rate <= 0 then return 0 end
 return math.max(0, dt - value / rate)
end
function Rules.Step(food, water, sick, rate, dt, config, maxHealth, resting, poisoned, knockedOut)
 food, water, sick = math.clamp(food, 0, 100), math.clamp(water, 0, 100), math.clamp(sick, 0, 100)
 local emptyTime = emptyDuration(food, rate, dt) + emptyDuration(water, rate, dt)
 local damageTime = emptyTime
 local sickTime=0
 if not resting and not knockedOut and sick >= config.SickThreshold then
  local growth=poisoned and 0 or config.SickGrowth
  local timeToMax = growth > 0 and (100 - sick) / growth or math.huge
  if sick == 100 then timeToMax = 0 end
  sickTime=math.max(0, dt - timeToMax)
  damageTime += sickTime
  sick = math.min(100, sick + growth * dt)
 end
 local damage=damageTime*config.NeedsDamage
 if config.NeedsDamagePeriod then damage=(emptyTime*config.StarvationDamageFraction+sickTime*config.SicknessDamageFraction)*(maxHealth or 100)/config.NeedsDamagePeriod end
 if knockedOut or resting then damage=0 end
 return math.max(0, food - rate * dt), math.max(0, water - rate * dt), sick, damage
end
return Rules
