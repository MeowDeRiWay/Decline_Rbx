local R={}
function R.Water(percent)
 if percent>=80 then return 1,0 elseif percent>=60 then return 1.2,0 elseif percent>=40 then return 1.5,.1 elseif percent>0 then return 2,.2 end
 return math.huge,.5
end
function R.Growth(dt,duration,factor,water,plants,perPlant)
 if plants<=0 or water<=0 then return 0 end
 return math.min(dt/duration/factor,water/(plants*perPlant))
end
function R.Stage(progress,rotten) return rotten and 4 or progress>=1 and 3 or progress>=.5 and 2 or 1 end
function R.Yield(base,multiplier,roll)
 local value=base*multiplier;local whole=math.floor(value)
 return whole+(roll<value-whole and 1 or 0)
end
return R
