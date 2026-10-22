local R={}
function R.Range(attention) return 10+3*math.clamp(attention or 5,1,10) end
function R.Hearing(attention) return math.clamp(attention or 5,1,12)/5 end
function R.Curve(curve,gain)
 local result={};for distance,volume in pairs(curve) do result[distance*gain]=volume end;return result
end
return R
