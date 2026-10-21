local P={}
local bonuses={Strength="+5 capacity, heavy weapons, unarmed, melee; +3 throwing; +1 melee damage",Attention="+5 light weapons, traps; +3 heavy weapons, unarmed; +5 studs view; +20% hearing volume/range",Endurance="+10 HP; +2 regeneration",Intelligence="+5 first aid, doctor, repair; +1 skill point per level",Agility="+5 armor class, unarmed, throwing, sneak; +0.3 walk speed; +1 sprint speed",Luck="+1% critical chance"}
function P.Attribute(id) return bonuses[id] and "Per point: "..bonuses[id] or nil end
return P
