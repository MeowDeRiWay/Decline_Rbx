local P={}
local bonuses={
 Strength="+5 kg carrying capacity; +3 heavy weapons; +5 unarmed and melee; +3 throwing; +1 melee / unarmed damage",
 Attention="+5 light weapons and traps; +3 heavy weapons and unarmed; +2 first aid; +3 doctor; +1 cook; +3 studs view (10 base); +20% hearing range",
 Endurance="+10 HP; +1 HP regeneration per minute",
 Intelligence="+5 first aid, doctor and repair; +4 cook; +1 skill point per level",
 Agility="+5 armor class, unarmed, throwing and sneak; +1 light weapons; +0.2 walk speed; +0.4 sprint speed; +1 second sprint duration",
 Luck="+1% critical chance",
}
function P.Attribute(id) return bonuses[id] and "Per point: "..bonuses[id] or nil end
function P.PerkRequirements(perk,names)
 local parts={}
 for _,key in ipairs({"Attributes","Skills"}) do
  local sorted={}
  for id,value in pairs(perk[key] or {}) do table.insert(sorted,{ID=id,Value=value}) end
  table.sort(sorted,function(a,b) return a.ID<b.ID end)
  for _,entry in ipairs(sorted) do table.insert(parts,(names and names[entry.ID] or entry.ID).." "..entry.Value) end
 end
 local text=#parts>0 and ("Requires: "..table.concat(parts,", ")) or "No requirements"
 return perk.ID=="Observant" and (text.."; also automatic at level 30") or text
end
return P
