from pathlib import Path
import re,subprocess,sys,tempfile
root=Path(__file__).resolve().parents[1]
service=(root/'src/server/Services/WorldItemService.luau').read_text().replace('local WorldActivity=require(script.Parent.WorldActivityService)', 'local WorldActivity={Register=function() end,IsDormant=function() return false end,Ensure=function() end,DormantNPCs=function() return {} end,Raycast=function() return nil end}')
service=re.sub(r'local (ItemConfig|Inventory|Rules|Interaction|EquipmentVisuals|AmmoRules|Stations)\s*=\s*require[^\n]+\n','',service)
service=service.replace('require(ReplicatedStorage.Shared.EconomyRules)','MoneyRules').replace('require(script.Parent.EconomyService)','Wallet')
mock='''
workspace.DescendantAdded=event()
local world=make("Folder","WorldItems",workspace);world.ChildAdded=event()
local box=make("Model","AmmoBox223FMJ",world,{Caliber="223",AmmoType="FMJ",MaxAmmo=50})
make("Part","Part",box)
local obsoleteCash=make("Part","bill",world)
local obsoleteTaggedCash=make("Part","CashModel",world,{Item_ID="Money"})
local randomCalls=0
local Random={new=function() return {NextNumber=function() randomCalls+=1;return .999 end} end}
local grants={}
function Inventory.Add(_,id,count) grants[id]=(grants[id] or 0)+count;return true end
local EquipmentVisuals={CaptureTemplate=function() end,Template=function() end}
a:LoadCharacterAsync()
'''
cases='''
assert(obsoleteCash.destroyed and obsoleteTaggedCash.destroyed,"existing world currency models are removed")
assert(box:GetAttribute("AmmoCount")==50 and randomCalls==0,"box uses full capacity without random rolls")
assert(Service.Pickup(a,box) and grants.AmmoPack223FMJ==1 and box.destroyed,"box remains a sealed inventory package")
assert(not Service.Pickup(b,box) and grants.AmmoPack223FMJ==1,"same box cannot be collected twice")
local loose=make("Model","Ammo223AP",world,{Item_ID="Ammo223AP",Quantity=7,AmmoCount=50})
assert(Service.Pickup(a,loose) and grants.Ammo223AP==7,"dropped loose stack preserves quantity and never rerolls from its box visual")
local head=make("Part","Head",a.Character);head.Position=Vector3.new(0,1,0)
local obstacle=make("Part","Table",workspace)
local stone=make("Model","Stone",world,{Item_ID="Stone",Quantity=1})
local rays=0
function workspace:Raycast(origin)
 rays+=1
 if origin.Y<.5 then return {Instance=obstacle} end
 return {Instance=stone}
end
assert(Service.Pickup(a,stone) and rays==2 and grants.Stone==1,"head ray reaches table loot when body ray hits the tabletop")
local shelfLoot=make("Model","Stone",world,{Item_ID="Stone",Quantity=1})
shelfLoot.CFrame=CFrame.new(Vector3.new(1,1,0));shelfLoot.Size=Vector3.new(.2,.2,.2)
function workspace:Raycast(origin,delta)
 local destination=origin+delta
 if destination.Y>1.05 then return {Instance=shelfLoot} end
 return {Instance=obstacle}
end
assert(Service.Pickup(a,shelfLoot) and grants.Stone==2,"visible top can be reached when shelf blocks nearest edge and center")
local centered=make("Model","Stone",world,{Item_ID="Stone",Quantity=1})
centered.CFrame=CFrame.new(Vector3.new(1,1,0))
function workspace:Raycast(origin,delta)
 if (origin+delta).X>.5 then return {Instance=centered} end
 return {Instance=obstacle}
end
assert(Service.Pickup(a,centered) and grants.Stone==3,"exposed center can be reached without ignoring shelf geometry")
local blocked=make("Model","Stone",world,{Item_ID="Stone",Quantity=1})
function workspace:Raycast() return {Instance=obstacle} end
assert(not Service.Pickup(a,blocked) and not blocked.destroyed and grants.Stone==3,"solid wall blocks all item points without granting loot")
obstacle:SetAttribute("Furniture",true)
local furnitureLoot=make("Model","Stone",world,{Item_ID="Stone",Quantity=1})
local wall=make("Part","Wall",workspace)
local wallBehind=false
function workspace:Raycast(_,_,params)
 if not table.find(params.FilterDescendantsInstances,obstacle) then return {Instance=obstacle} end
 return {Instance=wallBehind and wall or furnitureLoot}
end
wallBehind=true
assert(not Service.Pickup(a,furnitureLoot) and grants.Stone==3,"wall behind ignored furniture still blocks pickup")
wallBehind=false
assert(Service.Pickup(a,furnitureLoot) and grants.Stone==4,"tagged furniture does not block pickup")
local furnitureFolder=make("Folder","Furniture",workspace)
local shelf=make("Model","Shelf",furnitureFolder);local shelfPart=make("Part","Part",shelf)
local folderLoot=make("Model","Stone",world,{Item_ID="Stone",Quantity=1})
function workspace:Raycast(_,_,params)
 if not table.find(params.FilterDescendantsInstances,furnitureFolder) then return {Instance=shelfPart} end
 return {Instance=folderLoot}
end
assert(Service.Pickup(a,folderLoot) and grants.Stone==5,"furniture folders ignore nested shelf parts")
local nearest=Interaction.NearestPoint
Interaction.NearestPoint=function() return Vector3.new(3,0,0) end
function workspace:Raycast() error("out-of-range pickup must not raycast") end
assert(not Service.Pickup(a,blocked),"head fallback cannot extend the two-stud reach limit")
Interaction.NearestPoint=nearest
function workspace:Raycast() return nil end
local beforeMoney=Wallet.Balance(a)
for _,id in ipairs({"Money","Bill","bill"}) do
 assert(not ItemConfig.Items[id] and ItemConfig.RetiredItems[id],"physical currency is retired")
 local retired=make("Part",id,world,{Item_ID=id,Quantity=1,BanknoteValue=50})
 assert(not Service.Pickup(a,retired) and not grants[id] and Wallet.Balance(a)==beforeMoney,"retired cash cannot grant money or enter pockets")
end
print("PASS: physical banknotes removed; account money cannot be picked up")
print("PASS: full-capacity box without RNG, pickup grants sealed package once, dropped-stack exact quantity")
print("PASS: tabletop head ray, upper shelf item top/center, solid-wall rejection, root-based reach limit")
'''
station_source='local Stations=(function()\n'+(root/'src/shared/CraftStations.luau').read_text()+'\nend)()'
parts=[(root/'tests/fixtures/town_mock.luau').read_text(),station_source]
for variable,module in [('ItemConfig','ItemConfig'),('Rules','InventoryRules'),('AmmoRules','FirearmRules')]:
 parts.append(f'local {variable}=(function()\n'+(root/f'src/shared/{module}.luau').read_text()+'\nend)()')
parts += ['local MoneyRules=(function()\n'+(root/'src/shared/EconomyRules.luau').read_text()+'\nend)()', (root/'tests/fixtures/money_store_engine.luau').read_text(), 'local WalletStore=(function()\n'+(root/'src/server/Services/MoneyStore.luau').read_text().replace('local R=require(game:GetService("ReplicatedStorage").Shared.EconomyRules)','local R=MoneyRules')+'\nend)()', 'local Wallet=(function()\n'+re.sub(r'local R=require[^\n]+\n','local R=MoneyRules\n',(root/'src/server/Services/EconomyService.luau').read_text()).replace('local Store=require(script.Parent.MoneyStore)','local Store=WalletStore')+'\nend)();Wallet.Start()',mock,'local Service=(function()\n'+service+'\nend)()',cases]
with tempfile.TemporaryDirectory() as directory:
 p=Path(directory)/'ammo.luau';p.write_text('\n'.join(parts));subprocess.run([sys.argv[1] if len(sys.argv)>1 else 'luau',str(p)],check=True)
