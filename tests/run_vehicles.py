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
for gear=2,5 do
 local low=VehicleConfig.GearMinimums[gear]
 local top=VehicleConfig.GearSpeeds[gear]
 assert(math.abs(VehicleRules.RPM(low,1,gear,true,VehicleConfig)-1000)<.001)
 assert(math.abs(VehicleRules.RPM(top,1,gear,true,VehicleConfig)-6000)<.001)
 if gear>=3 then assert(VehicleRules.Stalls(0,gear,VehicleConfig) and not VehicleRules.Stalls(low,gear,VehicleConfig)) end
end
assert(math.abs(VehicleRules.RPM(200/3.6,1,5,true,VehicleConfig)-(1000+5000*100/140))<.001)
assert(VehicleRules.RPM(-15/3.6,1,-1,true,VehicleConfig)==4750)
assert(VehicleRules.RPM(20/3.6,1,1,true,VehicleConfig)==6000)
assert(VehicleRules.ReverseDamage(4.99/3.6,VehicleConfig)==0)
assert(math.abs(VehicleRules.ReverseDamage(5/3.6,VehicleConfig)-.05)<.001)
assert(VehicleRules.ReverseDamage(20/3.6,VehicleConfig)==1 and VehicleRules.ReverseDamage(50/3.6,VehicleConfig)==1)
assert(VehicleRules.ReverseDamage(-20/3.6,VehicleConfig)==0)
assert(VehicleRules.RPM(0,1,0,true,VehicleConfig)==6000)
assert(VehicleRules.WheelSteer(30,1,VehicleConfig)<.11)
local wanted={{1,2,4,4},{1,3,4,4},{1,5,4,4},{1,8,4,4},{1,12,4,4}}
for gear=-1,5 do
 local times=VehicleConfig.GearRPMTimes[math.max(1,gear)]
 for _,fps in ipairs({20,30,60,144}) do
  local rpm=800
  for band=1,#times do
   assert(times[band]==wanted[math.max(1,gear)][band])
   for _=1,times[band]*fps do rpm=VehicleRules.AdvanceRPM(rpm,gear,1/fps,VehicleConfig) end
   assert(math.abs(rpm-VehicleConfig.RPMBands[band+1])<.001,"gear-specific RPM ramp matches every band at every frame rate")
  end
 end
end
local held,heldRPM=VehicleRules.Cruise(30/3.6,2,1,1,VehicleConfig)
assert(math.abs(held-30/3.6)<.001 and heldRPM>1000 and heldRPM<6000)
local damaged=VehicleRules.Cruise(200/3.6,5,.3,1,VehicleConfig)
assert(damaged<=VehicleConfig.MaxSpeed*.3,"cruise respects damage and top speed")
for gear=1,5 do
 local speed,rpm=0,1000
 for _=1,250 do speed,rpm=VehicleRules.Drive(speed,rpm,1,gear,true,1,1,.1,VehicleConfig,false,false) end
 local expectedRPM=gear==5 and (1000+5000*100/140) or 6000
 assert(math.abs(rpm-expectedRPM)<.001,"first reaches the redline; fifth respects the car speed limit")
 assert(math.abs(speed-math.min(VehicleConfig.GearSpeeds[gear],VehicleConfig.MaxSpeed))<.001)
end
assert(math.abs(VehicleRules.SpeedFromRPM(1000,3,VehicleConfig)-20/3.6)<.001)
assert(math.abs(VehicleRules.SpeedFromRPM(6000,3,VehicleConfig)-80/3.6)<.001)
local reverse,reverseRPM=0,1000
for _=1,200 do reverse,reverseRPM=VehicleRules.Drive(reverse,reverseRPM,1,-1,true,1,1,.1,VehicleConfig,false,false) end
assert(math.abs(reverse+15/3.6)<.001 and reverseRPM==4750,"reverse ratio spans twenty km/h but is limited to fifteen")
local creep,rpm=0,1000
for _=1,100 do creep,rpm=VehicleRules.Drive(creep,rpm,0,2,true,1,1,.1,VehicleConfig,false,false) end
assert(math.abs(creep-10/3.6)<.001)
assert(VehicleRules.Steer(.8,0,20,.01,VehicleConfig)==0)
assert(VehicleRules.Steer(0,1,0,.01,VehicleConfig)<.01)
local top=VehicleConfig.GearSpeeds[3]
local braking,rpm,latch=VehicleRules.Drive(top,6000,0,3,true,1,1,.1,VehicleConfig,false,false)
assert(braking<top-VehicleConfig.RollingDeceleration*.1,"released redline activates stronger engine braking")
for _=1,100 do
 braking,rpm,latch=VehicleRules.Drive(braking,rpm,0,3,true,1,1,.01,VehicleConfig,false,latch)
 if not latch then break end
end
assert(rpm<=5000.001 and rpm>=4999.999,"forced braking ends exactly at five thousand RPM")
local damagedBrake=VehicleRules.Drive(2,6000,0,3,true,.2,1,.1,VehicleConfig,false,true)
assert(damagedBrake<=2,"engine braking never accelerates a damaged car")
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
local vehicle=workspace.Vehicles:FindFirstChild("Car_1")
assert(vehicle and vehicle.PrimaryPart.Name=="Chassis","startup assembles Car_1 from ServerStorage at the authored position")
near(vehicle.PrimaryPart.Position,referenceRoot.Position)
local remote=ReplicatedStorage.VehicleRemotes
assert(VehicleDamage.Apply(vehicle.Body,1000,"Bullet",player)==0 and vehicle.Body:GetAttribute("HP")==nil,"direct damage cannot create HP on the body")
local seatModel=componentModel(vehicle,"DriverSeat")
local seat=seatModel:FindFirstChildOfClass("VehicleSeat")
local door=seatModel.EntryDoor.Value
root.CFrame=door.PrimaryPart.CFrame*CFrame.new(-.5,0,0)
head.CFrame=root.CFrame*CFrame.new(0,.5,0)
physics()
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
assert(seat.SeatWeld.C0.Position.Y<.6,"SeatWeld fits the small custom rig rather than the default two-stud offset")
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
for _=1,10 do tick(.1) end
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
with tempfile.TemporaryDirectory() as directory:
    path = Path(directory) / "vehicles.luau"
    path.write_text(source)
    subprocess.run([sys.argv[1] if len(sys.argv) > 1 else "luau", str(path)], check=True)
