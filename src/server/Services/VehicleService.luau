local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local ServerStorage=game:GetService("ServerStorage")
local RunService=game:GetService("RunService")
local Shared=ReplicatedStorage.Shared
local Config=require(Shared.VehicleConfig)
local Rules=require(Shared.VehicleRules)
local Appearance=require(Shared.VehicleAppearance)
local Ground=require(script.Parent.VehicleGround)
local Suspension=require(script.Parent.VehicleSuspension)
local Interaction=require(Shared.Interaction)
local BulletCast=require(Shared.BulletCast)
local Assembly=require(script.Parent.VehicleAssembly)
local VehicleDamage=require(script.Parent.VehicleDamageService)
local Damage=require(script.Parent.DamageService)
local Explosions=require(script.Parent.ExplosionService)
local Inventory=require(script.Parent.InventoryService)
local Interact=require(script.Parent.InteractionAnimationService)
local Journal=require(script.Parent.JournalService)
local Service={}
local vehicles={}
local occupants={}
local requests={}
local remotes
local function notice(player,text) Journal.Send(player,text) end
local function component(data,kind)
 for _,record in ipairs(data.Components) do if record.Kind==kind then return record end end
end
local function set(object,key,value)
 if object:GetAttribute(key)~=value then object:SetAttribute(key,value) end
end
local function clearCruise(data)
 data.CruiseSpeed=nil
 set(data.Model,"CruiseOn",false);set(data.Model,"CruiseSpeed",0)
end
local function stop(data)
 clearCruise(data)
 data.EngineOn=false;data.Starting=nil
 set(data.Model,"EngineOn",false);set(data.Model,"EngineStarting",false)
end
local function filters(data,character)
 local excluded={data.Model}
 if character then table.insert(excluded,character) end
 for _,occupant in pairs(occupants) do if occupant.Data==data then table.insert(excluded,occupant.Character) end end
 return excluded
end
local function findExit(occupant)
 local data,root,hp=occupant.Data,occupant.Root,occupant.HP
 local door=occupant.Record.Door
 local localPoint=door and door.Rest.Position or data.Root.CFrame:PointToObjectSpace(occupant.Record.Seat.Position)
 local sign=localPoint.X<0 and -1 or 1
 local excluded=filters(data,occupant.Character)
 local overlap=OverlapParams.new();overlap.FilterType=Enum.RaycastFilterType.Exclude
 overlap.FilterDescendantsInstances={occupant.Character};overlap.RespectCanCollide=true
 local height=root.Size.Y+hp.HipHeight+.3
 for _,side in ipairs({sign,-sign}) do
  for _,offset in ipairs({0,-.8,.8}) do
   local point=data.Root.CFrame:PointToWorldSpace(Vector3.new(data.CollisionOffset.Position.X+side*(data.CollisionSize.X/2+math.max(.9,root.Size.X+.4)),localPoint.Y,localPoint.Z+offset))
   local ground=Ground.Cast(point+Vector3.new(0,3,0),Vector3.new(0,-8,0),excluded)
   if ground then
    local center=Vector3.new(point.X,ground.Position.Y+height/2+.08,point.Z)
    local blocked=workspace:GetPartBoundsInBox(CFrame.new(center),Vector3.new(root.Size.X+.15,height,root.Size.Z+.15),overlap)
    if #blocked==0 then
     local position=Vector3.new(point.X,ground.Position.Y+root.Size.Y/2+hp.HipHeight+.04,point.Z)
     return CFrame.lookAt(position,position+data.Root.CFrame.LookVector)
    end
   end
  end
 end
end
local function release(player,moveOutside,forced)
 local occupant=occupants[player]
 if not occupant then return false end
 local data=occupant.Data
 if not forced and math.abs(data.Speed)>Config.ExitMaximumSpeed then notice(player,"Stop the car before getting out.");return false end
 local exit=moveOutside and findExit(occupant)
 if moveOutside and not exit and not forced then notice(player,"There is no clear space to get out.");return false end
 occupants[player]=nil
 occupant.Record.Player=nil;occupant.Record.Reserved=nil
 for _,link in ipairs(occupant.Links) do link:Disconnect() end
 local seat=occupant.Record.Seat
 local weld=seat and seat:FindFirstChild("SeatWeld")
 if weld and ((weld.Part1 and weld.Part1:IsDescendantOf(occupant.Character))
  or (weld.Part0 and weld.Part0:IsDescendantOf(occupant.Character))) then weld:Destroy() end
 local c=occupant.Character
 c:SetAttribute("VehicleSeated",nil);c:SetAttribute("VehicleEntering",nil)
 c:SetAttribute("VehicleDriver",nil)
 c:SetAttribute("HandsBusy",nil)
 if occupant.Root.Parent then
  occupant.Root.CanCollide=occupant.Collidable
  occupant.Root.AssemblyLinearVelocity=Vector3.zero;occupant.Root.AssemblyAngularVelocity=Vector3.zero
  if exit then c:PivotTo(exit*c:GetPivot():ToObjectSpace(occupant.Root.CFrame):Inverse()) end
 end
 if occupant.HP.Parent then occupant.HP.Sit=false end
 if exit and occupant.Root.Parent then
  local root=occupant.Root
  local anchored=root.Anchored
  root.Anchored=true
  c:SetAttribute("VehicleExiting",true)
  task.delay(.15,function()
   if not root.Parent then return end
   -- Clear a late native SeatWeld before returning ownership to character movement.
   local late=seat and seat:FindFirstChild("SeatWeld")
   if late and late.Part1 and late.Part1:IsDescendantOf(c) then late:Destroy() end
   occupant.HP.Sit=false
   c:PivotTo(exit*c:GetPivot():ToObjectSpace(root.CFrame):Inverse())
   root.AssemblyLinearVelocity=Vector3.zero;root.AssemblyAngularVelocity=Vector3.zero
   root.Anchored=anchored;c:SetAttribute("VehicleExiting",nil)
   if occupant.HP.ChangeState and occupant.HP.Health>0 and not c:GetAttribute("Knockout") then occupant.HP:ChangeState(Enum.HumanoidStateType.GettingUp) end
  end)
 end
 if occupant.Record.Kind=="DriverSeat" then
  clearCruise(data)
  data.Throttle=0;data.InputSteer=0;data.LastInput=0;data.Speed=0
  set(data.Model,"DriverUserId",0)
 end
 return true
end
local function openPart(record,open)
 if Rules.Health(record.Model)<=0 then open=true end
 set(record.Model,"Open",open)
end
local function claim(player,data,record)
 local c=player.Character
 local hp=c and c:FindFirstChildOfClass("Humanoid")
 local root=c and c:FindFirstChild("HumanoidRootPart")
 if not c or not root or not hp or hp.Health<=0 or c:GetAttribute("Knockout") or record.Seat.Occupant~=hp then return false end
 local weld=record.Seat:FindFirstChild("SeatWeld")
 if not weld then return false end
 local occupant={Data=data,Record=record,Character=c,HP=hp,Root=root,Collidable=root.CanCollide,Links={}}
 occupants[player]=occupant;record.Player=player;record.Reserved=nil
 weld.C0=CFrame.new(0,record.Seat.Size.Y/2+root.Size.Y*.12,record.Seat.Size.Z*.08+root.Size.Z*.2)
 weld.C1=weld.Part1 and root.CFrame:ToObjectSpace(weld.Part1.CFrame):Inverse() or CFrame.identity
 root.CanCollide=false;root.AssemblyLinearVelocity=Vector3.zero
 c:SetAttribute("VehicleEntering",nil);c:SetAttribute("VehicleSeated",true)
 c:SetAttribute("VehicleDriver",record.Kind=="DriverSeat");c:SetAttribute("Running",false)
 c:SetAttribute("HandsBusy",record.Kind=="DriverSeat" and true or nil)
 if record.Kind=="DriverSeat" then set(data.Model,"DriverUserId",player.UserId) end
 if record.Door then openPart(record.Door,false) end
 local function invalid()
  if c:GetAttribute("Knockout") or c:GetAttribute("IsDead") or hp.Health<=0 then
   if record.Kind=="DriverSeat" then data.Speed=0;stop(data) end
   release(player,true,true)
  end
 end
 table.insert(occupant.Links,c:GetAttributeChangedSignal("Knockout"):Connect(invalid))
 table.insert(occupant.Links,c:GetAttributeChangedSignal("IsDead"):Connect(invalid))
 table.insert(occupant.Links,hp.HealthChanged:Connect(invalid))
 return true
end
local function eligible(player)
 local c=player.Character
 local hp=c and c:FindFirstChildOfClass("Humanoid")
 local root=c and c:FindFirstChild("HumanoidRootPart")
 if player:GetAttribute("AttributesConfirmed")~=true or not root or not hp or hp.Health<=0 or hp.Sit or hp.PlatformStand or root.Anchored then return end
 for _,key in ipairs({"Knockout","IsDead","InteractionLocked","CraftingLocked","MedicalTreating","HandsBusy","VehicleEntering","CarryingUserId","Reloading"}) do
  if c:GetAttribute(key) then return end
 end
 return c,root,hp
end
local function enter(player,data,record)
 local c,root,hp=eligible(player)
 if not c or occupants[player] or not record.Seat or record.Seat.Occupant or record.Reserved then return end
 if math.abs(data.Speed)>Config.ExitMaximumSpeed or Rules.Health(record.Model)<=0 then return end
 if record.Door and not record.Door.Model:GetAttribute("Open") then notice(player,"Open the door first.");return end
 record.Reserved=player
 local accepted=Interact.Reach(player,record.Model,Config.InteractionDistance,function()
  if record.Reserved~=player or not vehicles[data.Model] or player.Character~=c or hp.Health<=0
   or c:GetAttribute("Knockout") or record.Seat.Occupant or math.abs(data.Speed)>Config.ExitMaximumSpeed then return end
  Interact.Cancel(c)
  Inventory.ClearHands(player)
  c:SetAttribute("VehicleEntering",record.Kind=="DriverSeat" and "Driver" or true)
  if record.Kind=="DriverSeat" then
   player:SetAttribute("MedicalMode",nil);c:SetAttribute("HandsBusy",true)
  end
  record.Seat:Sit(hp)
  task.spawn(function()
   for _=1,10 do
    if record.Reserved~=player or player.Character~=c or not vehicles[data.Model] or c:GetAttribute("Knockout") then break end
    if claim(player,data,record) then return end
    RunService.Heartbeat:Wait()
   end
   c:SetAttribute("VehicleEntering",nil);c:SetAttribute("HandsBusy",nil);record.Reserved=nil;hp.Sit=false
  end)
 end)
 if not accepted then record.Reserved=nil end
 task.delay(1,function()
  if record.Reserved==player then record.Reserved=nil end
  if not occupants[player] and c.Parent then c:SetAttribute("VehicleEntering",nil) end
 end)
end
local function startEngine(player,data)
 if data.Starting then stop(data);return end
 if data.EngineOn then stop(data);return end
 if Rules.Health(data.Body)<=0 or data.Model:GetAttribute("Exploded") then notice(player,"The car is destroyed.");return end
 local engine,battery,tank=component(data,"Engine"),component(data,"Battery"),component(data,"FuelTank")
 local ready,message=Rules.CanStart(engine and engine.Model,battery and battery.Model,tank and tank.Model,Config)
 if not ready then notice(player,message);return end
 battery.Model:SetAttribute("Charge",math.max(0,battery.Model:GetAttribute("Charge")-Config.StartChargeCost))
 data.Starting={At=workspace:GetServerTimeNow()+Config.StartDuration,Player=player}
 set(data.Model,"EngineStarting",true)
 if data.StartSound then data.StartSound:Play() end
end
local function explodeTank(data,attacker)
 if data.Model:GetAttribute("Exploded") then return end
 set(data.Model,"Exploded",true);data.Speed=0;stop(data)
 local tank=component(data,"FuelTank")
 local point=tank and tank.Mount.Position or data.Root.Position
 if tank then tank.Model:SetAttribute("Fuel",0);tank.Model:SetAttribute("Burning",false) end
 remotes.Effects:FireAllClients(point,Config.TankExplosion.BlastRadius)
 Explosions.Detonate(point,Config.TankExplosion,attacker,nil,"FuelTank",Config.TankExplosionDamage,{FriendlyFire=true})
end
local function damaged(data,model,old,hp,kind,attacker)
 local name=model:GetAttribute("VehicleComponent")
 if name=="FuelTank" then
  local fuel=model:GetAttribute("Fuel") or 0
  local burning=model:GetAttribute("Burning")==true
  if hp==0 and fuel>0 and (kind=="Explosive" or burning) then explodeTank(data,attacker)
  elseif hp>0 and hp/(model:GetAttribute("MaxHP") or 100)<=Config.TankFireRatio and fuel>0 then model:SetAttribute("Burning",true) end
 end
 if name=="Engine" and Rules.Health(model)<=Config.EngineStopRatio or name=="Body" and hp<=0 or name=="FuelTank" and hp<=0 then stop(data) end
 if (name=="DriverSeat" or name=="PassengerSeat") and hp<=0 then
  for player,occupant in pairs(occupants) do if occupant.Record.Model==model then release(player,true,true) end end
 end
end
local function light(record,on,braking)
 Appearance.Lights(record,on,braking)
 if not record.Light then
  local part
  for _,candidate in ipairs(record.Parts) do if candidate~=record.Mount and candidate.Transparency<.95 then part=candidate;break end end
  if not part then return end
  record.Light=Instance.new(record.Kind=="Headlight" and "SpotLight" or "PointLight")
  record.Light.Name="VehicleLight";record.Light.Enabled=false
  record.Light.Color=record.Kind=="Headlight" and Color3.fromRGB(255,244,210) or Color3.fromRGB(255,45,25)
  record.Light.Range=record.Kind=="Headlight" and 22 or 4
  record.Light.Brightness=2
  if record.Light:IsA("SpotLight") then
   record.Light.Angle=75
   local direction=part.CFrame:VectorToObjectSpace(record.Data.Root.CFrame.LookVector)
   local ax,ay,az=math.abs(direction.X),math.abs(direction.Y),math.abs(direction.Z)
   record.Light.Face=ax>=ay and ax>=az and (direction.X>0 and Enum.NormalId.Right or Enum.NormalId.Left)
    or ay>=az and (direction.Y>0 and Enum.NormalId.Top or Enum.NormalId.Bottom)
    or (direction.Z>0 and Enum.NormalId.Back or Enum.NormalId.Front)
  end
  record.Light.Parent=part
 end
 record.Light.Enabled=on and Rules.Health(record.Model)>0
 if record.Kind=="Taillight" then record.Light.Brightness=braking and 3 or .6 end
end
local function resourceStep(data,dt)
 local engine,battery,tank=component(data,"Engine"),component(data,"Battery"),component(data,"FuelTank")
 if not engine or not battery or not tank then stop(data);return end
 if data.Starting and workspace:GetServerTimeNow()>=data.Starting.At then
  local occupant=occupants[data.Starting.Player]
  -- The starter's charge has already been paid; check the remaining voltage directly.
  local canRun=Rules.Health(engine.Model)>Config.EngineStopRatio and Rules.Health(tank.Model)>0
   and (tank.Model:GetAttribute("Fuel") or 0)>0 and Rules.Health(battery.Model)>0
   and (battery.Model:GetAttribute("Charge") or 0)>=(engine.Model:GetAttribute("MinStartingCharge") or 12)
  data.EngineOn=canRun and occupant~=nil and occupant.Data==data and occupant.Record.Kind=="DriverSeat"
  data.Starting=nil;set(data.Model,"EngineStarting",false)
 end
 if Rules.Health(engine.Model)<=Config.EngineStopRatio or Rules.Health(tank.Model)<=0 or (tank.Model:GetAttribute("Fuel") or 0)<=0 then stop(data) end
 local maximum=Rules.MaxHealth(tank.Model) or 0
 local fuel,charge,hp,burning=Rules.Resources({
  Fuel=tank.Model:GetAttribute("Fuel") or 0,Charge=battery.Model:GetAttribute("Charge") or 0,
  MaxCharge=battery.Model:GetAttribute("MaxCharge") or 14,TankHP=tank.Model:GetAttribute("HP") or 0,
  TankMaxHP=maximum,TankHealth=Rules.Health(tank.Model),Burning=tank.Model:GetAttribute("Burning")==true,
  BatteryHealthy=Rules.Health(battery.Model)>0,EngineOn=data.EngineOn,LightsOn=data.LightsOn,Speed=data.Speed,
 },dt,Config)
 set(tank.Model,"Fuel",fuel);set(battery.Model,"Charge",charge)
 if fuel<=0 then stop(data) end
 if hp<(tank.Model:GetAttribute("HP") or 0) then VehicleDamage.Apply(tank.Model,(tank.Model:GetAttribute("HP") or 0)-hp,"Fire") end
 set(data.Model,"Fuel",math.floor(fuel*100)/100);set(data.Model,"Charge",math.floor(charge*100)/100)
 set(data.Model,"EngineHealth",Rules.Health(engine.Model))
 set(data.Model,"EngineOn",data.EngineOn)
 local power=charge>0 and Rules.Health(battery.Model)>0
 if not power then data.LightsOn=false end
 set(data.Model,"LightsOn",data.LightsOn)
 for _,record in ipairs(data.Components) do
  if record.Kind=="Headlight" or record.Kind=="Taillight" then
   local braking=data.Throttle<0
   light(record,power and (data.LightsOn or record.Kind=="Taillight" and braking),braking)
  end
 end
 local health=Rules.Health(engine.Model)
 if not data.Smoke then
  data.Smoke=Instance.new("Smoke");data.Smoke.Name="EngineDamageSmoke";data.Smoke.Enabled=false
  data.Smoke.Color=Color3.fromRGB(100,100,100);data.Smoke.RiseVelocity=2
  data.Smoke.Parent=engine.Model:FindFirstChild("SmokeOrigin",true) or engine.Mount
 end
 data.Smoke.Enabled=health<.8
 data.Smoke.Opacity=math.clamp((1-health)*.5,0,.5);data.Smoke.Size=.4+(1-health)*1.5
 if not data.Fire then
  data.Fire=Instance.new("Fire");data.Fire.Name="FuelTankFire";data.Fire.Enabled=false
  data.Fire.Heat=2;data.Fire.Size=2;data.Fire.Parent=tank.Mount
 end
 data.Fire.Enabled=burning and Rules.Health(tank.Model)>0 and not data.Model:GetAttribute("Exploded")
 if data.StartSound and not data.Starting and data.StartSound.IsPlaying then data.StartSound:Stop() end
 if data.EngineSound then
  data.EngineSound.PlaybackSpeed=.65+((data.RPM or 0)/Config.RedlineRPM)*1.25
  data.EngineSound.Volume=.35+math.max(0,data.Throttle)*.3
  if data.EngineOn and not data.EngineSound.IsPlaying then data.EngineSound:Play()
  elseif not data.EngineOn and data.EngineSound.IsPlaying then data.EngineSound:Stop() end
 end
end
local function animateDoors(data,dt)
 local moving=false
 for _,record in ipairs(data.Components) do
  if record.Kind~="Door" and record.Kind~="Hood" and record.Kind~="Trunk" then continue end
  local target=record.Model:GetAttribute("Open") and 1 or 0
  local before=record.Angle
  record.Angle+=math.clamp(target-record.Angle,-dt/Config.DoorDuration,dt/Config.DoorDuration)
  if math.abs(record.Angle-before)<.00001 then continue end
  moving=true
  local default=record.Kind=="Door" and (record.Rest.Position.X<0 and -60 or 60) or record.Kind=="Trunk" and -70 or 70
  local angle=math.rad(Rules.Number(record.Model:GetAttribute("OpenAngle"),default,-150,150))*record.Angle
  record.Joint.C0=record.Rest*(record.Kind=="Door" and CFrame.Angles(0,angle,0) or CFrame.Angles(angle,0,0))
 end
 return moving
end
local function drive(data,dt)
 local occupant
 for _,record in ipairs(data.Components) do
  if record.Kind=="DriverSeat" and record.Player then occupant=occupants[record.Player];break end
 end
 if not occupant or workspace:GetServerTimeNow()-data.LastInput>Config.InputTimeout then data.Throttle=0;data.InputSteer=0;clearCruise(data) end
 if not occupant then
  data.Speed=0;data.RPM=data.EngineOn and Config.IdleRPM or 0;data.Steering=0
  data.LongitudinalAcceleration=0;data.LateralAcceleration=0
  local target=Suspension.Update(data,Suspension.Yaw(data.Root.CFrame),dt,filters(data))
  if (target.Position-data.Root.Position).Magnitude>.0001 or target.UpVector:Dot(data.Root.CFrame.UpVector)<.999999 then data.Model:PivotTo(target) end
  return
 end
 local engine=component(data,"Engine")
 local power=engine and Rules.Power(Rules.Health(engine.Model),Config.EngineStopRatio) or 0
 local good,total=0,0
 for _,record in ipairs(data.Components) do if record.Kind=="Wheel" then total+=1;good+=Rules.Health(record.Model) end end
 local wheels=total>=4 and good/total or 0
 if data.SuspensionContacts then wheels*=data.SuspensionContacts/math.max(1,total) end
 if data.SuspensionContacts==0 then clearCruise(data) end
 if data.EngineOn and workspace:GetServerTimeNow()>=(data.ShiftUntil or 0) and Rules.Stalls(data.Speed,data.Gear,data.Config) then
  stop(data)
  if occupant then notice(occupant.Record.Player,"Engine stalled: select a lower gear and restart.") end
 end
 local previousSpeed=data.Speed
 local shifting=workspace:GetServerTimeNow()<(data.ShiftUntil or 0)
 if data.Throttle<0 or not data.EngineOn or shifting or data.Gear<=0 then clearCruise(data) end
 data.Speed,data.RPM,data.EngineBraking=Rules.Drive(data.Speed,data.RPM,data.Throttle,data.Gear,data.EngineOn,power,wheels,dt,data.Config,shifting,data.EngineBraking,data.CruiseSpeed)
 if engine and data.EngineOn and not shifting then
  local wear=Rules.OverrevDamage(data.RPM,dt,Rules.MaxHealth(engine.Model) or 0,data.Config)
  if wear>0 then VehicleDamage.Apply(engine.Model,wear,"Overrev") end
 end
 data.Steering=Rules.Steer(data.Steering,data.InputSteer,data.Speed,dt,Config)
 local current=data.Root.CFrame
 local turn=Rules.Steering(data.Speed,data.Steering,data.Wheelbase,dt,Config)
 local proposed=Suspension.Yaw(current)*CFrame.Angles(0,turn,0)
 local travel=proposed.LookVector*data.Speed*dt
 local hit=travel.Magnitude>.00001 and Ground.Sweep(current*data.CollisionOffset,data.CollisionSize,travel,filters(data),current.Position.Y-data.GroundOffset,Config.MaximumGroundStep) or nil
 if hit then
  local impact=math.abs(data.Speed)
  if impact>=Config.MinimumCrashSpeed and workspace:GetServerTimeNow()>=(data.NextCrash or 0) then
   data.NextCrash=workspace:GetServerTimeNow()+.5
   local model=hit.Instance
   while model and model~=workspace and not model:FindFirstChildOfClass("Humanoid") do model=model.Parent end
   local hp=model and model:FindFirstChildOfClass("Humanoid")
   if hp then
    Damage.Apply(hp,impact*impact*Config.RamDamagePerSpeedSquared,"Blunt",data.Root.Position,"Collision",{HitChecked=true,Attacker=occupant and occupant.Record.Player,FriendlyFire=true})
   end
   local target=VehicleDamage.Component(hit.Instance)
   if target then VehicleDamage.Apply(target,impact*impact*Config.CrashDamagePerSpeedSquared,"Collision",occupant and occupant.Record.Player) end
   VehicleDamage.Apply(data.Body,impact*impact*Config.CrashDamagePerSpeedSquared,"Collision")
   if engine then VehicleDamage.Apply(engine.Model,impact*impact*Config.CrashDamagePerSpeedSquared*.25,"Collision") end
  end
  local distance=math.max(0,hit.Distance-.03)
  travel=travel.Unit*math.min(distance,travel.Magnitude)
  clearCruise(data);data.Speed=0;data.RPM=Rules.RPM(0,0,data.Gear,data.EngineOn,data.Config)
 end
 local point=current.Position+travel
 data.LongitudinalAcceleration=math.clamp((data.Speed-previousSpeed)/math.max(.001,dt),-15,15)
 data.LateralAcceleration=math.clamp(-data.Speed*turn/math.max(.001,dt),-20,20)
 local suspensionBefore=data.Suspension and table.clone(data.Suspension)
 local target,supports=Suspension.Update(data,CFrame.new(point)*(proposed-proposed.Position),dt,filters(data))
 -- Rotation needs its own overlap check: a long nose must not sweep through a wall.
 local ignored=filters(data)
 -- Test every proposed pose: shapecasts do not report initial overlaps.
 -- Do not exclude wheel supports wholesale; a support may be part of a wall.
 if Ground.Overlap(target*data.CollisionOffset,data.CollisionSize,ignored,current.Position.Y-data.GroundOffset,Config.MaximumGroundStep) then
  clearCruise(data);data.Speed=0;data.RPM=Rules.RPM(0,0,data.Gear,data.EngineOn,data.Config)
  data.Suspension=suspensionBefore
  data.Model:PivotTo(current);return
 end
 data.Model:PivotTo(target)
end
function Service.Spawn(id,frame)
 local library=ServerStorage:FindFirstChild("Vehicles")
 local template=library and library:FindFirstChild(id)
 local details=library and library:FindFirstChild(id.." details")
 if not template or not template:IsA("Model") or not details then return nil,"Vehicle template or details folder is missing." end
 local data,message=Assembly.Build(template,details)
 if not data then return nil,message end
 if frame then data.Model:PivotTo(frame) end
 local folder=workspace:FindFirstChild("Vehicles")
 if not folder then folder=Instance.new("Folder");folder.Name="Vehicles";folder.Parent=workspace end
 data.Speed=0;data.Steering=0;data.Throttle=0;data.InputSteer=0;data.LastInput=0;data.ResourceTime=0
 data.Gear=0;data.RPM=0
 set(data.Model,"Gear",0);set(data.Model,"RPM",0)
 local sounds=data.Model:FindFirstChild("Sounds")
 if not sounds then sounds=Instance.new("Folder");sounds.Name="Sounds";sounds.Parent=data.Model end
 local engine=component(data,"Engine")
 if engine then
  local emitter=Instance.new("Attachment");emitter.Name="EngineAudio";emitter.Parent=engine.Mount
  local function audio(name,id,loop)
   local sound=sounds:FindFirstChild(name)
   if not sound or not sound:IsA("Sound") then
    sound=Instance.new("Sound");sound.Name=name;sound.SoundId=id;sound.Volume=.6;sound.Parent=sounds
   end
   local live=sound:Clone();live.Name=name;live.Looped=loop
   live.RollOffMinDistance=4;live.RollOffMaxDistance=80;live.Parent=emitter
   return live
  end
  data.EngineSound=audio("EngineLoop",Config.EngineLoopId,true)
  data.StartSound=audio("EngineStart",Config.EngineStartId,false)
 end
 data.EngineOn=false;data.LightsOn=false;data.Config=table.clone(Config);data.Links={}
 for _,key in ipairs({"MaxSpeed","ReverseSpeed","BrakeDeceleration","MassKg","MaxTorqueNm","FinalDrive","DragArea"}) do
  data.Config[key]=Rules.Number(template:GetAttribute(key),Config[key],.01,100000)
 end
 if engine then data.Config.MaxTorqueNm=Rules.Number(engine.Model:GetAttribute("MaxTorqueNm"),data.Config.MaxTorqueNm,1,100000) end
 local radius,count=0,0
 for _,record in ipairs(data.Components) do if record.Kind=="Wheel" then radius+=record.Radius;count+=1 end end
 if count>0 then data.Config.WheelRadius=math.max(.05,radius/count) end
 data.Model:SetAttribute("GearCount",#data.Config.GearRatios)
 local damageable={data.Body}
 for _,record in ipairs(data.Components) do
  record.Data=data;table.insert(damageable,record.Model)
  if record.Seat then
   table.insert(data.Links,record.Seat:GetPropertyChangedSignal("Occupant"):Connect(function()
    if record.Player and record.Seat.Occupant~=(occupants[record.Player] and occupants[record.Player].HP) then release(record.Player,true,true) end
   end))
  end
 end
 Appearance.Paint(data.Model)
 table.insert(data.Links,data.Model:GetAttributeChangedSignal("PaintColor"):Connect(function() Appearance.Paint(data.Model) end))
 VehicleDamage.Register(data.Model,damageable,function(...) damaged(data,...) end)
 vehicles[data.Model]=data
 table.insert(data.Links,data.Model.Destroying:Connect(function()
  for player,occupant in pairs(occupants) do if occupant.Data==data then release(player,false,true) end end
  for _,link in ipairs(data.Links) do link:Disconnect() end
  VehicleDamage.Unregister(data.Model);vehicles[data.Model]=nil
 end))
 data.Model.Parent=folder
 resourceStep(data,0)
 return data.Model
end
local function interact(player,target)
 if typeof(target)~="Instance" then return end
 local model,vehicle=VehicleDamage.Component(target)
 local data=vehicle and vehicles[vehicle]
 if not model or not data then return end
 local record
 for _,candidate in ipairs(data.Components) do if candidate.Model==model then record=candidate;break end end
 if not record then return end
 local c,root=eligible(player)
 if not c or Interaction.Distance(model,root.Position)>Config.InteractionDistance then return end
 local head=c:FindFirstChild("Head")
 local point=Interaction.NearestPoint(model,root.Position)
 if BulletCast.Raycast(head and head.Position or root.Position,point-(head and head.Position or root.Position),{c,vehicle}) then return end
 if record.Seat then enter(player,data,record)
 elseif record.Kind=="Door" or record.Kind=="Hood" or record.Kind=="Trunk" then
  if math.abs(data.Speed)>Config.ExitMaximumSpeed then return end
  for _,seatRecord in ipairs(data.Components) do if seatRecord.Door==record and seatRecord.Reserved then return end end
  Interact.Reach(player,model,Config.InteractionDistance,function()
   if vehicles[vehicle] and player.Character==c and not c:GetAttribute("Knockout") then openPart(record,not model:GetAttribute("Open")) end
  end)
 end
end
function Service.Start()
 if Service.Started then return end
 Service.Started=true
 Ground.Start()
 remotes=Instance.new("Folder");remotes.Name="VehicleRemotes";remotes.Parent=ReplicatedStorage
 for _,name in ipairs({"Action","Input","Effects"}) do
  local remote=Instance.new("RemoteEvent");remote.Name=name;remote.Parent=remotes
 end
 remotes.Action.OnServerEvent:Connect(function(player,command,target)
  local now=workspace:GetServerTimeNow()
  if now<(requests[player] or 0) then return end
  requests[player]=now+.15
  if command=="Interact" then interact(player,target);return end
  local occupant=occupants[player]
  if not occupant then return end
  if command=="Exit" then
   if release(player,true,false) and occupant.Record.Door then openPart(occupant.Record.Door,true) end
  elseif occupant.Record.Kind=="DriverSeat" then
   if command=="Engine" then startEngine(player,occupant.Data)
   elseif command=="Lights" then occupant.Data.LightsOn=not occupant.Data.LightsOn
   elseif command=="Cruise" then
    local data=occupant.Data
    if data.CruiseSpeed then clearCruise(data)
    elseif data.EngineOn and data.Gear>0 and data.Speed>Config.ExitMaximumSpeed and now>=(data.ShiftUntil or 0) then
     data.CruiseSpeed=data.Speed;set(data.Model,"CruiseOn",true);set(data.Model,"CruiseSpeed",data.Speed)
    end
   elseif command=="Gear" then
    local data=occupant.Data
    local nextGear=Rules.SelectGear(target,data.Config)
    if nextGear==nil or nextGear==data.Gear or (nextGear~=0 and now<(data.ShiftUntil or 0)) then return end
    if nextGear==-1 then
     local engine=component(data,"Engine")
     local fraction=Rules.ReverseDamage(data.Speed,data.Config)
     if engine and Rules.MaxHealth(engine.Model) and fraction>0 then
      VehicleDamage.Apply(engine.Model,(Rules.MaxHealth(engine.Model) or 0)*fraction,"Mechanical",player)
      notice(player,"Reverse engaged while moving: engine damaged.")
     end
    end
    clearCruise(data)
    data.Gear=nextGear;data.ShiftUntil=now+Config.ShiftDuration
    data.EngineBraking=false;set(data.Model,"Gear",nextGear)
   end
  end
 end)
 remotes.Input.OnServerEvent:Connect(function(player,throttle,steer)
  local occupant=occupants[player]
  if not occupant or occupant.Record.Kind~="DriverSeat" then return end
  local data=occupant.Data;local now=workspace:GetServerTimeNow()
  if now-(data.LastPacket or 0)<1/30 then return end
  data.LastPacket=now
  data.Throttle=Rules.Number(throttle,0,-1,1)
  if data.Throttle<0 then clearCruise(data) end
  data.InputSteer=Rules.Number(steer,0,-1,1);data.LastInput=now
 end)
 local function watchPlayer(player)
  player.CharacterRemoving:Connect(function() release(player,false,true) end)
 end
 Players.PlayerAdded:Connect(watchPlayer)
 for _,player in ipairs(Players:GetPlayers()) do watchPlayer(player) end
 Players.PlayerRemoving:Connect(function(player) release(player,false,true);requests[player]=nil end)
 RunService.Heartbeat:Connect(function(dt)
  for player,occupant in pairs(occupants) do
   if player.Character~=occupant.Character or not occupant.Character.Parent or not occupant.Data.Model:IsDescendantOf(workspace) then release(player,false,true) end
  end
  for _,data in pairs(vehicles) do
   if not data.Model:IsDescendantOf(workspace) then continue end
   local steps=math.max(1,math.ceil(math.min(dt,.2)/.04))
   for _=1,steps do drive(data,math.min(dt,.2)/steps) end
   animateDoors(data,math.min(dt,.2))
   data.ResourceTime+=dt
   if data.ResourceTime>=.1 then resourceStep(data,data.ResourceTime);data.ResourceTime=0 end
   set(data.Model,"RPM",math.floor((data.RPM or 0)/10)*10)
   set(data.Model,"Speed",math.floor(data.Speed*100)/100)
   set(data.Model,"Steering",math.floor(data.Steering*1000)/1000)
  end
 end)
 task.spawn(function()
  local library=ServerStorage:WaitForChild("Vehicles")
  if not Config.AutoSpawn then return end
  local function spawnTemplate(template)
   if not template:IsA("Model") or not template:FindFirstChild("Body") then return end
   local folder=workspace:FindFirstChild("Vehicles")
   if folder then for _,live in ipairs(folder:GetChildren()) do if live:GetAttribute("VehicleTemplate")==template.Name then return end end end
   local model,message=Service.Spawn(template.Name)
   if not model then warn("[Decline Vehicles] "..template.Name..": "..tostring(message)) end
  end
  for _,template in ipairs(library:GetChildren()) do spawnTemplate(template) end
  library.ChildAdded:Connect(function(template) task.defer(function() spawnTemplate(template) end) end)
 end)
end
return Service
