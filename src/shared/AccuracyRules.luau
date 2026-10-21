local Rules={}
function Rules.Skill(base,bonus) return math.clamp((base or 25)+(bonus or 0),0,300) end
function Rules.Chance(base,bonus,distance,dodge)
 return math.clamp(Rules.Skill(base,bonus)-math.max(0,(distance or 0)-20)-math.max(0,dodge or 0),0,90)
end
-- Only the authored Sight model on the currently held weapon supplies this bonus.
function Rules.SightBonus(held)
 local sight=held and held:FindFirstChild("Sight",true)
 if not sight or not sight:IsA("Model") then return 0 end
 local value=sight:GetAttribute("AccuracyBonus")
 return typeof(value)=="number" and value==value and value<math.huge and value>-math.huge and math.clamp(value,0,300) or 0
end
function Rules.WeaponSkill(definition)
 if definition and definition.Firearm then
  return definition.Firearm.Skill or (definition.Firearm.Category=="MachineGun" and "HeavyWeapons" or "LightWeapons")
 end
 return definition and definition.Weapon and "Melee" or "Unarmed"
end
function Rules.ForWeapon(player,definition)
 return player:GetAttribute("Skill"..Rules.WeaponSkill(definition)) or player:GetAttribute("Accuracy") or 25
end
return Rules
