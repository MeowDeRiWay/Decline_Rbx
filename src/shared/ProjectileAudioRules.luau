-- Reusable flyby mix in studs/second; gameplay and asset loading stay outside.
local Rules={FlybyRadius=24,MinimumSpeed=15}
function Rules.Sample(position,velocity,listener,listenerVelocity)
 local offset=listener-position
 local distance=offset.Magnitude
 local relative=velocity-listenerVelocity
 local speed=relative.Magnitude
 local radial=distance>.001 and relative:Dot(offset/distance) or 0
 local approach=math.clamp(radial/math.max(speed,1),-1,1)
 local near=math.clamp(1-distance/Rules.FlybyRadius,0,1)
 local passing=1-math.abs(approach)*.6
 local whistle=near*near*passing*math.clamp((speed-Rules.MinimumSpeed)/35,0,1)
 -- Retreat dulls the high end; distant sources lose high-frequency detail.
 local distanceDamping=math.clamp((distance-15)/85,0,1)
 return {Distance=distance,Radial=radial,Whistle=whistle,
  HighGain=-12*distanceDamping-4*math.max(0,-approach),MidGain=-3*distanceDamping}
end
return Rules
