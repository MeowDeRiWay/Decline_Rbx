local Rules={}
function Rules.CureChance(luck,config)
 return math.clamp(config.AntisepticBaseChance+math.max(0,luck or 0)*config.AntisepticChancePerLuck,0,1)
end
function Rules.SickReduction(medicine,firstAid,paramedic)
 local steps=math.floor(math.clamp(firstAid or 0,0,300)/20)
 if medicine=="Antiseptic" then return 20+steps end
 if medicine=="SterileBandage" then return 20+2*steps+(paramedic and 10 or 0) end
 return 0
end
function Rules.Harmful(food,water,sick) return (food or 100)<=0 or (water or 100)<=0 or (sick or 0)>=100 end
return Rules
