"""Exercise actual firearm authority with an inventory and timer mock."""
from pathlib import Path
import subprocess,sys,tempfile,re
root=Path(__file__).resolve().parents[1]
service=(root/'src/server/Firearms.server.luau').read_text()
service=re.sub(r'local (Inventory|Projectiles|Items|Rules|Audio)=require[^\n]+\n','',service)
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
local character={attributes={HandsItem="Rifle223",WeaponCondition=3000}}
function character:GetAttribute(k) return self.attributes[k] end
function character:SetAttribute(k,v) self.attributes[k]=v end
local hp={Health=100}
local root={Position=Vector3.new(0,0,0)}
local muzzle={GetPivot=function() return CFrame.new(Vector3.new(0,.8,-.5)) end,IsA=function(_,kind) return kind=="Model" end}
local held={FindFirstChild=function() return muzzle end}
function character:FindFirstChild(name) return name=="HeldItem" and held or root end
function character:FindFirstChildOfClass() return hp end
local player={Character=character,attributes={}}
function player:GetAttribute(key) return self.attributes[key] end
local wearRoll=1
local Random={new=function() return {NextNumber=function() return wearRoll end} end}
local rounds={Ammo223FMJ=50,Ammo223AP=3}
local shots,uses=0,0
local played,stopped={},0
local Audio={Play=function(_,name) table.insert(played,name);return {} end,Stop=function(sound) if sound then stopped+=1 end end}
local Inventory={Changed=changed,Snapshot=function() return {Items=table.clone(rounds)} end,GetWeapon=function() return true end}
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
local rays={}
local wall=false
workspace={Raycast=function(_,origin,delta)
 table.insert(rays,{Origin=origin,Delta=delta})
 if wall and delta.Z<0 then return {} end
end}
local baseTypeof=typeof
typeof=function(v) if type(v)=="table" and v.X then return "Vector3" end;return baseTypeof(v) end
'''
cases='''
local fire=action.OnServerEvent.callback
local direction=Vector3.new(0,0,-1)
fire(player,"Fire",direction);assert(shots==0,"empty gun cannot fire")
fire(player,"Reload");assert(character:GetAttribute("Reloading"))
fire(player,"Fire",direction);assert(shots==0,"cannot fire while reloading")
advance(2.5);assert(character:GetAttribute("MagazineAmmo")==30 and rounds.Ammo223FMJ==50,"reload allocates existing rounds without creating/losing stock")
fire(player,"Fire",direction);assert(shots==1 and rounds.Ammo223FMJ==49 and character:GetAttribute("MagazineAmmo")==29 and uses==1)
assert(#rays==2 and rays[2].Origin.Y==.8 and rays[2].Delta.Y==0,"muzzle guard crosses window at raised gun height, not diagonally from waist")

fire(player,"Fire",direction);assert(shots==1,"rate limit")
advance(.1);wall=true;fire(player,"Fire",direction)
assert(shots==1 and rounds.Ammo223FMJ==49,"solid wall still blocks muzzle and consumes no ammo")
wall=false
advance(.1);fire(player,"Fire",Vector3.new(0,0,-100));assert(shots==1,"reject invalid direction")
fire(player,"Type");assert(character:GetAttribute("AmmoType")=="AP" and character:GetAttribute("MagazineAmmo")==0 and rounds.Ammo223FMJ==49)
fire(player,"Reload");advance(2.5);assert(character:GetAttribute("MagazineAmmo")==3)
fire(player,"Fire",direction);assert(rounds.Ammo223AP==2 and shots==2)
rounds.Ammo223AP=0;changed.callback(player);advance(.1);fire(player,"Fire",direction);assert(shots==2,"dropping/transferring stock cannot duplicate loaded rounds")
rounds.Ammo223AP=3;fire(player,"Reload")
character:SetAttribute("HandsItem","");changed.callback(player)
character:SetAttribute("HandsItem","Rifle223");changed.callback(player);advance(2.5)
assert(character:GetAttribute("MagazineAmmo")==0 and not character:GetAttribute("Reloading"),"weapon switch cancels delayed reload")
fire(player,"Type");fire(player,"Reload");advance(2.5)
player.attributes.PreserveDurabilityChance=.9;wearRoll=.1
local previous=uses
fire(player,"Fire",direction)
assert(uses==previous and rounds.Ammo223AP==2,"Careful preserves durability, not the cartridge")
advance(.1);wearRoll=.95;fire(player,"Fire",direction)
assert(uses==previous+1 and rounds.Ammo223AP==1,"failed preservation still wears weapon")
assert(table.find(played,"ShotSound") and table.find(played,"ReloadSound") and stopped>=3,"shot/reload start and completion/cancellation stop audio")
print("PASS: empty/reloading/rate/invalid direction guards, partial reload, exact ammo and condition consumption, AP switch, drop conservation and switch cancellation")
'''
parts=[(root/'tests/city_geometry.fixture.luau').read_text(),
 'local Items=(function()\n'+(root/'src/shared/ItemConfig.luau').read_text()+'\nend)().Items',
 'local Rules=(function()\n'+(root/'src/shared/FirearmRules.luau').read_text()+'\nend)()',mock,service,cases]
with tempfile.TemporaryDirectory() as directory:
 p=Path(directory)/'service.luau';p.write_text('\n'.join(parts));subprocess.run([sys.argv[1] if len(sys.argv)>1 else 'luau',str(p)],check=True)
