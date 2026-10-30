"""Exercise real dormancy, geometry reconstruction and virtual projectile barriers."""
from pathlib import Path
import re,subprocess,sys,tempfile
root=Path(__file__).resolve().parents[1]
source=(root/'src/server/Services/WorldActivityService.luau').read_text()
source=re.sub(r'local (Config|Rules|Ballistics|Stations)=require[^\n]+\n','',source)
setup='''
function vm.__mul(a,b) if type(a)=="number" then a,b=b,a end;return Vector3.new(a.X*b,a.Y*b,a.Z*b) end
function vm.__div(a,b) return Vector3.new(a.X/b,a.Y/b,a.Z/b) end
Enum.PartType={Block=1}
workspace.Parent=make("Folder","DataModel")
function methods:GetAttributes() return table.clone(self.attrs) end
local originalNew=Instance.new
Instance.new=function(class) local o=originalNew(class);o.Destroying=event();if o:IsA("BasePart") then o.Material={Name="Plastic"};o.Shape=1;o.CanQuery=true end;return o end
local originalDestroy=methods.Destroy
function methods:Destroy() if self.Destroying then self.Destroying:Fire() end;originalDestroy(self) end
local originalClone=methods.Clone
function methods:Clone()
 local o=originalClone(self)
 for _,key in ipairs({"CFrame","Size","Material","Shape","CanQuery","CanCollide","Transparency","Color"}) do o[key]=self[key] end
 return o
end
local function run(fn)
 local co=coroutine.create(fn)
 for _=1,1000 do local ok,err=coroutine.resume(co);assert(ok,err);if coroutine.status(co)=="dead" then return end end
 error("transition failed to finish")
end
local function building(x,source)
 local house=make("Model","House",workspace,{Material="Wood"})
 house.CFrame=CFrame.new(Vector3.new(x,0,0));house.Size=Vector3.new(20,10,20)
 local wall=make("Part","Wall",house,{HP=71});wall.CFrame=CFrame.new(Vector3.new(x,0,0));wall.Size=Vector3.new(10,10,2)
 wall.Material={Name="Wood"};wall.Shape=1;wall.CanQuery=true;wall.Color="brown"
 local door=make("Model","Door",house,{Door=true})
 local panel=make("Part","Panel",door);panel.CFrame=CFrame.new(Vector3.new(x+5,0,0));panel.Size=Vector3.new(2,10,2);panel.Shape=1;panel.CanQuery=false
 local chest=make("Model","Chest",house,{SavedLoot="one potato"})
 local lid=make("Part","Lid",chest);lid.CFrame=CFrame.new(Vector3.new(x+7,0,0));lid.Size=Vector3.new(1,1,1);lid.CanQuery=false
 return house,wall,panel,chest
end
'''
cases='''
local h,w,door,chest=building(0)
local h2,w2=building(1000)
Service.Register(h,"Building","same-template");Service.Register(h2,"Building","same-template")
assert(Service.Stats().Active==2)
local distant=make("Player","Distant",Players);distant.Character=make("Model","DistantCharacter",workspace)
local dr=make("Part","HumanoidRootPart",distant.Character);dr.Position=Vector3.new(100000,0,100000)
local dh=make("Humanoid","Humanoid",distant.Character);dh.Health=100
local nearCalls=0
local originalNear=Rules.Near
Rules.Near=function(...) nearCalls+=1;return originalNear(...) end
run(function() Service.Step(clock) end)
assert(nearCalls==0,"spatial interest index skips exact distance work for distant roots")
Rules.Near=originalNear;distant.Character=nil
run(function() Service.Step(clock+9) end);assert(h.Parent==workspace)
clock+=11;run(function() Service.Step(clock) end)
assert(Service.IsDormant(chest) and h.Parent==ServerStorage.DormantWorld)
assert(Service.Stats().Sleeping==2 and not w.destroyed)
local hit=Service.Raycast(Vector3.new(0,0,-10),Vector3.new(0,0,20),{})
assert(hit and math.abs(hit.Distance-9)<.001)
local kind,thickness,used=Service.Barrier(hit,Vector3.new(0,0,1))
assert(kind=="Wood" and thickness==2 and #used==1)
assert(not Service.Raycast(Vector3.new(0,0,-10),Vector3.new(0,0,20),{h}))
local consumed={[used[1]]=true}
assert(not Service.Raycast(Vector3.new(0,0,-10),Vector3.new(0,0,20),{},consumed))
clock+=11;run(function() Service.Step(clock) end)
assert(w.destroyed and w2.destroyed and not door.destroyed and chest.Parent==h)
assert(Service.Stats().Cold==2 and Service.Stats().ReleasedParts==2)
assert(#ServerStorage.WorldGeometryPrototypes:GetChildren()==1,"one shared leaf prototype per template slot")
local cold=Service.Raycast(Vector3.new(0,0,-10),Vector3.new(0,0,20),{})
assert(cold and cold.Distance==hit.Distance and cold.Instance==h)
local coldKind,coldThickness=Service.Barrier(cold,Vector3.new(0,0,1))
assert(coldKind==kind and coldThickness==thickness,"cold walls retain penetration cost")
door.CanQuery=true
assert(Service.Raycast(Vector3.new(5,0,-10),Vector3.new(0,0,20),{}),"closed sleeping door blocks shots")
door.CanQuery=false
local near=make("Player","Near",Players);near.Character=make("Model","Character",workspace)
local root=make("Part","HumanoidRootPart",near.Character);root.Position=Vector3.new(151,0,0)
local hp=make("Humanoid","Humanoid",near.Character);hp.Health=100
run(function() Service.Step(clock) end);assert(Service.IsDormant(h),"wake hysteresis uses footprint edge")
root.Position=Vector3.new(149,0,0)
run(function() Service.Step(clock) end)
assert(h.Parent==workspace and not Service.IsDormant(h))
assert(h.Wall~=w and h.Wall:GetAttribute("HP")==71 and h.Wall.Color=="brown" and h.Wall.CFrame.Position.X==0)
assert(chest:GetAttribute("SavedLoot")=="one potato" and h.Door.Panel==door,"gameplay object identities retained")
assert(not Service.Raycast(Vector3.new(0,0,-10),Vector3.new(0,0,20),{}),"awake roots leave virtual index")
run(function() Service.Ensure(Vector3.new(1000,0,0),4) end);assert(h2.Parent==workspace,"reconnect restores house before returning")
near.Character=nil
clock+=22;run(function() Service.Step(clock) end);clock+=11;run(function() Service.Step(clock) end)
local delay;run(function() delay=Service.Step(clock) end);assert(delay==10,"empty cold world has coarse updates")
h:Destroy();h2:Destroy();assert(Service.Stats().Cold==0 and #ServerStorage.WorldGeometryPrototypes:GetChildren()==0)
local actor=make("Model","Zombie",workspace);actor.CFrame=CFrame.new();actor.Size=Vector3.new(2,4,2)
local actorRoot=make("Part","HumanoidRootPart",actor);actorRoot.CFrame=CFrame.new();local health=make("Humanoid","Humanoid",actor);health.Health=20
Service.Register(actor,"NPC");clock+=11;run(function() Service.Step(clock) end)
assert(#Service.DormantNPCs()==1)
local actorHit=Service.Raycast(Vector3.new(0,0,-10),Vector3.new(0,0,20),{})
assert(actorHit and actorHit.Record.Kind=="NPC")
actor:SetAttribute("Knockout",true)
assert(not Service.Raycast(Vector3.new(0,0,-10),Vector3.new(0,0,20),{},nil,true),"virtual KO cannot stop bullets")
actor:SetAttribute("Knockout",false)
assert(Service.Raycast(Vector3.new(0,0,-10),Vector3.new(0,0,20),{},nil,true),"virtual standing NPC remains hittable")
run(function() Service.ResolveHit(actorHit) end)
assert(actor.Parent==workspace and #Service.DormantNPCs()==0,"struck NPC wakes before damage/death callbacks")
clock+=11;run(function() Service.Step(clock) end)
health.Health=0;run(function() Service.Step(clock) end)
assert(actor.Parent==workspace and #Service.DormantNPCs()==0 and not Service.Contains(actor),"dead NPC returns to corpse lifecycle")
local bottle=make("Model","Antiseptic",workspace,{Item_ID="Antiseptic"});bottle.CFrame=CFrame.new();bottle.Size=Vector3.new(1,1,1)
local bottlePart=make("Part","Bottle",bottle);bottlePart.CFrame=CFrame.new();bottlePart.Anchored=true
Service.Register(bottle,"Item");clock+=11;run(function() Service.Step(clock) end)
assert(Service.Raycast(Vector3.new(0,0,-10),Vector3.new(0,0,20),{}),"virtual item retains query geometry for ordinary queries")
assert(not Service.Raycast(Vector3.new(0,0,-10),Vector3.new(0,0,20),{},nil,true),"virtual items are ignored by bullets")
bottle:Destroy()
local scripted=building(0);make("Script","CustomLogic",scripted);Service.Register(scripted,"Building")
assert(not Service.Contains(scripted),"unknown runnable state stays active")
local roads=make("Folder","roads",workspace)
local slab=make("Part","Segment20",roads);slab.CFrame=CFrame.new(Vector3.new(2000,0,0));slab.Size=Vector3.new(20,1,20);slab.Anchored=true
Service.RegisterRoad(slab)
assert(Service.Contains(slab) and Service.IsRoad(slab))
local moving=make("Part","MovingRoad",roads);moving.Anchored=false;Service.RegisterRoad(moving)
assert(not Service.Contains(moving),"moving geometry is not enrolled as a road")
local roadModel=make("Model","GroupedRoad",workspace,{Road=true});roadModel.CFrame=CFrame.new(Vector3.new(3000,0,0));roadModel.Size=Vector3.new(20,1,20)
local pavement=make("Part","Pavement",roadModel,{Road=true});pavement.Anchored=true;pavement.CFrame=roadModel.CFrame
Service.RegisterRoad(roadModel);Service.RegisterRoad(pavement)
assert(Service.Contains(roadModel) and not Service.Contains(pavement),"nested road geometry has one owner")
clock+=11;run(function() Service.Step(clock) end)
assert(slab.Parent==ServerStorage.DormantWorld and Service.IsRoad(slab),"folder road retains identity outside original folder")
local roadFrame,roadSize=Service.Footprint(slab)
assert(roadFrame.Position.X==2000 and roadSize.X==20 and #Service.Roads()==2)
clock+=11;run(function() Service.Step(clock) end)
assert(not slab.destroyed and not pavement.destroyed,"cheap road parts retained without duplicate prototypes")
local cleanupRoad=make("Part","Cleanup",roads);cleanupRoad.Anchored=true;cleanupRoad.CFrame=CFrame.new(Vector3.new(4000,0,0))
Service.RegisterRoad(cleanupRoad)
near.Character=make("Model","PriorityCharacter",workspace)
local priorityRoot=make("Part","HumanoidRootPart",near.Character);priorityRoot.Position=Vector3.new(2000,0,0)
local priorityHP=make("Humanoid","Humanoid",near.Character);priorityHP.Health=100
Config.TransitionsPerStep=1;clock+=11
run(function() Service.Step(clock) end)
assert(slab.Parent==roads and cleanupRoad.Parent==roads,"nearest wake takes priority over distant cleanup budget")
near.Character=nil;Config.TransitionsPerStep=8;cleanupRoad:Destroy()
run(function() Service.Ensure(Vector3.new(2000,0,0),4) end)
assert(slab.Parent==roads and slab.Anchored,"road collision restored before reconnect caller returns")
slab:Destroy();roadModel:Destroy();assert(#Service.Roads()==0,"destroyed sleeping road metadata is released")
print("PASS: road enrollment, nested owner guard, sleeping bounds, folder identity, retained slabs, reconnect and deletion")
print("PASS: sleep delays, cold geometry release/shared prototypes, exact block raycasts and penetration, live door state, hysteresis, identity/HP/loot restoration, reconnect, idle interval and corpse cleanup")
'''
parts=[(root/'tests/fixtures/town_mock.luau').read_text(),(root/'tests/city_geometry.fixture.luau').read_text(),setup]
for var,module in [('Config','WorldActivityConfig'),('Rules','WorldActivityRules'),('Ballistics','FirearmRules'),('Stations','CraftStations')]:
 parts.append(f'local {var}=(function()\n'+(root/f'src/shared/{module}.luau').read_text()+'\nend)()')
parts+=['local Service=(function()\n'+source+'\nend)()',cases]
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'world.luau';p.write_text('\n'.join(parts));subprocess.run([sys.argv[1],str(p)],check=True)
