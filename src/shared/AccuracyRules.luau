local Rules={}
function Rules.Skill(base,bonus) return math.clamp((base or 25)+(bonus or 0),0,300) end
function Rules.Chance(base,bonus,distance,dodge)
 return math.clamp(Rules.Skill(base,bonus)-math.max(0,(distance or 0)-20)-math.max(0,dodge or 0),0,90)
end
return Rules
