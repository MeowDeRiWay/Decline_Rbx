"""Exercise assembly and server vehicle controls using the supplied Vehicles.rbxm geometry."""
from pathlib import Path
import re
import subprocess
import sys
import tempfile

root = Path(__file__).resolve().parents[1]
def module(path,imports=""):
    text = (root / path).read_text()
    text = re.sub(r"^local \w+\s*=\s*require[^\n]*\n", "", text, flags=re.MULTILINE)
    return "(function()\n" + imports + "\n" + text + "\nend)()"

source = (root / "tests/rig_math.fixture.luau").read_text()
source += "\n" + (root / "tests/vehicle_runtime.fixture.luau").read_text()
source += "\nlocal VehicleConfig=" + module("src/shared/VehicleConfig.luau")
source += "\nlocal Doors={Honk=function(player,model,frame,range) DoorsCalled={Player=player,Model=model,Frame=frame,Range=range} end}\n"
source += "\nlocal Ground=" + module("src/server/Services/VehicleGround.luau")
source += "\nlocal Suspension=" + module("src/server/Services/VehicleSuspension.luau")
source += "\nlocal Appearance=" + module("src/shared/VehicleAppearance.luau")
source += "\nlocal VehicleRules=" + module("src/shared/VehicleRules.luau")
source += "\nlocal ExplosionRules=" + module("src/shared/ExplosionRules.luau")
source += "\nlocal Interaction=" + module("src/shared/Interaction.luau")
source += "\nlocal geometry=" + module("tests/vehicle_geometry.fixture.luau")
source += r'''
local library=loadGeometry(geometry)
local template=library:FindFirstChild("Car_1")
local details=library:FindFirstChild("Car_1 details")
'''
source += "\nlocal Inspection=" + module("src/shared/VehicleInspection.luau")
source += "\nlocal Assembly=" + module("src/server/Services/VehicleAssembly.luau", "local Config=VehicleConfig\nlocal Rules=VehicleRules")
source += r'''
local built,message=Assembly.Build(template,details)
assert(built,message)
assert(#built.Components==17,"exactly one clone per Detail marker")
local wheels,steering,seats=0,0,0
for _,record in ipairs(built.Components) do
 assert(record.Model.PrimaryPart==record.Mount)
 assert(record.Mount.Transparency==1 and not record.Mount.CanCollide and not record.Mount.CanQuery)
 local original
 for _,marker in ipairs(template:GetChildren()) do
  if marker:IsA("BasePart") and marker:GetAttribute("Detail")==record.Model:GetAttribute("Detail") and (marker.Position-record.Mount.Position).Magnitude<.001 then original=marker;break end
 end
 assert(original,"component Mount aligns with its real Detail point")
 near(record.Mount.CFrame.LookVector,original.CFrame.LookVector,"PivotOffset does not double-rotate mounted components")
 if record.Kind=="Wheel" then
  local side=built.Root.CFrame:PointToObjectSpace(record.Mount.Position).X
  local face
  for _,part in ipairs(record.Parts) do if part~=record.Mount then face=part;break end end
  local outward=built.Root.CFrame:VectorToObjectSpace(face.Position-record.Mount.Position).X
  assert(side*outward>0,"wheel outer faces point away from the chassis on both sides")
 end
 if record.Kind=="Wheel" then wheels+=1;if record.Model:GetAttribute("Steerable") then steering+=1 end end
 if record.Seat then seats+=1;assert(record.Door and record.Door.Model:GetAttribute("Detail")=="Door (left)") end
end
assert(wheels==4 and steering==2 and seats==1,"one wheel template becomes four wheels, two steerable; passenger remains optional")
assert(built.Wheelbase>3 and built.Wheelbase<3.1)
assert(built.Body:GetAttribute("HP")==nil and built.Body:GetAttribute("MaxHP")==nil,"body without authored MaxHP has no health")
local inspected
for _,record in ipairs(built.Components) do
 local source=details:FindFirstChild(record.Model:GetAttribute("Detail"))
 local expected=source:GetAttribute("MaxHP")
 assert(record.Model:GetAttribute("MaxHP")==expected,"assembly never invents MaxHP")
 if expected then assert(record.Model:GetAttribute("HP")==expected);inspected=record.Model
 else assert(record.Model:GetAttribute("HP")==nil and VehicleRules.Health(record.Model)==1,"unconfigured parts remain functional without health") end
end
assert(inspected)
local hpInfo=Inspection.Read(inspected.PrimaryPart)
assert(hpInfo and hpInfo.Model==inspected and hpInfo.HP==hpInfo.MaxHP,"hovering child geometry resolves component health")
inspected:SetAttribute("HP",0)
assert(Inspection.Read(inspected.PrimaryPart).HP==0,"destroyed components still display zero HP")
inspected:SetAttribute("HP",12.5)
assert(Inspection.Read(inspected.PrimaryPart).HP==12.5,"hover reflects live fractional damage")
assert(not Inspection.Read(template),"stored templates and non-vehicles do not show inspection")
inspected:SetAttribute("MaxHP",0)
assert(not Inspection.Read(inspected.PrimaryPart),"invalid maximum health is ignored")

groundY=built.Root.Position.Y-built.GroundOffset
local referenceRoot=built.Root.CFrame
built.Model:Destroy()
local missing=details:FindFirstChild("Battery");missing.Name="MissingBattery"
local bad=Assembly.Build(template,details)
assert(bad==nil,"missing components fail before parenting a broken vehicle")
missing.Name="Battery"
local function componentModel(vehicle,kind)
 for _,model in ipairs(vehicle.Components:GetChildren()) do if model:GetAttribute("VehicleComponent")==kind then return model end end
end
assert(VehicleRules.SelectGear(5,VehicleConfig)==5 and VehicleRules.SelectGear(6,VehicleConfig)==nil)
assert(VehicleRules.SelectGear(0/0,VehicleConfig)==nil and VehicleRules.SelectGear(1.5,VehicleConfig)==nil)
for gear=1,5 do
 local speed=VehicleRules.SpeedFromRPM(3500,gear,VehicleConfig)
 assert(math.abs(VehicleRules.RPM(speed,0,gear,true,VehicleConfig)-3500)<.001,"ratios convert wheel speed and engine RPM both ways")
end
local sameSpeed=VehicleRules.SpeedFromRPM(4500,3,VehicleConfig)
local shiftedRPM=VehicleRules.RPM(sameSpeed,0,4,true,VehicleConfig)
assert(math.abs(shiftedRPM-4500*VehicleConfig.GearRatios[4]/VehicleConfig.GearRatios[3])<.001,"upshift lowers RPM proportionally without changing road speed")
assert(VehicleRules.Stalls(0,5,VehicleConfig) and not VehicleRules.Stalls(0,2,VehicleConfig))
assert(VehicleRules.ReverseDamage(4.99/3.6,VehicleConfig)==0)
assert(VehicleRules.ReverseDamage(20/3.6,VehicleConfig)==1)
assert(VehicleRules.WheelSteer(30,1,VehicleConfig)<.11)
assert(VehicleRules.Steer(.8,0,20,.01,VehicleConfig)==0)
assert(VehicleRules.WheelSteer(20/3.6,1,VehicleConfig)==1,"low-speed manoeuvres retain full wheel lock")
local lowTurn=VehicleRules.Steering(10/3.6,1,3,.1,VehicleConfig)
local radius=(10/3.6)*.1/math.abs(lowTurn)
assert(radius<4,"parking-speed turning radius is under four metres for a three-metre wheelbase")
local wheel=0
for _=1,60 do wheel=VehicleRules.Steer(wheel,1,10/3.6,1/60,VehicleConfig) end
assert(wheel>.9 and wheel<=1,"steering reaches near-full lock in one second without snapping")
assert(VehicleRules.WheelSteer(200/3.6,1,VehicleConfig)<.03,"high-speed steering remains limited")
assert(VehicleRules.Steering(10,1,3,.1,VehicleConfig)*VehicleRules.Steering(-10,1,3,.1,VehicleConfig)<0,"reverse steering retains correct turn direction")
local function simulate(config,gear,seconds,gas,speed,rpm,cruise,fps)
 speed=speed or 0;rpm=rpm or 800;fps=fps or 100
 for _=1,math.ceil(seconds*fps) do speed,rpm=VehicleRules.Drive(speed,rpm,gas,gear,true,1,1,1/fps,config,false,false,cruise) end
 return speed,rpm
end
local first=simulate(VehicleConfig,1,1,1)
local second=simulate(VehicleConfig,2,1,1)
assert(first>second and first>0,"lower gear multiplies wheel torque and automatic clutch launches smoothly")
local heavy=table.clone(VehicleConfig);heavy.MassKg*=2
assert(simulate(heavy,1,1,1)<first,"greater vehicle mass reduces acceleration")
local damaged=VehicleRules.Drive(10,3000,1,2,true,.2,1,.1,VehicleConfig,false,false)
local healthy=VehicleRules.Drive(10,3000,1,2,true,1,1,.1,VehicleConfig,false,false)
assert(damaged<healthy and damaged>9,"damage reduces force instead of teleporting speed")
assert(VehicleRules.RoadLoad(40,VehicleConfig)>VehicleRules.RoadLoad(20,VehicleConfig)*2,"aerodynamic resistance grows with squared speed")
local cruiseSpeed,cruiseRPM=simulate(VehicleConfig,2,10,0,30/3.6,2000,30/3.6)
assert(math.abs(cruiseSpeed-30/3.6)<.03,"cruise uses throttle to balance road load")
local shifted=VehicleRules.Drive(sameSpeed,4500,1,4,true,1,1,.04,VehicleConfig,true,false)
assert(math.abs(shifted-sameSpeed)<.1,"clutch disengagement preserves momentum")
local reverse=simulate(VehicleConfig,-1,20,1)
assert(reverse<0 and reverse>=-15/3.6 and math.abs(reverse+15/3.6)<.1)
local creep=simulate(VehicleConfig,2,20,0)
assert(math.abs(creep-10/3.6)<.03,"second gear still creeps at ten km/h")
local on=VehicleRules.Drive(20,3000,0,3,true,1,1,.1,VehicleConfig,false,false)
local off=VehicleRules.Drive(20,3000,0,0,false,1,1,.1,VehicleConfig,false,false)
assert(on<off and on<20,"coupled engine brakes harder than neutral")
local lowFPS=simulate(VehicleConfig,2,3,1,0,800,nil,20)
local highFPS=simulate(VehicleConfig,2,3,1,0,800,nil,144)
assert(math.abs(lowFPS-highFPS)<.05,"longitudinal integration is stable across client/server tick rates")
-- Exercise a complete drive: shift near the torque peak rather than a speed timer.
local fast,rpm,gear=0,800,1
for _=1,18000 do
 if rpm>4400 and gear<5 then gear+=1;rpm=VehicleRules.RPM(fast,0,gear,true,VehicleConfig) end
 fast,rpm=VehicleRules.Drive(fast,rpm,1,gear,true,1,1,.01,VehicleConfig,false,false)
end
assert(fast>180/3.6 and fast<=200/3.6,"healthy car reaches high speed with sensible shifts and respects its limiter")
print(string.format("Drive calibration: first %.1f km/h at1s, second %.1f, top %.1f km/h at %.0f RPM",first*3.6,second*3.6,fast*3.6,rpm))
assert(VehicleRules.OverrevDamage(5099,1,100,VehicleConfig)==0)
local wear=0
for _=1,100 do wear+=VehicleRules.OverrevDamage(5500,.01,100,VehicleConfig) end
assert(math.abs(wear-1)<.00001,"overrev damage is one percent per second at any simulation rate")
local starter=VehicleRules.Power
assert(starter(1,.2)==1 and starter(.2,.2)==0 and starter(0,.2)==0)
local function charged(attributes)
 return {GetAttribute=function(_,key) return attributes[key] end}
end
local engine=charged({MaxHP=100,HP=100,RequiredStartingCurrent=70,MinStartingCharge=12})
local battery=charged({MaxHP=100,HP=100,StartingCurrent=75,Charge=14})
local tank=charged({MaxHP=100,HP=100,Fuel=72})
assert(VehicleRules.CanStart(engine,battery,tank,VehicleConfig))
local weak=charged({MaxHP=100,HP=100,StartingCurrent=60,Charge=14})
assert(not VehicleRules.CanStart(engine,weak,tank,VehicleConfig),"starting current is enforced")
assert(VehicleRules.Number(0/0,0,-1,1)==0 and VehicleRules.Number(math.huge,0,-1,1)==0)
local BulletCast={Raycast=function() return nil end}
'''
source += "\nlocal VehicleDamage=" + module("src/server/Services/VehicleDamageService.luau", "local Rules=VehicleRules\nlocal Blast=ExplosionRules")
source += r'''
local notices={}
local Journal={Send=function(player,text) table.insert(notices,text) end}
local damageLog={}
local Damage={Apply=function(hp,amount)
 table.insert(damageLog,amount);hp.Health=math.max(0,hp.Health-math.ceil(amount));hp.HealthChanged:Fire(hp.Health);return amount
end}
local explosions={}
local Explosions={Detonate=function(point,settings,attacker,character,item,amount)
 table.insert(explosions,{Point=point,Amount=amount})
end}
local Inventory={ClearHands=function(player) player.ClearedHands=true end}
local Interact={
 Reach=function(player,target,range,activate)
  player.Character:SetAttribute("InteractionLocked",true)
  player.Character.HumanoidRootPart.Anchored=true
  task.delay(.3,activate)
  task.delay(.65,function()
   if not player.Character:GetAttribute("VehicleSeated") then
    player.Character:SetAttribute("InteractionLocked",nil)
    player.Character.HumanoidRootPart.Anchored=false
   end
  end)
  return true
 end,
 Cancel=function(character) character:SetAttribute("InteractionLocked",nil);character.HumanoidRootPart.Anchored=false end,
}
local player=create("Player",Players);player.UserId=77
player:SetAttribute("AttributesConfirmed",true)
local character=create("Model",workspace);character.Name="Character";player.Character=character
local root=create("Part",character);root.Name="HumanoidRootPart";root.Size=Vector3.new(.4,.7,.315)
character.PrimaryPart=root
local hp=create("Humanoid",character);hp.Health=100;hp.HipHeight=.9;hp.Sit=false;hp.PlatformStand=false;hp.WalkSpeed=1
local head=create("Part",character);head.Name="Head";head.Size=Vector3.new(.2,.2,.3)
'''
source += "\nlocal VehicleInput=" + module("src/shared/VehicleInputRules.luau")
source += r'''
local inputSignal=signal()
local Input={InputBegan=inputSignal,GetFocusedTextBox=function() return nil end}
local GuiService={MenuIsOpen=false}
Enum.KeyCode={One="One",Two="Two",Four="Four",KeypadOne="KeypadOne",KeypadTwo="KeypadTwo",KeypadFour="KeypadFour",H="H",Escape="Escape"}
Enum.UserInputType={MouseButton1="MouseButton1"}
local selected,highlight,hint=nil,{Enabled=false},{Visible=false}
local function cancel() player:SetAttribute("MedicalMode",nil) end
local remote={FireServer=function() end}
local inventory={FireServer=function() end}
'''
source += r'''
local Gui=GuiService
local slotCalls={}
local action={FireServer=function(_,command,slot) table.insert(slotCalls,{command,slot}) end}
'''
slots=(root / "src/client/WeaponSlots.client.luau").read_text()
source += "\n" + slots[slots.index("Input.InputBegan:Connect"):]
source += r'''
character:SetAttribute("VehicleDriver",true)
Input.InputBegan:Fire({KeyCode=Enum.KeyCode.One},false)
assert(#slotCalls==0,"driver's first gear never draws a weapon")
character:SetAttribute("VehicleDriver",false);character:SetAttribute("VehicleSeated",true)
Input.InputBegan:Fire({KeyCode=Enum.KeyCode.One},false)
assert(#slotCalls==1 and slotCalls[1][2]=="PrimaryWeapon","passenger keeps primary weapon selection")
character:SetAttribute("VehicleSeated",nil)
'''
medicine=(root / "src/client/Medicine.client.luau").read_text()
source += "\n" + medicine[medicine.index("local function blocked()"):medicine.index("local function cancel()")]
source += "\n" + medicine[medicine.index("Input.InputBegan:Connect"):medicine.index("Run.RenderStepped:Connect")]
source += r'''
character:SetAttribute("VehicleDriver",true)
Input.InputBegan:Fire({KeyCode=Enum.KeyCode.Four},false)
assert(player:GetAttribute("MedicalMode")==nil,"driver's fourth gear cannot enter doctor mode")
character:SetAttribute("VehicleDriver",false);character:SetAttribute("VehicleSeated",true)
Input.InputBegan:Fire({KeyCode=Enum.KeyCode.Four},false)
assert(player:GetAttribute("MedicalMode")=="Doctor","passenger keeps the doctor hotkey")
player:SetAttribute("MedicalMode",nil)
character:SetAttribute("VehicleSeated",nil)
local pending=create("VehicleSeat",template)
hp.SeatPart=pending;template:SetAttribute("Vehicle",true)
assert(VehicleInput.IsDriver(character),"native driver seat blocks actions before driver attribute replication")
hp.SeatPart=nil;pending:Destroy();template:SetAttribute("Vehicle",nil)
character:SetAttribute("VehicleEntering","Driver")
assert(VehicleInput.IsDriver(character),"driver entry reserves digit actions")
character:SetAttribute("VehicleEntering",nil)
assert(not VehicleInput.IsDriver(character),"leaving restores digit actions")
'''
source += "\nlocal Service=" + module("src/server/Services/VehicleService.luau", "local Config=VehicleConfig\nlocal Rules=VehicleRules")
source += r'''
Service.Start()
assert(not workspace:FindFirstChild("Vehicles") or #workspace.Vehicles:GetChildren()==0,"startup no longer spawns the test car")
local vehicle=assert(Service.Spawn("Car_1"))
assert(vehicle.PrimaryPart.Name=="Chassis","explicit spawning still assembles Car_1")
near(vehicle.PrimaryPart.Position,referenceRoot.Position)
vehicle:SetAttribute("OwnerID",player.UserId)
local remote=ReplicatedStorage.VehicleRemotes
local glass=vehicle.Body:FindFirstChild("Window"):FindFirstChildWhichIsA("BasePart",true)
local glassColor=glass.Color
local paint=Color3.fromRGB(30,100,160)
vehicle:SetAttribute("PaintColor",paint)
assert(vehicle.Body.Chassis.Color==paint and glass.Color==glassColor,"runtime paint affects body panels and preserves windows")
for _,model in ipairs(vehicle.Components:GetChildren()) do
 local kind=model:GetAttribute("VehicleComponent")
 if kind=="Hood" or kind=="Trunk" or kind=="Door" then
  for _,part in ipairs(model:GetDescendants()) do
   if part:IsA("BasePart") and part.Name~="Mount" and part.Transparency<.95 and not (part.Parent.Name=="Window") then assert(part.Color==paint) end
  end
 end
end
local front=componentModel(vehicle,"Headlight");local tail=componentModel(vehicle,"Taillight")
local lens
for _,part in ipairs(tail:GetDescendants()) do if part:IsA("BasePart") and part.Name~="Mount" then lens=part;break end end
assert(lens.Color.R>lens.Color.G*3,"tail lens is red even when switched off")
local tailColor=lens.Color
vehicle:SetAttribute("PaintColor",Color3.fromRGB(200,180,20))
assert(lens.Color==tailColor,"body painting cannot recolor lights")

assert(VehicleDamage.Apply(vehicle.Body,1000,"Bullet",player)==0 and vehicle.Body:GetAttribute("HP")==nil,"direct damage cannot create HP on the body")
local seatModel=componentModel(vehicle,"DriverSeat")
local seat=seatModel:FindFirstChildOfClass("VehicleSeat")
local door=seatModel.EntryDoor.Value
root.CFrame=door.PrimaryPart.CFrame*CFrame.new(-.5,0,0)
head.CFrame=root.CFrame*CFrame.new(0,.5,0)
physics()
vehicle:SetAttribute("OwnerID",player.UserId+1)
for _,kind in ipairs({"Door","Hood","Trunk"}) do
 local locked=componentModel(vehicle,kind)
 root.CFrame=locked.PrimaryPart.CFrame;head.CFrame=root.CFrame*CFrame.new(0,.5,0);physics()
 remote.Action.OnServerEvent:Fire(player,"Interact",locked);tick(.8)
 assert(not locked:GetAttribute("Open"),"nonowner cannot open "..kind)
end
door:SetAttribute("Open",true)
root.CFrame=seatModel.PrimaryPart.CFrame;head.CFrame=root.CFrame*CFrame.new(0,.5,0);physics()
remote.Action.OnServerEvent:Fire(player,"Interact",seatModel);tick(.8)
assert(not character:GetAttribute("VehicleSeated") and not hp.Sit,"open door does not let nonowner drive")
seat:Sit(hp)
assert(not hp.Sit and not seat:FindFirstChild("SeatWeld"),"native seat entry also rejects nonowner")
vehicle:SetAttribute("OwnerID",nil)
remote.Action.OnServerEvent:Fire(player,"Interact",seatModel);tick(.8)
assert(not character:GetAttribute("VehicleSeated"),"unowned vehicles are not publicly driveable")
door:SetAttribute("Open",false)
vehicle:SetAttribute("OwnerID",player.UserId)
root.CFrame=door.PrimaryPart.CFrame*CFrame.new(-.5,0,0)
head.CFrame=root.CFrame*CFrame.new(0,.5,0);physics()
remote.Input.OnServerEvent:Fire(player,1,1)
for _=1,5 do tick(.1) end
assert(vehicle:GetAttribute("Speed")==0,"nonoccupants cannot drive")
remote.Action.OnServerEvent:Fire(player,"Interact",seatModel);tick(.2)
assert(not hp.Sit,"closed door prevents entry")
remote.Action.OnServerEvent:Fire(player,"Interact",door)
for _=1,8 do tick(.1) end
assert(door:GetAttribute("Open")==true,"door interaction opens the mounted door")
player:SetAttribute("MedicalMode","Doctor")
remote.Action.OnServerEvent:Fire(player,"Interact",seatModel)
for _=1,5 do tick(.1) end
assert(character:GetAttribute("VehicleSeated") and hp.SeatPart==seat and hp.Sit,"open door allows reserved seat entry")
assert(player:GetAttribute("MedicalMode")==nil,"driver entry clears existing doctor selection")
assert(player.ClearedHands and character:GetAttribute("HandsBusy"),"driver hands are free for the steering wheel")
assert(door:GetAttribute("Open")==false,"entry automatically closes the associated door")
assert(seat.SeatWeld.C0.Position.Y<seat.Size.Y/2+root.Size.Y*.2,"lowered seat offset keeps the small rig below the roof")
remote.Action.OnServerEvent:Fire(player,"Honk");tick(.2)
assert(DoorsCalled and DoorsCalled.Player==player and DoorsCalled.Model==vehicle and DoorsCalled.Range==15,"owner driver horn calls server gate detection")
local horn=vehicle.Sounds:FindFirstChild("Horn")
assert(horn and horn.SoundId==VehicleConfig.HornId,"horn template lives in Car/Sounds")
DoorsCalled=nil
remote.Action.OnServerEvent:Fire(player,"Honk");tick(.2)
assert(not DoorsCalled,"horn cooldown prevents spam")
local engineModel=componentModel(vehicle,"Engine")
local batteryModel=componentModel(vehicle,"Battery")
local tankModel=componentModel(vehicle,"FuelTank")
batteryModel:SetAttribute("StartingCurrent",10)
remote.Action.OnServerEvent:Fire(player,"Engine");tick(.2)
assert(not vehicle:GetAttribute("EngineOn"))
batteryModel:SetAttribute("StartingCurrent",75)
batteryModel:SetAttribute("Charge",10)
remote.Action.OnServerEvent:Fire(player,"Engine");tick(.2)
assert(not vehicle:GetAttribute("EngineOn"),"discharged batteries cannot start")
batteryModel:SetAttribute("Charge",14)
remote.Action.OnServerEvent:Fire(player,"Engine")
assert(vehicle:GetAttribute("EngineStarting"),"starter has a visible timed phase")
assert(vehicle.Sounds.EngineStart.SoundId==VehicleConfig.EngineStartId,"default starter is supplied under Sounds")
local engineAudio=engineModel.PrimaryPart:FindFirstChild("EngineAudio")
assert(engineAudio.EngineStart.IsPlaying and engineAudio.EngineStart.SoundId==VehicleConfig.EngineStartId,"spatial starter plays at engine")
for _=1,22 do tick(.1) end
assert(vehicle:GetAttribute("EngineOn"),"charged correctly sized battery starts engine")
assert(vehicle:GetAttribute("Gear")==0,"starts in neutral")
local originalEngineHP=engineModel:GetAttribute("HP")
for _=1,201 do remote.Input.OnServerEvent:Fire(player,1,0);tick(.1) end
originalEngineHP=engineModel:GetAttribute("HP")
for _=1,10 do remote.Input.OnServerEvent:Fire(player,1,0);tick(.1) end
assert(math.abs(engineModel:GetAttribute("HP")-(originalEngineHP-1))<.001,"actual engine loses exactly one percent in one second at high RPM")
remote.Input.OnServerEvent:Fire(player,0,0)
for _=1,30 do tick(.1) end
local cooledHP=engineModel:GetAttribute("HP")
for _=1,10 do tick(.1) end
assert(engineModel:GetAttribute("HP")==cooledHP,"wear stops when RPM drops")
engineModel:SetAttribute("HP",100)

remote.Action.OnServerEvent:Fire(player,"Gear",1);tick(.4)
assert(vehicle:GetAttribute("Gear")==1,"driver selects first gear")
remote.Action.OnServerEvent:Fire(player,"Gear",5);tick(.4)
assert(not vehicle:GetAttribute("EngineOn"),"selecting fifth from rest stalls the actual engine")
remote.Action.OnServerEvent:Fire(player,"Gear",0);tick(.2)
remote.Action.OnServerEvent:Fire(player,"Engine")
for _=1,22 do tick(.1) end
assert(vehicle:GetAttribute("EngineOn"),"stalled engine can restart in neutral")
remote.Action.OnServerEvent:Fire(player,"Gear",1);tick(.4)
assert(engineAudio.EngineLoop.IsPlaying and not engineAudio.EngineStart.IsPlaying,"starter transitions into the engine loop")
assert(engineAudio.EngineLoop.PlaybackSpeed<1,"idle engine pitch reflects low RPM")
local initialFuel=tankModel:GetAttribute("Fuel")
local initialCharge=batteryModel:GetAttribute("Charge")
local initialPosition=vehicle.PrimaryPart.Position
for _=1,60 do remote.Input.OnServerEvent:Fire(player,1,0);tick(.1) end
assert(vehicle:GetAttribute("Speed")>1 and (vehicle.PrimaryPart.Position-initialPosition).Magnitude>1,"authorized throttle moves the assembled car")
assert(tankModel:GetAttribute("Fuel")<initialFuel and batteryModel:GetAttribute("Charge")>initialCharge,"running engine consumes fuel and charges battery")
remote.Action.OnServerEvent:Fire(player,"Cruise");tick(.2)
assert(vehicle:GetAttribute("CruiseOn"),"driver enables cruise at current speed")
local cruiseSpeed=vehicle:GetAttribute("Speed")
for _=1,10 do remote.Input.OnServerEvent:Fire(player,0,0);tick(.1) end
assert(math.abs(vehicle:GetAttribute("Speed")-cruiseSpeed)<.02,"cruise holds speed without gas")
remote.Action.OnServerEvent:Fire(player,"Cruise");tick(.2)
assert(not vehicle:GetAttribute("CruiseOn"),"second press cancels cruise")
remote.Action.OnServerEvent:Fire(player,"Cruise");tick(.2)
remote.Input.OnServerEvent:Fire(player,-1,0);tick(.1)
assert(not vehicle:GetAttribute("CruiseOn") and vehicle:GetAttribute("Speed")<cruiseSpeed,"S cancels cruise and brakes")
for _=1,20 do remote.Input.OnServerEvent:Fire(player,1,0);tick(.1) end

local beforeReverse=engineModel:GetAttribute("HP")
remote.Action.OnServerEvent:Fire(player,"Gear",-1)
assert(engineModel:GetAttribute("HP")<beforeReverse,"reverse engagement at forward speed damages the actual engine")
local afterReverse=engineModel:GetAttribute("HP");tick(.4)
remote.Action.OnServerEvent:Fire(player,"Gear",-1);tick(.2)
assert(engineModel:GetAttribute("HP")==afterReverse,"repeated reverse packets do not multiply damage")
engineModel:SetAttribute("HP",100)
remote.Action.OnServerEvent:Fire(player,"Gear",0);tick(.4)
if not vehicle:GetAttribute("EngineOn") then
 remote.Action.OnServerEvent:Fire(player,"Engine")
 for _=1,22 do tick(.1) end
end
remote.Action.OnServerEvent:Fire(player,"Gear",1);tick(.4)
for _=1,60 do remote.Input.OnServerEvent:Fire(player,1,0);tick(.1) end

remote.Input.OnServerEvent:Fire(player,0/0,math.huge);tick(.1)
for _=1,10 do tick(.1) end
assert(vehicle:GetAttribute("Steering")==vehicle:GetAttribute("Steering"),"invalid network input cannot poison simulation")
remote.Action.OnServerEvent:Fire(player,"Exit");tick(.2)
assert(character:GetAttribute("VehicleSeated"),"cannot jump out of a moving car")
blockMovement=true
remote.Input.OnServerEvent:Fire(player,1,0);tick(.1)
assert(vehicle:GetAttribute("Speed")==0,"solid obstacles stop the swept car")
blockMovement=false
blockExit=true
remote.Action.OnServerEvent:Fire(player,"Exit");tick(.2)
assert(character:GetAttribute("VehicleSeated"),"exit waits for free space")
blockExit=false
-- Native Roblox rigs may weld a torso, rather than HumanoidRootPart, to the seat.
seat.SeatWeld.Part1=head
remote.Action.OnServerEvent:Fire(player,"Exit");tick(.2)
local carSpace=vehicle.PrimaryPart.CFrame:PointToObjectSpace(root.Position)
assert(math.abs(carSpace.X)>1.5,"safe exit position clears the actual two-metre-wide car")
assert(not seat:FindFirstChild("SeatWeld"),"exit removes a native torso SeatWeld")
assert(not root.Anchored and not character:GetAttribute("VehicleExiting"),"exit settles outside before restoring movement")
assert(not character:GetAttribute("VehicleSeated") and not character:GetAttribute("HandsBusy") and not hp.Sit and root.CanCollide,"safe exit restores character movement and collision")
remote.Input.OnServerEvent:Fire(player,1,1);tick(.2)
assert(vehicle:GetAttribute("Speed")==0,"old driver packets have no authority after exit")
local chargeBefore=batteryModel:GetAttribute("Charge")
-- Re-enter through the still-open driver door.
root.CFrame=door.PrimaryPart.CFrame*CFrame.new(-.5,0,0);head.CFrame=root.CFrame*CFrame.new(0,.5,0)
remote.Action.OnServerEvent:Fire(player,"Interact",seatModel)
for _=1,5 do tick(.1) end
assert(character:GetAttribute("VehicleSeated"))
remote.Action.OnServerEvent:Fire(player,"Engine");tick(.2)
assert(not vehicle:GetAttribute("EngineOn"),"ignition toggles engine off")
chargeBefore=batteryModel:GetAttribute("Charge")
remote.Action.OnServerEvent:Fire(player,"Lights");tick(.2)
for _=1,10 do tick(.1) end
assert(batteryModel:GetAttribute("Charge")<chargeBefore,"lights drain battery with engine stopped")
local frontLens
for _,part in ipairs(front:GetDescendants()) do if part:IsA("BasePart") and part.Name~="Mount" then frontLens=part;break end end
assert(frontLens.Material==Enum.Material.Neon and frontLens.VehicleLight.Enabled,"headlight lens and beam illuminate together")
assert(lens.Material==Enum.Material.Neon and lens.VehicleLight.Brightness==.6,"tail running light uses a dim red glow")
remote.Action.OnServerEvent:Fire(player,"Lights");tick(.2)
remote.Input.OnServerEvent:Fire(player,-1,0);tick(.1)
assert(lens.VehicleLight.Enabled and lens.VehicleLight.Brightness==3 and not frontLens.VehicleLight.Enabled,"S activates bright red brake lights even with headlights off")
remote.Input.OnServerEvent:Fire(player,0,0);tick(.2)
assert(not lens.VehicleLight.Enabled and lens.Material~=Enum.Material.Neon,"releasing S stops the brake glow instead of treating coasting as braking")
vehicle:SetAttribute("PaintColor",nil)
assert(vehicle.Body.Chassis.Color~=paint and glass.Color==glassColor,"clearing paint restores original panel colors without changing glass")

local enginePart=engineModel:FindFirstChildWhichIsA("BasePart",true)
VehicleDamage.Hit(enginePart,81,"Bullet",player,{})
assert(engineModel:GetAttribute("HP")<=20 and not vehicle:GetAttribute("EngineOn"),"bullet damage reaches components and disables badly damaged engine")
local hitSet={}
local before=batteryModel:GetAttribute("HP")
local batteryPart=batteryModel:FindFirstChildWhichIsA("BasePart",true)
VehicleDamage.Hit(batteryPart,2,"Bullet",player,hitSet);VehicleDamage.Hit(batteryPart,2,"Bullet",player,hitSet)
assert(batteryModel:GetAttribute("HP")==before-2,"one penetrating bullet cannot damage a component twice")
VehicleDamage.Apply(tankModel,70,"Bullet",player)
assert(tankModel:GetAttribute("Burning"),"tank ignites at30 percent health")
local tankHP=tankModel:GetAttribute("HP");local fuel=tankModel:GetAttribute("Fuel")
for _=1,10 do tick(.1) end
assert(math.abs(tankModel:GetAttribute("HP")-(tankHP-1))<.001,"tank fire burns exactly1 percent per second, including fractional simulation ticks")
assert(tankModel:GetAttribute("Fuel")<fuel,"damaged tank continuously leaks")
VehicleDamage.Apply(tankModel,100,"Explosive",player)
assert(#explosions==1 and vehicle:GetAttribute("Exploded"),"fatal explosive damage detonates a fuelled tank")
VehicleDamage.Apply(tankModel,100,"Explosive",player);tick(.1)
assert(#explosions==1,"tank detonation is idempotent")
character:SetAttribute("Knockout",true);tick(.2)
assert(not seat:FindFirstChild("SeatWeld"),"exit removes a native torso SeatWeld")
assert(not root.Anchored and not character:GetAttribute("VehicleExiting"),"exit settles outside before restoring movement")
assert(not character:GetAttribute("VehicleSeated"),"knockout releases the seat weld")
character:SetAttribute("Knockout",false)
vehicle:Destroy()
assert(not workspace.Vehicles:FindFirstChild("Car_1"),"vehicle destruction cleans the live registry")
local second=assert(Service.Spawn("Car_1"))
physics()
VehicleDamage.Explosion(second.PrimaryPart.Position,{KillRadius=0,BlastRadius=8},player,10)
assert(second.Body:GetAttribute("HP")==nil,"blast cannot add health to the unconfigured body")
local blastedEngine=componentModel(second,"Engine")
assert(blastedEngine:GetAttribute("HP")<blastedEngine:GetAttribute("MaxHP"),"blast damages components with authored MaxHP")
local tank2=componentModel(second,"FuelTank")
VehicleDamage.Apply(tank2,70,"Bullet",player)
for _=1,301 do tick(.1) end
assert(second:GetAttribute("Exploded") and #explosions==2,"burning tank eventually detonates once")
print("PASS: real125-instance assembly, marker axes, optional passenger, safe startup, doors/seating/exit, authorized driving, invalid inputs, collision, charge/fuel, component hits, exact fire rate, explosions and cleanup")
'''
source += "\nlocal Garage=" + module("src/server/Services/GarageService.luau", "local Vehicles=Service")
source += r'''
local garage=create("Model",workspace);garage.Name="Garage (T1)";garage:SetAttribute("TownID",9);garage:SetAttribute("TeamID",2)
local carStation=create("Model",garage);carStation.Name="CarStation"
local marker=create("Model",garage);marker.Name="CarSpawn"
local pad=create("Part",marker);pad.Size=Vector3.new(4.236694,.1,8.200651)
pad.CFrame=CFrame.new(542.118225,-7.450012,-38.550003);pad.PivotOffset=CFrame.Angles(0,math.pi,0);marker.PrimaryPart=pad
Garage.Start()
assert(not pad.CanCollide and not pad.CanQuery and pad.Transparency==1,"CarSpawn remains an invisible nonphysical placement marker")
blockExit=true
assert(not Garage.CanCraft(carStation,"Car_1"),"real garage placement rejects an occupied bay")
blockExit=false
local made,message=Garage.Craft(carStation,"Car_1",player)
assert(made,message)
near(made.PrimaryPart.CFrame.LookVector,pad:GetPivot().LookVector,"garage uses authored CarSpawn correction pivot for facing")
assert(math.abs((made.PrimaryPart.Position.Y-(pad.Position.Y+.05))-built.GroundOffset)<.001,"vehicle wheels sit on the spawn surface rather than its root sinking into the floor")
assert(made:GetAttribute("OwnerID")==player.UserId and made:GetAttribute("TownID")==9,"crafted car belongs to the requesting player and garage town")
marker:Destroy()
assert(not Garage.CanCraft(carStation,"Car_1"),"missing spawn marker prevents crafting")
print("PASS: garage marker, real assembly/spawn, clearance checks, orientation, floor offset and ownership")
'''
source += r'''
local publicCar=assert(Service.Spawn("Car_1"))
publicCar:SetAttribute("OwnerID",player.UserId);tick(.1)
assert(not publicCar:GetAttribute("PublicAccess"),"online owner's car stays private")
Players.PlayerRemoving:Fire(player);player.Parent=nil
tick(599)
assert(publicCar:GetAttribute("OwnerID")==player.UserId and not publicCar:GetAttribute("PublicAccess"),"599 seconds of absence preserves ownership")
player.Parent=Players;Players.PlayerAdded:Fire(player);tick(.1)
tick(2)
assert(publicCar:GetAttribute("OwnerID")==player.UserId,"return cancels absence timer")
Players.PlayerRemoving:Fire(player);player.Parent=nil
tick(599);assert(not publicCar:GetAttribute("PublicAccess"),"new departure starts a fresh timer")
tick(1)
assert(publicCar:GetAttribute("PublicAccess") and publicCar:GetAttribute("OwnerID")==nil,"600 seconds makes car public and releases owner")
player.Parent=Players;Players.PlayerAdded:Fire(player);tick(.1)
assert(publicCar:GetAttribute("PublicAccess"),"old owner returning does not relock a public car")
local publicDoor=componentModel(publicCar,"Door")
root.CFrame=publicDoor.PrimaryPart.CFrame;head.CFrame=root.CFrame*CFrame.new(0,.5,0);physics()
remote.Action.OnServerEvent:Fire(player,"Interact",publicDoor);tick(.8)
assert(publicDoor:GetAttribute("Open"),"public vehicle permits door interaction")
local publicSeat=componentModel(publicCar,"DriverSeat")
publicSeat.EntryDoor.Value:SetAttribute("Open",true)
root.CFrame=publicSeat.PrimaryPart.CFrame;head.CFrame=root.CFrame*CFrame.new(0,.5,0);physics()
remote.Action.OnServerEvent:Fire(player,"Interact",publicSeat);tick(.8)
assert(character:GetAttribute("VehicleDriver") and character:GetAttribute("VehicleSeated"),"public vehicle allows a player without OwnerID to take the driver seat")
publicCar:Destroy();tick(.2)
local road=create("Part",workspace);road.Name="Road";road:SetAttribute("Road",true)
road.CanCollide=false;road.CanQuery=false
workspace.DescendantAdded:Fire(road);tick(.01)
assert(road.CanQuery and road.CanCollide,"new road surfaces support character collision and vehicle probes")
local roads=create("Folder",workspace);roads.Name="Roads"
local asphalt=create("Part",roads);asphalt.CanCollide=false;asphalt.CanQuery=false
workspace.DescendantAdded:Fire(asphalt);tick(.01)
assert(asphalt.CanCollide and asphalt.CanQuery,"road folder descendants gain collision")
local roadMarker=create("Part",roads);roadMarker.Transparency=1;roadMarker.CanCollide=false;roadMarker.CanQuery=false
workspace.DescendantAdded:Fire(roadMarker);tick(.01)
assert(not roadMarker.CanCollide and not roadMarker.CanQuery,"invisible road markers remain nonphysical")
roads:Destroy()
local sample=assert(Assembly.Build(template,details));sample.Config=table.clone(VehicleConfig)
local base=sample.Root.CFrame
local oldRay=workspace.Raycast
local rise=0;local absent=false
function workspace:Raycast(origin,direction,params)
 assert(params.RespectCanCollide==false,"road probes include noncollidable road tiles")
 if absent then return nil end
 local localPoint=base:PointToObjectSpace(origin)
 local height=groundY+((localPoint.X>0 and localPoint.Z<0) and rise or 0)
 local distance=(height-origin.Y)/direction.Y
 if distance<0 or distance>1 then return nil end
 return {Instance=road,Position=origin+direction*distance,Normal=Vector3.yAxis,Distance=math.abs(direction.Y*distance)}
end
local function suspensionFrames(count)
 local last,contacts
 for _=1,count do
  last,_,contacts=Suspension.Update(sample,Suspension.Yaw(sample.Root.CFrame),1/60,{sample.Model})
  sample.Model:PivotTo(last)
 end
 return last,contacts
end
local flat,contacts=suspensionFrames(120)
assert(contacts==4 and math.abs(flat.Position.Y-base.Position.Y)<.001,"all four wheels rest on the road surface rather than the grass beneath")
rise=.2
local bump=suspensionFrames(1)
local offsets={}
for _,record in ipairs(sample.Components) do if record.Kind=="Wheel" then table.insert(offsets,(record.Joint.C0.Position-record.Rest.Position).Magnitude) end end
table.sort(offsets)
assert(offsets[4]-offsets[1]>.1,"individual wheels compress independently at a raised road corner")
local tilted=suspensionFrames(120)
assert(math.abs(sample.Suspension.Pitch)>.005 and math.abs(sample.Suspension.Roll)>.005,"spring-supported body pitches and rolls over a single raised wheel")
assert(math.abs(sample.Suspension.Velocity)<.01,"damper settles without perpetual bouncing")
rise=0
local returned=suspensionFrames(180)
assert(math.abs(returned.Position.Y-flat.Position.Y)<.002 and returned.UpVector.Y>.9999,"suspension smoothly returns to its neutral stance")
absent=true
local fallingY=sample.Root.Position.Y
local falling,noContacts=suspensionFrames(10)
assert(noContacts==0 and falling.Position.Y<fallingY-.05,"car falls under gravity when every wheel loses ground")
local airSpeed=VehicleRules.Drive(10,1000,1,1,true,1,0,.1,VehicleConfig,false,false)
assert(airSpeed<=10,"airborne wheels cannot accelerate the vehicle horizontally")
workspace.Raycast=oldRay
local oldSweep=workspace.Blockcast
road.CFrame=CFrame.new(base.Position.X,groundY+.05,base.Position.Z);road.Size=Vector3.new(20,.1,20);road.CanCollide=true
function workspace:Blockcast(frame,size,direction,params)
 if not table.find(params.FilterDescendantsInstances,road) then
  return {Instance=road,Position=Vector3.new(base.Position.X,groundY+.1,base.Position.Z),Normal=Vector3.zAxis,Distance=.01}
 end
 return {Instance=wall,Position=base.Position,Normal=Vector3.zAxis,Distance=.2}
end
local sweep=Ground.Sweep(base,Vector3.new(2,1,5),Vector3.new(0,0,-1),{},groundY,.5)
assert(sweep and sweep.Instance==wall,"thin road edges are skipped without skipping the solid wall behind them")
workspace.Blockcast=oldSweep
local savedBounds=workspace.GetPartBoundsInBox
local obstacle=create("Part",workspace)
obstacle.CFrame=base;obstacle.Size=Vector3.new(2,3,1)
obstacle.CanCollide=false;obstacle.CanQuery=true
for _,name in ipairs({"Wall","Gate","OtherCarBody"}) do
 obstacle.Name=name
 function workspace:Blockcast(frame,size,direction,params)
  assert(not params.RespectCanCollide,"sweep includes nonphysical scenery and cars")
  return {Instance=obstacle,Position=base.Position,Normal=Vector3.zAxis,Distance=.2}
 end
 assert(Ground.Sweep(base,Vector3.new(2,1,5),Vector3.new(0,0,-10),{},groundY,.5).Instance==obstacle,"fast movement stops at "..name)
 function workspace:GetPartBoundsInBox(frame,size,params)
  assert(not params.RespectCanCollide,"overlap includes nonphysical scenery and cars")
  return {obstacle}
 end
 assert(Ground.Overlap(base,Vector3.new(2,1,5),{},groundY,.5)==obstacle,"initial overlap blocks "..name)
end
obstacle.Transparency=1
assert(not Ground.Overlap(base,Vector3.new(2,1,5),{},groundY,.5),"invisible nonphysical markers do not block movement")
obstacle.Transparency=0
obstacle.CFrame=CFrame.new(base.Position.X,groundY+.05,base.Position.Z)
obstacle.Size=Vector3.new(20,.1,20);obstacle:SetAttribute("Road",true)
assert(not Ground.Overlap(base,Vector3.new(2,1,5),{},groundY,.5),"road contact does not trigger body collision")
obstacle:SetAttribute("Road",nil)
obstacle.CanCollide=true;obstacle.Size=Vector3.new(1,4,1)
assert(Ground.Overlap(base,Vector3.new(2,1,5),{},groundY,.5)==obstacle,"tall support is still a wall")
workspace.Blockcast=oldSweep;workspace.GetPartBoundsInBox=savedBounds
obstacle:Destroy()
sample.Model:Destroy();road:Destroy()
print("PASS: nonphysical road contact, four wheel springs, independent travel, body pitch/roll, damping, rest recovery and loss of support")
'''
with tempfile.TemporaryDirectory() as directory:
    path = Path(directory) / "vehicles.luau"
    path.write_text(source)
    subprocess.run([sys.argv[1] if len(sys.argv) > 1 else "luau", str(path)], check=True)
