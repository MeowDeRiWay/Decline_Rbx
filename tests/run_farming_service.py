"""Actual farming authority: seed, watering, timing, ownership perk and container safety."""
from pathlib import Path
import re,subprocess,tempfile,sys
root=Path(__file__).resolve().parents[1]
s=(root/'src/server/Services/FarmingService.luau').read_text()
s=re.sub(r'local (Config|Rules|Interaction|ItemConfig|Inventory|Progression|Journal)=require[^\n]+\n','',s)
setup='''
workspace.DescendantAdded=event()
a:LoadCharacterAsync()
local stock={Potato=2,EmptyBottle=1,EmptyBucket=1};local equipment={}
local Inventory={}
function Inventory.Snapshot() return {Items=table.clone(stock),Equipment=table.clone(equipment)} end
function Inventory.Remove(_,id,count) if (stock[id] or 0)<count then return false end;stock[id]-=count;return true end
function Inventory.Add(_,id,count) stock[id]=(stock[id] or 0)+count;return true end
function Inventory.ReplaceOne(_,source,target)
 if equipment.Hands==source then equipment.Hands=target;return true end
 if not Inventory.Remove(nil,source,1) then return false end
 Inventory.Add(nil,target,1);return true
end
local xp=0;local Progression={FarmXP=function(_,count) xp+=count end}
local Journal={Send=function() end}
local Random={new=function() return {NextInteger=function(_,a) return a end,NextNumber=function() return .9 end} end}
local Interaction={NearestPoint=function(model) return model:GetPivot().Position end}
local greenhouse=make("Model","Greenhouse (T1)",workspace,{OwnerID=a.UserId})
local bed=make("Model","GardenBed",greenhouse);make("Part","Part",bed)
local well=make("Model","Well",greenhouse);make("Part","Part",well)
'''
cases='''
Service.Start()
assert(Service.Use(a,well) and stock.DirtyWaterBucket==1 and stock.EmptyBucket==0)
assert(Service.Use(a,well) and stock.DirtyWater==1 and stock.EmptyBottle==0)
assert(not Service.Use(a,well),"no free water without an empty container")
assert(Service.Use(a,bed) and stock.Potato==1 and bed:GetAttribute("Crop")=="Potato")
assert(Service.Use(a,bed) and stock.DirtyWaterBucket==0 and stock.EmptyBucket==1)
assert(not Service.Use(a,bed),"growing bed cannot be harvested early or replanted")
clock+=599;assert(not Service.Use(a,bed))
clock+=1;a:SetAttribute("GreenhouseYieldMultiplier",1.5)
assert(Service.Use(a,bed) and stock.Potato==4 and xp==3 and bed:GetAttribute("Crop")=="","owner perk yields three from base two")
equipment.Hands="Knife";assert(not Service.Use(a,bed),"plant/harvest needs empty hands");equipment.Hands=nil
assert(Service.Use(a,bed));assert(not Service.Use(a,bed),"watering requires filled bucket")
a.Character.HumanoidRootPart.Position=Vector3.new(20,0,0)
assert(not Service.Use(a,well),"server rejects distant interaction")
a.Character.HumanoidRootPart.Position=Vector3.zero
a.Character:SetAttribute("Knockout",true);assert(not Service.Use(a,well));a.Character:SetAttribute("Knockout",false)
assert(Rules.Stage(0,4)==1 and Rules.Stage(1,4)==4 and Rules.Stage(.5,0)==nil)
assert(Rules.Yield(3,1.5,.49)==5 and Rules.Yield(3,1.5,.5)==4,"fractional crop bonus unbiased")
print("PASS: actual well containers, planting, watering, growth delay, owner yield, harvest XP, empty hands, range/KO guards and stage/yield rules")
'''
parts=[(root/'tests/fixtures/town_mock.luau').read_text()]
for var,module in [('Config','FarmingConfig'),('Rules','FarmingRules'),('ItemConfig','ItemConfig')]:parts.append('local '+var+'=(function()\n'+(root/f'src/shared/{module}.luau').read_text()+'\nend)()')
parts +=[setup,'local Service=(function()\n'+s+'\nend)()',cases]
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'farm.luau';p.write_text('\n'.join(parts));subprocess.run([sys.argv[1],str(p)],check=True)
