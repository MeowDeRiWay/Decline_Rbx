local Rules = {}
Rules.Unarmed={Damage=0,DamageType="Blunt",AttacksPerMinute=60,Range=1,Width=2,Animation="SwingLeft"}
-- Randomize only the Strength-derived part; flat unarmed perks remain additive.
function Rules.UnarmedDamage(strengthBonus,flatBonus,roll)
 return math.max(0,strengthBonus or 0)*(.75+.45*math.clamp(roll,0,1))+(flatBonus or 0)
end
function Rules.GetWeapon(state,definitions)
 local id = state.Equipment.Hands
 if not id or id=="" then return Rules.Unarmed end
 local definition = id and definitions[id]
 local remaining = state.EquipmentCondition.Hands
 if not definition or not definition.Weapon then return nil end
 return definition.Weapon
end
function Rules.Use(state,definitions)
 local weapon = Rules.GetWeapon(state,definitions)
 if not weapon then return nil end
 -- Weapon wear is disabled.
 return weapon
end
return Rules
