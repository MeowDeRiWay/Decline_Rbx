"""Exercise authoritative inventory restoration, transfers, resets and one-time break notice."""
from pathlib import Path
import re,subprocess,sys,tempfile
root=Path(__file__).resolve().parents[1]
service=(root/'src/server/Services/InventoryService.luau').read_text()
service=re.sub(r'local (ItemConfig|Rules|CombatRules|Visuals|ArmorVisuals|Journal)\s*=\s*require[^\n]+\n','',service)
service=service.replace('require(script.Parent.CraftingService).Close(player)','Crafting.Close(player)').replace('require(script.Parent.ProgressionService).Meets','Progression.Meets')
setup='''
local strength=10
local Progression={Meets=function(_,req) return not req.Attributes or strength>=(req.Attributes.Strength or 0) end}
local Crafting={Close=function() end}
local Journal=journalPlaceholder
local notices=ReplicatedStorage:FindFirstChild("PersonalNotice").sent
local ArmorVisuals={Apply=function(c,id) c:SetAttribute("WornArmor",id) end}
local Visuals={Apply=function() end,Validate=function() return true end,Template=function() return {} end}
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
Service.UseWeapon(a);assert(#notices==0,"weapon wear disabled")
Service.UseWeapon(a);assert(#notices==0,"no wear notifications")
assert(#notices==0,"wear disabled without personal notices")
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
assert(data.Loaded==24 and Service.Snapshot(a).Items.Ammo223AP==26)
local weight=Service.Snapshot(a).Weight
Service.ToggleHolster(a)
assert(math.abs(Service.Snapshot(a).Weight-weight)<.00001,"holstering retains weight of loaded rounds")
Service.ToggleHolster(a)
assert(Service.GetMagazine(a).UID==uid and Service.GetMagazine(a).Loaded==24 and Service.GetMagazine(a).Type=="AP")
Service.ToggleHolster(a)
local loaded
for _,stack in ipairs(Service.Snapshot(a).Stacks) do if stack.Loaded==24 then loaded=stack end end
assert(loaded and Service.Transfer(a,storage,"AssaultRifle223",1,true,loaded.Key))
assert(storage.Weapons.AssaultRifle223[#storage.Weapons.AssaultRifle223].Loaded==24,"chest retains loaded rounds")
assert(Service.Transfer(a,storage,"AssaultRifle223",1,false,loaded.Key))
assert(Service.Equip(a,"AssaultRifle223",loaded.Key) and Service.GetMagazine(a).Loaded==24)
assert(not Service.Equip(a,"AssaultRifle223","forged variant"),"reject stale/forged selection")
print("PASS: state-based stacks, selected equipment/chest transfer, magazine/type persistence and weight conservation")
print("PASS: holster toggle preserves condition, drop/replacement/transfer cannot restore missing weapon, reset and one break notice")
'''
parts=[(root/'tests/fixtures/town_mock.luau').read_text()]
for name,module in [('ItemConfig','ItemConfig'),('Rules','InventoryRules'),('CombatRules','CombatRules')]:
 parts.append(f'local {name}=(function()\n'+(root/f'src/shared/{module}.luau').read_text()+'\nend)()')
world=(root/'src/server/Services/WorldItemService.luau').read_text().replace('local WorldActivity=require(script.Parent.WorldActivityService)', 'local WorldActivity={Register=function() end,IsDormant=function() return false end,Ensure=function() end,DormantNPCs=function() return {} end,Raycast=function() return nil end}')
world=world.replace('local Stations=require(ReplicatedStorage.Shared.CraftStations)', 'local Stations=(function()\n'+(root/'src/shared/CraftStations.luau').read_text()+'\nend)()')
world=re.sub(r'local (ItemConfig|Inventory|Rules|Interaction|EquipmentVisuals|AmmoRules|Stations)\s*=\s*require[^\n]+\n','',world)
world_setup='''
local warn=function() end
local Color3={fromRGB=function(r,g,b) return {r,g,b} end}
local encoded={}
local HttpService={JSONEncode=function(_,value) local key="payload"..(#encoded+1);table.insert(encoded,value);encoded[key]=value;return key end,JSONDecode=function(_,key) return encoded[key] end}
local oldService=game.GetService
function game:GetService(name) if name=="HttpService" then return HttpService end;return oldService(self,name) end
workspace.DescendantAdded=event()
local worldFolder=make("Folder","WorldItems",workspace);worldFolder.ChildAdded=event()
local Inventory=Service
local template=make("Model","AssaultRifle223",ServerStorage);make("Part","Part",template)
local EquipmentVisuals={Template=function() return template end,CaptureTemplate=function() end,Apply=function(model,id) model:SetAttribute("HandsItem",id or "") end}
local Random={new=function() return {NextNumber=function() return .5 end} end}
local originalPivot=methods.GetPivot
function methods:GetPivot() local cf=originalPivot(self);cf.Rotation=CFrame.new(Vector3.zero);return cf end
local ground=true
function workspace:Raycast() if ground then return {Position=Vector3.zero} end end
local Interaction={NearestPoint=function(_,position) return position end}
local AmmoRules={}
'''
world_cases='''
AmmoRules.BoxCount=function(maximum,roll) return math.floor(maximum*roll)+1 end
AmmoRules.AmmoID=function(caliber,kind) return "Ammo"..caliber..kind end
local ammoSource=make("Model","AmmoBox223FMJ",ServerStorage,{AmmoCount=3,MaxAmmo=50,Quantity=99});make("Part","Part",ammoSource)
local spawned=World.SpawnTemplate(ammoSource,"AmmoBox223FMJ",Vector3.zero)
assert(spawned and spawned.Parent==worldFolder and spawned:GetAttribute("Quantity")==1 and spawned:GetAttribute("AmmoCount")==nil)
worldFolder.ChildAdded:Fire(spawned)
assert(spawned:GetAttribute("AmmoCount")==26 and ammoSource:GetAttribute("AmmoCount")==3,"fresh pool spawn rerolls its own box without altering template")
worldFolder.ChildAdded:Fire(spawned);assert(spawned:GetAttribute("AmmoCount")==26)
ground=false;assert(World.Pickup(a,spawned) and Service.Snapshot(a).Items.Ammo223FMJ==26)
ground=true
local sourceTemplate=EquipmentVisuals.Template
EquipmentVisuals.Template=function(id) if id=="Kevlar" then return nil end;return sourceTemplate(id) end
Enum.Material={Fabric=1,Slate=2,Wood=3,Metal=4}
local beforeKevlar=Service.Snapshot(a).Items.Kevlar or 0
assert(World.SpawnLoot({Kevlar=5},Vector3.zero,{a.Character}))
local kevlarDrop
for _,child in ipairs(worldFolder:GetChildren()) do if child:GetAttribute("Item_ID")=="Kevlar" then kevlarDrop=child end end
assert(kevlarDrop and kevlarDrop:IsA("BasePart"),"Kevlar remains droppable before its model exists")
ground=false;assert(World.Pickup(a,kevlarDrop));ground=true
assert(Service.Snapshot(a).Items.Kevlar==beforeKevlar+5)
EquipmentVisuals.Template=sourceTemplate
print("PASS: actual pool template placement produces one box and unpacks one freshly rolled ammunition stack")
Service.ToggleHolster(a)
local charged
for _,stack in ipairs(Service.Snapshot(a).Stacks) do if stack.Loaded==24 then charged=stack end end
local beforeDrop=Service.Snapshot(a).Weight
assert(World.Drop(a,"AssaultRifle223",1,charged.Key))
local dropped=worldFolder:GetChildren()[1]
assert(dropped and dropped:GetAttribute("WeaponData") and dropped:GetAttribute("Conditions"))
assert(not Service.ToggleHolster(a),"dropped loaded weapon cannot be remotely restored")
ground=false
assert(World.Pickup(a,dropped))
assert(math.abs(Service.Snapshot(a).Weight-beforeDrop)<.00001,"drop/pickup conserves weapon plus ammunition weight")
assert(Service.Equip(a,"AssaultRifle223",charged.Key) and Service.GetMagazine(a).Loaded==24 and Service.GetMagazine(a).Type=="AP")
assert(not World.Pickup(a,dropped),"pickup cannot duplicate a loaded weapon")
ground=true
assert(World.Disarm(a) and not Service.Snapshot(a).Equipment.Hands,"bolt disarm drops equipped gun")
local disarmed=worldFolder:GetChildren()[1]
ground=false
assert(disarmed and World.Pickup(a,disarmed))
assert(Service.Equip(a,"AssaultRifle223",charged.Key) and Service.GetMagazine(a).Loaded==24 and Service.GetMagazine(a).Type=="AP","disarm conserves loaded ammunition")
ground=false
assert(not World.Disarm(a) and Service.Snapshot(a).Equipment.Hands=="AssaultRifle223","failed world placement restores held gun")
local corpseInventory=Service.ExtractAll(a)
local foundLoaded=false
for _,stack in ipairs(Rules.Stacks(corpseInventory,ItemConfig.Items)) do if stack.ID=="AssaultRifle223" and stack.Loaded==24 and stack.AmmoType=="AP" then foundLoaded=true end end
assert(foundLoaded and not Service.GetMagazine(a),"death inventory extraction retains charged gun in corpse, clears player")
assert(#ItemConfig.Slots==5 and not table.find(ItemConfig.Slots,"Head"),"exactly five equipment slots, no Head")
ItemConfig.Items.TestArmor={Name="Armor suit",Weight=2,Slot="Body",Armor={Absorption=3,Resistance=.2}}
ItemConfig.Items.Apron.Armor={Absorption=10,Resistance=.5}
assert(Service.Add(a,"Apron",1) and Service.Equip(a,"Apron"))
assert(a:GetAttribute("ArmorAbsorption")==0 and a:GetAttribute("ArmorResistance")==0,"accessories cannot add a second armor layer")
assert(Service.Add(a,"TestArmor",1) and Service.Equip(a,"TestArmor"))
assert(a:GetAttribute("ArmorAbsorption")==3 and a:GetAttribute("ArmorResistance")==.2,"only Body armor feeds authoritative totals")
Service.Unequip(a,"Body")
assert(a:GetAttribute("ArmorAbsorption")==0 and a:GetAttribute("ArmorResistance")==0,"removing body armor clears defense despite accessory")
local legacy=Service.Export(a)
legacy.Equipment.Head="AssaultRifle223";legacy.EquipmentCondition.Head=17
legacy.EquipmentWeapon.Head={Loaded=7,Type="AP",UID="retired-slot-item"}
Service.Refresh(a)
assert(not legacy.Equipment.Head and not legacy.EquipmentCondition.Head and not legacy.EquipmentWeapon.Head,"retired slot is cleared")
local recovered=false
for _,stack in ipairs(Service.Snapshot(a).Stacks) do if stack.ID=="AssaultRifle223" and stack.Condition==17 and stack.Loaded==7 and stack.AmmoType=="AP" then recovered=true end end
assert(recovered,"retired slot item returns to inventory with condition and ammunition")
local count=Service.Snapshot(a).Items.AssaultRifle223
Service.Refresh(a);assert(Service.Snapshot(a).Items.AssaultRifle223==count,"slot migration cannot duplicate item")
ItemConfig.Items.TestHelmet={Name="Old helmet",Weight=1,Slot="Head"}
assert(Service.Add(a,"TestHelmet",1) and not Service.Equip(a,"TestHelmet") and not Service.Unequip(a,"Head"),"client cannot equip or address removed slot")
ItemConfig.Items.Apron.Armor=nil
assert(Service.Add(a,"LeatherArmor",1) and Service.Equip(a,"LeatherArmor"))
assert(Service.Snapshot(a).Equipment.Body=="LeatherArmor" and a.Character:GetAttribute("WornArmor")=="LeatherArmor")
assert(a:GetAttribute("ArmorAbsorption")==2 and a:GetAttribute("ArmorResistance")==.1)
assert(Service.Unequip(a,"Body") and a.Character:GetAttribute("WornArmor")==nil and a:GetAttribute("ArmorAbsorption")==0)
assert(Service.Add(a,"LeatherArmor2",1) and Service.Equip(a,"LeatherArmor2"))
assert(Service.Snapshot(a).Equipment.Body=="LeatherArmor2" and a.Character:GetAttribute("WornArmor")=="LeatherArmor2")
assert(a:GetAttribute("ArmorAbsorption")==4 and a:GetAttribute("ArmorResistance")==.15)
assert(Service.Unequip(a,"Body") and a:GetAttribute("ArmorResistance")==0)
assert(Service.Add(a,"MiliArmor1",1) and Service.Equip(a,"MiliArmor1"))
assert(a:GetAttribute("ArmorAbsorption")==6 and a:GetAttribute("ArmorResistance")==.3)
assert(Service.Unequip(a,"Body"))
assert(Service.Add(a,"MiliArmor2",1) and Service.Equip(a,"MiliArmor2"))
assert(a:GetAttribute("ArmorAbsorption")==8 and a:GetAttribute("ArmorResistance")==.4)
assert(Service.Snapshot(a).Equipment.Body=="MiliArmor2" and a.Character:GetAttribute("WornArmor")=="MiliArmor2")
assert(Service.Unequip(a,"Body") and a:GetAttribute("ArmorAbsorption")==0 and a:GetAttribute("ArmorResistance")==0)
for id,minimum in pairs({Pistol9mm=3,SMG9mm=4,PipePistol9mm=3,PipeRifle9mm=4,Rifle223=4,ServiceRifle223=4,AssaultRifle223=5,LSW223=6}) do
 assert(Service.Add(a,id,1))
 local previous=Service.Snapshot(a).Equipment.Hands
 strength=minimum-1;assert(not Service.Equip(a,id) and Service.Snapshot(a).Equipment.Hands==previous,"server equip gate: "..id)
 strength=minimum;assert(Service.Equip(a,id) and Service.GetWeapon(a),"exact minimum can equip/use: "..id)
 strength=minimum-1;assert(Service.GetWeapon(a)==nil,"already-held weapon stops working after attribute reduction")
 strength=minimum;assert(Service.Unequip(a,"Hands"))
end
strength=10
print("PASS: five slots, Body-only armor, retired-slot recovery without duplication, removed-slot commands rejected")
print("PASS: actual world drop/pickup preserves condition, loaded rounds, ammo type and total mass without duplicate pickup")
'''
world_cases+='''
Service.Reset(a)
assert(Service.Add(a,"Bandage",3) and Service.Equip(a,"Bandage"))
assert(Service.Snapshot(a).Equipment.Medicine=="Bandage" and a.Character:GetAttribute("MedicineCount")==3)
local medWeight=Service.Snapshot(a).Weight
assert(Service.UseMedicine(a) and Service.Snapshot(a).Items.Bandage==1 and Service.Snapshot(a).Equipment.Medicine=="Bandage")
assert(math.abs(Service.Snapshot(a).Weight-(medWeight-.1))<1e-9,"one bandage consumed, next automatically equipped")
assert(Service.UseMedicine(a) and Service.UseMedicine(a) and not Service.UseMedicine(a))
assert(Service.Snapshot(a).Equipment.Medicine==nil and a.Character:GetAttribute("MedicineCount")==0)
assert(Service.Add(a,"GreatBandage",2) and Service.Equip(a,"GreatBandage"))
assert(a.Character:GetAttribute("MedicineCount")==2)
assert(Service.UseMedicine(a) and Service.Snapshot(a).Equipment.Medicine=="GreatBandage" and a.Character:GetAttribute("MedicineCount")==1)
assert(Service.UseMedicine(a) and not Service.UseMedicine(a) and a.Character:GetAttribute("MedicineCount")==0)
assert(Service.Add(a,"SewingKit",1) and Service.Snapshot(a).CraftTools.SewingKit==1,"sewing kit works from inventory")
print("PASS: both bandage qualities, exact consumption, automatic pocket refill, sewing kit inventory tool and empty-state synchronization")
'''
world_cases+='''
assert(Service.Add(a,"EmptyBucket",1) and Service.Equip(a,"EmptyBucket"))
assert(Service.ReplaceOne(a,"EmptyBucket","DirtyWaterBucket") and Service.Snapshot(a).Equipment.Hands=="DirtyWaterBucket")
assert(Service.ReplaceOne(a,"DirtyWaterBucket","EmptyBucket") and Service.Snapshot(a).Equipment.Hands=="EmptyBucket")
assert(not Service.ReplaceOne(a,"EmptyBottle","DirtyWater"),"container conversion cannot create water without source")
assert(Service.Unequip(a,"Hands"))
Service.Start()
assert(Service.Add(a,"AssaultRifle223",1) and Service.Equip(a,"AssaultRifle223"))
local mag=Service.GetMagazine(a);mag.Loaded=7;mag.Type="AP"
Crafting.Close=function(p) Service.Add(p,"Plank",1) end
Service.RemovePlayer(a);a.Parent=nil
local rejoined=player(a.UserId);Players.PlayerAdded:Fire(rejoined)
rejoined.Character=make("Model","Returned",workspace,{ReturningSession=true});rejoined.CharacterAdded:Fire(rejoined.Character)
assert(Service.GetMagazine(rejoined).Loaded==7 and Service.Snapshot(rejoined).Items.Plank==1,"disconnect refunds before detach and restores loaded magazine")
rejoined:LoadCharacterAsync();assert(Service.Snapshot(rejoined).Equipment.Hands==nil,"fresh respawn still resets inventory")
print("PASS: actual inventory disconnect/reconnect continuity, crafting refund order, magazine preservation and fresh respawn reset")
'''
parts += [setup,'local Service=(function()\n'+service+'\nend)()',cases,world_setup,'local World=(function()\n'+world+'\nend)()',world_cases]
with tempfile.TemporaryDirectory() as folder:
 path=Path(folder)/'holster.luau';path.write_text('\n'.join(parts));subprocess.run([sys.argv[1] if len(sys.argv)>1 else 'luau',str(path)],check=True)
