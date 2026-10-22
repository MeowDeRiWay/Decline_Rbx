local Rules = {}
function Rules.GetWeapon(state,definitions)
 local id = state.Equipment.Hands
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
