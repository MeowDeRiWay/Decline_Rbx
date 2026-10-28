"""Exercise resource generation and harvesting with engine mocks, not Studio."""
from pathlib import Path
import subprocess
import sys
import tempfile
root = Path(__file__).resolve().parents[1]
service = (root/'src/server/Services/ResourceService.luau').read_text()
for name in ['Config', 'Rules', 'CombatRules', 'Journal', 'Area', 'Inventory', 'WorldItems', 'Items', 'Progression']:
    import re
    service = re.sub(rf'local {name} = require\([^\n]+\)\n', '', service)
setup = 'local CombatRules=(function()\n'+(root/'src/shared/CombatRules.luau').read_text()+'\nend)()\n' + '''
local messages={}
local Journal={Send=function(_,message) table.insert(messages,message) end}
local xp=0
local Progression={Loot=function(_,items) return items end,Harvest=function(_,kind,count) assert(kind=="StoneVein" and count==1);xp+=count end}

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
assert(#workspace.Resources:GetChildren()==0,"no players means no resource generation")
local observer=make("Player","Observer",Players)
observer.Character=make("Model","ObserverCharacter",workspace)
local observerRoot=make("Part","HumanoidRootPart",observer.Character);observerRoot.Position=Vector3.zero
local observerHP=make("Humanoid","Humanoid",observer.Character);observerHP.Health=100
tick(1)
local generated=workspace.Resources:GetChildren()
assert(#generated==100,"100 successful cell rolls, no old population cap or doubled overlapping marker")
assert(marker.Transparency==1 and marker.CanQuery==false and marker.CanCollide==false)
local target=generated[1]
assert(target:GetAttribute("Health")==100 and target:GetAttribute("ResourceMaterial")=="Stone")
assert(target.Part.Anchored and target.Part.CanQuery)
local player={Character=make("Model","Character")}
function player:GetAttribute() return 0 end
player.Character:SetAttribute("HandsItem","StoneAxe")
assert(Service.Hit(player,target,weapon) and target:GetAttribute("Health")==100 and used==1,"wrong tool wears but cannot mine")
player.Character:SetAttribute("HandsItem","StoneShowel")
assert(#messages==0,"unsuitable tool does not claim progress")
assert(Service.Hit(player,target,weapon) and messages[#messages]=="Stone vein: 19 hits remaining.")
for _=2,20 do assert(Service.Hit(player,target,weapon)) end
assert(messages[#messages]=="Stone vein: 0 hits remaining.")
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
assert(xp==3,"one XP per actual resource, no XP per hit")
assert(ironTarget.destroyed and lootCalls==3,"iron multiplier mines in seven hits")
Enum.Material={Wood="Wood"}
local tree=make("Model","Tree_1",workspace);tree.CFrame=CFrame.new();tree.Size=Vector3.new(1,3,1);make("Part","Part",tree)
workspace.DescendantAdded:Fire(tree)
player.Character:SetAttribute("HandsItem","")
function player:GetAttribute(id) return ({MeleeBonus=10,UnarmedDamageBonus=10})[id] end
local usedBefore=used
assert(Service.Hit(player,tree,weapon) and tree:GetAttribute("Health")==82.5,"tree receives actual unarmed damage including flat perk bonus")
assert(Service.Hit(player,tree,weapon) and tree:GetAttribute("Health")==65 and used==usedBefore,"fists do not consume weapon durability")
assert(messages[#messages]=="Tree: about 4 hits remaining.","variable unarmed damage is labelled approximate")
assert(not Service.Hit(player,generated[4],weapon) and generated[4]:GetAttribute("Health")==100,"hands cannot mine stone")
-- Two tiny distant chunks keep this test focused on scheduling and state.
local far=make("Model","StoneYard",workspace);far.DescendantAdded=event()
local farMarker=make("Part","Part",far)
farMarker.CFrame=CFrame.new(Vector3.new(1000,0,0));farMarker.Size=Vector3.new(40,.1,1)
workspace.DescendantAdded:Fire(far)
local before=#workspace.Resources:GetChildren()
tick(1)
assert(#workspace.Resources:GetChildren()==before,"distant chunks do not generate")
observerRoot.Position=Vector3.new(1000,0,0)
tick(1)
assert(#workspace.Resources:GetChildren()==before+40,"both nearby 20-stud chunks generate exactly once")
local first=workspace.Resources:GetChildren()[before+1]
assert(Service.Hit(player,first,weapon)==false,"empty hands cannot mine a distant stone")
first:SetAttribute("Health",42)
observerRoot.Position=Vector3.new(3000,0,0);tick(1)
observerRoot.Position=Vector3.new(1000,0,0);tick(1)
assert(#workspace.Resources:GetChildren()==before+40 and first:GetAttribute("Health")==42,"re-entry preserves nodes and does not reroll")
local victims={}
for _,model in ipairs(workspace.Resources:GetChildren()) do
 if model:GetPivot().Position.X>900 then table.insert(victims,model) end
end
for _,model in ipairs(victims) do model:Destroy() end
tick(1)
assert(#workspace.Resources:GetChildren()==before,"depleted chunks wait for respawn")
tick(29)
assert(#workspace.Resources:GetChildren()==before,"respawn cannot happen early")
observerRoot.Position=Vector3.new(3000,0,0);tick(2)
assert(#workspace.Resources:GetChildren()==before,"due distant chunks wait until approached")
observerRoot.Position=Vector3.new(1000,0,0);tick(1)
assert(#workspace.Resources:GetChildren()==before+40,"due nearby chunks respawn and reuse freed footprints")
local budgetZone=make("Model","StoneYard",workspace);budgetZone.DescendantAdded=event()
local budgetMarker=make("Part","Part",budgetZone)
budgetMarker.CFrame=CFrame.new(Vector3.new(5000,0,0));budgetMarker.Size=Vector3.new(20,.1,1)
workspace.DescendantAdded:Fire(budgetZone)
observerRoot.Position=Vector3.new(5000,0,0)
local baseline=#workspace.Resources:GetChildren()
-- Simulate one millisecond per clock check; the real generator must suspend and resume.
function os.clock() clock+=.001;return clock end
for _=1,400 do tick(.01) end
assert(#workspace.Resources:GetChildren()==baseline+20,"budgeted generation resumes without duplicated or lost cell rolls")
assert(workspace.Resources:GetAttribute("GenerationMode")=="NearbyChunks20")
print("PASS: time-sliced generator resumes correctly under an advancing clock")
print("PASS: virtual chunks defer distant work, preserve re-entry state and respawn only nearby after cooldown")
print("PASS: bare hands damage trees using combat rolls and bonuses, without tool wear or stone mining")
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
