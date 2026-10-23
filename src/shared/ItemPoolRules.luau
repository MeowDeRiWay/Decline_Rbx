local Rules={}
local function finite(value) return typeof(value)=="number" and value==value and math.abs(value)<math.huge end
function Rules.Weight(value)
 if value==nil then return 1 end
 return finite(value) and value>0 and math.min(value,1000000) or 0
end
function Rules.Pick(entries,roll)
 local total=0
 for _,entry in ipairs(entries) do total+=entry.Weight end
 if total<=0 then return nil end
 local target=math.clamp(roll,0,.999999999)*total
 for _,entry in ipairs(entries) do target-=entry.Weight;if target<0 then return entry end end
end
function Rules.Delay(value)
 return finite(value) and math.clamp(value,1,86400) or 300
end
function Rules.Chance(value)
 return finite(value) and math.clamp(value,0,1) or 1
end
return Rules
