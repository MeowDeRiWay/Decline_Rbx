local R={}
function R.StepMultiplier(skill,sneaking)
 return sneaking and math.max(.1,.5*(1-math.clamp(skill or 0,0,300)/375)) or 1
end
function R.Audible(distance,radius,attention) return distance<=radius*math.clamp(attention or 5,1,10)/5 end
return R
