local P={}
local bonuses={
 Strength="+2 base HP; +5 kg carrying capacity; +3 heavy weapons, unarmed, melee, throwing and farmer; +1 melee / unarmed damage",
 Attention="+3 light weapons; +2 traps; +3 studs view (10 base); +20% hearing range",
 Endurance="+4 base HP; +1 HP regeneration per minute; +1 cook and first aid",
 Intelligence="+3 first aid, doctor, repair and cook; +1 skill point at creation and per level",
 Agility="+3 armor class and sneak; +0.2 walk speed; +0.6 sprint speed; +1 second sprint duration",
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
 return perk.ID=="Observant" and ("Free; "..text.."; also automatic at level 30") or text
end
return P
