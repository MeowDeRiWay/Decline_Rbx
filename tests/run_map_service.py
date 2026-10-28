"""Run actual map authority: discovered-only data, geometry and fresh-life reset."""
from pathlib import Path
import subprocess,sys,tempfile
root=Path(__file__).resolve().parents[1]
source=(root/'src/server/Services/MapService.luau').read_text().replace('local Rules=require(ReplicatedStorage.Shared.MapRules)','')
setup='''
local Run={Heartbeat=event()};local baseGet=game.GetService
function game:GetService(name) if name=="RunService" then return Run end;return baseGet(self,name) end
workspace.DescendantAdded=event();workspace.DescendantRemoving=event()
local anchor=make("Model","YardPlace",workspace)
anchor.CFrame=CFrame.new(Vector3.new(10,0,10));anchor.Size=Vector3.new(20,1,20);make("Part","Floor",anchor)
local road=make("Part","Road",workspace,{Road=true});road.CFrame=CFrame.new(Vector3.new(10,0,10));road.Size=Vector3.new(20,1,100)
local home=make("Model","GeneratedHome",workspace,{GeneratedCityHouse=true,GenerationCategory="Houses"})
home.CFrame=CFrame.new(Vector3.new(30,0,10));home.Size=Vector3.new(20,20,20);make("Part","Wall",home)
local factory=make("Model","Factory",workspace,{GeneratedCityHouse=true,GenerationCategory="Factories"})
factory.CFrame=CFrame.new(Vector3.new(210,0,10));factory.Size=Vector3.new(40,20,40);make("Part","Wall",factory)
local forest=make("Model","Forest",workspace)
local floor=make("Part","Floor",forest);floor.CFrame=CFrame.new(Vector3.new(10,0,50));floor.Size=Vector3.new(100,1,20)
a:LoadCharacterAsync();a.Character.HumanoidRootPart.Position=Vector3.new(10,0,10)
b:LoadCharacterAsync();b.Character.HumanoidRootPart.Position=Vector3.new(-390,0,10)
'''
cases='''
Service.Start()
local state=ReplicatedStorage.MapState;local request=ReplicatedStorage.MapRequest
Service.Step(a);Service.Step(b)
local first=state.sent[1];assert(first.player==a and #first.data.Cells==25)
local byKey={};for _,cell in ipairs(first.data.Cells) do byKey[Rules.Key(cell.X,cell.Z)]=cell end
assert(byKey["0:0"].Kind=="Ground" and byKey["0:0"].RoadMask==65535 and byKey["1:0"].Kind=="House")
assert(not byKey["10:0"],"unexplored factory must never be sent")
assert(state.sent[2].player==b)
for _,cell in ipairs(state.sent[2].data.Cells) do assert(cell.X<0,"players cannot receive each other's explored cells") end
local count=#state.sent;Service.Step(a);assert(#state.sent==count,"no repeated packet while stationary")
a.Character.HumanoidRootPart.Position=Vector3.new(30,0,10);Service.Step(a)
assert(#state.sent[#state.sent].data.Cells==5,"only new edge cells are sent on movement")
a.Character:SetAttribute("Knockout",true);a.Character.HumanoidRootPart.Position=Vector3.new(210,0,10)
count=#state.sent;Service.Step(a);assert(#state.sent==count,"knockout cannot explore")
a.Character:SetAttribute("Knockout",false);Service.Step(a)
local factorySeen=false;for _,cell in ipairs(state.sent[#state.sent].data.Cells) do if cell.Kind=="Infrastructure" then factorySeen=true end end
assert(factorySeen)
clock+=2;request.OnServerEvent:Fire(a,{RevealAll=true,Position={X=99999}})
local requestEnd=#state.sent;request.OnServerEvent:Fire(a);assert(#state.sent==requestEnd,"full-map requests throttled")
local hasReset=false;for _,packet in ipairs(state.sent) do if packet.data.Reset then hasReset=true end end;assert(hasReset)
a:SetAttribute("MapExplorationVersion",1)
assert(state.sent[#state.sent].data.Reset and #state.sent[#state.sent].data.Cells==0,"new character clears exploration")
a.Character.HumanoidRootPart.Position=Vector3.new(10,0,10);Service.Step(a)
for _,cell in ipairs(state.sent[#state.sent].data.Cells) do assert(cell.X<3,"old distant exploration is gone") end
-- Rejoin same generated server retains personal discoveries, but no other player data.
a.Parent=nil;local again=player(a.UserId);Players.PlayerAdded:Fire(again);again:SetAttribute("MapExplorationVersion",1)
clock+=2;request.OnServerEvent:Fire(again)
local latest=state.sent[#state.sent].data;assert(#latest.Cells==25)
print("PASS: real world footprints, road/house/infra, private fog, movement deltas, KO guards, request limits, fresh-life reset and reconnect")
'''
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'map.luau';p.write_text((root/'tests/fixtures/town_mock.luau').read_text()+'\n'+setup+'\nlocal Rules=(function()\n'+(root/'src/shared/MapRules.luau').read_text()+'\nend)()\nlocal Service=(function()\n'+source+'\nend)()\n'+cases)
 subprocess.run([sys.argv[1],str(p)],check=True)
