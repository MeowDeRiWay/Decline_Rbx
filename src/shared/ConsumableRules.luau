local Rules = {}
function Rules.Apply(food, sick, effects, water)
 return math.clamp(food + (effects.Food or 0), 0, 100), math.clamp(sick + (effects.Sick or 0), 0, 100), math.clamp((water or 100) + (effects.Water or 0), 0, 100)
end
return Rules
