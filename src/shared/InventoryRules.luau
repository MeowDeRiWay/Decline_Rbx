local Rules = {}
function Rules.New()
 return {Items = {}, Equipment = {}}
end
local function quantity(value)
 return typeof(value) == "number" and value == value and value > 0 and value < math.huge and value == math.floor(value)
end
function Rules.DropAmount(available, requested)
 if not quantity(available) then return nil end
 if requested == "All" then return available end
 if requested == nil then requested = 1 end
 if not quantity(requested) or requested > available then return nil end
 return requested
end
function Rules.Add(state, definitions, id, amount)
 if typeof(id) ~= "string" or not definitions[id] or not quantity(amount) then return false end
 state.Items[id] = (state.Items[id] or 0) + amount
 return true
end
function Rules.Remove(state, id, amount)
 if typeof(id) ~= "string" or not quantity(amount) or (state.Items[id] or 0) < amount then return false end
 local remaining = state.Items[id] - amount
 state.Items[id] = remaining > 0 and remaining or nil
 return true
end
function Rules.Equip(state, definitions, slots, id)
 local item = typeof(id) == "string" and definitions[id]
 if not item or not table.find(slots, item.Slot) or (state.Items[id] or 0) < 1 then return false end
 local previous = state.Equipment[item.Slot]
 Rules.Remove(state, id, 1)
 if previous then Rules.Add(state, definitions, previous, 1) end
 state.Equipment[item.Slot] = id
 return true
end
function Rules.Unequip(state, definitions, slots, slot)
 if typeof(slot) ~= "string" or not table.find(slots, slot) then return false end
 local id = state.Equipment[slot]
 if not id then return false end
 Rules.Add(state, definitions, id, 1)
 state.Equipment[slot] = nil
 return true
end
function Rules.Weight(state, definitions)
 local total = 0
 for id, count in pairs(state.Items) do total += (definitions[id].Weight or 0) * count end
 for _, id in pairs(state.Equipment) do total += definitions[id].Weight or 0 end
 return total
end
function Rules.Transfer(source, target, definitions, id, requested)
 if typeof(id) ~= "string" or not definitions[id] then return false end
 local count = Rules.DropAmount(source.Items[id], requested)
 if not count then return false end
 -- Both states are server-owned. No yields or partial public updates.
 if not Rules.Remove(source, id, count) then return false end
 if not Rules.Add(target, definitions, id, count) then
  Rules.Add(source, definitions, id, count)
  return false
 end
 return true
end
return Rules
