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
cases='''
local library=make("Folder","CityGeneration",ServerStorage)
local templates=make("Folder","Houses",library)
local house=make("Model","Any House Name",templates,{ZHouse=true,ZNumber=2})
house.CFrame=CFrame.new(Vector3.new(40,1,30))
local yard=make("Model","Yard",house)
yard.CFrame=CFrame.new(Vector3.new(43,0,37)); yard.Size=Vector3.new(20,.2,20)
make("Part","Part",yard)
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
Service.Generate(); Service.Start()
assert(#generated:GetChildren()==1,"repeated Generate/Start must not duplicate house")
plot:Destroy(); Service.Generate()
assert(#generated:GetChildren()==0,"removing source plot removes generated house")
print("PASS: template discovery by attribute, placement, source references, hidden markers, ZNumber preservation, idempotence and removed-plot cleanup")
'''
parts=[mock,geometry,(root/'tests/city_service.fixture.luau').read_text()]
for name,var in [('CityGenerationConfig','Config'),('CityGenerationRules','Rules')]:
    parts.append('local '+var+'=(function()\n'+(root/f'src/shared/{name}.luau').read_text()+'\nend)()')
parts.extend(['local Service=(function()\n'+service+'\nend)()',cases])
with tempfile.TemporaryDirectory(prefix='decline-city-service-') as directory:
    path=Path(directory)/'test.luau'
    path.write_text('\n'.join(parts))
    subprocess.run([sys.argv[1] if len(sys.argv)>1 else 'luau',str(path)],check=True)
