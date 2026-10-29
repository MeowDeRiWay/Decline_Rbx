-- Keep a support foot at a world point; only the swinging foot advances.
local Foot={}
local function horizontal(v) return Vector3.new(v.X,0,v.Z) end
function Foot.Step(state,neutral,velocity,dt,running,length)
 if not state then state={Left=neutral.Left,Right=neutral.Right,Next="Left"} end
 local speed=horizontal(velocity).Magnitude
 local moving=speed>.025
 if not state.Swing then
  local side=state.Next
  local distance=horizontal(neutral[side]-state[side]).Magnitude
  if distance>length*(moving and .12 or .08) then
   local duration=moving and math.clamp(length*.25/math.max(speed,.01),.07,.32) or .18
   state.Swing={Side=side,From=state[side],Goal=neutral[side]+(moving and velocity*duration*.9 or Vector3.zero),Time=0,Duration=duration}
  elseif not moving then state.Next=side=="Left" and "Right" or "Left" end
 end
 local swing=state.Swing
 local left,right=state.Left,state.Right
 if swing then
  swing.Time+=dt
  local t=math.clamp(swing.Time/swing.Duration,0,1)
  local smooth=t*t*(3-2*t)
  local p=swing.From+(swing.Goal-swing.From)*smooth+Vector3.new(0,math.sin(t*math.pi)*length*(running and .22 or .10),0)
  if swing.Side=="Left" then left=p else right=p end
  if t>=1 then
   state[swing.Side]=swing.Goal
   state.Next=swing.Side=="Left" and "Right" or "Left"
   state.Swing=nil
  end
 end
 return state,{Left=left,Right=right}
end
return Foot
