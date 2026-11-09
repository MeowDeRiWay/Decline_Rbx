"""Exercise the real crafting service's station permissions, completion XP and output hooks."""
from pathlib import Path
import re
import subprocess
import sys
import tempfile
root=Path(__file__).resolve().parents[1]
service=(root/'src/server/Services/CraftingService.luau').read_text().replace('local WorldActivity=require(script.Parent.WorldActivityService)', 'local WorldActivity={Register=function() end,IsDormant=function() return false end,Ensure=function() end,DormantNPCs=function() return {} end,Raycast=function() return nil end}').replace('local Journal=require(script.Parent.JournalService)', 'local Journal={Send=function() end}')
for variable in ['Inventory','Items','Recipes','Rules','Amounts','Interaction','Progression','ProgressionRules','Stations','Chests','Supply']:
 service=re.sub(rf'local {variable}=require\([^\n]+\)\n','',service)
setup='''
local baseNew=Instance.new
function Instance.new(class)
 local object=baseNew(class)
 if class=="BindableEvent" then object.Event=event(); object.Fire=function(self,...) self.Event:Fire(...) end end
 return object
end

local callbacks,durations={},{}
function task.delay(duration,fn) table.insert(callbacks,fn); table.insert(durations,duration) end
local cookState={Profession="Cook",Talents={}}
local allowed=false
local doctor=false
local sewing=true
local repair=300
local xp,bonuses=0,0
local Progression={Meets=function(_,requirement) if requirement.Skills.Repair then return repair>=requirement.Skills.Repair end;if requirement.Skills.Cook then return true end;return doctor end,CraftEffects=function(_,station,count) return ProgressionRules.CraftEffects(cookState,station,count) end,CanStation=function(_,name) return name=="Workstation" or allowed end,
 CraftXP=function(_,recipe,count) xp+=ProgressionRules.CraftExperience(recipe,count) end,
 Loot=function(_,items) bonuses+=1; return items end}
local stock={Potato=10,CleanWater=10,TreeLog=5}
local own={Items=stock,Conditions={},Weapons={},Equipment={SecondaryWeapon="ScrapKnife"},EquipmentCondition={SecondaryWeapon=500},EquipmentWeapon={}}
function Inventory.Export() stock.SewingKit=sewing and math.max(stock.SewingKit or 0,1) or nil;return own end
function Inventory.Refresh() end
local Chests={CraftSources=function() return {} end,CraftChanged=function() end,CraftRefundTarget=function(source) return source.State end}
function Inventory.Snapshot() return {Items=table.clone(stock),CraftTools={Knife=1,SewingKit=sewing and 1 or nil}} end
function Inventory.ConsumeIngredients(_,recipe,count)
 for id,n in pairs(recipe.Ingredients) do if (stock[id] or 0)<n*count then return false end end
 for id,n in pairs(recipe.Ingredients) do stock[id]-=n*count end
 return true
end
function Inventory.Add(_,id,n) stock[id]=(stock[id] or 0)+n; return true end
'''
cases='''
a:LoadCharacterAsync();a.Character.HumanoidRootPart.Anchored=false
allowed=true;doctor=true
local medicalSkills={Cook=300,FirstAid=300,Doctor=300}
Progression.Meets=function(_,requirement)
 for skill,value in pairs(requirement.Skills or {}) do
  if (skill=="Repair" and repair or medicalSkills[skill] or 0)<value then return false end
 end
 return true
end
local bench=make("Model","Bench",workspace,{Workstation=true});make("Part","Part",bench)
local stove=make("Model","Stove",workspace);make("Part","Part",stove)
local board=make("Model","CuttingBoard",workspace);make("Part","Part",board)
local med=make("Model","MedStation",workspace);make("Part","Part",med)
local arms=make("Model","ArmsBench",workspace);make("Part","Part",arms)
local workshop=make("Model","Workbench (T2)",workspace,{BuildingID="Workbench",BuildingLevel=2})
local furnace=make("Model","Furnace",workshop);make("Part","Part",furnace)
local stations={Workstation=bench,Stove=stove,CuttingBoard=board,MedStation=med,ArmsBench=arms,Furnace=furnace}
local function fill(recipe,repeats)
 table.clear(stock);sewing=true;repair=300
 for key in pairs(medicalSkills) do medicalSkills[key]=300 end
 for id,count in pairs(recipe.Ingredients) do stock[id]=count*repeats end
 for _,group in ipairs(recipe.IngredientGroups or {}) do stock[group.IDs[1]]=group.Count*repeats end
 if recipe.Fuel then stock[recipe.Fuel.ID]=(stock[recipe.Fuel.ID] or 0)+recipe.Fuel.Count*repeats end
 if recipe.Variants then stock[recipe.Variants[1].Ingredient]=repeats end
end
local requirements={MakeSurgicalKit=100,MakePlate=25,MakeBucket=50,MakePistol9mm=75,MakeSMG9mm=90,MakeAmmo9mm=50,MakeAmmo223=100,MakeRifle223=100,MakeServiceRifle223=110,MakeAssaultRifle223=120,MakeMarksmanRifle223=130,MakeLSW223=140,MakeLeatherArmor=60,MakeLeatherArmor2=80,MakeMiliArmor1=100,MakeMiliArmor2=130,MakeScrapAxe=50,MakeScrapShovel=50,MakeKnife=50,MakeIronKnife=100,MakeSteelKnife=150,MakeSewingKit=50,MakeBackpack1=50,MakeHandle=50,MakePlanks=50}
for id,threshold in pairs(requirements) do
 local recipe=Recipes[id];assert(recipe.Requirements.Skills.Repair==threshold)
 Service.Close(a);fill(recipe,2);assert(Service.Open(a,stations[recipe.Station]))
 repair=threshold-1
 assert(not Service.Cook(a,id,{Batch=1,Repeats=2}),id.." rejects one below repair")
 for input,count in pairs(recipe.Ingredients) do assert(stock[input]==count*2) end
 repair=threshold
 local before=xp
 assert(Service.Cook(a,id,{Batch=1,Repeats=2}),id.." starts at exact repair")
 assert(a.Character:GetAttribute("CraftingLocked") and a.Character.HumanoidRootPart.Anchored)
 callbacks[#callbacks]();assert(stock[recipe.Output]==recipe.OutputCount+(recipe.Output=="SewingKit" and 1 or 0),"first item is delivered automatically: "..id)
 callbacks[#callbacks]();assert(stock[recipe.Output]==2*recipe.OutputCount+(recipe.Output=="SewingKit" and 1 or 0) and xp==before+2*ProgressionRules.CraftExperience(recipe,1))
 assert(not a.Character:GetAttribute("CraftingLocked") and not a.Character.HumanoidRootPart.Anchored)
end
for id,entry in pairs({MakeBandage={"FirstAid",50},MakeGreatBandage={"FirstAid",75},MakeSterileBandage={"FirstAid",100},MakeAntiseptic={"Doctor",50},SliceSausage={"Cook",50},MashedPotatoesWithSausage={"Cook",60}}) do
 local recipe=Recipes[id];Service.Close(a);fill(recipe,1);assert(Service.Open(a,stations[recipe.Station]))
 medicalSkills[entry[1]]=entry[2]-1;assert(not Service.Cook(a,id,1))
 medicalSkills[entry[1]]=entry[2];assert(Service.Cook(a,id,1));callbacks[#callbacks]()
end
for _,id in ipairs({"BoilPotatoes","BoilPotatoesCoal","BoilWater","BurnLogs","BurnWoodParts","SmeltIron","SmeltSteel"}) do
 local recipe=Recipes[id]
 assert(recipe.Automated and recipe.FixedBatch and not recipe.ManualBatch and recipe.MaxBatch==1 and recipe.OutputCount==((id=="BurnLogs" or id=="BurnWoodParts") and 1 or 5),id)
 Service.Close(a);fill(recipe,1);assert(Service.Open(a,stations[recipe.Station]))
 assert(not Service.Cook(a,id,5) and not Service.Cook(a,id,{Batch=1,Repeats=2}),"processing cannot queue or resize batch")
 local ingredient=next(recipe.Ingredients) or recipe.IngredientGroups[1].IDs[1];local amount=stock[ingredient]
 stock[ingredient]=amount-1;assert(not Service.Cook(a,id,1),"partial input rejected");stock[ingredient]=amount
 if recipe.Requirements and recipe.Requirements.Skills.Cook then medicalSkills.Cook=49;assert(not Service.Cook(a,id,1));medicalSkills.Cook=50 end
 if recipe.Requirements and recipe.Requirements.Skills.Doctor then medicalSkills.Doctor=49;assert(not Service.Cook(a,id,1));medicalSkills.Doctor=50 end
 if recipe.WorkshopLevel then workshop:SetAttribute("BuildingLevel",1);assert(not Service.Cook(a,id,1));workshop:SetAttribute("BuildingLevel",2) end
 local before=xp
 assert(Service.Cook(a,id,1) and not a.Character.HumanoidRootPart.Anchored)
 Service.Close(a);callbacks[#callbacks]();assert(Service.Open(a,stations[recipe.Station]))
 assert(stock[recipe.Output]==recipe.OutputCount and next(Service.Snapshot(a).CookingReady)==nil,"automatic delivery while away")
 assert(xp==before+ProgressionRules.CraftExperience(recipe,1))
 fill(recipe,1)
 assert(Service.Cook(a,id,1));local stale=callbacks[#callbacks]
 assert(Service.Cancel(a));stale();assert(next(Service.Snapshot(a).CookingReady)==nil,"cancelled timer produces nothing")
end
-- Two stove processes maximum; furnaces retain the workbench queue limit.
for _,id in ipairs({"BoilPotatoes","SmeltIron"}) do
 local recipe=Recipes[id];Service.Close(a);fill(recipe,3);assert(Service.Open(a,stations[recipe.Station]))
 local limit=recipe.Station=="Stove" and 2 or Rules.MaxQueue
 assert(Service.Snapshot(a).CookingMaxQueue==limit)
 if limit==2 then assert(not Service.Cook(a,id,{Batch=1,Repeats=3})) end
 assert(Service.Cook(a,id,{Batch=1,Repeats="All"}))
 assert(Service.Snapshot(a).CookingQueueTotal==(limit==2 and 2 or 3))
 Service.Close(a)
 for i=1,(limit==2 and 2 or 3) do callbacks[#callbacks]() end
 assert(stock[recipe.Output]==recipe.OutputCount*(limit==2 and 2 or 3))
end
assert(Recipes.BoilPotatoes.Ingredients.Potato==5 and Recipes.BoilPotatoes.Ingredients.CleanWater==1)
local fixed=Rules.Discount(Recipes.BoilPotatoes,.8)
assert(fixed.Ingredients.Potato==5 and fixed.Ingredients.CleanWater==1,"fixed processing amounts cannot shrink")
local recipe=Recipes.BoilPotatoes;Service.Close(a);fill(recipe,1);cookState.Ramsay=1
assert(Service.Open(a,stove) and Service.Cook(a,"BoilPotatoes",1));callbacks[#callbacks]()
local ready=Service.Snapshot(a).CookingReady
assert(stock.Ramsay_BoiledPotato==5 and stock.Coal==1 and not stock.Ramsay_Coal)
assert(not Service.CollectAll(a))
Service.Close(a);fill(Recipes.MakePlanks,2);assert(Service.Open(a,bench))
assert(Service.Cook(a,"MakePlanks",{Batch=1,Repeats=2}));local stale=callbacks[#callbacks];local before=xp
Service.Close(a);stale()
assert(stock.TreeLog==2 and not stock.Plank and xp==before and not a.Character.HumanoidRootPart.Anchored,"leaving item crafts cancels/refunds queue")
print("PASS: repair/medical/cook boundaries, regular presence queues with auto delivery, fixed stove/furnace batches, bounded unattended queues and automatic delivery, T2 furnace, exact potato/water/fuel, quality, XP and cancellation")
'''
station_source='local Stations=(function()\n'+(root/'src/shared/CraftStations.luau').read_text()+'\nend)()'
parts=[(root/'tests/fixtures/town_mock.luau').read_text(),station_source,'local ProgressionRules=(function()\n'+(root/'src/shared/ProgressionRules.luau').read_text()+'\nend)()',setup]
for variable,file in [('Items','ItemConfig'),('Recipes','CraftConfig'),('Rules','CraftRules'),('Amounts','InventoryRules')]:
 parts.append(f'local {variable}=(function()\n'+(root/f'src/shared/{file}.luau').read_text()+'\nend)()')
parts.extend(['local Supply=(function()\n'+(root/'src/shared/CraftSupply.luau').read_text().replace('local Inventory=require(script.Parent.InventoryRules)','local Inventory=Amounts')+'\nend)()', 'local Service=(function()\n'+service+'\nend)()',cases])
with tempfile.TemporaryDirectory(prefix='decline-cooking-') as directory:
 path=Path(directory)/'test.luau';path.write_text('\n'.join(parts))
 subprocess.run([sys.argv[1] if len(sys.argv)>1 else 'luau',str(path)],check=True)
