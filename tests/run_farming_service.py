"""Actual farming authority: seed, watering, timing, ownership perk and container safety."""
from pathlib import Path
import re,subprocess,tempfile,sys
root=Path(__file__).resolve().parents[1]
s=(root/'src/server/Services/FarmingService.luau').read_text()
s=re.sub(r'local (Config|Rules|Interaction|ItemConfig|Inventory|Progression|Journal)=require[^\n]+\n','',s)
setup='''
workspace.DescendantAdded=event()
a:LoadCharacterAsync()
local stock={EmptyBottle=1,EmptyBucket=1};local equipment={}
local roll=.9
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
local Random={new=function() return {NextInteger=function() return 3 end,NextNumber=function() return roll end} end}
local Interaction={NearestPoint=function(model) return model:GetPivot().Position end}
local greenhouse=make("Model","Greenhouse (T1)",workspace,{OwnerID=a.UserId})
local bed=make("Model","GardenBed",greenhouse,{MaxPlants=5,MaxWatering=100});make("Part","Part",bed)
local well=make("Model","Well",greenhouse);make("Part","Part",well)
'''
cases='''
assert(Config.GrowthSeconds/2==120 and Config.HarvestSeconds==180)
Service.Start()
assert(Service.Use(a,well) and stock.DirtyWaterBucket==1 and stock.EmptyBucket==0)
assert(Service.Use(a,well) and stock.DirtyWater==1 and stock.EmptyBottle==0)
assert(not Service.Use(a,well),"no free water without container")
assert(Service.Use(a,bed) and bed:GetAttribute("PlantCount")==5 and not stock.Potato,"plant five without seeds")
assert(Service.Use(a,bed) and stock.EmptyBucket==1 and bed:GetAttribute("Watering")==100)
clock+=240;Service.Step(bed,clock)
assert(bed:GetAttribute("CropProgress")<1,"low water slows growth")
clock+=160;Service.Step(bed,clock)
assert(bed:GetAttribute("ReadyPlants")==5 and bed:GetAttribute("Watering")<.00001,"five plants consume exactly100 water")
a:SetAttribute("GreenhouseYieldMultiplier",1.5)
assert(Service.Use(a,bed) and stock.Potato==20 and xp==20,"per-bush yield plus owner perk")
assert(bed:GetAttribute("PlantCount")==0)
assert(Service.Use(a,bed));roll=0;clock+=60;Service.Step(bed,clock)
assert(bed:GetAttribute("RottenPlants")==5,"dry bed50% rot check per bush")
clock+=1200;Service.Step(bed,clock);assert(bed:GetAttribute("RottenPlants")==5,"rot never disappears by itself")
assert(Service.Use(a,bed) and stock.Potato==20 and bed:GetAttribute("PlantCount")==0,"clear rot without loot")
roll=.9;assert(Service.Use(a,bed));assert(Service.Use(a,well));assert(Service.Use(a,bed))
clock+=400;Service.Step(bed,clock);assert(bed:GetAttribute("ReadyPlants")==5)
clock+=Config.HarvestSeconds;Service.Step(bed,clock)
assert(bed:GetAttribute("RottenPlants")==5,"uncollected harvest rots")
equipment.Hands="Knife";assert(not Service.Use(a,bed));equipment.Hands=nil
assert(Service.Use(a,bed));assert(Service.Use(a,well));equipment.Hands="DirtyWaterBucket";stock.DirtyWaterBucket=0
bed:SetAttribute("Watering",95);assert(Service.Use(a,bed) and bed:GetAttribute("Watering")==100 and equipment.Hands=="EmptyBucket","bucket caps at max")
equipment.Hands=nil
a.Character.HumanoidRootPart.Position=Vector3.new(20,0,0);assert(not Service.Use(a,well))
a.Character.HumanoidRootPart.Position=Vector3.zero;a.Character:SetAttribute("Knockout",true);assert(not Service.Use(a,well))
for _,case in ipairs({{100,1,0},{80,1,0},{79,1.2,0},{60,1.2,0},{59,1.5,.1},{40,1.5,.1},{39,2,.2},{1,2,.2},{0,math.huge,.5}}) do
 local f,c=Rules.Water(case[1]);assert(f==case[2] and c==case[3])
end
assert(Rules.Stage(0,false)==1 and Rules.Stage(.5,false)==2 and Rules.Stage(1,false)==3 and Rules.Stage(0,true)==4)
assert(Rules.Yield(0,1.5,0)==0 and Rules.Yield(3,1.5,.49)==5 and Rules.Yield(3,1.5,.5)==4)
print("PASS: multi-plant seedless bed, continuous water budget, slowdown tiers, rot/harvest expiry, yield/XP, container caps and authority guards")
'''

parts=[(root/'tests/fixtures/town_mock.luau').read_text()]
for var,module in [('Config','FarmingConfig'),('Rules','FarmingRules'),('ItemConfig','ItemConfig')]:parts.append('local '+var+'=(function()\n'+(root/f'src/shared/{module}.luau').read_text()+'\nend)()')
parts +=[setup,'local Service=(function()\n'+s+'\nend)()',cases]
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'farm.luau';p.write_text('\n'.join(parts));subprocess.run([sys.argv[1],str(p)],check=True)
