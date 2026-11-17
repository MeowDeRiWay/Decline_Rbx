-- Alternating strides: plant during support, then lift and swing to the next step.
local Foot={}
local function horizontal(v) return Vector3.new(v.X,0,v.Z) end
function Foot.Step(state,neutral,velocity,dt,running,length)
 if not state then state={Left=neutral.Left,Right=neutral.Right,Next="Left",Phase=0,Pause=0} end
 dt=math.min(dt,.1)
 local speed=horizontal(velocity).Magnitude
 local moving=speed>.025
 local cadence=running and math.clamp(speed/math.max(length*1.5,.01),1.3,2.4)
  or math.clamp(speed/math.max(length*1.2,.01),.55,1.35)
 local halfCycle=.5/cadence
 local swingFraction=running and 1 or .8
 state.Pause=math.max(0,(state.Pause or 0)-dt)
 if not state.Swing and state.Pause<=0 then
  local side=state.Next
  local distance=horizontal(neutral[side]-state[side]).Magnitude
  if moving or distance>length*.035 then
   local duration=moving and halfCycle*swingFraction or .2
   local lead=moving and horizontal(velocity)*halfCycle*.5 or Vector3.zero
   if lead.Magnitude>length*.4 then lead=lead.Unit*length*.4 end
   state.Swing={Side=side,From=state[side],Goal=neutral[side]+lead,Time=0,Duration=duration,Pause=moving and halfCycle*(1-swingFraction) or 0}
  elseif not moving then state.Next=side=="Left" and "Right" or "Left" end
 end
 local swing=state.Swing
 local left,right=state.Left,state.Right
 if swing then
  if not moving then
   swing.Duration=math.min(swing.Duration,swing.Time+.12)
   swing.Goal=neutral[swing.Side]
   swing.Pause=0
  end
  swing.Time+=dt
  local t=math.clamp(swing.Time/swing.Duration,0,1)
  local smooth=t*t*(3-2*t)
  local lift=math.sin(t*math.pi)*length*(running and .3 or .09)
  local p=swing.From+(swing.Goal-swing.From)*smooth+Vector3.new(0,lift,0)
  if t>=1 then p=swing.Goal end
  state.Phase=(swing.Side=="Left" and 0 or math.pi)+t*math.pi
  if swing.Side=="Left" then left=p else right=p end
  if running and moving then
   -- Late push-off gives running a short flight phase.
   local push=math.max(0,(t-.75)/.25)*length*.08*math.sin(t*math.pi)
   if swing.Side=="Left" then right+=Vector3.new(0,push,0) else left+=Vector3.new(0,push,0) end
  end
  if t>=1 then
   state[swing.Side]=swing.Goal
   state.Next=swing.Side=="Left" and "Right" or "Left"
   state.Pause=swing.Pause
   state.Swing=nil
  end
 end
 return state,{Left=left,Right=right}
end
return Foot
