local Rules = {}
function Rules.ValidID(value)
 return typeof(value) == "number" and value == value and value > 0 and value < math.huge and value % 1 == 0
end
function Rules.Removed(keep, remove)
 return remove > keep
end
function Rules.Relation(current, requested)
 -- War and neutrality are unilateral; becoming allies needs both mayors.
 if requested == "Ally" and current ~= "Ally" then return "Pending" end
 return requested
end
function Rules.ParseOwners(value)
 local result = {}
 if Rules.ValidID(value) then result[value] = true
 elseif typeof(value) == "string" then
  for id in string.gmatch(value, "%d+") do
   local number = tonumber(id)
   if Rules.ValidID(number) then result[number] = true end
  end
 end
 return result
end
function Rules.SerializeOwners(owners)
 local ids = {}
 for id in pairs(owners) do table.insert(ids, id) end
 table.sort(ids)
 for index, id in ipairs(ids) do ids[index] = tostring(id) end
 return table.concat(ids, ",")
end
return Rules
