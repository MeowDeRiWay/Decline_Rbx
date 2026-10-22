local P={}
local bonuses={
 Strength="+5 kg carrying capacity; +3 heavy weapons; +5 unarmed and melee; +3 throwing; +1 melee / unarmed damage",
 Attention="+5 light weapons and traps; +3 heavy weapons and unarmed; +2 first aid; +3 doctor; +1 cook; +3 studs view; +20% hearing range",
 Endurance="+10 HP; +2 HP regeneration per minute",
 Intelligence="+5 first aid, doctor and repair; +4 cook; +1 skill point per level",
 Agility="+5 armor class, unarmed, throwing and sneak; +1 light weapons; +0.2 walk speed; +0.4 sprint speed; +1 second sprint duration",
 Luck="+1% critical chance",
}
function P.Attribute(id) return bonuses[id] and "Per point: "..bonuses[id] or nil end
return P
