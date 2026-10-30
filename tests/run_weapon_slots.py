"""Authoritative two-slot inventory and timed handoffs; no weapon/magazine copies."""
from pathlib import Path
import subprocess,re,sys,tempfile
root=Path(__file__).resolve().parents[1]
def module(p):return '(function()\n'+(root/p).read_text()+'\nend)()'
s=(root/'tests/fixtures/town_mock.luau').read_text()
for name in ['ItemConfig','InventoryRules','CombatRules']:
 s+='\nlocal '+{'InventoryRules':'Rules'}.get(name,name)+'='+module('src/shared/'+name+'.luau')
s+='\nlocal Pose='+module('src/shared/HandActionPose.luau').replace('require(script.Parent.CharacterPose)','{}')
s+='''
local HandActions
local Crafting={Close=function() end}
local Progression={Meets=function(_,r) return not r.Attributes or (r.Attributes.Strength or 0)<=10 end}
local Motion={Cancel=function() end}
local Journal={Send=function() end}
local Visuals={Template=function() return {} end,Validate=function() return true end,Apply=function(c,id) c:SetAttribute("HandsItem",id or "") end}
local HolsterVisuals={Apply=function(c,slot,id) c:SetAttribute("Stored"..slot,id or "") end}
local ArmorVisuals={Apply=function() end};local BackVisuals={Apply=function() end}
local baseNew=Instance.new
function Instance.new(kind)
 local o=baseNew(kind)
 if kind=="BindableEvent" then o.Event=event();o.Fire=function(self,...) self.Event:Fire(...) end end
 return o
end
local jobs={}
function task.delay(dt,fn) table.insert(jobs,{At=clock+dt,Run=fn}) end
local function advance(dt)
 local untilTime=clock+dt
 while true do
  local nextJob
  for _,job in ipairs(jobs) do if not job.Done and job.At<=untilTime+.0000001 and (not nextJob or job.At<nextJob.At) then nextJob=job end end
  if not nextJob then break end
  clock=nextJob.At;nextJob.Done=true;nextJob.Run()
 end
 clock=untilTime
end
'''
source=(root/'src/server/Services/InventoryService.luau').read_text()
source=re.sub(r'local (ItemConfig|Rules|CombatRules|Visuals|ArmorVisuals|BackVisuals|HolsterVisuals|Journal)\s*=\s*require[^\n]+\n','',source)
source=source.replace('require(script.Parent.ProgressionService)','Progression').replace('require(script.Parent.CraftingService)','Crafting').replace('require(script.Parent.HandActionService)','HandActions')
s+='\nlocal Service=(function()\n'+source+'\nend)()\nlocal Inventory=Service'
source=(root/'src/server/Services/HandActionService.luau').read_text()
source=re.sub(r'local (Pose|Motion|Inventory)=require[^\n]+\n','',source)
s+='\nHandActions=(function()\n'+source+'\nend)()'
s+='''
a:LoadCharacterAsync();b:LoadCharacterAsync();a.Character.HumanoidRootPart.Anchored=false
Service.Reset(a)
for _,entry in ipairs({{"StoneAxe","PrimaryWeapon"},{"StoneShovel","PrimaryWeapon"},{"SMG9mm","PrimaryWeapon"},{"Rifle223","PrimaryWeapon"},{"LSW223","PrimaryWeapon"},{"PipeRifle9mm","PrimaryWeapon"},{"Pistol9mm","SecondaryWeapon"},{"PipePistol9mm","SecondaryWeapon"},{"IronKnife","SecondaryWeapon"}}) do
 assert(ItemConfig.Items[entry[1]].Slot==entry[2],entry[1])
end
assert(Service.Add(a,"AssaultRifle223",1,{1234},{{Loaded=17,Type="AP",Mode="Single"}}))
assert(Service.Add(a,"Pistol9mm",1,{321},{{Loaded=3,Type="FMJ",Mode="Single"}}))
assert(Service.Add(a,"SterileBandage",2))
assert(Service.Equip(a,"AssaultRifle223") and Service.Equip(a,"Pistol9mm") and Service.Equip(a,"SterileBandage"))
local state=Service.Export(a);local rifle=state.EquipmentWeapon.PrimaryWeapon;local pistol=state.EquipmentWeapon.SecondaryWeapon
assert(not state.ActiveWeaponSlot and not state.Items.AssaultRifle223 and not state.Items.Pistol9mm)
assert(a.Character:GetAttribute("StoredPrimaryWeapon")=="AssaultRifle223" and a.Character:GetAttribute("StoredSecondaryWeapon")=="Pistol9mm")
local originalWeight=Service.Snapshot(a).Weight
assert(HandActions.Switch(a,"PrimaryWeapon") and a.Character:GetAttribute("HandsBusy"))
assert(not HandActions.Switch(a,"SecondaryWeapon") and not Service.Equip(a,"Pistol9mm"),"no overlapping transitions")
advance(Pose.DrawContact-.01);assert(not state.ActiveWeaponSlot and Service.GetWeapon(a)==nil)
advance(.01);assert(state.ActiveWeaponSlot=="PrimaryWeapon" and Service.GetWeapon(a)==nil,"draw contact still combat-locked")
advance(Pose.DrawDuration-Pose.DrawContact);assert(Service.GetWeapon(a)==ItemConfig.Items.AssaultRifle223.Weapon and Service.GetMagazine(a)==rifle)
assert(HandActions.Switch(a,"SecondaryWeapon"));advance(Pose.StowContact-.01)
assert(state.ActiveWeaponSlot=="PrimaryWeapon" and a.Character:GetAttribute("HandAction")=="Stow")
advance(.01);assert(not state.ActiveWeaponSlot and a.Character:GetAttribute("StoredPrimaryWeapon")=="AssaultRifle223")
advance(Pose.StowDuration-Pose.StowContact);assert(a.Character:GetAttribute("HandAction")=="Draw")
advance(Pose.DrawDuration);assert(state.ActiveWeaponSlot=="SecondaryWeapon" and Service.GetMagazine(a)==pistol)
assert(rifle.Loaded==17 and rifle.Type=="AP" and rifle.UID~=pistol.UID and state.EquipmentCondition.PrimaryWeapon==1234)
assert(HandActions.Medicine(a,true));advance(Pose.StowDuration+Pose.DrawDuration)
assert(state.MedicalHeld and not state.ActiveWeaponSlot and a.Character:GetAttribute("HandsItem")=="SterileBandage" and not Service.GetWeapon(a))
local applied=0
assert(HandActions.Treat(a,a,function() applied+=1;Service.UseMedicine(a);return true end))
assert(a.Character:GetAttribute("HandAction")=="TreatSelf")
advance(Pose.TreatContact-.01);assert(applied==0 and a.Character:GetAttribute("MedicineCount")==2)
advance(.01);assert(applied==1 and a.Character:GetAttribute("MedicineCount")==1 and not HandActions.Switch(a,"PrimaryWeapon"))
advance(Pose.TreatDuration-Pose.TreatContact);assert(not a.Character:GetAttribute("HandsBusy"))
assert(HandActions.Treat(a,b,function() applied+=1;return true end))
a.Character:SetAttribute("Knockout",true);advance(Pose.TreatContact)
assert(applied==1 and not a.Character:GetAttribute("HandsBusy"),"KO cancels treatment before contact without consuming medicine")
a.Character:SetAttribute("Knockout",false)
assert(HandActions.Switch(a,"PrimaryWeapon"));HandActions.Cancel(a);advance(3)
assert(not state.ActiveWeaponSlot and state.MedicalHeld,"cancelled switch cannot draw later")
assert(HandActions.Switch(a,"PrimaryWeapon"));advance(Pose.StowDuration+Pose.DrawDuration)
assert(state.EquipmentWeapon.PrimaryWeapon==rifle and Service.GetMagazine(a).Loaded==17)
assert(HandActions.Switch(a,"PrimaryWeapon"));advance(Pose.StowDuration)
assert(not state.ActiveWeaponSlot and Service.GetWeapon(a)==CombatRules.Unarmed,"same key stows and frees hands")
assert(math.abs(Service.Snapshot(a).Weight-(originalWeight-.1))<.000001,"no duplicate ownership or ammunition; one consumed bandage only")
-- Weapon-free weight perk applies to the drawn weapon only.
assert(HandActions.Switch(a,"SecondaryWeapon"));advance(Pose.DrawDuration)
a:SetAttribute("EquippedWeaponWeightMultiplier",0)
assert(math.abs(Service.Snapshot(a).Weight-(originalWeight-.1-ItemConfig.Items.Pistol9mm.Weight))<.000001)
a:SetAttribute("EquippedWeaponWeightMultiplier",1)
assert(HandActions.Switch(a,"SecondaryWeapon"));advance(Pose.StowDuration)
assert(Service.Unequip(a,"PrimaryWeapon") and Service.Unequip(a,"SecondaryWeapon"))
assert(state.Weapons.AssaultRifle223[1].UID==rifle.UID and state.Weapons.Pistol9mm[1].UID==pistol.UID)
-- Older hand-only sessions migrate the exact instance once.
local legacy=Rules.New();legacy.Equipment.Hands="AssaultRifle223";legacy.EquipmentCondition.Hands=12
local oldMagazine={UID="legacy",Loaded=7,Type="AP"};legacy.EquipmentWeapon.Hands=oldMagazine
Rules.ReconcileEquipment(legacy,ItemConfig.Items,ItemConfig.Slots);Rules.ReconcileEquipment(legacy,ItemConfig.Items,ItemConfig.Slots)
assert(legacy.ActiveWeaponSlot=="PrimaryWeapon" and legacy.EquipmentWeapon.PrimaryWeapon==oldMagazine and not legacy.Equipment.Hands and not legacy.Items.AssaultRifle223)
-- A fresh inventory on the same rig also invalidates queued draw callbacks.
assert(HandActions.Medicine(a,true));Service.Reset(a);advance(3)
assert(not a.Character:GetAttribute("HandsBusy") and not a.Character:GetAttribute("MedicalHeld") and not Service.Export(a).ActiveWeaponSlot)
print("PASS: exact slot classes, separate ownership/UID/magazines/condition/weight, sequential timed switching, medicine draw and delayed treatment, KO/cancel guards, free hands and legacy migration")
'''
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'weapons.luau';p.write_text(s);subprocess.run([sys.argv[1],str(p)],check=True)
