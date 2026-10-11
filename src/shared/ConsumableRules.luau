local Rules = {}
function Rules.Apply(food, sick, effects)
 return math.clamp(food + (effects.Food or 0), 0, 100), math.clamp(sick + (effects.Sick or 0), 0, 100)
end
return Rules
