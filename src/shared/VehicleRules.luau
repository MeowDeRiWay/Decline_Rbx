local Rules={}
function Rules.Number(value,fallback,minimum,maximum)
 if typeof(value)~="number" or value~=value or math.abs(value)==math.huge then return fallback end
 return math.clamp(value,minimum or -math.huge,maximum or math.huge)
end
function Rules.Health(component)
 if not component then return 0 end
 local maximum=Rules.Number(component:GetAttribute("MaxHP"),100,.001,1000000)
 return Rules.Number(component:GetAttribute("HP"),0,0,maximum)/maximum
end
function Rules.Power(health,stopRatio)
 return math.clamp((health-stopRatio)/(1-stopRatio),0,1)
end
function Rules.CanStart(engine,battery,tank,config)
 if not engine or Rules.Health(engine)<=config.EngineStopRatio then return false,"Engine is damaged." end
 if not battery or Rules.Health(battery)<=0 then return false,"Battery is damaged." end
 if not tank or Rules.Health(tank)<=0 or (tank:GetAttribute("Fuel") or 0)<=0 then return false,"Fuel tank is empty or damaged." end
 local current=battery:GetAttribute("StartingCurrent") or 0
 if current<(engine:GetAttribute("RequiredStartingCurrent") or 0) then return false,"Battery starting current is too low." end
 if (battery:GetAttribute("Charge") or 0)<(engine:GetAttribute("MinStartingCharge") or 12)+config.StartChargeCost then return false,"Battery charge is too low." end
 return true
end
local function approach(value,target,amount)
 if value<target then return math.min(target,value+amount) end
 return math.max(target,value-amount)
end
function Rules.GearSpeed(gear,config)
 if gear==-1 then return -config.ReverseSpeed end
 return config.GearSpeeds[gear] or 0
end
function Rules.RPM(speed,throttle,gear,engineOn,config)
 if not engineOn then return 0 end
 local moving=math.abs(speed)
 if gear==0 then return config.IdleRPM+math.max(0,throttle)*(config.RedlineRPM-config.IdleRPM) end
 local top=math.abs(Rules.GearSpeed(gear,config))
 local low=gear>0 and config.GearMinimums[gear] or 0
 local rpm=config.GearIdleRPM+(moving-low)/(top-low)*(config.RedlineRPM-config.GearIdleRPM)
 if gear>0 and speed<0 or gear==-1 and speed>0 then rpm=0 end
 return math.clamp(rpm,(gear<=2) and config.GearIdleRPM or 0,config.RedlineRPM)
end
function Rules.SpeedFromRPM(rpm,gear,config)
 if gear==0 then return 0 end
 local low=gear>0 and config.GearMinimums[gear] or 0
 local top=math.abs(Rules.GearSpeed(gear,config))
 local fraction=math.clamp((rpm-config.GearIdleRPM)/(config.RedlineRPM-config.GearIdleRPM),0,1)
 return (low+(top-low)*fraction)*(gear==-1 and -1 or 1)
end
function Rules.AdvanceRPM(rpm,gear,dt,config)
 local times=config.GearRPMTimes[math.max(1,gear)] or config.GearRPMTimes[1]
 local edges={config.GearIdleRPM,4000,5000,config.RedlineRPM}
 rpm=math.clamp(rpm,config.GearIdleRPM,config.RedlineRPM)
 for band=1,3 do
  if rpm<edges[band+1] and dt>0 then
   local rate=(edges[band+1]-edges[band])/times[band]
   local used=math.min(dt,(edges[band+1]-rpm)/rate)
   rpm=math.min(edges[band+1],rpm+rate*used);dt-=used
  end
 end
 return rpm
end

function Rules.SelectGear(value,config)
 if typeof(value)~="number" or value~=value or value%1~=0 then return nil end
 if value < -1 or value > #config.GearSpeeds then return nil end
 return value
end
function Rules.Stalls(speed,gear,config)
 return gear>=3 and Rules.RPM(speed,0,gear,true,config)<=config.StallRPM
end
function Rules.ReverseDamage(speed,config)
 -- Only engaging reverse against forward travel damages the transmission/engine.
 if speed<config.ReverseDamageStart then return 0 end
 local fraction=math.clamp((speed-config.ReverseDamageStart)/(config.ReverseDamageFull-config.ReverseDamageStart),0,1)
 return config.ReverseMinimumDamage+(1-config.ReverseMinimumDamage)*fraction
end
function Rules.WheelSteer(speed,steer,config)
 return steer/(1+(math.abs(speed)/config.SteeringSpeedScale)^2)
end
function Rules.Steer(current,input,speed,dt,config)
 if input==0 then return 0 end
 local target=Rules.WheelSteer(speed,input,config)
 return current+math.clamp((target-current)*(1-math.exp(-config.SteeringResponse*dt)),-config.SteeringRate*dt,config.SteeringRate*dt)
end
function Rules.BrakeSpeed(gear,config)
 return math.abs(Rules.SpeedFromRPM(config.EngineBrakeRPM,gear,config))
end
function Rules.OverrevDamage(rpm,dt,maximum,config)
 return rpm>=config.OverrevRPM and maximum*config.OverrevDamagePerSecond*dt or 0
end
-- RPM is integrated first; the selected ratio converts it into road speed.
function Rules.Drive(speed,rpm,throttle,gear,engineOn,power,wheels,dt,config,shifting,engineBraking)
 local braking=throttle<0
 if not engineOn or shifting or gear==0 then
  speed=approach(speed,0,(braking and config.BrakeDeceleration or config.RollingDeceleration)*dt)
  if not engineOn then rpm=0
  elseif shifting and gear~=0 then rpm=Rules.RPM(speed,0,gear,true,config)
  elseif throttle>0 then rpm=math.min(config.RedlineRPM,math.max(config.IdleRPM,rpm)+config.NeutralRPMRise*throttle*dt)
  else rpm=approach(rpm,config.IdleRPM,config.NeutralRPMFall*dt) end
  return speed,rpm,false
 end
 local direction=gear==-1 and -1 or 1
 if braking or speed*direction<0 then
  speed=approach(speed,0,config.BrakeDeceleration*dt)
  return speed,Rules.RPM(speed,0,gear,true,config),false
 end
 if throttle>0 then
  rpm=Rules.AdvanceRPM(rpm,gear,dt*throttle,config)
  if gear>0 and Rules.GearSpeed(gear,config)>config.MaxSpeed then
   rpm=math.min(rpm,Rules.RPM(config.MaxSpeed,0,gear,true,config))
  end
  local target=Rules.SpeedFromRPM(rpm,gear,config)*power*wheels
  target=math.clamp(target,-config.ReverseSpeed,config.MaxSpeed*power*wheels)
  if gear==2 and speed<config.GearMinimums[2] then speed=approach(speed,target,config.CreepAcceleration*dt)
  else speed=target end
  return speed,rpm,false
 end
 if rpm>=config.RedlineRPM-.001 then engineBraking=true end
 local magnitude=math.abs(speed)
 if engineBraking and rpm>config.EngineBrakeRPM then
  local target=Rules.BrakeSpeed(gear,config)
  if magnitude>target then magnitude=approach(magnitude,target,config.EngineBrakeDeceleration*dt) end
 else
  local creep=gear==2 and config.GearMinimums[2]*power*wheels or 0
  magnitude=approach(magnitude,creep,(magnitude<creep and config.CreepAcceleration or config.RollingDeceleration)*dt)
 end
 speed=magnitude*direction
 rpm=Rules.RPM(speed,0,gear,true,config)
 return speed,rpm,engineBraking and rpm>config.EngineBrakeRPM+.001
end

function Rules.Resources(state,dt,config)
 local fuel=state.Fuel
 local charge=state.Charge
 local burning=state.Burning and fuel>0
 local hp=state.TankHP
 if state.TankHealth<1 then
  fuel=math.max(0,fuel-config.LeakPerSecond*(1-state.TankHealth)*dt)
 end
 if burning then
  hp=math.max(0,hp-state.TankMaxHP*config.TankBurnPerSecond*dt)
  fuel=math.max(0,fuel-config.LeakPerSecond*dt)
 end
 if state.EngineOn then
  fuel=math.max(0,fuel-(config.FuelPerSecond+math.abs(state.Speed)*config.FuelPerStud)*dt)
  if state.BatteryHealthy then charge=math.min(state.MaxCharge,charge+config.ChargePerSecond*dt) end
 end
 if state.LightsOn then charge=math.max(0,charge-config.HeadlightDrainPerSecond*dt) end
 return fuel,charge,hp,burning
end
function Rules.Steering(speed,steer,wheelbase,dt,config)
 return -speed/math.max(.5,wheelbase)*math.tan(math.rad(config.SteeringAngle)*steer)*dt
end
return Rules
