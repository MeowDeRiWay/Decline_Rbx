"""Exercise the real crafting service's station permissions, completion XP and output hooks."""
from pathlib import Path
import re
import subprocess
import sys
import tempfile
root=Path(__file__).resolve().parents[1]
service=(root/'src/server/Services/CraftingService.luau').read_text().replace('local WorldActivity=require(script.Parent.WorldActivityService)', 'local WorldActivity={Register=function() end,IsDormant=function() return false end,Ensure=function() end,DormantNPCs=function() return {} end,Raycast=function() return nil end}').replace('local Journal=require(script.Parent.JournalService)', 'local Journal={Send=function() end}')
for variable in ['Inventory','Items','Recipes','Rules','Amounts','Interaction','Progression','ProgressionRules','Stations']:
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
local Progression={Meets=function(_,requirement) if requirement.Skills.Repair then return repair>=requirement.Skills.Repair end;return doctor end,CraftEffects=function(_,station,count) return ProgressionRules.CraftEffects(cookState,station,count) end,CanStation=function(_,name) return name=="Workstation" or allowed end,
 CraftXP=function(_,recipe,count) xp+=ProgressionRules.CraftExperience(recipe,count) end,
 Loot=function(_,items) bonuses+=1; return items end}
local stock={Potato=10,CleanWater=10,TreeLog=5}
function Inventory.Snapshot() return {Items=table.clone(stock),CraftTools={Knife=1,SewingKit=sewing and 1 or nil}} end
function Inventory.ConsumeIngredients(_,recipe,count)
 for id,n in pairs(recipe.Ingredients) do if (stock[id] or 0)<n*count then return false end end
 for id,n in pairs(recipe.Ingredients) do stock[id]-=n*count end
 return true
end
function Inventory.Add(_,id,n) stock[id]=(stock[id] or 0)+n; return true end
'''
cases='''
a:LoadCharacterAsync()
for _,kind in ipairs({"MedStation","Workstation","ArmorStation","WeaponStation","ChemistryStation"}) do
 local station=make("Model","Any convenient model name",workspace)
 station:SetAttribute(kind,false);assert(Stations.Kind(station)==nil,"false attribute is inactive")
 station:SetAttribute(kind,true)
 assert(Stations.Kind(station)==(kind=="WeaponStation" and "ArmsBench" or kind),"Boolean attribute defines station regardless of name")
 station:SetAttribute("StationLevel",99)
 assert(not Stations.Label(station):find("T99",1,true),"station tiers are not displayed")
 station:Destroy()
end
local stove=make("Model","Stove",workspace); make("Part","Part",stove)
local bench=make("Model","Workshop table",workspace,{Workstation=true}); make("Part","Part",bench)
assert(not Service.Open(a,stove),"station requirements block cooking access")
assert(Service.Open(a,bench))
assert(Service.Cook(a,"MakePlanks",1))
Service.Close(a)
callbacks[1]()
assert(stock.TreeLog==5 and xp==0 and bonuses==0,"cancelled crafting refunds ingredients and grants no XP/bonus")
allowed=true
stock.TreeLog=20
assert(Service.Open(a,stove))
assert(not Service.Cook(a,"BoilPotatoes",6))
assert(Service.Cook(a,"BoilPotatoes",5))
assert(not Service.Cook(a,"BoilPotatoes",1),"station remains single-job")
callbacks[2]()
assert(Service.Snapshot(a).CookingReady.BoiledPotato==5 and stock.Potato==5 and stock.CleanWater==5)
assert(xp==250 and bonuses==1,"one specialty XP award and loot roll at successful completion")
cookState.Talents={SurpriseServing=true,GrandmasMethod=true,RamsayMethod=true}
assert(Service.Cook(a,"BoilPotatoes",5))
assert(durations[3]==60,"retired talent cannot speed stove")
callbacks[3]()
assert(Service.Snapshot(a).CookingReady.BoiledPotato==10,"second full batch adds five")
stock.Potato=1; stock.CleanWater=1
assert(Service.Cook(a,"BoilPotatoes",1)); callbacks[4]()
assert(Service.Snapshot(a).CookingReady.BoiledPotato==11,"partial batch has no extra serving")
local board=make("Model","CuttingBoard",workspace); make("Part","Part",board)
stock.Sausage=1
assert(Service.Open(a,board) and Service.Cook(a,"SliceSausage",1))
assert(durations[5]==10,"retired talent cannot speed cutting board")
callbacks[5]()
assert(Service.Snapshot(a).CookingReady.SausageSlice==5,"stove serving talent must not affect board")
assert(xp==600 and bonuses==4)
cookState.Profession="Worker"; cookState.Talents={GoldenHands=10}
assert(Service.Open(a,bench) and Service.Cook(a,"MakePlanks",1))
assert(math.abs(durations[6]-10)<1e-6,"retired crafting perks have no effect")
callbacks[6]()
assert(Service.Snapshot(a).CookingReady.Plank==3 and xp==675,"one log to three boards awards 25 XP per plank")
Service.Close(a);assert(Service.Open(a,bench))
stock.Rags=4;a:SetAttribute("CraftCostMultiplier",.8)
assert(not Service.Cook(a,"MakeBandage",1),"workstation cannot craft medicines")
local med=make("Model","Medical table",workspace,{MedStation=true});make("Part","Part",med)
Service.Close(a);assert(Service.Open(a,med) and Service.Snapshot(a).CookingStation=="MedStation")
assert(not Service.Cook(a,"MakePlanks",1),"medical station cannot craft workshop recipes")
assert(not Service.Cook(a,"MakeBandage",1),"First Aid requirement enforced")
doctor=true
sewing=false;assert(not Service.Cook(a,"MakeBandage",1) and stock.Rags==4,"missing sewing kit consumes nothing");sewing=true
assert(not Service.Cook(a,"MakeBandage",2),"one bandage per queue")
assert(Service.Cook(a,"MakeBandage",1) and stock.Rags==0 and durations[#durations]==20,"discounted rags consumed,20second craft")
callbacks[#callbacks]()
assert(Service.Snapshot(a).CookingReady.Bandage==1,"bandage delivered once at completion")
Service.Close(a);assert(Service.Open(a,stove));stock.Potato=1;stock.CleanWater=1;stock.TreeLog=1;cookState.Ramsay=1
assert(Service.Cook(a,"BoilPotatoes",1));callbacks[#callbacks]()
assert(Service.Snapshot(a).CookingReady.Ramsay_BoiledPotato==1,"cook quality persists in station output")
assert(Service.CollectRecipe(a,"BoilPotatoes","All") and stock.Ramsay_BoiledPotato==1,"collect all preserves Ramsay food variant")
Service.Close(a);assert(Service.Open(a,bench));stock.Scrap=3;a:SetAttribute("CraftCostMultiplier",1)
assert(Recipes.MakeBucket.Requirements.Skills.Repair==100)
repair=99;assert(not Service.Cook(a,"MakeBucket",1),"bucket skill requirement checked")
repair=100;assert(not Service.Cook(a,"MakeBucket",2))
assert(Service.Cook(a,"MakeBucket",1) and stock.Scrap==0 and durations[#durations]==20)
callbacks[#callbacks]();assert(Service.Snapshot(a).CookingReady.EmptyBucket==1,"bucket craft output")
Service.Close(a);assert(Service.Open(a,bench));stock.Cloth=6
repair=99;assert(not Service.Cook(a,"MakeLeatherArmor",1) and stock.Cloth==6)
repair=100;sewing=false;assert(not Service.Cook(a,"MakeLeatherArmor",1) and stock.Cloth==6)
sewing=true;assert(not Service.Cook(a,"MakeLeatherArmor",2))
assert(Service.Cook(a,"MakeLeatherArmor",1) and stock.Cloth==0 and durations[#durations]==60)
assert(a.Character:GetAttribute("CraftingLocked"),"jacket requires presence for the full craft")
callbacks[#callbacks]();assert(Service.Snapshot(a).CookingReady.LeatherArmor==1)
assert(Service.CollectRecipe(a,"MakeLeatherArmor","All") and stock.LeatherArmor==1)
stock.Scrap=5
repair=139;assert(not Service.Cook(a,"MakeLeatherArmor2",1) and stock.LeatherArmor==1 and stock.Scrap==5)
repair=140;sewing=false;assert(not Service.Cook(a,"MakeLeatherArmor2",1) and stock.LeatherArmor==1 and stock.Scrap==5)
sewing=true;assert(Service.Cook(a,"MakeLeatherArmor2",1) and stock.LeatherArmor==0 and stock.Scrap==0 and durations[#durations]==60)
callbacks[#callbacks]();assert(Service.Snapshot(a).CookingReady.LeatherArmor2==1)
assert(Service.CollectRecipe(a,"MakeLeatherArmor2","All") and stock.LeatherArmor2==1)
print("PASS: station permissions, retired perk effects absent, fixed timing/outputs, batches, refunds and completion XP")
repair=99
Progression.Meets=function(_,requirement)
 return not requirement.Skills.Repair or repair>=requirement.Skills.Repair
end
Service.Close(a);assert(Service.Open(a,bench));stock.Scrap=100;stock.Coal=10;stock.Chemicals=10
stock.Plank=10
for id,required in pairs({MakePistol9mm=100,MakeSMG9mm=120,MakePipePistol9mm=60,MakePipeRifle9mm=60}) do
 local recipe=Recipes[id];stock.TreeLog=1
 local oldScrap,oldPlank=stock.Scrap,stock.Plank
 repair=required-1;assert(not Service.Cook(a,id,1) and stock.Scrap==oldScrap and stock.Plank==oldPlank and stock.TreeLog==1)
 repair=required;assert(Service.Cook(a,id,1));callbacks[#callbacks]()
 assert(Service.Snapshot(a).CookingReady[recipe.Output]==1)
 assert(stock.Scrap==oldScrap-recipe.Ingredients.Scrap)
 if id=="MakePipePistol9mm" or id=="MakePipeRifle9mm" then
  assert(stock.TreeLog==0 and stock.Plank==oldPlank,"pipe guns consume a log, not a plank")
 else assert(stock.Plank==oldPlank-1) end
end
stock.Scrap=100;repair=59
assert(not Service.Cook(a,"MakeAmmo9mm",1) and stock.Scrap==100)
repair=60
local before=xp
assert(Service.Cook(a,"MakeAmmo9mm",1) and stock.Scrap==99 and stock.Coal==9 and stock.Chemicals==9)
callbacks[#callbacks]();assert(xp==before+100 and Service.Snapshot(a).CookingReady.Ammo9mmFMJ==50)
stock.Iron=100;stock.Plank=20
repair=149;assert(not Service.Cook(a,"MakeAmmo223",1));repair=150
for _,id in ipairs({"MakeAmmo223","MakeRifle223"}) do
 before=xp;local recipe=Recipes[id]
 assert(Service.Cook(a,id,1));callbacks[#callbacks]()
 assert(xp==before+recipe.XP and Service.Snapshot(a).CookingReady[recipe.Output]==recipe.OutputCount)
end
assert(not Service.Cook(a,"MakeMarksmanRifle223",1),"marksman rifle requires arms bench")
local arms=make("Model","Custom weapons machine",workspace,{WeaponStation=true});make("Part","Part",arms)
Service.Close(a);assert(Service.Open(a,arms))
for _,id in ipairs({"MakeAssaultRifle223","MakeLSW223","MakeServiceRifle223","MakeMarksmanRifle223"}) do
 before=xp;local recipe=Recipes[id]
 assert(Service.Cook(a,id,1));callbacks[#callbacks]()
 assert(xp==before+recipe.XP and Service.Snapshot(a).CookingReady[recipe.Output]==recipe.OutputCount)
end
assert(stock.Iron==70 and not Service.Cook(a,"MakePistol9mm",1))
stock.Cloth=5;stock.Chemicals=1;repair=100;sewing=false
assert(not Service.Cook(a,"MakeKevlar",1) and stock.Cloth==5 and stock.Chemicals==1)
sewing=true;assert(Service.Cook(a,"MakeKevlar",1) and stock.Cloth==0 and stock.Chemicals==0 and durations[#durations]==60)
callbacks[#callbacks]();assert(Service.Snapshot(a).CookingReady.Kevlar==5)
assert(Service.CollectRecipe(a,"MakeKevlar","All") and stock.Kevlar==5)
stock.Kevlar=6;stock.Iron=3;repair=174
assert(not Service.Cook(a,"MakeMiliArmor1",1) and stock.Kevlar==6 and stock.Iron==3)
repair=175;assert(Service.Cook(a,"MakeMiliArmor1",1) and stock.Kevlar==0 and stock.Iron==0 and durations[#durations]==60)
callbacks[#callbacks]();assert(Service.Snapshot(a).CookingReady.MiliArmor1==1)
assert(Service.CollectRecipe(a,"MakeMiliArmor1","All") and stock.MiliArmor1==1)
stock.Kevlar=2;stock.Iron=3;repair=199
assert(not Service.Cook(a,"MakeMiliArmor2",1) and stock.MiliArmor1==1 and stock.Kevlar==2 and stock.Iron==3)
repair=200;sewing=false
assert(not Service.Cook(a,"MakeMiliArmor2",1) and stock.MiliArmor1==1)
sewing=true
assert(Service.Cook(a,"MakeMiliArmor2",1) and stock.MiliArmor1==0 and stock.Kevlar==0 and stock.Iron==0 and durations[#durations]==60)
Service.Close(a)
assert(stock.MiliArmor1==1 and stock.Kevlar==2 and stock.Iron==3,"cancelled upgrade returns original armor and materials")
assert(Service.Open(a,arms) and Service.Cook(a,"MakeMiliArmor2",1))
callbacks[#callbacks]();assert(Service.Snapshot(a).CookingReady.MiliArmor2==1)
assert(Service.CollectRecipe(a,"MakeMiliArmor2","All") and stock.MiliArmor2==1 and stock.MiliArmor1==0)
local workshop=make("Model","Workbench (T2)",workspace,{BuildingID="Workbench",BuildingLevel=1})
local furnace=make("Model","Furnace",workshop);make("Part","Part",furnace)
Service.Close(a);assert(Service.Open(a,furnace));stock.Scrap=25;stock.Coal=1
assert(not Service.Cook(a,"SmeltIron",1),"tier1 cannot smelt iron")
workshop:SetAttribute("BuildingLevel",2)
assert(Service.Snapshot(a).CookingWorkshopLevel==2 and Service.Cook(a,"SmeltIron",5))
assert(stock.Scrap==0 and stock.Coal==0 and durations[#durations]==120 and not Service.Snapshot(a).CookingRequiresPresence)
Service.Close(a);a.Character.HumanoidRootPart.Position=Vector3.new(100,0,0)
callbacks[#callbacks]();a.Character.HumanoidRootPart.Position=Vector3.zero
assert(Service.Open(a,furnace) and Service.Snapshot(a).CookingReady.Iron==5,"furnace completes after closing and leaving")
assert(Service.CollectRecipe(a,"SmeltIron","All") and stock.Iron==5)
stock.TreeLog=5;stock.Coal=0
assert(Service.Cook(a,"BurnLogs",5) and durations[#durations]==60);Service.Close(a);callbacks[#callbacks]()
assert(Service.Open(a,furnace) and Service.Snapshot(a).CookingReady.Coal==5)
assert(Service.CollectRecipe(a,"BurnLogs","All") and stock.Coal==5)
stock.TreeLog=5
assert(Service.Cook(a,"BurnLogsWithCoal",5) and stock.Coal==4 and durations[#durations]==30)
Service.Close(a);callbacks[#callbacks]();assert(Service.Open(a,furnace) and Service.Snapshot(a).CookingReady.Coal==5)
Service.Close(a);assert(Service.Open(a,stove));stock.TreeLog=1;stock.Potato=5;stock.CleanWater=5;cookState.Ramsay=1
assert(Service.Cook(a,"BoilPotatoes",5));Service.Close(a);callbacks[#callbacks]()
assert(Service.Open(a,stove) and Service.Snapshot(a).CookingReady.Coal==1 and Service.Snapshot(a).CookingReady.Ramsay_BoiledPotato==5,"charcoal byproduct cannot become a food quality alias")
assert(Service.CollectRecipe(a,"BoilPotatoes","All"))
stock.Potato=5;stock.CleanWater=5;stock.TreeLog=0;stock.Coal=1
assert(not Service.Cook(a,"BoilPotatoes",5),"no unfueled boiling bypass")
assert(Service.Cook(a,"BoilPotatoesCoal",5) and stock.Coal==0 and durations[#durations]==30)
Service.Close(a);callbacks[#callbacks]();assert(Service.Open(a,stove))
assert(Service.Snapshot(a).CookingReady.Ramsay_BoiledPotato==5 and not Service.Snapshot(a).CookingReady.Coal,"coal cooks twice as fast without producing charcoal")
print("PASS: one fuel for five servings, one wood charcoal byproduct, wood60s versus coal30s, no unfueled bypass")
Service.Close(a);assert(Service.Open(a,bench))
for id,required in pairs({MakeBackpack1=60,MakeSewingKit=60,MakeAxe=60,MakeShovel=60,MakeScrapAxe=100,MakeScrapShovel=100,MakeKnife=100,MakeBucket=100,MakeHandle=60,MakePlanks=60}) do
 for item,count in pairs(Recipes[id].Ingredients) do stock[item]=count end
 repair=required-1
 assert(not Service.Cook(a,id,1),id.." must reject Repair one below threshold")
 for item,count in pairs(Recipes[id].Ingredients) do assert(stock[item]==count,"failed Repair check consumes nothing") end
 repair=required
 assert(Service.Cook(a,id,1),id.." must accept exact Repair threshold");callbacks[#callbacks]()
end
print("PASS: actual tool/component craft Repair boundaries60/100 and no ingredients lost on rejection")
stock.Cloth=3;repair=60;sewing=false
assert(not Service.Cook(a,"MakeBackpack1",1) and stock.Cloth==3,"backpack requires reusable sewing kit")
sewing=true;assert(Service.Cook(a,"MakeBackpack1",1) and stock.Cloth==0 and durations[#durations]==60)
callbacks[#callbacks]();assert(Service.Snapshot(a).CookingReady.Backpack1==2)
assert(Service.CollectRecipe(a,"MakeBackpack1","All") and stock.Backpack1==2)
print("PASS: starter backpack uses three cloth, Repair60, reusable kit and sixty seconds; kit itself unlocks at60")
print("PASS: industrial recipe inputs, Repair gates, exact XP/output, town/factory separation, Furnace T2 gate, unattended processing, charcoal fuel and food byproducts")

'''
station_source='local Stations=(function()\n'+(root/'src/shared/CraftStations.luau').read_text()+'\nend)()'
parts=[(root/'tests/fixtures/town_mock.luau').read_text(),station_source,'local ProgressionRules=(function()\n'+(root/'src/shared/ProgressionRules.luau').read_text()+'\nend)()',setup]
for variable,file in [('Items','ItemConfig'),('Recipes','CraftConfig'),('Rules','CraftRules'),('Amounts','InventoryRules')]:
 parts.append(f'local {variable}=(function()\n'+(root/f'src/shared/{file}.luau').read_text()+'\nend)()')
parts.extend(['local Service=(function()\n'+service+'\nend)()',cases])
with tempfile.TemporaryDirectory(prefix='decline-cooking-') as directory:
 path=Path(directory)/'test.luau';path.write_text('\n'.join(parts))
 subprocess.run([sys.argv[1] if len(sys.argv)>1 else 'luau',str(path)],check=True)
