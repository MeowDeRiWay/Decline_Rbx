local Rules={}
function Rules.Maximum(agility) return 10+math.max(0,agility or 0) end
function Rules.Step(value,maximum,exhausted,wantsRun,moving,allowed,dt,costMultiplier)
 value=math.clamp(value,0,maximum)
 local running=allowed and wantsRun and not exhausted and value>0
 if running and moving then
  value=math.max(0,value-dt*(costMultiplier or 1))
  if value==0 then exhausted=true;running=false end
 else
  -- Full recovery takes ten seconds, at every agility level.
  value=math.min(maximum,value+maximum/10*dt)
  if value>=maximum*.2 then exhausted=false end
 end
 return value,exhausted,running
end
return Rules
