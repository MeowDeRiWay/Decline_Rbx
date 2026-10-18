"""Exercise resource generation and harvesting with engine mocks, not Studio."""
from pathlib import Path
import subprocess
import sys
import tempfile
root = Path(__file__).resolve().parents[1]
service = (root/'src/server/Services/ResourceService.luau').read_text()
for name in ['Config', 'Rules', 'Area', 'Inventory', 'WorldItems', 'Items']:
    import re
    service = re.sub(rf'local {name} = require\([^\n]+\)\n', '', service)
setup = '''
function CFrame.Angles(_,y,_) return cf(Vector3.zero,y) end
local originalIndex=cm.__index
function cm.__index(a,k)
 if k=="Rotation" then return cf(Vector3.zero,a.yaw) end
 if k=="RightVector" then return a:VectorToWorldSpace(Vector3.new(1,0,0)) end
 if k=="LookVector" then return a:VectorToWorldSpace(Vector3.new(0,0,-1)) end
 return originalIndex(a,k)
end
local baseClone=methods.Clone
function methods:Clone()
 local clone=baseClone(self); clone.CFrame=self.CFrame; clone.Size=self.Size
 return clone
end
workspace.DescendantAdded=event()
local groundHits=true
function workspace:Raycast(origin)
 if not groundHits then return nil end
 return {Position=Vector3.new(origin.X,0,origin.Z),Normal=Vector3.new(0,1,0)}
end
local Random={new=function() return {
 NextNumber=function(_,low,high) if low then return (low+high)/2 end return 0 end,
 NextInteger=function(_,low) return low end,
} end}
local lootCalls=0
local WorldItems={SpawnLoot=function(loot) lootCalls+=1; assert(loot.Stone==1); return true end}
local weapon={Damage=20}
local used=0
local Inventory={GetWeapon=function() return weapon end,UseWeapon=function() used+=1; return true end}
'''
cases = '''
local library=make("Folder","Resources",ServerStorage)
local group=make("Folder","StoneVeins",library)
local vein=make("Model","StoneVein",group)
vein.CFrame=CFrame.new(); vein.Size=Vector3.new(.1,.1,.1)
make("Part","Part",vein)
local zone=make("Model","StoneYard",workspace); zone.DescendantAdded=event()
local marker=make("Part","Part",zone)
marker.CFrame=CFrame.new(); marker.Size=Vector3.new(10,.1,10)
local duplicate=make("Part","Part",zone)
duplicate.CFrame=marker.CFrame; duplicate.Size=marker.Size
Service.Start()
local generated=workspace.Resources:GetChildren()
assert(#generated==100,"100 successful cell rolls, no old population cap or doubled overlapping marker")
assert(marker.Transparency==1 and marker.CanQuery==false and marker.CanCollide==false)
local target=generated[1]
assert(target:GetAttribute("Health")==100 and target:GetAttribute("ResourceMaterial")=="Stone")
assert(target.Part.Anchored and target.Part.CanQuery)
local player={Character=make("Model","Character")}
player.Character:SetAttribute("HandsItem","StoneAxe")
assert(Service.Hit(player,target,weapon) and target:GetAttribute("Health")==100 and used==1,"wrong tool wears but cannot mine")
player.Character:SetAttribute("HandsItem","StoneShowel")
for _=1,20 do assert(Service.Hit(player,target,weapon)) end
assert(target.destroyed and lootCalls==1 and used==21,"twenty stone shovel hits drop stone once")
assert(not Service.Hit(player,target,weapon) and lootCalls==1,"no duplicate loot")
assert(#workspace.Resources:GetChildren()==99)
local scrapTarget=generated[2]
player.Character:SetAttribute("HandsItem","ScrapShowel")
for _=1,10 do assert(Service.Hit(player,scrapTarget,weapon)) end
assert(scrapTarget.destroyed and lootCalls==2,"scrap multiplier mines in ten hits")
local ironTarget=generated[3]
player.Character:SetAttribute("HandsItem","IronShowel")
for _=1,7 do assert(Service.Hit(player,ironTarget,weapon)) end
assert(ironTarget.destroyed and lootCalls==3,"iron multiplier mines in seven hits")
print("PASS: real resource service generates StoneYard by cells, skips duplicate markers, anchors veins, requires shovel and drops stone once")
'''
parts = [(root/'tests/fixtures/town_mock.luau').read_text(), (root/'tests/city_geometry.fixture.luau').read_text(), setup]
for var, file in [('Config','ResourceConfig'),('Rules','ResourceRules'),('Items','ItemConfig')]:
    parts.append(f'local {var}=(function()\n'+(root/f'src/shared/{file}.luau').read_text()+'\nend)()')
parts.append('local Area=(function()\n'+(root/'src/server/Services/AreaService.luau').read_text()+'\nend)()')
parts.extend(['local Service=(function()\n'+service+'\nend)()',cases])
with tempfile.TemporaryDirectory(prefix='decline-resources-') as directory:
    path=Path(directory)/'test.luau'; path.write_text('\n'.join(parts))
    subprocess.run([sys.argv[1] if len(sys.argv)>1 else 'luau',str(path)],check=True)
