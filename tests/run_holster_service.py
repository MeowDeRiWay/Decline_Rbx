"""Exercise authoritative inventory restoration, transfers, resets and one-time break notice."""
from pathlib import Path
import re,subprocess,sys,tempfile
root=Path(__file__).resolve().parents[1]
service=(root/'src/server/Services/InventoryService.luau').read_text()
service=re.sub(r'local (ItemConfig|Rules|CombatRules|Visuals|Journal)\s*=\s*require[^\n]+\n','',service)
setup='''
local Journal=journalPlaceholder
local notices=ReplicatedStorage:FindFirstChild("PersonalNotice").sent
local Visuals={Apply=function() end,Validate=function() return true end}
local baseNew=Instance.new
function Instance.new(kind)
 local value=baseNew(kind)
 if kind=="BindableEvent" then value.Event=event();value.Fire=function(self,...) self.Event:Fire(...) end end
 return value
end
'''
setup=setup.replace('journalPlaceholder','(function()\n'+(root/'src/server/Services/JournalService.luau').read_text()+'\nend)()')
cases='''
a:LoadCharacterAsync();Service.Reset(a)
assert(Service.Add(a,"AssaultRifle223",1,{17}))
assert(Service.Equip(a,"AssaultRifle223"))
assert(Service.ToggleHolster(a) and Service.Snapshot(a).Equipment.Hands==nil)
assert(Service.Snapshot(a).Items.AssaultRifle223==1)
assert(Service.ToggleHolster(a) and Service.Snapshot(a).Equipment.Hands=="AssaultRifle223")
assert(a.Character:GetAttribute("WeaponCondition")==17,"condition preserved")
assert(Service.ToggleHolster(a));assert(Service.Remove(a,"AssaultRifle223",1))
assert(Service.Add(a,"AssaultRifle223",1,{99}))
assert(not Service.ToggleHolster(a),"dropping original invalidates memory, new same-ID weapon cannot restore it")
assert(Service.Equip(a,"AssaultRifle223"));assert(Service.ToggleHolster(a))
local storage=Rules.New()
assert(Service.Transfer(a,storage,"AssaultRifle223",1,true))
assert(not Service.ToggleHolster(a),"transfer invalidates holster memory")
assert(Service.Add(a,"AssaultRifle223",1,{1}));assert(Service.Equip(a,"AssaultRifle223"))
Service.UseWeapon(a);assert(#notices==1 and notices[1].data:find("broke",1,true))
Service.UseWeapon(a);assert(#notices==1,"broken item does not repeat notification")
assert(notices[1].player==a,"personal notices are sent only to their owner")
Service.Reset(a);assert(not Service.ToggleHolster(a),"reset clears memory")
Service.Reset(a)
assert(Service.Add(a,"AssaultRifle223",2))
assert(Service.Add(a,"AssaultRifle223",1,{2999}))
local stacks=Service.Snapshot(a).Stacks
assert(#stacks==2 and (stacks[1].Count==2 or stacks[2].Count==2),"identical pristine weapons stack, used gun separate")
local pristine
for _,stack in ipairs(stacks) do if stack.Condition==3000 then pristine=stack end end
assert(Service.Equip(a,"AssaultRifle223",pristine.Key))
Service.Add(a,"Ammo223AP",50)
Service.UnloadMagazine(a,"AP");Service.ReloadMagazine(a)
local data=Service.GetMagazine(a);local uid=data.UID
assert(data.Loaded==30 and Service.Snapshot(a).Items.Ammo223AP==20)
local weight=Service.Snapshot(a).Weight
Service.ToggleHolster(a)
assert(math.abs(Service.Snapshot(a).Weight-weight)<.00001,"holstering retains weight of loaded rounds")
Service.ToggleHolster(a)
assert(Service.GetMagazine(a).UID==uid and Service.GetMagazine(a).Loaded==30 and Service.GetMagazine(a).Type=="AP")
Service.ToggleHolster(a)
local loaded
for _,stack in ipairs(Service.Snapshot(a).Stacks) do if stack.Loaded==30 then loaded=stack end end
assert(loaded and Service.Transfer(a,storage,"AssaultRifle223",1,true,loaded.Key))
assert(storage.Weapons.AssaultRifle223[#storage.Weapons.AssaultRifle223].Loaded==30,"chest retains loaded rounds")
assert(Service.Transfer(a,storage,"AssaultRifle223",1,false,loaded.Key))
assert(Service.Equip(a,"AssaultRifle223",loaded.Key) and Service.GetMagazine(a).Loaded==30)
assert(not Service.Equip(a,"AssaultRifle223","forged variant"),"reject stale/forged selection")
print("PASS: state-based stacks, selected equipment/chest transfer, magazine/type persistence and weight conservation")
print("PASS: holster toggle preserves condition, drop/replacement/transfer cannot restore missing weapon, reset and one break notice")
'''
parts=[(root/'tests/fixtures/town_mock.luau').read_text()]
for name,module in [('ItemConfig','ItemConfig'),('Rules','InventoryRules'),('CombatRules','CombatRules')]:
 parts.append(f'local {name}=(function()\n'+(root/f'src/shared/{module}.luau').read_text()+'\nend)()')
world=(root/'src/server/Services/WorldItemService.luau').read_text()
world=re.sub(r'local (ItemConfig|Inventory|Rules|Interaction|EquipmentVisuals|AmmoRules)\s*=\s*require[^\n]+\n','',world)
world_setup='''
local encoded={}
local HttpService={JSONEncode=function(_,value) local key="payload"..(#encoded+1);table.insert(encoded,value);encoded[key]=value;return key end,JSONDecode=function(_,key) return encoded[key] end}
local oldService=game.GetService
function game:GetService(name) if name=="HttpService" then return HttpService end;return oldService(self,name) end
workspace.DescendantAdded=event()
local worldFolder=make("Folder","WorldItems",workspace);worldFolder.ChildAdded=event()
local Inventory=Service
local template=make("Model","AssaultRifle223",ServerStorage);make("Part","Part",template)
local EquipmentVisuals={Template=function() return template end,CaptureTemplate=function() end}
local Random={new=function() return {NextNumber=function() return .5 end} end}
local originalPivot=methods.GetPivot
function methods:GetPivot() local cf=originalPivot(self);cf.Rotation=CFrame.new(Vector3.zero);return cf end
local ground=true
function workspace:Raycast() if ground then return {Position=Vector3.zero} end end
local Interaction={NearestPoint=function(_,position) return position end}
local AmmoRules={}
'''
world_cases='''
Service.ToggleHolster(a)
local charged
for _,stack in ipairs(Service.Snapshot(a).Stacks) do if stack.Loaded==30 then charged=stack end end
local beforeDrop=Service.Snapshot(a).Weight
assert(World.Drop(a,"AssaultRifle223",1,charged.Key))
local dropped=worldFolder:GetChildren()[1]
assert(dropped and dropped:GetAttribute("WeaponData") and dropped:GetAttribute("Conditions"))
assert(not Service.ToggleHolster(a),"dropped loaded weapon cannot be remotely restored")
ground=false
assert(World.Pickup(a,dropped))
assert(math.abs(Service.Snapshot(a).Weight-beforeDrop)<.00001,"drop/pickup conserves weapon plus ammunition weight")
assert(Service.Equip(a,"AssaultRifle223",charged.Key) and Service.GetMagazine(a).Loaded==30 and Service.GetMagazine(a).Type=="AP")
assert(not World.Pickup(a,dropped),"pickup cannot duplicate a loaded weapon")
local corpseInventory=Service.ExtractAll(a)
local foundLoaded=false
for _,stack in ipairs(Rules.Stacks(corpseInventory,ItemConfig.Items)) do if stack.ID=="AssaultRifle223" and stack.Loaded==30 and stack.AmmoType=="AP" then foundLoaded=true end end
assert(foundLoaded and not Service.GetMagazine(a),"death inventory extraction retains charged gun in corpse, clears player")
ItemConfig.Items.Apron.Armor={Absorption=3,Resistance=.2}
assert(Service.Add(a,"Apron",1) and Service.Equip(a,"Apron"))
assert(a:GetAttribute("ArmorAbsorption")==3 and a:GetAttribute("ArmorResistance")==.2,"equipped armor feeds authoritative totals")
Service.Unequip(a,"Additional")
assert(a:GetAttribute("ArmorAbsorption")==0 and a:GetAttribute("ArmorResistance")==0,"removing armor removes its bonuses")
print("PASS: equipped armor totals update and clear")
print("PASS: actual world drop/pickup preserves condition, loaded rounds, ammo type and total mass without duplicate pickup")
'''
parts += [setup,'local Service=(function()\n'+service+'\nend)()',cases,world_setup,'local World=(function()\n'+world+'\nend)()',world_cases]
with tempfile.TemporaryDirectory() as folder:
 path=Path(folder)/'holster.luau';path.write_text('\n'.join(parts));subprocess.run([sys.argv[1] if len(sys.argv)>1 else 'luau',str(path)],check=True)
