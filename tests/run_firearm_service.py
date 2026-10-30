"""Exercise actual firearm authority with an inventory and timer mock."""
from pathlib import Path
import subprocess,sys,tempfile,re
root=Path(__file__).resolve().parents[1]
service=(root/'src/server/Firearms.server.luau').read_text()
service=re.sub(r'local (Inventory|Projectiles|Items|Rules|Audio|Journal|Progression|Noise|Config|BulletCast)=require[^\n]+\n','',service)
mock='''
local function signal() return {Connect=function(self,fn) self.callback=fn end} end
local changed=signal()
local time=0
os={clock=function() return time end}
local tasks={}
task={delay=function(seconds,fn) table.insert(tasks,{At=time+seconds,Run=fn}) end}
local function advance(seconds)
 time+=seconds
 for index=#tasks,1,-1 do if tasks[index].At<=time then local fn=tasks[index].Run;table.remove(tasks,index);fn() end end
end
local character={attributes={HandsItem="AssaultRifle223",WeaponCondition=3000}}
function character:GetAttribute(k) return self.attributes[k] end
function character:SetAttribute(k,v) self.attributes[k]=v end
local Config={ShotMovementLockSeconds=.2}
local hp={Health=100,WalkSpeed=8,Move=function(self) self.Stopped=true end}
local root={Position=Vector3.new(0,0,0)}
local muzzle={GetPivot=function() return CFrame.new(Vector3.new(0,.8,-.5)) end,IsA=function(_,kind) return kind=="Model" end}
local held={FindFirstChild=function() return muzzle end}
function character:FindFirstChild(name) return name=="HeldItem" and held or root end
function character:FindFirstChildOfClass() return hp end
local player={Character=character,attributes={AttributesConfirmed=true}}
function player:GetAttribute(key) return self.attributes[key] end
local Progression={Meets=function(p,req) return (p:GetAttribute("Strength") or 10)>=(req.Attributes and req.Attributes.Strength or 0) end}
local wearRoll=1
local Random={new=function() return {NextNumber=function() return wearRoll end} end}
local rounds={Ammo223FMJ=50,Ammo223AP=3}
local notices={}
local Journal={Send=function(_,message) table.insert(notices,message) end}
local magazine={UID=1,Type="FMJ",Loaded=0,Mode="Auto"}
local noises=0
local noiseRadius
local Noise={Emit=function(_,radius) noises+=1;noiseRadius=radius end}
local shots,uses=0,0
local played,stopped={},0
local Audio={Play=function(_,name) table.insert(played,name);return {} end,Stop=function(sound) if sound then stopped+=1 end end}
local Inventory={Changed=changed,Snapshot=function() return {Items=table.clone(rounds)} end,GetWeapon=function() return true end}
function Inventory.GetMagazine() return magazine end
function Inventory.SaveMagazine(_,loaded,kind,mode,ready)
 magazine.Loaded=loaded;magazine.Type=kind;magazine.Mode=mode;magazine.ReadyAt=ready or magazine.ReadyAt
 changed.callback(player)
end
function Inventory.ReloadMagazine()
 local id="Ammo"..Items[character:GetAttribute("HandsItem")].Firearm.Caliber..magazine.Type
 local count=math.min(Items[character:GetAttribute("HandsItem")].Firearm.Magazine-magazine.Loaded,rounds[id] or 0)
 rounds[id]-=count;magazine.Loaded+=count;changed.callback(player)
end
function Inventory.UnloadMagazine(_,kind)
 rounds["Ammo223"..magazine.Type]+=magazine.Loaded;magazine.Loaded=0;magazine.Type=kind;changed.callback(player)
end
function Inventory.Remove(_,id,count) assert(rounds[id]>=count);rounds[id]-=count;changed.callback(player);return true end
function Inventory.UseWeapon() uses+=1;changed.callback(player);return true end
local Projectiles={Fire=function() shots+=1;return true end}
local action
Instance={new=function() action={OnServerEvent=signal()};return action end}
local Players={PlayerRemoving=signal()}
local ReplicatedStorage={}
game={GetService=function(_,name) return name=="Players" and Players or ReplicatedStorage end}
Enum={RaycastFilterType={Exclude=1}}
RaycastParams={new=function() return {} end}
local BulletCast={Raycast=function(origin,delta) return workspace:Raycast(origin,delta) end}
local rays={}
local wall=false
workspace={GetServerTimeNow=function() return time end,Raycast=function(_,origin,delta)
 table.insert(rays,{Origin=origin,Delta=delta})
 if wall and delta.Z<0 then return {} end
end}
local baseTypeof=typeof
typeof=function(v) if type(v)=="table" and v.X then return "Vector3" end;return baseTypeof(v) end
'''
cases='''
local fire=action.OnServerEvent.callback
local direction=Vector3.new(0,0,-1)
fire(player,"Fire",direction);assert(shots==0)
assert(character:GetAttribute("ShotMovementUntil")==nil,"empty input cannot stop walking")
fire(player,"Mode");assert(character:GetAttribute("FireMode")=="Single")
fire(player,"Mode");assert(character:GetAttribute("FireMode")=="Single")
advance(.3);fire(player,"Mode");assert(character:GetAttribute("FireMode")=="Auto")
fire(player,"Reload");fire(player,"Fire",direction);assert(shots==0)
advance(2.5);assert(magazine.Loaded==24 and rounds.Ammo223FMJ==26,"reload moves loose cartridges into weapon")
fire(player,"Fire",direction);assert(shots==1 and magazine.Loaded==23 and rounds.Ammo223FMJ==26 and uses==1)
assert(hp.WalkSpeed==0 and hp.Stopped and character:GetAttribute("ShotMovementUntil")==time+.2,"accepted shot stops walking with shared-clock deadline")
local shotDeadline=character:GetAttribute("ShotMovementUntil")
assert(#rays==2 and rays[2].Origin.Y==.8 and rays[2].Delta.Y==0)
fire(player,"Fire",direction);assert(shots==1 and noises==1,"RPM limit emits no noise")
advance(.1);wall=true;fire(player,"Fire",direction);assert(shots==1 and magazine.Loaded==23,"wall guards consume nothing")
assert(character:GetAttribute("ShotMovementUntil")==shotDeadline,"blocked shot cannot extend pause")
wall=false;advance(.1);fire(player,"Fire",Vector3.new(0,0,-100));assert(shots==1)
fire(player,"Type");assert(magazine.Type=="AP" and magazine.Loaded==0 and rounds.Ammo223FMJ==49,"type switch returns previous rounds")
fire(player,"Reload");advance(2.5);assert(magazine.Loaded==3 and rounds.Ammo223AP==0)
fire(player,"Fire",direction);assert(magazine.Loaded==2 and shots==2)
rounds.Ammo223AP=0;changed.callback(player)
assert(character:GetAttribute("MagazineAmmo")==2,"dropping loose stock cannot erase loaded rounds")
character:SetAttribute("HandsItem","");changed.callback(player)
character:SetAttribute("HandsItem","AssaultRifle223");changed.callback(player)
assert(character:GetAttribute("MagazineAmmo")==2 and character:GetAttribute("AmmoType")=="AP","holster restores charge/type")
fire(player,"Fire",direction);assert(shots==2,"holster cannot bypass cooldown")
rounds.Ammo223AP=3;fire(player,"Reload")
character:SetAttribute("HandsItem","");changed.callback(player)
character:SetAttribute("HandsItem","AssaultRifle223");changed.callback(player);advance(2.5)
assert(magazine.Loaded==2 and rounds.Ammo223AP==3 and not character:GetAttribute("Reloading"),"switch cancels pending reload without losing charge")
local original=magazine
magazine={UID=2,Type="FMJ",Loaded=0,Mode="Auto"};changed.callback(player)
assert(character:GetAttribute("MagazineAmmo")==0,"same-ID different weapon has independent magazine")
magazine=original;changed.callback(player)
assert(character:GetAttribute("MagazineAmmo")==2)
local previous=uses;player.attributes.PreserveDurabilityChance=.9;wearRoll=.1
fire(player,"Fire",direction);assert(uses==previous and magazine.Loaded==1)
advance(.1);wearRoll=.95;fire(player,"Fire",direction);assert(uses==previous+1 and magazine.Loaded==0)
advance(3);rounds.Ammo223AP=0;changed.callback(player)
fire(player,"Reload");assert(magazine.Type=="FMJ" and character:GetAttribute("Reloading"),"R automatically selects available alternative")
advance(2.5);assert(magazine.Loaded==24 and rounds.Ammo223FMJ==25 and #notices==0)
fire(player,"Type");rounds.Ammo223AP=4
fire(player,"Reload");advance(2.5)
assert(magazine.Type=="AP" and magazine.Loaded==4,"prefer selected type when both types are available")
fire(player,"Reload");advance(2.5)
assert(magazine.Type=="FMJ" and magazine.Loaded==24 and rounds.Ammo223AP==4,"partial magazine switches safely, returns old cartridges")
Inventory.UnloadMagazine(player,"AP");rounds.Ammo223FMJ=0;rounds.Ammo223AP=0
fire(player,"Reload");fire(player,"Reload");assert(#notices==1,"empty notification only when no type is available, throttled")
assert(table.find(played,"ShotSound") and table.find(played,"ReloadSound") and stopped>=3)
character:SetAttribute("HandsItem","Rifle223");magazine={UID=99,Type="FMJ",Loaded=5,Mode="Auto"}
changed.callback(player);assert(character:GetAttribute("FireMode")=="Single","bolt action normalizes old auto state")
fire(player,"Mode");assert(character:GetAttribute("FireMode")=="Single","V cannot enable automatic mode")
local before=magazine.Loaded
player.attributes.AttributesConfirmed=false;fire(player,"Fire",direction);assert(magazine.Loaded==before,"creation cannot shoot")
player.attributes.AttributesConfirmed=true
fire(player,"Fire",direction);assert(magazine.Loaded==before-1)
advance(.1);fire(player,"Fire",direction);assert(magazine.Loaded==before-1,"bolt cycle blocks rapid fire")
advance(1.4);fire(player,"Fire",direction);assert(magazine.Loaded==before-2)
assert(noiseRadius==80,".223 shot noise is80studs even without an audio asset")
advance(3);character:SetAttribute("HandsItem","ServiceRifle223");magazine={UID=100,Type="FMJ",Loaded=0,Mode="Auto"};rounds.Ammo223FMJ=100
changed.callback(player);assert(character:GetAttribute("FireMode")=="Single")
fire(player,"Mode");assert(character:GetAttribute("FireMode")=="Single")
fire(player,"Reload");advance(2.5);assert(magazine.Loaded==20 and rounds.Ammo223FMJ==80,"SR20-round reload")
fire(player,"Fire",direction);assert(magazine.Loaded==19)
advance(.1);fire(player,"Fire",direction);assert(magazine.Loaded==19)
advance(.11);fire(player,"Fire",direction);assert(magazine.Loaded==18,"SR semi-auto300RPM")
advance(3);character:SetAttribute("HandsItem","LSW223");magazine={UID=101,Type="FMJ",Loaded=0,Mode="Auto"};changed.callback(player)
fire(player,"Reload");advance(2.5);assert(magazine.Loaded==30,"LSW30-round reload")
fire(player,"Fire",direction);assert(magazine.Loaded==29)
advance(.08);fire(player,"Fire",direction);assert(magazine.Loaded==29)
advance(.007);fire(player,"Fire",direction);assert(magazine.Loaded==28,"LSW700RPM")
for index,id in ipairs({"PipePistol9mm","PipeRifle9mm"}) do
 advance(5);character:SetAttribute("HandsItem",id);magazine={UID=200+index,Type="FMJ",Loaded=0,Mode="Auto"};rounds.Ammo9mmFMJ=10
 changed.callback(player)
 local gun=Items[id].Firearm
 assert(gun.Magazine==1 and gun.SingleOnly and gun.ManualReload and gun.Skill=="LightWeapons")
 fire(player,"Mode");assert(character:GetAttribute("FireMode")=="Single")
 fire(player,"Reload");advance(gun.ReloadTime-.1);assert(magazine.Loaded==0)
 advance(.11);assert(magazine.Loaded==1 and rounds.Ammo9mmFMJ==9)
 fire(player,"Fire",direction);assert(magazine.Loaded==0)
 advance(5);fire(player,"Fire",direction);assert(magazine.Loaded==0 and rounds.Ammo9mmFMJ==9,"empty gun cannot fire or reload itself")
 fire(player,"Reload");advance(gun.ReloadTime+.1);assert(magazine.Loaded==1 and rounds.Ammo9mmFMJ==8)
end
local before=magazine.Loaded
character:SetAttribute("InteractionLocked",true);fire(player,"Fire",direction)
assert(magazine.Loaded==before,"loot/recovery blocks server shots, regardless of client UI")
character:SetAttribute("InteractionLocked",nil);fire(player,"Fire",direction)
assert(magazine.Loaded==before-1,"shots resume after recovery completes")
for index,entry in ipairs({{"Pistol9mm",3},{"PipePistol9mm",3},{"PipeRifle9mm",4},{"Rifle223",4},{"AssaultRifle223",5},{"LSW223",6}}) do
 advance(10);local id,minimum=entry[1],entry[2]
 character:SetAttribute("HandsItem",id);magazine={UID=500+index,Type="FMJ",Loaded=1,Mode="Auto"}
 player.attributes.Strength=minimum-1;changed.callback(player)
 local beforeShots=shots;fire(player,"Fire",direction)
 assert(shots==beforeShots and magazine.Loaded==1,"server firing rejects insufficient Strength: "..id)
 player.attributes.Strength=minimum;fire(player,"Fire",direction)
 assert(shots==beforeShots+1 and magazine.Loaded==0,"server firing accepts exact Strength: "..id)
end
player.attributes.Strength=10
print("PASS: both pipe guns load exactly one 9mm round and require reload between shots")
print("PASS: SR20 semi-auto and LSW30/700RPM reload, mode and fire timing")
print("PASS: persistent per-weapon charge, independent identical guns, loose/loaded conservation, holster cooldown, reload cancellation, RPM/wall/direction guards, mode, sound, durability and empty notice")
'''
parts=[(root/'tests/city_geometry.fixture.luau').read_text(),
 'local Items=(function()\n'+(root/'src/shared/ItemConfig.luau').read_text()+'\nend)().Items',
 'local Rules=(function()\n'+(root/'src/shared/FirearmRules.luau').read_text()+'\nend)()',mock,service,cases]
with tempfile.TemporaryDirectory() as directory:
 p=Path(directory)/'service.luau';p.write_text('\n'.join(parts));subprocess.run([sys.argv[1] if len(sys.argv)>1 else 'luau',str(p)],check=True)
