local R={}
function R.StepRadius(skill,running,base)
 base=base or 12
 return running and base or math.max(0,base-math.floor(math.clamp(skill or 0,0,300)/10))
end
function R.StepMultiplier(skill,running) return R.StepRadius(skill,running)/12 end
function R.Audible(distance,radius,attention) return radius>0 and distance<radius*math.clamp(attention or 5,1,10)/5 end
return R
