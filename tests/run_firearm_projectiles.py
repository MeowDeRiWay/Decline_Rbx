"""Run the real projectile loop on block geometry, including a two-layer wall."""
from pathlib import Path
import re,subprocess,sys,tempfile
root=Path(__file__).resolve().parents[1]
service=(root/'src/server/Services/FirearmProjectiles.luau').read_text().replace('local WorldActivity=require(script.Parent.WorldActivityService)', 'local WorldActivity={Register=function() end,IsDormant=function() return false end,Ensure=function() end,DormantNPCs=function() return {} end,Raycast=function() return nil end}')
service=re.sub(r'local (Rules|Damage|Accuracy|BulletCast|Audio|Items|ExplosionRules|Explosions|Visuals)=require[^\n]+\n','',service)
mock='''
local Visuals={Template=function() return nil end}
local Audio={Describe=function(_,name) return {SoundId="rbxassetid://"..name,Volume=.7,PlaybackSpeed=1,MinDistance=3,MaxDistance=100} end}
local Accuracy={Chance=function() return 90 end,NightMultiplier=function() return 1 end,SightBonus=function() return 0 end,ForWeapon=function() return 25 end}
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
function workspace:FindFirstChild() end
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
 function g:GetAttribute(key) return self.attributes and self.attributes[key] or key=="Material" and kind or nil end
 function g:GetDescendants() return self.children end
 function g:FindFirstChildOfClass() end
 function g:SetAttribute() end
 return g
end
local function part(parent,z,depth)
 local p={Parent=parent,CFrame=CFrame.new(Vector3.new(0,0,z)),Size=Vector3.new(2,3,depth),CanQuery=true,Shape=1,Material={Name="Plastic"}}
 function p:IsA(class) return class=="Part" or class=="BasePart" end
 function p:GetAttribute() return nil end
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
-- A real shot must reach the standing target through nested item parts and KO.
parts={};packets={};dealt=0
local bottle=group(nil);bottle.attributes={Item_ID="CleanWater"};part(bottle,1,.4)
local bag=group(nil);bag.attributes={Item_ID="Backpack1"};part(bag,2,.4)
local unconscious=group(nil);unconscious.attributes={Knockout=true}
function unconscious:FindFirstChildOfClass() return {Health=50,Parent=self} end
part(unconscious,3,.5);part(target,5,.5)
Service.Fire(player,character,Vector3.zero,Vector3.new(0,0,1),definition,"FMJ","AssaultRifle223")
for i=1,60 do heartbeat.fire(1/60) end
assert(math.abs(dealt-clear)<1e-8,"items and KO neither stop nor weaken bullets")
local flesh=0
for _,packet in ipairs(packets) do for _,e in ipairs(packet) do if e.Kind=="Impact" then assert(e.Material=="Flesh");flesh+=1 end end end
assert(flesh==1,"ignored objects emit no hit effects; standing target still hit")
-- Worn item geometry continues to represent a conscious character's hitbox.
local armor=group(nil);armor.Parent=target;armor.attributes={Item_ID="MiliArmor1"}
local armorPart=part(armor,1,.4)
assert(BulletCast.Ignored(armorPart)==nil)
unconscious.attributes.Knockout=false
assert(BulletCast.Ignored(unconscious.children[1])==nil,"revived players are hittable immediately")

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
assert(lastOptions.ArmorIgnoreAbsorption==3 and lastOptions.ArmorIgnoreResistance==.2)
assert(run("Concrete","FMJ")==0 and run("Concrete","AP")==0,"223 cannot penetrate concrete")
definition.Caliber="9mm";definition.Range=200
assert(run("Brick","FMJ")==0 and run("Brick","AP")==0,"9mm cannot penetrate brick even with SMG range")
definition.Caliber="308";definition.Range=450
assert(run("Concrete","FMJ")>0 and run("Concrete","AP")>0,"308 crosses a10cm concrete wall")
assert(lastOptions.ArmorIgnoreAbsorption==6 and lastOptions.ArmorIgnoreResistance==.4)
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
for _,entry in ipairs({{"LSW223",18,22},{"ServiceRifle223",21,25},{"MarksmanRifle223",21,25},{"MarksmanRifle308",30,34},{"AssaultRifle223",19,23},{"Rifle223",23,27}}) do
 definition=Items[entry[1]].Firearm
 highRoll=false;assert(math.abs(run(nil,"FMJ")-entry[2]*clear/25)<1e-6,entry[1].." minimum damage")
 highRoll=true;assert(math.abs(run(nil,"AP")-entry[3]*clear/25)<1e-6,entry[1].." maximum damage")
end
-- Rockets stop at the first wall and never roll a second hit chance.
Damage.RollHit=function() error("rockets must use physical collisions, not impact hit rolls") end
for _,entry in ipairs({{"ScrapKnife",10,15},{"IronKnife",20,25},{"SteelKnife",30,40}}) do
 local w=Items[entry[1]].Weapon;assert(w.DamageMin==entry[2] and w.DamageMax==entry[3])
end
task={spawn=function(fn) fn() end}
local rootPart={Position=Vector3.new(0,0,5)}
function target:FindFirstChild(name) return name=="HumanoidRootPart" and rootPart or nil end
function workspace:GetPartBoundsInRadius() return {parts[#parts],parts[#parts]} end
definition=Items.AT4.Firearm
assert(definition.Skill=="HeavyWeapons" and definition.Magazine==1)
for _,kind in ipairs({false,"Brick"}) do
 parts={};packets={};dealt=0
 if kind then part(group(kind),3,.1) end
 part(target,5,.5)
 Service.Fire(player,character,Vector3.zero,Vector3.new(0,0,1),definition,"FMJ","AT4")
 heartbeat.fire(.1)
 local backblast=false
 for _,batch in ipairs(packets) do for _,event in ipairs(batch) do
  if event.Kind=="Backblast" then backblast=true end
  assert(event.Kind~="Trace" and event.Kind~="Muzzle" and event.Kind~="Explosion","warmup emits exhaust only")
 end end
 assert(backblast,"rear jet starts before rocket leaves")
 for i=1,3 do heartbeat.fire(.1) end
 packets={};heartbeat.fire(.09)
 assert(#packets==0,"no rocket before half-second ignition")
 heartbeat.fire(.01)
 local launched=false
 for _,batch in ipairs(packets) do for _,event in ipairs(batch) do
  if event.Kind=="Trace" and event.Rocket then launched=true;assert(event.Point.Magnitude<1e-5,"no travel during warmup") end
 end end
 assert(launched,"rocket appears at half a second")
 packets={}
 for i=1,200 do heartbeat.fire(1/60) end
 assert(dealt==(kind and 50 or 100),"obstructed core becomes normal reduced damage, unshielded core lethal")
 assert(lastOptions.InstantKill==(not kind),"walls remove instant death even inside lethal radius")
 local explosions=0
 for _,batch in ipairs(packets) do for _,event in ipairs(batch) do if event.Kind=="Explosion" then explosions+=1;assert(event.Sound.SoundId=="rbxassetid://ExplosionSound") end
  if event.Kind=="Trace" and event.Rocket then assert(event.FlightSound.SoundId=="rbxassetid://FlightSound" and event.FlybySound.SoundId=="rbxassetid://FlybySound" and math.abs(event.Velocity.Magnitude-100)<1e-5) end end end
 assert(explosions==1,"one explosion per rocket")
end
rootPart.Position=Vector3.new(0,0,30)
parts={};dealt=0;part(group("Brick"),3,.1);part(target,30,.5)
Service.Fire(player,character,Vector3.zero,Vector3.new(0,0,1),definition,"FMJ","AT4")
for i=1,200 do heartbeat.fire(1/60) end
assert(dealt==0,"outside blast radius is safe")
-- Source is the rocket ammo model, never attributes on the launcher definition.
local originalTemplate=Visuals.Template
local attrs={KillRadius=0,BlastRadius=8}
Visuals.Template=function(id)
 assert(id=="AmmoAT4FMJ","blast attributes must come from projectile ammunition")
 return {GetAttribute=function(_,key) return attrs[key] end}
end
rootPart.Position=Vector3.new(0,0,5);parts={};packets={};dealt=0;part(target,5,.5)
definition.BlastRadius=999
Service.Fire(player,character,Vector3.zero,Vector3.new(0,0,1),definition,"FMJ","AT4")
attrs.BlastRadius=100 -- settings for this airborne rocket must already be frozen
for i=1,200 do heartbeat.fire(1/60) end
assert(math.abs(dealt-96.25)<1e-5 and not lastOptions.InstantKill,"custom nonlethal rocket radius uses linear falloff")
for _,batch in ipairs(packets) do for _,event in ipairs(batch) do
 if event.Kind=="Explosion" then assert(event.Radius==8,"visual explosion uses the same ammo radius") end
end end
Visuals.Template=originalTemplate;definition.BlastRadius=nil
-- Own blast must bypass affiliation immunity only for the actual shooter.
local shooterHP={Health=100,Parent=character}
local shooterRoot={Position=Vector3.zero}
function character:FindFirstChildOfClass() return shooterHP end
function character:FindFirstChild(name) if name=="HumanoidRootPart" then return shooterRoot end end
local originalApply=Damage.Apply
local ownDamage,otherDamage=0,0
Damage.Apply=function(victim,amount,kind,point,attackKind,options)
 if victim==shooterHP then
  assert(options.FriendlyFire==true and options.Attacker==player,"self-blast bypasses same-team/group immunity")
  ownDamage+=amount
 else
  assert(not options.FriendlyFire,"self-blast exception must not enable ally damage")
  otherDamage+=amount
 end
 return amount
end
rootPart.Position=Vector3.new(0,0,5)
for _,case in ipairs({{0,false,100},{-5,true,100*(20-9.7)/15*.5},{-30,false,0}}) do
 parts={};packets={};ownDamage=0;otherDamage=0
 shooterRoot.Position=Vector3.new(0,0,case[1])
 if case[2] then part(group("Brick"),-2,.1) end
 part(target,5,.5)
 Service.Fire(player,character,Vector3.zero,Vector3.new(0,0,1),definition,"FMJ","AT4")
 for i=1,200 do heartbeat.fire(1/60) end
 assert(math.abs(ownDamage-case[3])<1e-5,"own blast respects radius and wall shielding exactly once")
 assert(otherDamage==100,"other victims still use ordinary blast rules")
end
Damage.Apply=originalApply
function character:FindFirstChildOfClass() end
function character:FindFirstChild() end
print("PASS: own rocket splash bypasses self-affiliation only, ignores missing query parts, respects walls and radius")
-- Death-created geometry cannot change wall shielding for later victims.
local originalBounds=workspace.GetPartBoundsInRadius
local originalDamage=Damage.Apply
local second=group(nil);local secondHP={Health=100,Parent=second}
function second:FindFirstChildOfClass() return secondHP end
function second:FindFirstChild() return {Position=Vector3.new(0,0,3)} end
parts={};rootPart.Position=Vector3.new(0,0,2);part(target,2,.5);part(second,3,.5)
function workspace:GetPartBoundsInRadius() return parts end
local orderedHits=0
Damage.Apply=function(_,_,_,_,_,options)
 assert(options.InstantKill,"corpse geometry spawned by first victim must not shield the second")
 orderedHits+=1
 if orderedHits==1 then part(group("Brick"),1,.1) end
 return 100
end
Explosions.Detonate(Vector3.zero,{KillRadius=5,BlastRadius=20},player,character,"Mine",100,{FriendlyFire=true})
assert(orderedHits==2)
Damage.Apply=originalDamage;workspace.GetPartBoundsInRadius=originalBounds
print("PASS: wall shielding is snapshotted before terminal deaths spawn new bodies")
for _,item in pairs(Items) do if item.Armor then assert(typeof(item.Armor.ExplosiveAbsorption)=="number" and typeof(item.Armor.ExplosiveResistance)=="number") end end
parts={};part(target,-5,.5);rootPart.Position=Vector3.new(0,0,-5);dealt=0
Service.Backblast(player,character,Vector3.zero,Vector3.new(0,0,1),definition,"AT4")
assert(dealt==50 and lastOptions.FriendlyFire==true,"backblast deals50 even to a teammate")
rootPart.Position=Vector3.new(5,0,-1);dealt=0
Service.Backblast(player,character,Vector3.zero,Vector3.new(0,0,1),definition,"AT4")
assert(dealt==0,"outside rear cone is safe")
rootPart.Position=Vector3.new(0,0,-11);dealt=0
Service.Backblast(player,character,Vector3.zero,Vector3.new(0,0,1),definition,"AT4")
assert(dealt==0,"outside backblast reach is safe")
rootPart.Position=Vector3.new(0,0,-5);parts={};part(group("Brick"),-2,.1);part(target,-5,.5);dealt=0
Service.Backblast(player,character,Vector3.zero,Vector3.new(0,0,1),definition,"AT4")
assert(dealt==0,"wall blocks backblast")
assert(Items.MiliArmor2.Armor.ExplosiveAbsorption==8 and Items.Exosuit.Armor.ExplosiveResistance==.5)
print("PASS: rear cone50 damage, ally hazard, angular/range bounds and wall shielding")
print("PASS: AT4 first-impact detonation, lethal core, outer falloff/shielding, deduplication and radius")
print("PASS: configured .223 and .308 marksman weapons roll exact new damage endpoints")
print("PASS: real swept projectile loop hits moving targets, thin two-layer wall entrance/exit, FMJ/AP wall parity and caliber gates, metal/unknown stop and exact air range")
'''
explosion=(root/'src/server/Services/ExplosionService.luau').read_text()
explosion=explosion.replace('local WorldActivity=require(script.Parent.WorldActivityService)','local WorldActivity={Ensure=function() end}')
explosion=re.sub(r'local (Shared|Rules|BulletCast|Damage)=.*\n','',explosion)
explosion='local Rules=ExplosionRules\n'+explosion
with tempfile.TemporaryDirectory() as directory:
 path=Path(directory)/'projectiles.luau'
 path.write_text((root/'tests/city_geometry.fixture.luau').read_text()+'\nlocal Items=(function()\n'+(root/'src/shared/ItemConfig.luau').read_text()+'\nend)().Items\nlocal Rules=(function()\n'+(root/'src/shared/FirearmRules.luau').read_text()+'\nend)()\n'+mock+'\nlocal BulletCast=(function()\n'+(root/'src/shared/BulletCast.luau').read_text()+'\nend)()\nlocal ExplosionRules=(function()\n'+(root/'src/shared/ExplosionRules.luau').read_text()+'\nend)()\nlocal Explosions=(function()\n'+explosion+'\nend)()\nlocal Service=(function()\n'+service+'\nend)()\n'+cases)
 subprocess.run([sys.argv[1] if len(sys.argv)>1 else 'luau',str(path)],check=True)
