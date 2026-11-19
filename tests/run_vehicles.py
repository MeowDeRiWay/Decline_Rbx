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
assert(VehicleRules.RPM(150/3.6,1,5,true,VehicleConfig)==4750)
assert(VehicleRules.RPM(15/3.6,1,-1,true,VehicleConfig)==VehicleConfig.GentleRPM)
assert(VehicleRules.RPM(20/3.6,1,1,true,VehicleConfig)==VehicleConfig.GentleRPM)
assert(VehicleRules.ReverseDamage(4.99/3.6,VehicleConfig)==0)
assert(math.abs(VehicleRules.ReverseDamage(5/3.6,VehicleConfig)-.05)<.001)
assert(VehicleRules.ReverseDamage(20/3.6,VehicleConfig)==1 and VehicleRules.ReverseDamage(50/3.6,VehicleConfig)==1)
assert(VehicleRules.ReverseDamage(-20/3.6,VehicleConfig)==0)
assert(VehicleRules.RPM(0,1,0,true,VehicleConfig)==6000)
assert(VehicleRules.WheelSteer(30,1,VehicleConfig)<.11)
assert(VehicleRules.Speed(0,1,true,1,1,1,VehicleConfig,0,false)==0)
assert(VehicleRules.Speed(0,1,true,1,1,1,VehicleConfig,-1,false)<0)
assert(VehicleRules.Speed(-3,-1,true,1,1,.1,VehicleConfig,-1,false)>-3)
local creep=0
for _=1,100 do creep=VehicleRules.Speed(creep,0,true,1,1,.1,VehicleConfig,2,false) end
assert(math.abs(creep-10/3.6)<.001,"second gear creeps at ten km/h without throttle")
local fast=0
for _=1,1000 do fast=VehicleRules.Speed(fast,1,true,1,1,.1,VehicleConfig,5,false) end
assert(math.abs(fast-150/3.6)<.001,"fifth gear never exceeds vehicle speed cap")
assert(VehicleRules.AccelerationFactor(2000,VehicleConfig)==1)
assert(VehicleRules.AccelerationFactor(4000,VehicleConfig)<VehicleRules.AccelerationFactor(2000,VehicleConfig))
assert(VehicleRules.AccelerationFactor(5000,VehicleConfig)==.5)
assert(VehicleRules.Steer(.8,0,20,.01,VehicleConfig)==0,"releasing steering instantly centers wheels")
assert(VehicleRules.Steer(0,1,0,.01,VehicleConfig)>0 and VehicleRules.Steer(0,1,0,.01,VehicleConfig)<.01,"turning into a corner remains gradual")
local top=VehicleConfig.GearSpeeds[3]
local braking=VehicleRules.Speed(top,0,true,1,1,.1,VehicleConfig,3,false,true)
local coasting=VehicleRules.Speed(top,0,true,1,1,.1,VehicleConfig,3,false,false)
assert(braking<coasting,"engine braking is stronger than passive coasting")
local target=VehicleRules.BrakeSpeed(3,VehicleConfig)
assert(math.abs(VehicleRules.RPM(target,0,3,true,VehicleConfig)-5000)<.001)
assert(VehicleRules.Speed(target+.01,0,true,1,1,.1,VehicleConfig,3,false,true)==target,"forced braking never overshoots five thousand RPM")
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
source += "\nlocal Service=" + module("src/server/Services/VehicleService.luau", "local Config=VehicleConfig\nlocal Rules=VehicleRules")
source += r'''
Service.Start()
local vehicle=workspace.Vehicles:FindFirstChild("Car_1")
assert(vehicle and vehicle.PrimaryPart.Name=="Chassis","startup assembles Car_1 from ServerStorage at the authored position")
near(vehicle.PrimaryPart.Position,referenceRoot.Position)
local remote=ReplicatedStorage.VehicleRemotes
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
remote.Action.OnServerEvent:Fire(player,"Interact",seatModel)
for _=1,5 do tick(.1) end
assert(character:GetAttribute("VehicleSeated") and hp.SeatPart==seat and hp.Sit,"open door allows reserved seat entry")
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
for _=1,10 do remote.Input.OnServerEvent:Fire(player,1,0);tick(.1) end
assert(math.abs(engineModel:GetAttribute("HP")-(originalEngineHP-1))<.001,"actual engine loses exactly one percent in one second at high RPM")
remote.Input.OnServerEvent:Fire(player,0,0);tick(.1)
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
for _=1,12 do remote.Input.OnServerEvent:Fire(player,1,0);tick(.1) end
assert(vehicle:GetAttribute("Speed")>3 and (vehicle.PrimaryPart.Position-initialPosition).Magnitude>1,"authorized throttle moves the assembled car")
assert(tankModel:GetAttribute("Fuel")<initialFuel and batteryModel:GetAttribute("Charge")>initialCharge,"running engine consumes fuel and charges battery")
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
for _=1,12 do remote.Input.OnServerEvent:Fire(player,1,0);tick(.1) end

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
assert(second.Body:GetAttribute("HP")<second.Body:GetAttribute("MaxHP"),"blast damage reaches live registered components")
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
