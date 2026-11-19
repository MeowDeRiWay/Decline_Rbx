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
function Rules.Speed(speed,throttle,engineOn,power,wheelFactor,dt,config)
 local target=0
 if engineOn then target=throttle*(throttle>=0 and config.MaxSpeed or config.ReverseSpeed)*power*wheelFactor end
 local rate=config.Acceleration
 if throttle==0 or not engineOn then rate=config.RollingDeceleration
 elseif speed*throttle<0 or math.abs(target)<math.abs(speed) then rate=config.BrakeDeceleration end
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
