"""Run the real projectile loop on block geometry, including a two-layer wall."""
from pathlib import Path
import re,subprocess,sys,tempfile
root=Path(__file__).resolve().parents[1]
service=(root/'src/server/Services/FirearmProjectiles.luau').read_text().replace('local WorldActivity=require(script.Parent.WorldActivityService)', 'local WorldActivity={Register=function() end,IsDormant=function() return false end,Ensure=function() end,DormantNPCs=function() return {} end,Raycast=function() return nil end}')
service=re.sub(r'local (Rules|Damage|Accuracy)=require[^\n]+\n','',service)
mock='''
local Accuracy={SightBonus=function() return 0 end,ForWeapon=function() return 25 end}
function vm.__mul(a,b) if type(a)=="number" then a,b=b,a end;return Vector3.new(a.X*b,a.Y*b,a.Z*b) end
local function signal() return {Connect=function(self,fn) self.fire=fn end} end
local heartbeat=signal()
local packets={}
Instance={new=function() return {FireClient=function(_,player,events) local copy={} for _,e in ipairs(events) do table.insert(copy,table.clone(e)) end;table.insert(packets,copy) end} end}
local critChance=0
local criticalMax=2
local sniper=0
local since=0
local cowboy=1
local player={UserId=7,GetAttribute=function(_,key) return key=="Accuracy" and 1 or key=="CriticalChance" and critChance or key=="SniperCriticalBonus" and sniper or key=="StationarySince" and since or key=="CowboyMultiplier" and cowboy or key=="CriticalMax" and criticalMax or key=="CriticalMin" and 1.5 or 0 end,Character={FindFirstChild=function() return {Position=Vector3.zero} end}}
local Players={GetPlayers=function() return {player} end}
game={GetService=function(_,name) return ({Players=Players,RunService={Heartbeat=heartbeat},ReplicatedStorage={}})[name] end}
local highRoll=true
Random={new=function() return {NextNumber=function(_,a,b) return b or 0 end,NextInteger=function(_,a,b) return if highRoll then b else a end} end}
Enum={RaycastFilterType={Exclude=1},PartType={Block=1}}
RaycastParams={new=function() return {} end}
local dealt=0
local lastOptions
local Damage={RollHit=function() return true end,Apply=function(_,amount,_,_,_,options) lastOptions=options;dealt+=amount*(options and options.CriticalMultiplier or 1);return amount end,Miss=function() error("unexpected miss") end}
local parts={}
workspace={}
function workspace:Raycast(origin,delta,params)
 local best,nearest=nil,math.huge
 for _,part in ipairs(parts) do
  local ignored=false
  for _,object in ipairs(params.FilterDescendantsInstances) do if object==part or part:IsDescendantOf(object) then ignored=true end end
  if ignored then continue end
  local a,b=Rules.Interval(origin,delta.Unit,part.CFrame,part.Size)
  if a and b>1e-7 and a<=delta.Magnitude and a<nearest then
   nearest=a;best={Instance=part,Position=origin+delta.Unit*a,Normal=Vector3.new(0,0,-1)}
  end
 end
 return best
end
local function group(kind)
 local g={Parent=workspace,children={}}
 function g:IsA(class) return class=="Model" end
 function g:GetAttribute(key) return key=="Material" and kind or nil end
 function g:GetDescendants() return self.children end
 function g:FindFirstChildOfClass() end
 function g:SetAttribute() end
 return g
end
local function part(parent,z,depth)
 local p={Parent=parent,CFrame=CFrame.new(Vector3.new(0,0,z)),Size=Vector3.new(2,3,depth),CanQuery=true,Shape=1,Material={Name="Plastic"}}
 function p:IsA(class) return class=="Part" or class=="BasePart" end
 function p:GetAttribute() end
 function p:IsDescendantOf(object) local a=self.Parent while a do if a==object then return true end;a=a.Parent end;return false end
 table.insert(parent.children,p);table.insert(parts,p);return p
end
local character=group(nil)
function character:FindFirstChild() end
local target=group(nil)
local hp={Health=100,Parent=target}
function target:FindFirstChildOfClass() return hp end
local definition={Caliber="223",Category="Automatic",Speed=750,Range=350,Damage=25}
'''
cases='''
local function run(kind,ammo)
 parts={};packets={};dealt=0
 if kind then local wall=group(kind);part(wall,3-.025,.05);part(wall,3+.025,.05) end
 part(target,5,.5)
 assert(Service.Fire(player,character,Vector3.zero,Vector3.new(0,0,1),definition,ammo,"AssaultRifle223"))
 for i=1,60 do heartbeat.fire(1/60) end
 return dealt
end
local clear=run(nil,"FMJ");assert(clear>0)
for _,caliber in ipairs({"9mm","223","308"}) do
 definition.Caliber=caliber
 local wood=run("Wood","FMJ")
 local aluminum=run("Aluminum","FMJ")
 assert(aluminum>0 and math.abs(aluminum-wood)<1e-8,"aluminum has wood-level penetration and damage loss for "..caliber)
 assert(math.abs(run("Aluminum","AP")-aluminum)<1e-8,"AP does not change aluminum penetration")
 local impacts=0
 for _,packet in ipairs(packets) do for _,e in ipairs(packet) do if e.Kind=="Impact" and e.Material=="Aluminum" then impacts+=1 end end end
 assert(impacts==2,"aluminum emits one entry and one exit effect")
end
definition.Caliber="223"
local fmj=run("Brick","FMJ");assert(fmj>0 and fmj<clear,"thin wall crossed with damage loss")
local brick=0
for _,packet in ipairs(packets) do for _,e in ipairs(packet) do if e.Kind=="Impact" and e.Material=="Brick" then brick+=1 end end end
assert(brick==2,"two visual layers produce ONE entrance and ONE exit")
local ap=run("Brick","AP");assert(math.abs(ap-fmj)<1e-8,"AP and FMJ lose identical range/damage through walls")
assert(lastOptions.ArmorIgnoreAbsorption==3 and lastOptions.ArmorIgnoreResistance==.15)
assert(run("Concrete","FMJ")==0 and run("Concrete","AP")==0,"223 cannot penetrate concrete")
definition.Caliber="9mm";definition.Range=200
assert(run("Brick","FMJ")==0 and run("Brick","AP")==0,"9mm cannot penetrate brick even with SMG range")
definition.Caliber="308";definition.Range=450
assert(run("Concrete","FMJ")>0 and run("Concrete","AP")>0,"308 crosses a10cm concrete wall")
assert(lastOptions.ArmorIgnoreAbsorption==5 and lastOptions.ArmorIgnoreResistance==.4)
definition.Caliber="223";definition.Range=350
assert(run("Metal","FMJ")==0,"insufficient budget stops projectile before target")
assert(run("Unknown","AP")==0,"unknown material stops safely")
parts={};packets={};definition.Range=10
Service.Fire(player,character,Vector3.zero,Vector3.new(0,0,1),definition,"FMJ","AssaultRifle223")
heartbeat.fire(1/60)
local stopped=false
for _,packet in ipairs(packets) do for _,e in ipairs(packet) do if e.Kind=="Stop" then assert(math.abs(e.Point.Z-10)<1e-6);stopped=true end end end
assert(stopped,"air travel consumes range 1:1")
parts={};packets={};dealt=0;definition.Range=350;definition.Speed=60
local moving=part(target,5,.5)
Service.Fire(player,character,Vector3.zero,Vector3.new(0,0,1),definition,"FMJ","AssaultRifle223")
heartbeat.fire(1/60);assert(dealt==0)
moving.CFrame=CFrame.new(Vector3.new(0,0,2))
heartbeat.fire(1/60);assert(dealt>0,"world raycasts sample moved target during flight")
definition.DamageMin=10;definition.DamageMax=15
highRoll=false;local low=run(nil,"FMJ")
highRoll=true;local high=run(nil,"FMJ")
assert(math.abs(high/low-1.5)<1e-6,"projectiles independently roll configured damage bounds")
definition.DamageMin=nil;definition.DamageMax=nil
critChance=.1
assert(math.abs(run(nil,"FMJ")-clear*2)<1e-6,"player critical multiplier is capped at x2")
criticalMax=2.5
assert(math.abs(run(nil,"FMJ")-clear*2.5)<1e-6,"brutal criticals raise upper roll limit to2.5, not multiply the result")
critChance=0;definition.Category="Rifle";definition.SingleOnly=true;sniper=.1
workspace.GetServerTimeNow=function() return 4 end
since=3;assert(math.abs(run(nil,"FMJ")-clear)<1e-6,"sniper requires two stationary seconds")
since=2;assert(math.abs(run(nil,"FMJ")-clear*2.5)<1e-6,"sniper gives critical bonus on steady bolt-action shot")
definition.BoltAction=false;assert(math.abs(run(nil,"FMJ")-clear)<1e-6,"SR semi-auto excludes bolt-action sniper bonus")
definition.BoltAction=nil;definition.SingleOnly=false;assert(math.abs(run(nil,"FMJ")-clear)<1e-6,"sniper excludes automatic rifles")
definition.Category="Pistol";cowboy=1.15
assert(math.abs(run(nil,"FMJ")-clear*1.15)<1e-6,"cowboy pistol damage")
critChance=0;sniper=0;cowboy=1
for _,entry in ipairs({{"LSW223",18,22},{"ServiceRifle223",21,25},{"AssaultRifle223",19,23},{"Rifle223",23,27}}) do
 definition=Items[entry[1]].Firearm
 highRoll=false;assert(math.abs(run(nil,"FMJ")-entry[2]*clear/25)<1e-6,entry[1].." minimum damage")
 highRoll=true;assert(math.abs(run(nil,"AP")-entry[3]*clear/25)<1e-6,entry[1].." maximum damage")
end
print("PASS: all four configured .223 weapons roll exact new damage endpoints")
print("PASS: real swept projectile loop hits moving targets, thin two-layer wall entrance/exit, FMJ/AP wall parity and caliber gates, metal/unknown stop and exact air range")
'''
with tempfile.TemporaryDirectory() as directory:
 path=Path(directory)/'projectiles.luau'
 path.write_text((root/'tests/city_geometry.fixture.luau').read_text()+'\nlocal Items=(function()\n'+(root/'src/shared/ItemConfig.luau').read_text()+'\nend)().Items\nlocal Rules=(function()\n'+(root/'src/shared/FirearmRules.luau').read_text()+'\nend)()\n'+mock+'\nlocal Service=(function()\n'+service+'\nend)()\n'+cases)
 subprocess.run([sys.argv[1] if len(sys.argv)>1 else 'luau',str(path)],check=True)
