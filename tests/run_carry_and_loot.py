"""Real carrier authority and live knockout inventory transfer, without Studio physics."""
from pathlib import Path
import re,subprocess,sys,tempfile
root=Path(__file__).resolve().parents[1]
s=(root/'tests/fixtures/town_mock.luau').read_text()
s+='''
local beat
local Run={Heartbeat={Connect=function(_,fn) beat=fn end}}
local oldGet=game.GetService
function game:GetService(name) if name=="RunService" then return Run end;return oldGet(self,name) end
local oldNew=CFrame.new
function CFrame.new(x,y,z) return oldNew(type(x)=="number" and Vector3.new(x,y,z) or x) end
function CFrame.Angles() return CFrame.new() end
local oldIndex=cfmeta.__index
cfmeta.__index=function(frame,key)
 if key=="Inverse" then return function(self) return CFrame.new(-self.Position.X,-self.Position.Y,-self.Position.Z) end end
 return oldIndex(frame,key)
end
local oldPivot=methods.PivotTo
function methods:PivotTo(frame)
 oldPivot(self,frame)
 local root=self:FindFirstChild("HumanoidRootPart");if root then root.CFrame=frame end
end
for _,p in ipairs({a,b,c}) do p:LoadCharacterAsync() end
b.Character:SetAttribute("Knockout",true);b.Character:SetAttribute("KnockoutEndsAt",clock-100)
local Config={InteractionDistance=3}
local moves=0
local Life={MoveKnockout=function(p,frame) moves+=1;p.Character:PivotTo(frame);return true end}
local Fall={Carry=function(c,frame) c:SetAttribute("BodyPoseKind","Carried");c:PivotTo(frame);return true end}
local allowed=true;local placed
local Beds={CanPlace=function() return allowed end,PlacePatient=function(_,patient,bed) placed={patient,bed};return true end}
local Inventory={ClearHands=function() return true end}
local Chests={Close=function() end}
local Crafting={Close=function() end}
'''
carry=(root/'src/server/Services/CarryService.luau').read_text()
carry=re.sub(r'local (Config|Life|Fall|Beds|Inventory|Chests|Pose)=require[^\n]+\n','',carry).replace('require(script.Parent.CraftingService)','Crafting')
s+='\nlocal Pose=(function()\n'+(root/'src/shared/CarryPose.luau').read_text()+'\nend)()'
s+='\nlocal Carry=(function()\n'+carry+'\nend)()'
s+='''
assert(not Carry.Pickup(a,a) and not Carry.Pickup(a,c))
b.Character.HumanoidRootPart.Position=Vector3.new(10,0,0);assert(not Carry.Pickup(a,b))
b.Character.HumanoidRootPart.Position=Vector3.zero
local wall=make("Part","Wall",workspace)
function workspace:Raycast() return {Instance=wall} end
assert(not Carry.Pickup(a,b),"wall blocks pickup")
function workspace:Raycast() return nil end
assert(Carry.Pickup(a,b) and Carry.Patient(a)==b and a.Character:GetAttribute("CarryingUserId")==b.UserId)
assert(b.Character:GetAttribute("BodyPoseKind")=="Carried" and b.Character:GetPivot().Position.X<0,"pickup replaces fetal KO with a left shoulder pose immediately")
assert(not Carry.Pickup(c,b),"one carrier per patient")
beat();assert(b.Character:GetAttribute("Knockout") and b.Character:GetAttribute("KnockoutEndsAt")==clock-100,"carrying an overdue patient never kills or resets their timer")
allowed=false;assert(not Carry.PlaceOnBed(a,wall) and Carry.Patient(a)==b,"occupied/invalid bed does not drop patient")
allowed=true;assert(Carry.PlaceOnBed(a,wall) and placed[1]==b and Carry.Patient(a)==nil and not b.Character:GetAttribute("CarriedByUserId"))
assert(Carry.Pickup(a,b));a.Character:SetAttribute("Knockout",true);beat()
assert(Carry.Patient(a)==nil and not b.Character:GetAttribute("CarriedByUserId"),"carrier incapacitation releases victim")
a.Character:SetAttribute("Knockout",false);assert(Carry.Pickup(a,b));Carry.ReleasePlayer(b)
assert(Carry.Patient(a)==nil and moves>=3,"release is safe for either participant")
print("PASS: carry authority, wall/range/self/living target denial, exclusive ownership, overdue patient survival, invalid-bed atomicity, placement, KO and release cleanup")
'''
for variable,path in [('Rules','src/shared/InventoryRules.luau'),('Items','src/shared/ItemConfig.luau')]:s+='\nlocal '+variable+'=(function()\n'+(root/path).read_text()+'\nend)()'
s+='''
local storage={[a]=Rules.New(),[b]=Rules.New(),[c]=Rules.New()}
Rules.Add(storage[b],Items.Items,"Cloth",3)
Rules.Add(storage[b],Items.Items,"Backpack1",1)
Rules.Equip(storage[b],Items.Items,Items.Slots,"Backpack1")
Rules.Add(storage[b],Items.Items,"LeatherArmor",2);Rules.Equip(storage[b],Items.Items,Items.Slots,"LeatherArmor")
Rules.Add(storage[b],Items.Items,"Pistol9mm",1,{123},{{Loaded=3,Type="AP",Mode="Single"}})
Rules.Equip(storage[b],Items.Items,Items.Slots,"Pistol9mm");storage[b].ActiveWeaponSlot="SecondaryWeapon"
local pistolUID=storage[b].EquipmentWeapon.SecondaryWeapon.UID
local updates=0
local Inventory={Export=function(p) return storage[p] end,Refresh=function() updates+=1 end,
 CorpseStorage=function() error("opening KO loot must never convert worn gear into pocket items") end,
 TakeEquippedLoot=function(p,data,id,n,key) return Rules.TransferEquipment(data,storage[p],Items.Items,id,n,key,true) end,
 Transfer=function(p,chest,id,n,into,key) return Rules.Transfer(into and storage[p] or chest,into and chest or storage[p],Items.Items,id,n,key) end}
local Interaction={NearestPoint=function(_,pos) return pos end}
local Animation={BeginLoot=function(_,_,_,fn) return fn() end,EndLoot=function() end}
local baseNew=Instance.new
function Instance.new(kind)
 local obj=baseNew(kind)
 if kind=="BindableEvent" then obj.Event=event();function obj:Fire(...) self.Event:Fire(...) end end
 return obj
end
'''
chest=(root/'src/server/Services/ChestService.luau').read_text()
chest=re.sub(r'local (Inventory|Rules|Items|Interaction|Animation)\s*=\s*require[^\n]+\n','',chest)
s+='\nlocal Chest=(function()\n'+chest+'\nend)()'
s+='''
assert(not Chest.OpenKnockout(a,c),"living players cannot be looted")
local beginLoot=Animation.BeginLoot
Animation.BeginLoot=function() return false end
assert(not Chest.OpenKnockout(a,b) and storage[b].Equipment.Back=="Backpack1","denied animation cannot unequip the victim")
local pendingOpen
Animation.BeginLoot=function(_,_,_,fn) pendingOpen=fn;return true end
assert(Chest.OpenKnockout(a,b));b.Character:SetAttribute("Knockout",false)
assert(not pendingOpen() and storage[b].Equipment.Back=="Backpack1","revival before opening cancels without touching inventory")
b.Character:SetAttribute("Knockout",true);Animation.BeginLoot=beginLoot
assert(Chest.OpenKnockout(a,b) and Chest.Snapshot(a).ChestReadOnly)
assert(not storage[b].Items.Backpack1 and storage[b].Equipment.Back=="Backpack1" and storage[b].Equipment.Body=="LeatherArmor","opening keeps worn armor/backpack in their slots")
local armorKey,pistolKey
for _,stack in ipairs(Chest.Snapshot(a).ChestStacks) do
 if stack.EquipmentSlot=="Body" then armorKey=stack.Key;assert(stack.ID=="LeatherArmor" and stack.Count==1 and stack.LootLocked) end
 if stack.EquipmentSlot=="SecondaryWeapon" then pistolKey=stack.Key;assert(stack.Loaded==3 and stack.Condition==123 and stack.AmmoType=="AP") end
end
assert(armorKey and pistolKey,"worn gear remains visible and separately selectable from pocket copies")
Chest.Close(a)
assert(storage[b].Equipment.Body=="LeatherArmor" and storage[b].Items.LeatherArmor==1,"merely opening/closing never strips equipment")
assert(Chest.OpenKnockout(a,b));assert(Chest.OpenKnockout(c,b))
assert(not Chest.Transfer(a,"LeatherArmor",2,false,armorKey) and storage[b].Equipment.Body=="LeatherArmor","equipped item count cannot be forged")
assert(not Chest.Transfer(a,"LeatherArmor",1,false,armorKey.."forged"))
local grant=Rules.Add
Rules.Add=function() return false end
assert(not Chest.Transfer(a,"LeatherArmor",1,false,armorKey) and storage[b].Equipment.Body=="LeatherArmor" and not storage[a].Items.LeatherArmor,"failed grant leaves original armor worn")
Rules.Add=grant
assert(not Chest.Transfer(a,"LeatherArmor",1,false,armorKey) and storage[b].Equipment.Body=="LeatherArmor" and not storage[a].Items.LeatherArmor,"worn armor cannot be removed even with the exact key")
assert(Chest.Transfer(a,"LeatherArmor",1,false) and storage[b].Equipment.Body=="LeatherArmor" and storage[a].Items.LeatherArmor==1,"spare pocket armor remains normal loot")
assert(not Chest.Transfer(c,"LeatherArmor",1,false,armorKey) and not storage[c].Items.LeatherArmor,"two looters cannot take the same equipped item")
assert(Chest.Transfer(a,"Pistol9mm",1,false,pistolKey) and not storage[b].ActiveWeaponSlot)
assert(storage[a].Weapons.Pistol9mm[1].UID==pistolUID and storage[a].Weapons.Pistol9mm[1].Loaded==3 and storage[a].Conditions.Pistol9mm[1]==123,"equipped weapon metadata survives transfer without copying")
assert(not Chest.Transfer(a,"Cloth",1,true),"cannot insert items into patient")
assert(Chest.Transfer(a,"Cloth",1,false) and storage[a].Items.Cloth==1 and storage[b].Items.Cloth==2 and updates>=1)
b.Character:SetAttribute("CarriedByUserId",123)
assert(not Chest.Transfer(a,"Cloth",1,false),"carrying closes the loot route")
b.Character:SetAttribute("CarriedByUserId",nil);assert(Chest.OpenKnockout(a,b));assert(Chest.TakeAll(a))
assert(storage[a].Items.Cloth==3 and storage[a].Items.Backpack1==1 and storage[a].Items.LeatherArmor==1 and next(storage[b].Items)==nil and storage[b].Equipment.Body=="LeatherArmor" and not storage[b].Equipment.Back,"all loot moves exactly once")
b.Character.Name="Chest";b.Character:SetAttribute("Knockout",false);assert(not Chest.OpenKnockout(a,b),"revival closes patient loot even for a character named Chest")
assert(not Chest.Transfer(c,"Cloth",1,false),"an already-open second viewer cannot loot after revival")
print("PASS: knockout loot shares authoritative inventory, includes equipment, read-only insertion, owner refresh, carry/revival guards and no duplication")
'''
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'carry.luau';p.write_text(s);subprocess.run([sys.argv[1],str(p)],check=True)
