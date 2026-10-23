from pathlib import Path
import re,subprocess,sys,tempfile
root=Path(__file__).resolve().parents[1]
service=(root/'src/server/Services/WorldItemService.luau').read_text()
service=re.sub(r'local (ItemConfig|Inventory|Rules|Interaction|EquipmentVisuals|AmmoRules|Stations)\s*=\s*require[^\n]+\n','',service)
mock='''
workspace.DescendantAdded=event()
local world=make("Folder","WorldItems",workspace);world.ChildAdded=event()
local box=make("Model","AmmoBox223FMJ",world,{Caliber="223",AmmoType="FMJ",MaxAmmo=50})
make("Part","Part",box)
local randomCalls=0
local Random={new=function() return {NextNumber=function() randomCalls+=1;return .999 end} end}
local grants={}
function Inventory.Add(_,id,count) grants[id]=(grants[id] or 0)+count;return true end
local EquipmentVisuals={CaptureTemplate=function() end,Template=function() end}
a:LoadCharacterAsync()
'''
cases='''
assert(box:GetAttribute("AmmoCount")==50 and randomCalls==1,"box rolls only once despite repeat registration")
assert(Service.Pickup(a,box) and grants.Ammo223FMJ==50 and box.destroyed,"box unpacks into loose inventory rounds")
assert(not Service.Pickup(b,box) and grants.Ammo223FMJ==50,"same box cannot be collected twice")
local loose=make("Model","Ammo223AP",world,{Item_ID="Ammo223AP",Quantity=7,AmmoCount=50})
assert(Service.Pickup(a,loose) and grants.Ammo223AP==7,"dropped loose stack preserves quantity and never rerolls from its box visual")
print("PASS: box1..MaxAmmo rolls once, pickup grants loose rounds once, dropped-stack exact quantity")
'''
station_source='local Stations=(function()\n'+(root/'src/shared/CraftStations.luau').read_text()+'\nend)()'
parts=[(root/'tests/fixtures/town_mock.luau').read_text(),station_source]
for variable,module in [('ItemConfig','ItemConfig'),('Rules','InventoryRules'),('AmmoRules','FirearmRules')]:
 parts.append(f'local {variable}=(function()\n'+(root/f'src/shared/{module}.luau').read_text()+'\nend)()')
parts += [mock,'local Service=(function()\n'+service+'\nend)()',cases]
with tempfile.TemporaryDirectory() as directory:
 p=Path(directory)/'ammo.luau';p.write_text('\n'.join(parts));subprocess.run([sys.argv[1] if len(sys.argv)>1 else 'luau',str(p)],check=True)
