local Rules = {}
function Rules.Roll(config,definitions,random)
 local items = {}
 random = random or math.random
 for id,range in pairs(config) do
  local definition = definitions[id]
  if definition and definition.Lootable ~= false and typeof(range) == "table" then
   local minimum,maximum = range.Min,range.Max
   if typeof(minimum) == "number" and typeof(maximum) == "number" and minimum == minimum and maximum == maximum and minimum >= 0 and maximum < math.huge and minimum == math.floor(minimum) and maximum == math.floor(maximum) and maximum >= minimum then
    local count = random(minimum,maximum)
    if count > 0 then items[id] = count end
   end
  end
 end
 return items
end
return Rules
