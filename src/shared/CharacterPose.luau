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
function Pose.Arm(upper,lower,target,pole)
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
 return shoulder,shoulder:Inverse()*forearm
end
function Pose.Legs(phase,amount,forward,sideways)
 local swing=math.sin(phase)*amount
 return CFrame.Angles(swing*forward,0,-swing*sideways),CFrame.Angles(-swing*forward,0,swing*sideways),
  CFrame.Angles(-math.max(0,-math.sin(phase))*amount*.9,0,0),
  CFrame.Angles(-math.max(0,math.sin(phase))*amount*.9,0,0)
end
return Pose
