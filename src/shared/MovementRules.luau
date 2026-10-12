local Rules = {}
function Rules.LoadMultiplier(weight, config)
 if typeof(weight) ~= "number" or weight ~= weight or math.abs(weight) == math.huge then weight = 0 end
 local excess = math.max(0,weight-config.CarryLimitKg)
 return math.clamp(1-excess*config.OverloadPenaltyPerKg,0,1)
end
return Rules
