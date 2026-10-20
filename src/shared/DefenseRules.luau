local Rules={}
-- Resistance is a fraction of incoming damage; flat absorption follows it.
function Rules.Resolve(damage,resistance,absorption)
 return math.max(0,math.max(0,damage)*(1-math.clamp(resistance or 0,0,1))-math.max(0,absorption or 0))
end
return Rules
