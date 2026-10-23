"""Run actual pool authority with nested authored folders, weights and pickup lifecycle."""
from pathlib import Path
import re,subprocess,sys,tempfile
root=Path(__file__).resolve().parents[1]
source=(root/'src/server/Services/ItemPoolService.luau').read_text()
source=re.sub(r'local (Items|Rules|WorldItems)=require[^\n]+\n','',source)
setup='''
local warn=function() end
local world=make("Folder","WorldItems",workspace)
local authored=make("Folder","Items",ServerStorage)
local food=make("Folder","Food",authored)
local potato=make("Model","Potato",food);make("Part","Part",potato)
local components=make("Model","Prop",food);make("Part","Rags",components)
local nested=make("Folder","Rare",food)
local disabled=make("Model","Chemicals",nested,{SpawnWeight=0});make("Part","Part",disabled)
local ammunition=make("Folder","Ammunition",authored)
local loose=make("Model","Ammo9mmFMJ",ammunition);make("Part","Part",loose)
local box=make("Model","AmmoBox9mmFMJ",ammunition,{MaxAmmo=30});make("Part","Part",box)
local calls={}
local WorldItems={SpawnTemplate=function(source,id,position)
 local item=source:Clone();item:SetAttribute("Quantity",1);item:SetAttribute("Item_ID",id);item.Parent=world
 table.insert(calls,{Source=source,ID=id,Item=item});return item
end}
local Random={new=function() return {NextNumber=function() return .5 end} end}
local foodPoint=make("Model","Any marker",workspace,{ItemPool="Food",RespawnSeconds=10})
local marker=make("Part","Surface",foodPoint)
local ammoPoint=make("Model","Ammo point",workspace,{ItemPool="Items/Ammunition",RespawnSeconds=10});make("Part","Surface",ammoPoint)
local missing=make("Part","Missing pool point",workspace,{ItemPool="Later"})
'''
cases='''
Service.Start()
assert(#calls==2 and #world:GetChildren()==2)
assert(calls[1].ID=="Potato" and calls[1].Source==potato,"pool filters unregistered props, model components and zero weights")
assert(calls[2].ID=="AmmoBox9mmFMJ" and calls[2].Item:GetAttribute("Quantity")==1 and calls[2].Item:GetAttribute("MaxAmmo")==30,"one ammo box model, never a loose round")
assert(marker.Transparency==1 and marker.CanCollide==false and marker.CanQuery==false)
Service.Update();Service.Start();assert(#calls==2,"idempotent updates while pickups remain")
calls[1].Item:Destroy();Service.Update();clock+=9;Service.Update();assert(#calls==2)
clock+=1;Service.Update();assert(#calls==3 and calls[3].ID=="Potato","respawn delay begins after pickup")
local later=make("Folder","Later",authored);make("Part","Chemicals",later)
clock+=5;Service.Update();assert(#calls==4 and calls[4].ID=="Chemicals","late supplied pool retries")
foodPoint:Destroy();Service.Update();assert(calls[3].Item.destroyed,"deleting marker removes its remaining pickup")
ammoPoint:SetAttribute("ItemPool",nil);Service.Update();assert(calls[2].Item.destroyed)
local noSpawn=make("Part","No spawn",workspace,{ItemPool="Food",SpawnChance=0,RespawnSeconds=1})
clock+=5;Service.Update();assert(#calls==4,"zero chance respects authored setting")
noSpawn:SetAttribute("SpawnChance",1);clock+=1;Service.Update();assert(#calls==5)
assert(Rules.Pick({{ID="a",Weight=1},{ID="b",Weight=3}},.1).ID=="a")
assert(Rules.Pick({{ID="a",Weight=1},{ID="b",Weight=3}},.5).ID=="b")
assert(Rules.Delay(0)==1 and Rules.Delay(0/0)==300 and Rules.Weight(-1)==0)
print("PASS: nested folder pools, registered model boundaries, weights/chance, one-model ammo boxes, one active item, pickup cooldown, late templates and marker removal")
'''
parts=[(root/'tests/fixtures/town_mock.luau').read_text()]
parts.append('local Items=(function()\n'+(root/'src/shared/ItemConfig.luau').read_text()+'\nend)().Items')
parts.append('local Rules=(function()\n'+(root/'src/shared/ItemPoolRules.luau').read_text()+'\nend)()')
parts.extend([setup,'local Service=(function()\n'+source+'\nend)()',cases])
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'pool.luau';p.write_text('\n'.join(parts));subprocess.run([sys.argv[1],str(p)],check=True)
