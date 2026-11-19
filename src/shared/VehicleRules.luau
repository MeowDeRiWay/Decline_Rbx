local Rules={}
function Rules.Number(value,fallback,minimum,maximum)
 if typeof(value)~="number" or value~=value or math.abs(value)==math.huge then return fallback end
 return math.clamp(value,minimum or -math.huge,maximum or math.huge)
end
function Rules.MaxHealth(component)
 local maximum=component and component:GetAttribute("MaxHP")
 if typeof(maximum)~="number" or maximum~=maximum or maximum<=0 or maximum==math.huge then return nil end
 return maximum
end
function Rules.Health(component)
 if not component then return 0 end
 local maximum=Rules.MaxHealth(component)
 -- Unconfigured parts work normally and have no damage/durability state.
 if not maximum then return 1 end
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
function Rules.Ratio(gear,config)
 local ratio=gear==-1 and config.ReverseGearRatio or config.GearRatios[gear] or 0
 return ratio*config.FinalDrive
end
function Rules.WheelRPM(speed,gear,config)
 return math.abs(speed)*Rules.Ratio(gear,config)*60/(2*math.pi*config.WheelRadius)
end
function Rules.GearSpeed(gear,config)
 return Rules.SpeedFromRPM(config.RedlineRPM,gear,config)
end
function Rules.RPM(speed,throttle,gear,engineOn,config)
 if not engineOn then return 0 end
 if gear==0 then return config.IdleRPM end
 local rpm=Rules.WheelRPM(speed,gear,config)
 if gear<=2 then rpm=math.max(config.IdleRPM,rpm) end
 return math.min(config.RedlineRPM*1.5,rpm)
end
function Rules.SpeedFromRPM(rpm,gear,config)
 local ratio=Rules.Ratio(gear,config)
 if ratio==0 then return 0 end
 return rpm/60*2*math.pi*config.WheelRadius/ratio*(gear==-1 and -1 or 1)
end
function Rules.Torque(rpm,config)
 local curve=config.TorqueCurve
 if rpm<=curve[1][1] then return config.MaxTorqueNm*curve[1][2] end
 for i=2,#curve do
  if rpm<=curve[i][1] then
   local before,after=curve[i-1],curve[i]
   local alpha=(rpm-before[1])/(after[1]-before[1])
   return config.MaxTorqueNm*(before[2]+(after[2]-before[2])*alpha)
  end
 end
 return config.MaxTorqueNm*curve[#curve][2]
end
function Rules.RoadLoad(speed,config)
 if math.abs(speed)<.001 then return 0 end
 return config.RollingResistance*config.MassKg*9.81+.5*config.AirDensity*config.DragArea*speed*speed
end
local function freeRPM(rpm,throttle,dt,config)
 rpm=math.max(config.IdleRPM,rpm)
 local friction=config.EngineFrictionNm+config.EngineFrictionPerRPM*rpm
 local torque=Rules.Torque(rpm,config)*throttle-friction
 return math.clamp(rpm+torque/config.EngineInertia*60/(2*math.pi)*dt,config.IdleRPM,config.RedlineRPM)
end

function Rules.SelectGear(value,config)
 if typeof(value)~="number" or value~=value or value%1~=0 then return nil end
 if value < -1 or value > #config.GearRatios then return nil end
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
 local excess=math.max(0,math.abs(speed)-config.SteeringFullSpeed)
 return steer/(1+(excess/config.SteeringSpeedScale)^2)
end
function Rules.Steer(current,input,speed,dt,config)
 if input==0 then return 0 end
 local target=Rules.WheelSteer(speed,input,config)
 return current+math.clamp((target-current)*(1-math.exp(-config.SteeringResponse*dt)),-config.SteeringRate*dt,config.SteeringRate*dt)
end
function Rules.OverrevDamage(rpm,dt,maximum,config)
 return rpm>=config.OverrevRPM and maximum*config.OverrevDamagePerSecond*dt or 0
end
-- Force at the tyres accelerates mass; speed feeds back through the gearbox to RPM.
local function driveStep(speed,rpm,throttle,gear,engineOn,power,wheels,dt,config,shifting,cruise)
 local direction=gear==-1 and -1 or 1
 local ratio=Rules.Ratio(gear,config)
 local wheelRPM=Rules.WheelRPM(speed,gear,config)
 local linked=engineOn and not shifting and gear~=0 and speed*direction>=0
 local slipping=linked and gear<=2 and wheelRPM<config.ClutchLockRPM
 local gas=math.max(0,throttle)
 local factor=math.clamp(power*wheels,0,1)
 local load=Rules.RoadLoad(speed,config)
 if not engineOn then rpm=0
 elseif not linked then rpm=freeRPM(rpm,shifting and 0 or gas,dt,config)
 elseif slipping then
  local target=gear==2 and gas==0 and 1000 or config.IdleRPM+gas*(config.LaunchRPM-config.IdleRPM)
  if gas==0 then rpm=target
  elseif rpm<target then rpm=math.min(target,freeRPM(rpm,gas,dt,config))
  else rpm=math.max(target,freeRPM(rpm,0,dt,config)) end
 else rpm=math.min(wheelRPM,config.RedlineRPM*1.5) end
 local available=Rules.Torque(rpm,config)*ratio*config.DrivetrainEfficiency/config.WheelRadius*factor
 if cruise and linked and gear>0 and available>0 then
  -- Feed forward road resistance, then correct any speed error with real throttle.
  gas=math.clamp((load+(cruise-speed)*config.MassKg*config.CruiseGain)/available,0,1)
 end
 local force=0
 if linked and available>0 then
  if gas>0 and rpm<config.RedlineRPM then force=available*gas
  elseif slipping and gear==2 and throttle>=0 then
   force=math.clamp(load+(config.CreepSpeed-speed)*config.MassKg*.8,0,available)
  end
 end
 force=math.min(force,config.MassKg*config.MaxTractionAcceleration*math.clamp(wheels,0,1))
 local engineBrake=linked and not slipping and gas<.001
 if engineBrake then load+=config.EngineBrakeTorqueNm*(.2+rpm/config.RedlineRPM)*ratio*config.DrivetrainEfficiency/config.WheelRadius end
 if throttle<0 then speed=approach(speed,0,config.BrakeDeceleration*dt)
 else
  local sign=speed>0 and 1 or speed<0 and -1 or direction
  local nextSpeed=speed+(force*direction-sign*load)/config.MassKg*dt
  if speed*nextSpeed<0 and (force==0 or sign==direction) then nextSpeed=0 end
  speed=math.clamp(nextSpeed,-config.ReverseSpeed,config.MaxSpeed)
 end
 if linked and not slipping then rpm=Rules.RPM(speed,0,gear,true,config) end
 return speed,rpm,engineBrake
end
function Rules.Drive(speed,rpm,throttle,gear,engineOn,power,wheels,dt,config,shifting,engineBraking,cruise)
 local steps=math.max(1,math.ceil(dt/.01))
 for _=1,steps do
  speed,rpm,engineBraking=driveStep(speed,rpm,throttle,gear,engineOn,power,wheels,dt/steps,config,shifting,cruise)
 end
 return speed,rpm,engineBraking
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
