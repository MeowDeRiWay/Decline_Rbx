"""Exercise actual generator service with mock Instances and geometry."""
from pathlib import Path
import tempfile
import subprocess
import sys
root=Path(__file__).resolve().parents[1]
mock=(root/'tests/fixtures/town_mock.luau').read_text()
geometry=(root/'tests/city_geometry.fixture.luau').read_text()
service=(root/'src/server/Services/CityGenerationService.luau').read_text()
service=service.replace('local Config = require(ReplicatedStorage.Shared.CityGenerationConfig)','')
service=service.replace('local Rules = require(ReplicatedStorage.Shared.CityGenerationRules)','')
service=service.replace('local Furniture=require(script.Parent.StoreFurnitureService)','')
service=service.replace('local Walls=require(script.Parent.WallReplacementService)','')
furniture=(root/'src/server/Services/StoreFurnitureService.luau').read_text().replace('local Rules=require(ReplicatedStorage.Shared.CityGenerationRules)','')
cases='''
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
'''
parts=[mock,geometry,(root/'tests/city_service.fixture.luau').read_text()]
for name,var in [('CityGenerationConfig','Config'),('CityGenerationRules','Rules')]:
    parts.append('local '+var+'=(function()\n'+(root/f'src/shared/{name}.luau').read_text()+'\nend)()')
parts.append('local Walls=(function()\n'+(root/'src/server/Services/WallReplacementService.luau').read_text()+'\nend)()')
parts.append('local Furniture=(function()\n'+furniture+'\nend)()')
parts.extend(['local Service=(function()\n'+service+'\nend)()',cases])
with tempfile.TemporaryDirectory(prefix='decline-city-service-') as directory:
    path=Path(directory)/'test.luau'
    path.write_text('\n'.join(parts))
    subprocess.run([sys.argv[1] if len(sys.argv)>1 else 'luau',str(path)],check=True)
