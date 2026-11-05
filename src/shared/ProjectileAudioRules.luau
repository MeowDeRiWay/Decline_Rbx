-- Reusable flyby mix in studs/second; gameplay and asset loading stay outside.
local Rules={SoundSpeed=300,FlybyRadius=48,FlybyMinDistance=16,WhistleGain=1.7,WhistleAttack=32,WhistleRelease=8,MinimumSpeed=15}
function Rules.Sample(position,velocity,listener,listenerVelocity)
 local offset=listener-position
 local distance=offset.Magnitude
 local relative=velocity-listenerVelocity
 local speed=relative.Magnitude
 local radial=distance>.001 and relative:Dot(offset/distance) or 0
 local approach=math.clamp(radial/math.max(speed,1),-1,1)
 local near=math.clamp(1-distance/Rules.FlybyRadius,0,1)
 -- Spatial rolloff already attenuates this layer: avoid a second squared fade
 -- that made a fast rocket whistle audible only within a few studs.
 local passing=(1-math.abs(approach)*.2)*(1-.35*math.max(0,-approach))
 local whistle=near*passing*math.clamp((speed-Rules.MinimumSpeed)/35,0,1)
 -- Retreat dulls the high end; distant sources lose high-frequency detail.
 local distanceDamping=math.clamp((distance-15)/85,0,1)
 return {Distance=distance,Radial=radial,Whistle=whistle,
  HighGain=-12*distanceDamping-4*math.max(0,-approach),MidGain=-3*distanceDamping}
end
-- Arrival times use the shared server clock, so network transit is not added twice.
function Rules.Arrival(time,position,listener)
 return time+(listener-position).Magnitude/Rules.SoundSpeed
end
function Rules.Heard(samples,first,listener,now,ended)
 local count=#samples
 if count==0 then return nil,nil,first,ended end
 first=first or 1
 while first<count and Rules.Arrival(samples[first+1].Time,samples[first+1].Position,listener)<=now do first+=1 end
 local a=samples[first]
 local at=Rules.Arrival(a.Time,a.Position,listener)
 if now<at then return nil,nil,first,false end
 local b=samples[first+1]
 if b then
  local bt=Rules.Arrival(b.Time,b.Position,listener)
  local t=math.clamp((now-at)/math.max(.0001,bt-at),0,1)
  return a.Position+(b.Position-a.Position)*t,a.Velocity,first,false
 end
 if ended then return nil,nil,first,true end
 -- Bridge a small packet gap; stale streams are terminated by the client owner.
 return a.Position+a.Velocity*math.min(.05,now-at),a.Velocity,first,false
end
return Rules
