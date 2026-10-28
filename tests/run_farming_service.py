"""Actual farming authority: seed, watering, timing, ownership perk and container safety."""
from pathlib import Path
import re,subprocess,tempfile,sys
root=Path(__file__).resolve().parents[1]
s=(root/'src/server/Services/FarmingService.luau').read_text().replace('local WorldActivity=require(script.Parent.WorldActivityService)', 'local WorldActivity={Register=function() end,IsDormant=function() return false end,Ensure=function() end,DormantNPCs=function() return {} end,Raycast=function() return nil end}')
s=re.sub(r'local (Config|Rules|Interaction|ItemConfig|Inventory|Progression|Journal)=require[^\n]+\n','',s)
setup='''
local warnings={}
local function warn(message) table.insert(warnings,message) end
function cfmeta.__add(a,b) return CFrame.new(a.Position+b) end
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
local xp,practice=0,0;local Progression={FarmXP=function(_,count,bushes) xp+=25*count;practice+=bushes end}
local Journal={Send=function() end}
local Random={new=function() return {NextInteger=function() return 3 end,NextNumber=function() return roll end} end}
local Interaction={NearestPoint=function(model) return model:GetPivot().Position end}
local greenhouse=make("Model","Greenhouse (T1)",workspace,{OwnerID=a.UserId})
local bed=make("Model","GardenBed",greenhouse,{MaxPlants=5,MaxWatering=100});make("Part","Part",bed)
local well=make("Model","Well",greenhouse);make("Part","Part",well)
'''
cases='''
Service.Start()
assert(not Service.Use(a,well),"pocket bucket cannot draw water")
equipment.Hands="EmptyBottle";assert(not Service.Use(a,well),"well requires bucket")
equipment.Hands="EmptyBucket";assert(Service.Use(a,well) and equipment.Hands=="DirtyWaterBucket")
equipment.Hands=nil
assert(Service.Use(a,bed) and bed:GetAttribute("PlantCount")==0,"E opens menu without planting")
assert(not Service.Use(a,bed,"Carrot"),"reject unsupported crop")
assert(Service.Use(a,bed,"Potato") and bed:GetAttribute("PlantCount")==5)
assert(#warnings==1 and string.find(warnings[1],"PotatoStage1"))
local farming=make("Folder","Farming",ServerStorage)
local stages=make("Folder","PotatoStages",farming)
for i=1,4 do local model=make("Model","PotatoStage"..i,stages);make("Part","Leaf",model) end
Service.Step(bed,clock)
local visuals=0
for _,child in ipairs(bed:GetChildren()) do
 if child.Name=="GrowingPotato" then
  visuals+=1;assert(child:GetPivot().Position.Y==1,"crop bottom matches bed top despite center pivot")
 end
end
assert(visuals==5,"missing models are retried")
assert(string.find(bed:GetAttribute("CropDetails"),"Paused"))
stock.DirtyWaterBucket=1
assert(Service.Use(a,bed) and bed:GetAttribute("Watering")==0,"pocket bucket never waters")
equipment.Hands="DirtyWaterBucket";assert(Service.Use(a,bed) and equipment.Hands=="EmptyBucket")
assert(bed:GetAttribute("Watering")==100)
Service.Step(bed,clock);assert(string.find(bed:GetAttribute("CropDetails"),"240s"))
clock+=200;Service.Step(bed,clock)
assert(string.find(bed:GetAttribute("CropDetails"),"Late growth"))
clock+=200;Service.Step(bed,clock)
assert(bed:GetAttribute("ReadyPlants")==5 and bed:GetAttribute("Watering")<.00001)
equipment.Hands=nil;a:SetAttribute("GreenhouseYieldMultiplier",1.5)
assert(Service.Use(a,bed) and stock.Potato==20 and xp==500 and practice==5)
assert(Service.Use(a,bed,"Potato"));roll=0;clock+=60;Service.Step(bed,clock)
assert(bed:GetAttribute("RottenPlants")==5 and string.find(bed:GetAttribute("CropDetails"),"Rotten"))
clock+=1200;Service.Step(bed,clock);assert(bed:GetAttribute("RottenPlants")==5)
assert(Service.Use(a,bed) and bed:GetAttribute("PlantCount")==0 and xp==500 and practice==5,"clearing rotten plants grants no XP")
roll=.9;assert(Service.Use(a,bed,"Potato"));equipment.Hands="EmptyBucket";assert(Service.Use(a,well));assert(Service.Use(a,bed))
clock+=400;Service.Step(bed,clock);assert(bed:GetAttribute("ReadyPlants")==5)
clock+=Config.HarvestSeconds;Service.Step(bed,clock);assert(bed:GetAttribute("RottenPlants")==5)
equipment.Hands="Knife";assert(not Service.Use(a,bed,"Potato"));equipment.Hands=nil
assert(Service.Use(a,bed));equipment.Hands="EmptyBucket";assert(Service.Use(a,well))
bed:SetAttribute("Watering",95);assert(Service.Use(a,bed) and bed:GetAttribute("Watering")==100 and equipment.Hands=="EmptyBucket")
equipment.Hands=nil
a.Character.HumanoidRootPart.Position=Vector3.new(20,0,0);assert(not Service.Use(a,bed,"Potato"))
a.Character.HumanoidRootPart.Position=Vector3.zero;a.Character:SetAttribute("Knockout",true);assert(not Service.Use(a,bed,"Potato"))
print("PASS: menu-only planting, crop validation, held buckets only, surface placement, stage retry, stage/ETA data, water budget, rot, harvest, XP and authority")
'''

parts=[(root/'tests/fixtures/town_mock.luau').read_text()]
for var,module in [('Config','FarmingConfig'),('Rules','FarmingRules'),('ItemConfig','ItemConfig')]:parts.append('local '+var+'=(function()\n'+(root/f'src/shared/{module}.luau').read_text()+'\nend)()')
parts +=[setup,'local Service=(function()\n'+s+'\nend)()',cases]
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'farm.luau';p.write_text('\n'.join(parts));subprocess.run([sys.argv[1],str(p)],check=True)
