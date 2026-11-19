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
 if gear==-1 or gear==1 then
  return config.IdleRPM+math.clamp(moving/top,0,1)*(config.GentleRPM-config.IdleRPM)
 end
 local low=config.GearMinimums[gear]
 local rpm=config.GearIdleRPM+(moving-low)/(top-low)*(config.RedlineRPM-config.GearIdleRPM)
 if speed<0 then rpm=0 end
 return math.clamp(rpm,gear==2 and config.GearIdleRPM or 0,config.RedlineRPM)
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
function Rules.Speed(speed,throttle,engineOn,power,wheelFactor,dt,config,gear,shifting)
 gear=gear or 0
 if throttle<0 then return approach(speed,0,config.BrakeDeceleration*dt) end
 if not engineOn or shifting or gear==0 then return approach(speed,0,config.RollingDeceleration*dt) end
 local target=0
 if throttle>0 then
  local top=math.min(math.abs(Rules.GearSpeed(gear,config)),config.MaxSpeed)
  target=top*throttle*power*wheelFactor*(gear==-1 and -1 or 1)
 elseif gear==2 then
  target=config.GearMinimums[2]*power*wheelFactor
 end
 local rate=config.Acceleration*(gear>0 and math.max(.35,1-(gear-1)*.14) or .6)
 if speed*target<0 then return approach(speed,0,config.BrakeDeceleration*dt) end
 if math.abs(target)<math.abs(speed) then rate=config.RollingDeceleration end
 return approach(speed,target,rate*dt)
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
