-- Client-only shared direction: mouse, camera and body use the same target yaw.
local AimState = {Yaw = nil}
function AimState.Step(current, target, speed, dt)
 local delta = math.atan2(math.sin(target - current), math.cos(target - current))
 local limit = math.rad(math.max(0, speed)) * dt
 return current + math.clamp(delta, -limit, limit)
end
return AimState
