"""Exercise armor/backpack capacity through the production inventory service."""
from pathlib import Path
import re
import subprocess
import sys
import tempfile

root = Path(__file__).resolve().parents[1]
def module(path):
    return "(function()\n" + (root / path).read_text() + "\nend)()"

source = "local ItemConfig=" + module("src/shared/ItemConfig.luau")
source += "\nlocal Rules=" + module("src/shared/InventoryRules.luau")
source += r'''
local function attributes()
 return {Values={},GetAttribute=function(self,key) return self.Values[key] end,
 SetAttribute=function(self,key,value) self.Values[key]=value end}
end
local player=attributes()
player.UserId=1
player.Character=attributes()
player:SetAttribute("BaseCarryLimitKg",25)
player:SetAttribute("AttributesConfirmed",true)
local noop={Apply=function() end}
local Visuals={Apply=function() end,Template=function() end,Validate=function() return true end}
local ArmorVisuals,AdditionalVisuals,HolsterVisuals=noop,noop,noop
local renderedBack
local BackVisuals={Apply=function(_,id) renderedBack=id end}
local Journal={Send=function() end}
local CombatRules={}
game={GetService=function() return {Shared={}} end}
Instance={new=function() return {Event={},Fire=function() end} end}
script={Parent={ProgressionService={}}}
local require=function() return {Meets=function() return true end} end
'''
service = (root / "src/server/Services/InventoryService.luau").read_text()
service = re.sub(r"^local \w+\s*=\s*require[^\n]*\n", "", service, flags=re.MULTILINE)
source += "\nlocal Service=(function()\n" + service + "\nend)()\n"
source += r'''
for _,id in ipairs({"MiliArmor1","MiliArmor2","Exosuit"}) do
 Service.Reset(player)
 assert(Service.Add(player,"Backpack1",1))
 assert(Service.Equip(player,"Backpack1"))
 assert(renderedBack=="Backpack1" and player:GetAttribute("CarryLimitKg")==35)
 assert(Service.Add(player,id,1))
 assert(Service.Equip(player,id))
 local state=Service.Export(player)
 assert(state.Equipment.Body==id and state.Equipment.Back==nil)
 assert(state.Items.Backpack1==1 and renderedBack==nil,"backpack returns to pockets and its visual is removed")
 assert(not Service.Equip(player,"Backpack1"),"armor blocks backpack re-equipping")
 assert(player:GetAttribute("CarryLimitKg")==35 and player.Character:GetAttribute("CarryLimitKg")==35)
 assert(player:GetAttribute("EquipmentCarryBonusKg")==10,"armor and backpack bonuses never stack")
 for _=1,3 do Service.Refresh(player) end
 assert(player:GetAttribute("CarryLimitKg")==35 and state.Items.Backpack1==1,"refresh neither duplicates bags nor stacks capacity")
 player:SetAttribute("BaseCarryLimitKg",30);Service.Refresh(player)
 assert(player:GetAttribute("CarryLimitKg")==40,"progression base increases retain armor capacity")
 assert(Service.Unequip(player,"Body"))
 assert(player:GetAttribute("CarryLimitKg")==30 and player:GetAttribute("EquipmentCarryBonusKg")==0,"removing armor removes its bonus")
 assert(Service.Equip(player,"Backpack1") and player:GetAttribute("CarryLimitKg")==40)
 -- Old saved sessions can contain both pieces. Refresh migrates them safely.
 state.Equipment.Body=id;state.Items[id]=nil
 Service.Refresh(player)
 assert(state.Equipment.Back==nil and state.Items.Backpack1==1 and renderedBack==nil)
 assert(player:GetAttribute("CarryLimitKg")==40)
 player:SetAttribute("BaseCarryLimitKg",25)
end
Service.Reset(player)
Service.Add(player,"LeatherArmor",1);Service.Add(player,"Backpack1",1)
assert(Service.Equip(player,"LeatherArmor") and Service.Equip(player,"Backpack1"))
assert(player:GetAttribute("CarryLimitKg")==35 and renderedBack=="Backpack1","ordinary armor keeps its backpack")
print("PASS: all three armor variants auto-stow and block backpacks, grant exactly10kg, restore legacy sessions and track base capacity/removal")
'''
with tempfile.TemporaryDirectory() as directory:
    path = Path(directory) / "armor_capacity.luau"
    path.write_text(source)
    subprocess.run([sys.argv[1] if len(sys.argv) > 1 else "luau", str(path)], check=True)
