-- Body-relative stride paths keep both feet within reach as the player turns.
local Foot={}
local function horizontal(v) return Vector3.new(v.X,0,v.Z) end
function Foot.Step(state,neutral,velocity,dt,running,length,right)
 if not state then state={Phase=math.pi*1.24,Stride=Vector3.zero,Weight=0} end
 dt=math.min(dt,.1)
 local speed=horizontal(velocity).Magnitude
 local moving=speed>.025
 local cadence=running and math.clamp(speed/math.max(length*1.6,.01),1.2,2.2)
  or math.clamp(speed/math.max(length*.85,.01),.5,1.8)
 local stance=running and .46 or .62
 local stride=horizontal(velocity)*(stance/(2*cadence))
 local limit=length*(running and .38 or .28)
 if stride.Magnitude>limit then stride=stride.Unit*limit end
 local blend=1-math.exp(-16*dt)
 state.Stride+=(stride-state.Stride)*blend
 state.Weight+=((moving and 1 or 0)-state.Weight)*blend
 if not moving and state.Weight<.001 then state.Weight=0;state.Stride=Vector3.zero end
 if moving then state.Phase=(state.Phase+cadence*dt*2*math.pi)%(2*math.pi) end
 right=right or horizontal(neutral.Right-neutral.Left).Unit
 local gap=math.max(.001,horizontal(neutral.Right-neutral.Left):Dot(right))
 local targets={}
 for _,side in ipairs({"Left","Right"}) do
  local phase=(state.Phase/(2*math.pi)+(side=="Right" and .5 or 0))%1
  local travel,lift
  if phase<stance then
   -- The support foot travels from heel strike to toe-off relative to the hip.
   travel=1-2*phase/stance
   lift=0
  else
   local t=(phase-stance)/(1-stance)
   local recovery=running and t*t*(3-2*t) or t
   travel=-math.cos(recovery*math.pi)
   -- Recover the heel behind the body, then swing through with lower clearance.
   local clearance=running and .18*(1-.5*t) or .11
   lift=math.sin(t*math.pi)*length*clearance*state.Weight
  end
  local offset=state.Stride*travel
  -- Lateral steps retain separate lanes instead of crossing through the other leg.
  local lateral=offset:Dot(right)
  local bounded=side=="Left" and math.min(lateral,gap*.3) or math.max(lateral,-gap*.3)
  offset+=right*(bounded-lateral)
  targets[side]=neutral[side]+offset+Vector3.new(0,lift,0)
 end
 return state,targets
end
return Foot
