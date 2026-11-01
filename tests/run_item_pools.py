"""Run actual pool authority with nested authored folders, weights and pickup lifecycle."""
from pathlib import Path
import re,subprocess,sys,tempfile
root=Path(__file__).resolve().parents[1]
source=(root/'src/server/Services/ItemPoolService.luau').read_text()
source=re.sub(r'local (Items|Rules|WorldItems|Activity|ActivityRules|ActivityConfig)=require[^\n]+\n','',source)
setup='''
local Activity={Positions=function() return {Vector3.zero} end,IsDormant=function(o) return o:GetAttribute("WorldDormant")==true end}
local ActivityRules={Near=function() return true end};local ActivityConfig={ActiveRadius=140}
workspace.DescendantAdded=event()
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
local function current(id)
 for i=#calls,1,-1 do if calls[i].ID==id then return calls[i].Item end end
end
assert(current("AmmoBox9mmFMJ"):GetAttribute("MaxAmmo")==30)
assert(marker.Transparency==1 and not marker.CanQuery)
local oldFood,oldAmmo=current("Potato"),current("AmmoBox9mmFMJ")
Service.Update();Service.Start();assert(#calls==2)
clock+=9;Service.Update();assert(#calls==2 and not oldFood.destroyed)
clock+=1;Service.Update()
assert(#calls==4 and oldFood.destroyed and oldAmmo.destroyed and #world:GetChildren()==2,"uncollected loot replaced once per cycle")
current("Potato"):Destroy();clock+=5;Service.Update();assert(#calls==4)
foodPoint:SetAttribute("SpawnChance",0)
oldAmmo=current("AmmoBox9mmFMJ");clock+=5;Service.Update()
assert(#calls==5 and oldAmmo.destroyed and #world:GetChildren()==1,"pickup does not restart cycle and failed roll leaves empty point")
foodPoint:SetAttribute("SpawnChance",1);clock+=10;Service.Update()
assert(#calls==7 and #world:GetChildren()==2)
oldFood=current("Potato")
foodPoint:SetAttribute("WorldDormant",true);foodPoint.Parent=ServerStorage
clock+=20;Service.Update();assert(not oldFood.destroyed,"sleep retains point state")
foodPoint:SetAttribute("WorldDormant",nil);foodPoint.Parent=workspace
Service.Update();assert(oldFood.destroyed and #world:GetChildren()==2,"wake rerolls overdue loot once")
foodPoint:SetAttribute("SpawnChance",0);oldFood=current("Potato")
clock+=10;Service.Update();assert(oldFood.destroyed and #world:GetChildren()==1,"failed reroll removes uncollected item")
local later=make("Folder","Later",authored);make("Part","Chemicals",later)
clock+=5;Service.Update();assert(current("Chemicals"),"late templates retry")
foodPoint:Destroy();Service.Update()
oldAmmo=current("AmmoBox9mmFMJ");ammoPoint:SetAttribute("ItemPool",nil);Service.Update();assert(oldAmmo.destroyed)
assert(Rules.Delay(nil)==300 and Rules.Delay(0)==1 and Rules.Delay(0/0)==300)
assert(Rules.Pick({{ID="a",Weight=1},{ID="b",Weight=3}},.5).ID=="b")
print("PASS: fixed reroll schedule, leftover cleanup, empty rolls, pickup timing, dormant wake, one item per point, late templates and marker removal")
'''
parts=[(root/'tests/fixtures/town_mock.luau').read_text()]
parts.append('local Items=(function()\n'+(root/'src/shared/ItemConfig.luau').read_text()+'\nend)().Items')
parts.append('local Rules=(function()\n'+(root/'src/shared/ItemPoolRules.luau').read_text()+'\nend)()')
parts.extend([setup,'local Service=(function()\n'+source+'\nend)()',cases])
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'pool.luau';p.write_text('\n'.join(parts));subprocess.run([sys.argv[1],str(p)],check=True)
