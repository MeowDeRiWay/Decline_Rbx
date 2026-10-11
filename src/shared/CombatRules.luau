local Rules = {}
function Rules.GetWeapon(state,definitions)
 local id = state.Equipment.Hands
 local definition = id and definitions[id]
 local remaining = state.EquipmentCondition.Hands
 if not definition or not definition.Weapon or not remaining or remaining <= 0 then return nil end
 return definition.Weapon
end
function Rules.Use(state,definitions)
 local weapon = Rules.GetWeapon(state,definitions)
 if not weapon then return nil end
 state.EquipmentCondition.Hands -= 1
 return weapon
end
return Rules
