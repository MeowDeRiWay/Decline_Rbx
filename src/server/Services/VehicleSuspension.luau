local Ground=require(script.Parent.VehicleGround)
local Suspension={}
function Suspension.Yaw(frame)
 local forward=Vector3.new(frame.LookVector.X,0,frame.LookVector.Z)
 if forward.Magnitude<.001 then forward=Vector3.new(0,0,-1) end
 return CFrame.lookAt(frame.Position,frame.Position+forward.Unit)
end
local function spring(position,velocity,target,dt,frequency,damping)
 local steps=math.max(1,math.ceil(dt/.008))
 local omega=frequency*2*math.pi
 for _=1,steps do
  local step=dt/steps
  velocity+=((target-position)*omega*omega-2*damping*omega*velocity)*step
  position+=velocity*step
 end
 return position,velocity
end
-- Least-squares support plane handles diagonally twisted terrain without jitter.
function Suspension.Plane(points)
 local x,z,y=0,0,0
 for _,p in ipairs(points) do x+=p.X;z+=p.Z;y+=p.Y end
 local n=#points
 if n==0 then return end
 x/=n;z/=n;y/=n
 local xx,zz,xz,xy,zy=0,0,0,0,0
 for _,p in ipairs(points) do
  local a,b,c=p.X-x,p.Z-z,p.Y-y
  xx+=a*a;zz+=b*b;xz+=a*b;xy+=a*c;zy+=b*c
 end
 local det=xx*zz-xz*xz
 local sx,sz=0,0
 if math.abs(det)>.00001 then sx=(xy*zz-zy*xz)/det;sz=(zy*xx-xy*xz)/det end
 return y-sx*x-sz*z,-math.atan(sz),math.atan(sx)
end
function Suspension.Update(data,yaw,dt,excluded)
 local config=data.Config
 local state=data.Suspension
 if not state then state={Height=data.Root.Position.Y,Velocity=0,Pitch=0,Roll=0,PitchVelocity=0,RollVelocity=0};data.Suspension=state end
 local points,contacts,parts={},{},{}
 for _,record in ipairs(data.Components) do
  if record.Kind~="Wheel" then continue end
  local rest=record.Rest.Position
  local hub=yaw:PointToWorldSpace(rest)
  local origin=hub+Vector3.new(0,config.MaximumGroundStep+.35,0)
  local hit=Ground.Cast(origin,Vector3.new(0,-config.SuspensionProbeDepth,0),excluded)
  if hit and hit.Normal.Y>=config.SuspensionMinimumNormal then
   local currentHub=data.Root.CFrame:PointToWorldSpace(rest)
   local gap=currentHub.Y-record.Radius-hit.Position.Y
   if gap<=config.SuspensionDroop and gap>=-config.MaximumGroundStep then
    table.insert(points,Vector3.new(rest.X,hit.Position.Y+record.Radius-rest.Y,rest.Z))
    contacts[record]=hit;parts[hit.Instance]=true
   end
  end
 end
 local height,pitch,roll=Suspension.Plane(points)
 if height then
  state.Height,state.Velocity=spring(state.Height,state.Velocity,height,dt,config.SuspensionFrequency,config.SuspensionDamping)
  if state.Height<height-config.SuspensionCompression then state.Height=height-config.SuspensionCompression;state.Velocity=math.max(0,state.Velocity) end
  local tilt=math.rad(config.SuspensionMaximumTilt)
  pitch=math.clamp(pitch+(data.LongitudinalAcceleration or 0)*config.SuspensionPitchTransfer,-tilt,tilt)
  roll=math.clamp(roll+(data.LateralAcceleration or 0)*config.SuspensionRollTransfer,-tilt,tilt)
 else
  state.Velocity-=config.SuspensionGravity*dt;state.Height+=state.Velocity*dt
  pitch=state.Pitch;roll=state.Roll
 end
 state.Pitch,state.PitchVelocity=spring(state.Pitch,state.PitchVelocity,pitch,dt,config.SuspensionFrequency,config.SuspensionDamping)
 state.Roll,state.RollVelocity=spring(state.Roll,state.RollVelocity,roll,dt,config.SuspensionFrequency,config.SuspensionDamping)
 local target=CFrame.new(yaw.Position.X,state.Height,yaw.Position.Z)*(yaw-yaw.Position)*CFrame.Angles(state.Pitch,0,state.Roll)
 for _,record in ipairs(data.Components) do
  if record.Kind~="Wheel" then continue end
  local hub=target:PointToWorldSpace(record.Rest.Position)
  local hit=contacts[record]
  local offset=hit and math.clamp(hit.Position.Y+record.Radius-hub.Y,-config.SuspensionDroop,config.SuspensionCompression) or -config.SuspensionDroop
  record.Joint.C0=CFrame.new(target:VectorToObjectSpace(Vector3.new(0,offset,0)))*record.Rest
 end
 data.SuspensionContacts=#points
 return target,parts,#points
end
return Suspension
