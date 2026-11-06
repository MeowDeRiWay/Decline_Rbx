-- Cosmetic poses only. Gameplay, collision and shot origin remain server-owned.
local Pose={}
function Pose.Between(a,b)
 a,b=a.Unit,b.Unit
 local dot=math.clamp(a:Dot(b),-1,1)
 if dot>.99999 then return CFrame.identity end
 local axis=a:Cross(b)
 if axis.Magnitude<.00001 then
  axis=a:Cross(Vector3.yAxis)
  if axis.Magnitude<.00001 then axis=a:Cross(Vector3.xAxis) end
 end
 return CFrame.fromAxisAngle(axis.Unit,math.acos(dot))
end
function Pose.Arm(upper,lower,target,pole,hingeWeight)
 local a,b=upper.Magnitude,lower.Magnitude
 if a<.0001 or b<.0001 then return CFrame.identity,CFrame.identity end
 local d=math.clamp(target.Magnitude,math.abs(a-b)+.0001,a+b-.0001)
 local direction=target.Magnitude>.0001 and target.Unit or Vector3.new(0,-1,0)
 local bend=pole-direction*pole:Dot(direction)
 if bend.Magnitude<.0001 then bend=Vector3.xAxis-direction*direction.X end
 if bend.Magnitude<.0001 then bend=Vector3.zAxis-direction*direction.Z end
 local along=(a*a+d*d-b*b)/(2*d)
 local elbow=direction*along+bend.Unit*math.sqrt(math.max(0,a*a-along*along))
 local shoulder=Pose.Between(upper,elbow)
 local forearm=Pose.Between(lower,direction*d-elbow)
 local relative=shoulder:Inverse()*forearm
 if hingeWeight and hingeWeight>0 then
  -- Solve the elbow in its parent's frame. Independent world-space shortest
  -- arcs aim the hands correctly but introduce axial roll into armored sleeves.
  local hinged=Pose.Between(lower,shoulder:VectorToObjectSpace(direction*d-elbow))
  local weight=math.clamp(hingeWeight,0,1)
  if weight>=1 then relative=hinged
  else
   -- Both solutions reach the same hand point; their difference is pure roll
   -- around the authored forearm axis. Blend only that roll, preserving reach.
   local axis=lower.Unit
   local reference=axis:Cross(Vector3.yAxis)
   if reference.Magnitude<.0001 then reference=axis:Cross(Vector3.zAxis) end
   reference=reference.Unit
   local rolled=(hinged:Inverse()*relative):VectorToWorldSpace(reference)
   local angle=math.atan2(axis:Dot(reference:Cross(rolled)),reference:Dot(rolled))
   relative=hinged*CFrame.fromAxisAngle(axis,angle*(1-weight))
  end
 end
 return shoulder,relative
end
function Pose.Gait(speed,running)
 if speed<=.025 then return 0,0 end
 if running then return .42,math.clamp(speed*.65,.8,1.8) end
 return .18,math.clamp(speed*.6,.35,1.05)
end
function Pose.Legs(phase,amount,forward,sideways,kneeFactor)
 kneeFactor=kneeFactor or .4
 local swing=math.sin(phase)*amount
 return CFrame.Angles(swing*forward,0,-swing*sideways),CFrame.Angles(-swing*forward,0,swing*sideways),
  CFrame.Angles(-math.max(0,-math.sin(phase))*amount*kneeFactor,0,0),
  CFrame.Angles(-math.max(0,math.sin(phase))*amount*kneeFactor,0,0)
end
return Pose
