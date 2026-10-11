local Rules = {}
function Rules.Use(state,definitions)
 local id = state.Equipment.Hands
 local definition = id and definitions[id]
 local remaining = state.EquipmentCondition.Hands
 if not definition or not definition.Weapon or not remaining or remaining <= 0 then return nil end
 state.EquipmentCondition.Hands = remaining-1
 return definition.Weapon
end
return Rules
