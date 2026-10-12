local Rules = {}
function Rules.Batch(available,requested,maximum)
 if available < 1 then return nil end
 if requested == "All" then return math.min(available,maximum) end
 if typeof(requested)~="number" or requested~=requested or requested<1 or requested>maximum or requested>available or requested~=math.floor(requested) then return nil end
 return requested
end
function Rules.Available(items,recipe)
 local available=math.huge
 for id,count in pairs(recipe.Ingredients) do available=math.min(available,math.floor((items[id] or 0)/count)) end
 return available==math.huge and 0 or available
end
function Rules.Speed(tools,recipe)
 if not recipe.Tool then return 1 end
 return tools[recipe.Tool]
end
return Rules
