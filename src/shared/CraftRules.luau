local Rules = {}
function Rules.Batch(available,requested,maximum)
 if available < 1 then return nil end
 if requested == "All" then return math.min(available,maximum) end
 if typeof(requested)~="number" or requested~=requested or requested<1 or requested>maximum or requested>available or requested~=math.floor(requested) then return nil end
 return requested
end
return Rules
