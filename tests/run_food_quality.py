"""Actual consumption of quality food; effects stay attached to the item, not eater perks."""
from pathlib import Path
import re,subprocess,sys,tempfile
root=Path(__file__).resolve().parents[1]
s=(root/'src/server/Services/ConsumableService.luau').read_text()
s=re.sub(r'local (Items|Rules|Inventory|Debuffs|Journal)\s*=\s*require[^\n]+\n','',s)
mock='''
local Debuffs={Antiseptic=function() return false end}
local Journal={Send=function() end}
local Random={new=function() return {} end}
a:LoadCharacterAsync();local hp=a.Character.Humanoid;hp.Health=90
local stock={DirtyWaterBucket=1,Ramsay_BoiledPotato=1,Ramsay_MashedPotatoesWithSausage_2=1}
local Inventory={Remove=function(_,id,n) if (stock[id] or 0)<n then return false end;stock[id]-=n;return true end,Add=function(_,id,n) stock[id]=(stock[id] or 0)+n;return true end}
local held
function Inventory.ReplaceOne(_,source,target)
 if held==source then held=target;return true end
 if not Inventory.Remove(nil,source,1) then return false end
 Inventory.Add(nil,target,1);return true
end
a.Character:SetAttribute("Food",10);a.Character:SetAttribute("Water",50);a.Character:SetAttribute("Sick",2)
'''
cases='''
assert(Service.Eat(a,"Ramsay_BoiledPotato") and a.Character:GetAttribute("Food")==17.5 and hp.Health==95)
assert(a.Character:GetAttribute("Sick")==2 and a.Character:GetAttribute("Water")==50)
hp.Health=98
assert(Service.Eat(a,"Ramsay_MashedPotatoesWithSausage_2") and hp.Health==100 and stock.Plate==1)
assert(a.Character:GetAttribute("Food")==26.5 and a.Character:GetAttribute("Water")==49,"negative nutrition not amplified")
assert(not Service.Eat(a,"Ramsay_Potato"),"uncooked food never inherits cook quality")
assert(Items.Items.Ramsay_BoiledPotato.TemplateID=="BoiledPotato")
a.Character:SetAttribute("Water",0);a.Character:SetAttribute("Sick",0)
assert(Service.Eat(a,"DirtyWaterBucket") and a.Character:GetAttribute("Water")==100 and a.Character:GetAttribute("Sick")==80 and stock.EmptyBucket==1,"drink bucket and return container")
local water,sick,food,health=a.Character:GetAttribute("Water"),a.Character:GetAttribute("Sick"),a.Character:GetAttribute("Food"),hp.Health
for _,id in ipairs({"DirtyWater","CleanWater","DirtyWaterBucket"}) do
 local empty=Items.Items[id].EmptyContainer
 assert(empty and Items.Items[id].ConsumeAction=="Drink")
 stock[id]=2;local before=stock[empty] or 0
 assert(Service.PourOut(a,id) and stock[id]==1 and stock[empty]==before+1)
 held=id
 assert(Service.PourOut(a,id) and held==empty and stock[id]==1,"held container stays equipped after emptying")
 held=nil;assert(Service.PourOut(a,id));assert(not Service.PourOut(a,id),"cannot duplicate containers")
end
assert(not Service.PourOut(a,"Potato") and not Service.PourOut(a,"EmptyBucket") and not Service.PourOut(a,{}))
stock.CleanWater=1;a.Character:SetAttribute("Knockout",true);assert(not Service.PourOut(a,"CleanWater"));a.Character:SetAttribute("Knockout",false)
a.Character:SetAttribute("CraftingLocked",true);assert(not Service.PourOut(a,"CleanWater"));a.Character:SetAttribute("CraftingLocked",false)
hp.Health=0;assert(not Service.PourOut(a,"CleanWater"));hp.Health=health
assert(a.Character:GetAttribute("Water")==water and a.Character:GetAttribute("Sick")==sick and a.Character:GetAttribute("Food")==food and hp.Health==health,"pouring never applies consumption effects")
print("PASS: liquid pouring, pocket/held returns, invalid items, no duplication or consumption effects, authority guards")
print("PASS: persistent quality food heals5, positive nutrition x1.5, negatives unchanged, HP cap and plate return")
'''
parts=[(root/'tests/fixtures/town_mock.luau').read_text()]
for var,module in [('Items','ItemConfig'),('Rules','ConsumableRules')]:parts.append('local '+var+'=(function()\n'+(root/f'src/shared/{module}.luau').read_text()+'\nend)()')
parts +=[mock,'local Service=(function()\n'+s+'\nend)()',cases]
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'food.luau';p.write_text('\n'.join(parts));subprocess.run([sys.argv[1],str(p)],check=True)
