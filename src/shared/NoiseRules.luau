local R={}
function R.StepRadius(skill,running,base,silentRun)
 base=base or (running and 10 or 5)
 return running and not silentRun and base or math.max(0,base-math.floor(math.clamp(skill or 0,0,300)/10))
end
function R.StepMultiplier(skill,running,silentRun) return R.StepRadius(skill,running,nil,silentRun)/(running and 10 or 5) end
function R.Audible(distance,radius,attention) return radius>0 and distance<radius*math.clamp(attention or 5,1,10)/5 end
return R
