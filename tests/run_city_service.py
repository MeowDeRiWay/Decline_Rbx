"""Exercise actual generator service with mock Instances and geometry."""
from pathlib import Path
import tempfile
import subprocess
import sys
root=Path(__file__).resolve().parents[1]
mock=(root/'tests/fixtures/town_mock.luau').read_text()
geometry=(root/'tests/city_geometry.fixture.luau').read_text()
service=(root/'src/server/Services/CityGenerationService.luau').read_text().replace('local WorldActivity=require(script.Parent.WorldActivityService)', 'local WorldActivity={Register=function() end,IsDormant=function() return false end,Ensure=function() end,DormantNPCs=function() return {} end,Raycast=function() return nil end}')
service=service.replace('local Config = require(ReplicatedStorage.Shared.CityGenerationConfig)','')
service=service.replace('local Rules = require(ReplicatedStorage.Shared.CityGenerationRules)','')
service=service.replace('local Furniture=require(script.Parent.StoreFurnitureService)','')
service=service.replace('local Walls=require(script.Parent.WallReplacementService)','')
service=service.replace('local Placement=require(script.Parent.StaticPlacement)','')
furniture=(root/'src/server/Services/StoreFurnitureService.luau').read_text().replace('local Rules=require(ReplicatedStorage.Shared.CityGenerationRules)','')
cases='''
assert(Config.ZoneLoadSeconds==10)
-- Legacy placement/geometry regressions run without pacing; timed cases below
-- restore the real setting and exercise the scheduler with a controlled clock.
Config.ZoneLoadSeconds=0
local observer=make("Player","Observer",Players)
observer.Character=make("Model","ObserverCharacter",workspace)
local observerRoot=make("Part","HumanoidRootPart",observer.Character);observerRoot.Position=Vector3.zero
local observerHP=make("Humanoid","Humanoid",observer.Character);observerHP.Health=100
assert(Config.StoreChance==.05)
local library=make("Folder","CityGeneration",ServerStorage)
local templates=make("Folder","Houses",library)
local house=make("Model","Any House Name",templates,{ZHouse=true,ZNumber=2})
house.CFrame=CFrame.new(Vector3.new(40,1,30))
local yard=make("Model","Yard",house)
yard.CFrame=CFrame.new(Vector3.new(43,0,37)); yard.Size=Vector3.new(20,.2,20)
make("Part","Part",yard)
local wallLibrary=make("Folder","Walls",library)
local wall=make("Model","Wall (brick)",wallLibrary,{BlocksVision=true})
local wallYard=make("Model","WallYard",wall);make("Part","Part",wallYard)
local wallMarker=make("Model","WallPlacer",house,{Replace="Wall (brick)"})
local wallTarget=make("Model","YardPlacer",wallMarker);make("Part","Part",wallTarget)
local road=make("Model","Custom Road Name",workspace,{Road=true})
road.CFrame=CFrame.new(Vector3.new(0,0,30)); road.Size=Vector3.new(20,.2,20)
make("Part","Part",road)
local plot=make("Model","YardPlace",workspace,{ForZHouse=true})
plot.CFrame=CFrame.new(Vector3.new(0,0,0)); plot.Size=Vector3.new(20,.2,20)
local marker=make("Part","Part",plot)
Service.Start()
local generated=workspace.GeneratedCityHouses
assert(#generated:GetChildren()==1,"one template placed for one plot")
assert(plot.GeneratedHouse.Value==generated:GetChildren()[1])
assert(marker.Transparency==1 and marker.CanQuery==false and marker.CanCollide==false,"placeholder hidden and disabled")
local built=generated:GetChildren()[1]
assert(built:GetAttribute("ZNumber")==2 and built:GetAttribute("ZHouse"),"house attributes preserved")
assert(built.Yard.Part.Transparency==1,"template yard marker is hidden")
assert(built:FindFirstChild("Wall (brick)") and not built:FindFirstChild("WallPlacer"),"house wall pieces replaced before the clone enters workspace")
assert(house:FindFirstChild("WallPlacer"),"house template keeps reusable markers")
Service.Generate(); Service.Start()
assert(#generated:GetChildren()==1,"repeated Generate/Start must not duplicate house")
plot:Destroy(); Service.Generate()
assert(#generated:GetChildren()==0,"removing source plot removes generated house")
local stores=make("Folder","Stores",library)
local shop=make("Model","StoreA",stores)
shop.CFrame=CFrame.new(Vector3.new(40,1,30))
local shopYard=make("Model","Yard",shop); shopYard.CFrame=CFrame.new(Vector3.zero); shopYard.Size=Vector3.new(20,.2,20)
make("Part","Part",shopYard)
local furnishings=make("Folder","StoreFurniture",library)
local shelf=make("Model","Shelf",furnishings)
shelf.CFrame=CFrame.new(Vector3.new(2,1,3)); shelf.Size=Vector3.new(1,2,1)
local shelfPart=make("Part","Part",shelf); shelfPart.CFrame=shelf.CFrame; shelfPart.Size=shelf.Size
local placer=make("Model","AutoPlacer",shop,{StoreFurniture="Shelf"})
placer.CFrame=cf(Vector3.new(0,0,0),math.pi/2); placer.Size=Vector3.new(1,.2,10)
make("Part","Part",placer)
Config.StoreChance=1
local yardFolder=make("Folder","Yards",workspace)
local shopPlot=make("Model","YardPlace",yardFolder,{ForZHouse=true})
shopPlot.Size=Vector3.new(20,.2,20); make("Part","Part",shopPlot)
Service.Generate()
local store=shopPlot.GeneratedHouse.Value
assert(store:GetAttribute("GenerationCategory")=="Stores" and not store:GetAttribute("ZHouse"),"store templates do not require zombie-house flag")
assert(store.AutoPlacer:GetAttribute("FurnitureCount")==10)
assert(#store.AutoPlacer.GeneratedFurniture:GetChildren()==10)
assert(store.AutoPlacer.Part.CanQuery==false and store.AutoPlacer.Part.Transparency==1)
for _,object in ipairs(store.AutoPlacer.GeneratedFurniture:GetChildren()) do
 assert(object.Part.Anchored and object.Part.Transparency~=1,"furniture anchored and not hidden with marker")
end
Service.Generate()
assert(#store.AutoPlacer.GeneratedFurniture:GetChildren()==10,"no duplicate shelves on retry")
assert(shopPlot.GeneratedHouse.Value==store,"no category reroll for filled plot")
shopPlot:Destroy(); Service.Generate()
assert(store.destroyed,"store and contained furniture removed with plot")
stores:Destroy()
local fallback=make("Model","YardPlace",yardFolder,{ForZHouse=true}); fallback.Size=Vector3.new(20,.2,20); make("Part","Part",fallback)
Service.Generate()
assert(fallback.GeneratedHouse.Value:GetAttribute("GenerationCategory")=="Houses","missing store library falls back to a usable house")
local standalone=make("Part","AutoPlacer",workspace,{StoreFurniture="MissingShelf"}); standalone.CFrame=CFrame.new(); standalone.Size=Vector3.new(1,.2,1)
Furniture.Fill(standalone); assert(not standalone:FindFirstChild("GeneratedFurniture"))
local missing=make("Model","MissingShelf",furnishings); missing.CFrame=CFrame.new(); missing.Size=Vector3.new(1,1,1); local missingPart=make("Part","Part",missing); missingPart.CFrame=missing.CFrame; missingPart.Size=missing.Size
Furniture.Fill(standalone); assert(#standalone.GeneratedFurniture:GetChildren()==1,"missing furniture can be supplied on a later retry")
local general=make("Folder","Furniture",library)
local chair=make("Part","Chair",general);chair.CFrame=CFrame.new();chair.Size=Vector3.new(1,1,1)
chair:SetAttribute("SourceLibrary","Furniture")
local chairMarker=make("Part","AutoPlacer",workspace,{StoreFurniture="Chair"});chairMarker.CFrame=CFrame.new();chairMarker.Size=Vector3.new(1,.2,1)
Furniture.Fill(chairMarker)
assert(chairMarker.GeneratedFurniture:GetChildren()[1]:GetAttribute("SourceLibrary")=="Furniture","AutoPlacer selects named furniture from the general library")
assert(chairMarker.GeneratedFurniture:GetChildren()[1]:GetAttribute("Furniture")==true,"generated furniture is marked for pickup ray exclusion")
Furniture.Fill(chairMarker);assert(#chairMarker.GeneratedFurniture:GetChildren()==1,"general furniture is not duplicated on retry")
local same=make("Part","Chair",furnishings);same.CFrame=CFrame.new();same.Size=Vector3.new(1,1,1);same:SetAttribute("SourceLibrary","StoreFurniture")
local sameMarker=make("Part","AutoPlacer",workspace,{StoreFurniture="Chair"});sameMarker.CFrame=CFrame.new();sameMarker.Size=Vector3.new(1,.2,1)
Furniture.Fill(sameMarker)
assert(sameMarker.GeneratedFurniture:GetChildren()[1]:GetAttribute("SourceLibrary")=="StoreFurniture","existing store library wins duplicate names")
print("PASS: store choice, nested plots, furniture fill/anchoring, missing-template fallback and retry idempotence")
local factories=make("Folder","Factories",library)
local factory=make("Model","FactoryA",factories,{ForInfrastructure=true})
factory.CFrame=CFrame.new(Vector3.zero);factory.Size=Vector3.new(40,5,40)
local factoryYard=make("Model","Yard",factory);factoryYard.CFrame=CFrame.new(Vector3.zero);factoryYard.Size=Vector3.new(40,.2,40);make("Part","Part",factoryYard)
local large=make("Model","InfrastructurePlace",workspace,{ForInfrastructure=true});large.CFrame=CFrame.new(Vector3.new(100,0,0));large.Size=Vector3.new(40,.2,40);make("Part","Part",large)
Service.Generate()
assert(large.GeneratedHouse.Value:GetAttribute("GenerationCategory")=="Factories" and large.GeneratedHouse.Value.Name=="FactoryA")
local same=large.GeneratedHouse.Value
local buildingCount=#generated:GetChildren()
-- Reproduce the screenshots: the source factory was also tagged as a plot.
-- Retag the clone to cover an already-generated building and nested marker too.
same:SetAttribute("ForInfrastructure",true);same.Yard:SetAttribute("ForInfrastructure",true)
for _=1,5 do Service.Generate() end
assert(large.GeneratedHouse.Value==same and #generated:GetChildren()==buildingCount,"tagged factory and its inner Yard must never become new plots")
assert(not same:FindFirstChild("GeneratedHouse") and not same.Yard:FindFirstChild("GeneratedHouse"),"no recursive factories inside generated buildings")
assert(factory:GetAttribute("ForInfrastructure"),"template attributes are not mutated")
local small=make("Model","YardPlace",workspace,{ForZHouse=true,GenerationCategory="Factories"});small.CFrame=CFrame.new(Vector3.new(200,0,0));small.Size=Vector3.new(20,.2,20);make("Part","Part",small)
Service.Generate();assert(not small:FindFirstChild("GeneratedHouse"),"40x40 factory cannot fit a 20x20 plot or fall back to a house")
large:Destroy();Service.Generate();assert(same.destroyed)
print("PASS:40x40 infrastructure factory, explicit category, footprint rejection, idempotence and removal")

print("PASS: template discovery by attribute, placement, source references, hidden markers, ZNumber preservation, idempotence and removed-plot cleanup")
-- Retry ticks must not fall back to a full Workspace scan.
local scans=0
local originalDescendants=workspace.GetDescendants
workspace.GetDescendants=function(self) scans+=1;return originalDescendants(self) end
for _=1,3 do Service.Generate(true) end
assert(scans==0,"incremental retries never enumerate the world")
local namedMarker=make("Part","KitchenChairs",workspace,{StoreFurniture="Chair"})
namedMarker.CFrame=CFrame.new();namedMarker.Size=Vector3.new(1,.2,1)
workspace.DescendantAdded:Fire(namedMarker)
Service.Generate(true);assert(not namedMarker:FindFirstChild("GeneratedFurniture"),"template selector alone is not a placer")
namedMarker:SetAttribute("AutoPlacer",true)
Service.Generate(true)
assert(namedMarker:FindFirstChild("GeneratedFurniture"),"late Boolean marker attribute updates incremental index regardless of name")
local namedRoot=make("Model","MyShelves",workspace,{AutoPlacer=true,StoreFurniture="Chair"})
namedRoot.CFrame=CFrame.new();namedRoot.Size=Vector3.new(1,.2,1);make("Part","Marker",namedRoot)
Furniture.Fill(namedRoot);assert(namedRoot:FindFirstChild("GeneratedFurniture"),"arbitrarily named root Models are accepted")
local disabled=make("Part","AutoPlacer",workspace,{AutoPlacer=false,StoreFurniture="Chair"})
disabled.CFrame=CFrame.new();disabled.Size=Vector3.new(1,.2,1)
Furniture.Fill(disabled);assert(not disabled:FindFirstChild("GeneratedFurniture"),"explicit false disables legacy name")
assert(scans==0,"attribute furniture markers preserve incremental world indexing")
local late=make("Model","YardPlace",workspace)
late.Size=Vector3.new(20,.2,20);make("Part","Part",late)
workspace.DescendantAdded:Fire(late)
Service.Generate(true);assert(not late:FindFirstChild("GeneratedHouse"))
late:SetAttribute("ForZHouse",true)
Service.Generate(true);assert(late:FindFirstChild("GeneratedHouse"),"late plot attribute changes update index")
local lateHouse=late.GeneratedHouse.Value
workspace.DescendantRemoving:Fire(late);late:Destroy();Service.Generate(true)
assert(lateHouse.destroyed,"cached plot removal still cleans generated house")
assert(scans==0,"addition, attribute updates and removal keep retries incremental")
workspace.GetDescendants=originalDescendants
print("PASS: incremental retries have zero full world scans; late plots, changed attributes and removals work")
-- Regression for the real capture's 20,450 geometry queries during one sort.
small:SetAttribute("ForZHouse",false)
local originalBounds=methods.GetBoundingBox
local roadBounds=0
function methods:GetBoundingBox()
 if self:GetAttribute("Road")==true then roadBounds+=1 end
 return originalBounds(self)
end
for i=1,120 do
 local r=make("Model","PerfRoad"..i,workspace,{Road=true})
 r.CFrame=CFrame.new(Vector3.new(i*20,0,40));r.Size=Vector3.new(20,.2,20);make("Part","Part",r)
 workspace.DescendantAdded:Fire(r)
end
Service.Generate(true)
assert(roadBounds==0,"settled towns do not compute or sort road bounds on retry")
local pendingPlot=make("Model","YardPlace",workspace,{ForZHouse=true})
pendingPlot.CFrame=CFrame.new(Vector3.zero);pendingPlot.Size=Vector3.new(20,.2,20);make("Part","Part",pendingPlot)
workspace.DescendantAdded:Fire(pendingPlot)
roadBounds=0
Service.Generate(true)
assert(pendingPlot:FindFirstChild("GeneratedHouse"),"late plot still generates with cached sort keys")
assert(roadBounds<4*121,"road geometry calls scale linearly, not with sort comparisons")
roadBounds=0
Service.Generate(true)
assert(roadBounds==0,"completed late plot restores zero road-bound work")
local removed=pendingPlot.GeneratedHouse.Value
removed:Destroy();Service.Generate(true)
assert(pendingPlot.GeneratedHouse.Value~=removed and not pendingPlot.GeneratedHouse.Value.destroyed,"removed generated buildings can be regenerated")
print("PASS: 120-road regression has no settled-town geometry work, linear pending-sort queries and removed-house recovery")


-- Real service proximity, bounded queue and state preservation.
local function addPlot(x,z)
 local plot=make("Model","YardPlace",workspace,{ForZHouse=true})
 plot.CFrame=CFrame.new(Vector3.new(x,0,z));plot.Size=Vector3.new(20,.2,20)
 local part=make("Part","Part",plot)
 workspace.DescendantAdded:Fire(plot)
 workspace.DescendantAdded:Fire(part)
 return plot,part
end
local function addRoad(x,z)
 local r=make("Model","Road",workspace,{Road=true})
 r.CFrame=CFrame.new(Vector3.new(x,0,z));r.Size=Vector3.new(20,.2,20);make("Part","Part",r)
 workspace.DescendantAdded:Fire(r)
 return r
end
addRoad(10000,30)
local far,farPart=addPlot(10000,0)
Service.Generate(true)
assert(not far:FindFirstChild("GeneratedHouse"),"distant plots remain ungenerated")
assert(farPart.Transparency==1 and farPart.CanCollide==false,"pending plot markers are hidden before building")
local nearEmpty=addPlot(0,0)
local originalCharacter=observer.Character
observer.Character=nil
Service.Generate(true)
assert(not nearEmpty:FindFirstChild("GeneratedHouse"),"world without living players generates no houses")
observer.Character=originalCharacter;observerHP.Health=0
Service.Generate(true)
assert(not nearEmpty:FindFirstChild("GeneratedHouse"),"dead players cannot activate plots")
observerHP.Health=100;observerRoot.Position=Vector3.new(10000,0,0)
Service.Generate(true)
assert(far:FindFirstChild("GeneratedHouse") and not nearEmpty:FindFirstChild("GeneratedHouse"),"approaching one town does not generate another")
local persistent=far.GeneratedHouse.Value;persistent:SetAttribute("LootProbe",true)
observerRoot.Position=Vector3.zero;Service.Generate(true)
assert(nearEmpty:FindFirstChild("GeneratedHouse"))
observerRoot.Position=Vector3.new(10000,0,0);Service.Generate(true)
assert(far.GeneratedHouse.Value==persistent and persistent:GetAttribute("LootProbe"),"re-entry preserves house and its state")
local second=make("Player","SecondObserver",Players)
second.Character=make("Model","SecondCharacter",workspace)
local secondRoot=make("Part","HumanoidRootPart",second.Character);secondRoot.Position=Vector3.new(20000,0,0)
local secondHP=make("Humanoid","Humanoid",second.Character);secondHP.Health=100
addRoad(20000,30)
local otherTown=addPlot(20000,0)
Service.Generate(true)
assert(otherTown:FindFirstChild("GeneratedHouse"),"all living players activate their nearby plots")
secondHP.Health=0;observerRoot.Position=Vector3.new(30000,0,0)
addRoad(30000,30)
local queued={}
for i=1,10 do queued[i]=addPlot(30000+(i-1)*12,0) end
Service.Generate(true)
local count=0
for _,p in ipairs(queued) do if p:FindFirstChild("GeneratedHouse") then count+=1 end end
assert(count==Config.PlotsPerStep,"one pass respects the building limit")
assert(queued[1]:FindFirstChild("GeneratedHouse") and not queued[10]:FindFirstChild("GeneratedHouse"),"nearest plots generate first")
Service.Generate(true);Service.Generate(true)
for _,p in ipairs(queued) do assert(p:FindFirstChild("GeneratedHouse"),"later passes finish the nearby queue") end
-- Moving an authored part invalidates cached model bounds (mock geometry moved explicitly).
local moving,movingPart=addPlot(50000,0)
Service.Generate(true);assert(not moving:FindFirstChild("GeneratedHouse"))
moving.CFrame=CFrame.new(Vector3.new(30000,0,60))
movingPart:GetPropertyChangedSignal("CFrame"):Fire()
Service.Generate(true)
assert(moving:FindFirstChild("GeneratedHouse"),"geometry changes invalidate proximity bounds")
local seeds={}
local originalNew=Random.new
Random.new=function(value) table.insert(seeds,value);return originalNew(value) end
local seeded=addPlot(30000,100)
Service.Generate(true)
local firstSeed=seeds[#seeds]
seeded.GeneratedHouse.Value:Destroy()
Service.Generate(true)
assert(seeds[#seeds]==firstSeed,"per-plot random seed survives different visits and house replacement")
Random.new=originalNew
-- Large markers activate by distance from their edge, including rotated plots.
local radius=Config.GenerationRadius
local edge=CFrame.new(Vector3.new(0,0,0))
assert(Rules.DistanceSquared(edge,Vector3.new(40,.2,20),Vector3.new(20+radius,1000,0))==radius*radius)
assert(Rules.DistanceSquared(edge,Vector3.new(40,.2,20),Vector3.new(21+radius,0,0))>radius*radius)
assert(Rules.DistanceSquared(cf(Vector3.zero,math.pi/2),Vector3.new(40,.2,20),Vector3.new(0,0,20+radius))<=radius*radius+.001)
local farFurniture=make("Part","AutoPlacer",workspace,{StoreFurniture="Chair"})
farFurniture.CFrame=CFrame.new(Vector3.new(60000,0,0));farFurniture.Size=Vector3.new(1,.2,1)
workspace.DescendantAdded:Fire(farFurniture)
local farWall=make("Model","FarWall",workspace,{Replace="Wall (brick)"})
farWall.CFrame=CFrame.new(Vector3.new(60000,0,10));make("Part","Part",farWall)
workspace.DescendantAdded:Fire(farWall)
Service.Generate(true)
assert(not farFurniture:FindFirstChild("GeneratedFurniture") and not farWall.destroyed,"standalone furniture and wall markers stay deferred at distance")
observerRoot.Position=Vector3.new(60000,0,0)
Service.Generate(true)
assert(farFurniture:FindFirstChild("GeneratedFurniture") and farWall.destroyed,"standalone furniture and wall replacements activate nearby")
assert(workspace.GeneratedCityHouses:GetAttribute("GenerationMode")=="NearbyPlots")
assert(workspace.GeneratedCityHouses:GetAttribute("GenerationRadius")==Config.GenerationRadius)
print("PASS: lazy city generation, hidden markers, no-player/dead-player guards, multiple towns/players, state retention, closest-first bounded queue and moved geometry")
Config.ZoneLoadSeconds=10
addRoad(70000,30)
local paced={addPlot(70000,0),addPlot(70020,0),addPlot(70040,0)}
observerRoot.Position=Vector3.new(70000,0,0)
Service.Generate(true)
assert(paced[1]:FindFirstChild("GeneratedHouse") and not paced[2]:FindFirstChild("GeneratedHouse") and not paced[3]:FindFirstChild("GeneratedHouse"),"10-second batch starts with its nearest plot only")
local firstHouse=paced[1].GeneratedHouse.Value
-- Polling does not restart the original deadlines.
for _=1,3 do Service.Generate(true) end
tick(4.75)
assert(not paced[2]:FindFirstChild("GeneratedHouse"),"middle plot cannot start early")
tick(.25)
assert(paced[2]:FindFirstChild("GeneratedHouse") and not paced[3]:FindFirstChild("GeneratedHouse"),"middle plot loads at 5 seconds")
tick(4.75)
assert(not paced[3]:FindFirstChild("GeneratedHouse"),"last plot cannot start before the 10-second deadline")
tick(.25)
assert(paced[3]:FindFirstChild("GeneratedHouse"),"last plot loads at 10 seconds")
assert(paced[1].GeneratedHouse.Value==firstHouse,"pacing never replaces finished state")
addRoad(80000,30)
local moved={addPlot(80000,0),addPlot(80020,0),addPlot(80040,0)}
observerRoot.Position=Vector3.new(80000,0,0);Service.Generate(true)
assert(moved[1]:FindFirstChild("GeneratedHouse") and not moved[2]:FindFirstChild("GeneratedHouse"))
observerRoot.Position=Vector3.new(70000,0,0);Service.Generate(true)
tick(40)
assert(not moved[2]:FindFirstChild("GeneratedHouse") and not moved[3]:FindFirstChild("GeneratedHouse"),"leaving cancels the distant pending batch")
observerRoot.Position=Vector3.new(80000,0,0);Service.Generate(true)
assert(moved[2]:FindFirstChild("GeneratedHouse") and not moved[3]:FindFirstChild("GeneratedHouse"),"returning schedules unfinished work afresh without catch-up burst")
tick(30)
assert(moved[3]:FindFirstChild("GeneratedHouse"),"remaining work finishes in its new window")
-- Missed deadlines are caught up across frames, rather than cloning in a burst.
addRoad(90000,30)
local delayed={addPlot(90000,0),addPlot(90020,0),addPlot(90040,0),addPlot(90060,0)}
observerRoot.Position=Vector3.new(90000,0,0);Service.Generate(true)
clock+=31
local finished=false
task.spawn(function() Service.Generate(true);finished=true end)
assert(delayed[2]:FindFirstChild("GeneratedHouse") and not delayed[3]:FindFirstChild("GeneratedHouse") and not finished,"catch-up yields before creating another house")
tick(0)
assert(delayed[3]:FindFirstChild("GeneratedHouse") and not delayed[4]:FindFirstChild("GeneratedHouse"),"catch-up clones at most one house per resumed frame")
tick(0)
assert(delayed[4]:FindFirstChild("GeneratedHouse") and finished,"serialized catch-up completes without duplicate generation")
for i=#loops,1,-1 do if coroutine.status(loops[i])=="dead" then table.remove(loops,i) end end
-- Standalone furniture follows the same window instead of creating a new burst.
local furnitureBatch={}
for i=1,3 do
 local marker=make("Part","AutoPlacer",workspace,{StoreFurniture="Chair"})
 marker.CFrame=CFrame.new(Vector3.new(100000+(i-1)*20,0,0));marker.Size=Vector3.new(1,.2,1)
 workspace.DescendantAdded:Fire(marker);furnitureBatch[i]=marker
end
observerRoot.Position=Vector3.new(100000,0,0);Service.Generate(true)
assert(furnitureBatch[1]:FindFirstChild("GeneratedFurniture") and not furnitureBatch[2]:FindFirstChild("GeneratedFurniture"))
tick(5)
assert(furnitureBatch[2]:FindFirstChild("GeneratedFurniture") and not furnitureBatch[3]:FindFirstChild("GeneratedFurniture"))
tick(5)
assert(furnitureBatch[3]:FindFirstChild("GeneratedFurniture"))
print("PASS: missed-deadline catch-up yields between buildings and standalone furniture uses 10-second pacing")
print("PASS: 10-second pacing, nearest-first slots at 0/5/10 seconds, stable polling deadlines, departure cancellation and paced re-entry")



'''
parts=[mock,geometry,(root/'tests/city_service.fixture.luau').read_text()]
for name,var in [('CityGenerationConfig','Config'),('CityGenerationRules','Rules')]:
    parts.append('local '+var+'=(function()\n'+(root/f'src/shared/{name}.luau').read_text()+'\nend)()')
parts.append('local Walls=(function()\n'+(root/'src/server/Services/WallReplacementService.luau').read_text()+'\nend)()')
parts.append('local Furniture=(function()\n'+furniture+'\nend)()')
parts.append('workspace.DescendantAdded=event();workspace.DescendantRemoving=event();function methods:GetPropertyChangedSignal(key) self.propertySignals=self.propertySignals or {};self.propertySignals[key]=self.propertySignals[key] or event();return self.propertySignals[key] end')
parts.append('local Placement={Move=function(model,target) model:PivotTo(target) end}')
parts.extend(['local Service=(function()\n'+service+'\nend)()',cases])
with tempfile.TemporaryDirectory(prefix='decline-city-service-') as directory:
    path=Path(directory)/'test.luau'
    path.write_text('\n'.join(parts))
    subprocess.run([sys.argv[1] if len(sys.argv)>1 else 'luau',str(path)],check=True)
