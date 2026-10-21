local Rules={}
function Rules.Skill(base,bonus) return math.clamp((base or 25)+(bonus or 0),0,300) end
function Rules.Chance(base,bonus,distance,dodge)
 return math.clamp(Rules.Skill(base,bonus)-math.max(0,(distance or 0)-20)-math.max(0,dodge or 0),0,90)
end
-- Only the authored Sight model on the currently held weapon supplies this bonus.
function Rules.SightBonus(held)
 local sight=held and held:FindFirstChild("Sight",true)
 if not sight or not sight:IsA("Model") then return 0 end
 local value=sight:GetAttribute("AccuracyBonus")
 return typeof(value)=="number" and value==value and value<math.huge and value>-math.huge and math.clamp(value,0,300) or 0
end
return Rules
