local R={}
function R.Progress(started,now,duration) return started and math.clamp((now-started)/duration,0,1) or 0 end
function R.Stage(progress,count) return count>0 and math.min(count,math.floor(math.clamp(progress,0,1)*math.max(0,count-1))+1) or nil end
function R.Yield(base,multiplier,roll)
 local value=base*multiplier;local whole=math.floor(value)
 return whole+(roll<value-whole and 1 or 0)
end
return R
