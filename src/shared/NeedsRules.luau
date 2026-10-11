local Rules = {}
local function emptyDuration(value, rate, dt)
 if value <= 0 then return dt end
 if rate <= 0 then return 0 end
 return math.max(0, dt - value / rate)
end
function Rules.Step(food, water, sick, rate, dt, config)
 food, water, sick = math.clamp(food, 0, 100), math.clamp(water, 0, 100), math.clamp(sick, 0, 100)
 local damageTime = emptyDuration(food, rate, dt) + emptyDuration(water, rate, dt)
 if sick >= config.SickThreshold then
  local timeToMax = config.SickGrowth > 0 and (100 - sick) / config.SickGrowth or math.huge
  if sick == 100 then timeToMax = 0 end
  damageTime += math.max(0, dt - timeToMax)
  sick = math.min(100, sick + config.SickGrowth * dt)
 end
 return math.max(0, food - rate * dt), math.max(0, water - rate * dt), sick, damageTime * config.NeedsDamage
end
return Rules
