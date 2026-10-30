local Rules={}
function Rules.CureChance(luck,config)
 return math.clamp(config.AntisepticBaseChance+math.max(0,luck or 0)*config.AntisepticChancePerLuck,0,1)
end
function Rules.Harmful(food,water,sick) return (food or 100)<=0 or (water or 100)<=0 or (sick or 0)>=100 end
return Rules
