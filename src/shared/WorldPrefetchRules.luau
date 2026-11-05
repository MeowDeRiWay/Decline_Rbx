-- Bounded horizontal look-ahead shared by generation and geometry wake-up.
local Rules={}
function Rules.Velocity(root,humanoid)
 local velocity=root.AssemblyLinearVelocity or Vector3.zero
 velocity=Vector3.new(velocity.X,0,velocity.Z)
 if velocity.Magnitude<.1 and humanoid.MoveDirection then
  local direction=humanoid.MoveDirection
  velocity=Vector3.new(direction.X,0,direction.Z)*(humanoid.WalkSpeed or 0)
 end
 return velocity
end
function Rules.Append(points,position,velocity,config)
 table.insert(points,position)
 local speed=velocity.Magnitude
 local ahead=math.min(speed*(config.PrefetchSeconds or 0),config.MaxPrefetchDistance or 160)
 if ahead<1 then return end
 local steps=math.ceil(ahead/40)
 for i=1,steps do table.insert(points,position+velocity*(ahead/speed*i/steps)) end
end
function Rules.Due(now,scheduled,gap,speed,config)
 local urgent=config.UrgentRadius or 0
 if gap<=urgent then return now end
 if speed<.1 then return scheduled end
 local remaining=math.max(0,(gap-urgent)/speed-(config.ArrivalSafetySeconds or 2))
 return math.min(scheduled,now+remaining)
end
return Rules
