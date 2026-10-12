local Rules = {}
function Rules.CanDamage(resource, definition)
 return definition ~= nil and definition.HarvestTool == resource.Tool
end
function Rules.Damage(health, damage)
 return math.max(0, health - damage)
end
function Rules.Spaced(points, x, z, spacing)
 for _,point in ipairs(points) do
  if (point.X-x)^2 + (point.Z-z)^2 < spacing^2 then return false end
 end
 return true
end
-- The last occupant leaving starts a fresh delay; re-entry resets it.
function Rules.Occupancy(state, occupied, now, delay)
 if occupied then state.Occupied = true; state.AllowedAt = now + delay
 elseif state.Occupied then state.Occupied = false; state.AllowedAt = now + delay end
 return not occupied and now >= (state.AllowedAt or 0)
end
return Rules
