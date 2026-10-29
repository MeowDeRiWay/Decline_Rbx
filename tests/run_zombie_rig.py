"""Use actual uploaded geometry, AI setup, viewer driver and attack branch."""
from pathlib import Path
import re,subprocess,sys,tempfile
root=Path(__file__).resolve().parents[1]
def module(path):return '(function()\n'+(root/path).read_text()+'\nend)()'
helpers=(root/'tests/run_character_rig.py').read_text().split("source+=r'''")[1].split('local function test(frame)')[0]
s=(root/'tests/rig_math.fixture.luau').read_text()+helpers
s+='\nlocal Rig='+module('src/shared/CharacterRig.luau')
s+='\nlocal Z='+module('src/shared/ZombiePose.luau')
s+='\nlocal Pose='+module('src/shared/CharacterPose.luau')
s+='\nlocal geometry='+module('tests/zombie_geometry.fixture.luau')
s+=r'''
local function signal()
 local callbacks={}
 return {Connect=function(_,fn) callbacks[fn]=true;return {Disconnect=function() callbacks[fn]=nil end} end,Fire=function(_,...) for fn in pairs(callbacks) do fn(...) end end}
end
local serverTime=100
workspace={GetServerTimeNow=function() return serverTime end}
local deferred={}
task={defer=function(fn) table.insert(deferred,fn) end}
function methods:IsDescendantOf(target) local p=self.Parent;while p do if p==target then return true end;p=p.Parent end;return false end
local directFind=methods.FindFirstChild
function methods:FindFirstChild(name,recursive)
 if not recursive then return directFind(self,name) end
 for _,v in ipairs(self:GetDescendants()) do if v.Name==name then return v end end
end
function methods:GetAttributeChangedSignal(key) self.Signals=self.Signals or {};self.Signals[key]=self.Signals[key] or signal();return self.Signals[key] end
local tags={}
local added,removed=signal(),signal()
local Collection={AddTag=function(_,model) tags[model]=true end,GetTagged=function() local a={};for m in pairs(tags) do table.insert(a,m) end;return a end,GetInstanceAddedSignal=function() return added end,GetInstanceRemovedSignal=function() return removed end}
local CollectionService=Collection
local registered,baseStats={},{}
local rolled=0
local statRandom={NextInteger=function(_,a) rolled+=1;return a end,NextNumber=function(_,a) return a or .5 end}
local function positive(v) return type(v)=="number" and v>0 end
local Audio={Prepare=function() end,Play=function() end}
local ZombieStats={Roll=function() return {} end,Infection=function() return 0 end}
local function applyDayStats(_,hp) hp.MaxHealth=20;hp.Health=20;hp.WalkSpeed=1 end
local ZombiePose=Z
local Enum={HumanoidDisplayDistanceType={None=1}}
'''
ai=(root/'src/server/Zombie.server.luau').read_text()
prefix=ai[ai.index('local function prepare(model)'):ai.index(' local ready = 0')]
s+='\n'+prefix+'\nend\n'
s+=r'''
local models={}
for kind=1,3 do
 local model=Instance.new("Model",workspace);model.Name="Zombie"
 for _,g in ipairs(geometry) do local p=Instance.new("Part",model);p.Name=g.Name;p.CFrame=g.CFrame;p.Size=g.Size end
 Instance.new("Humanoid",model)
 local oldHand=Instance.new("Part",model);oldHand.Name="HeldItem"
 model:SetAttribute("HandsItem","ZombieHand")
 model:SetAttribute("ZombieAnimationType",kind);model:SetAttribute("ZombieAttackSide","Left")
 model.DescendantAdded=signal();model.DescendantRemoving=signal();model.Destroying=signal()
 prepare(model)
 local root=model:FindFirstChild("HumanoidRootPart")
 assert(root and root.Anchored and root.CanCollide)
 assert(not model:FindFirstChild("HeldItem") and model:GetAttribute("HandsItem")==nil,"old hand model is unnecessary")
 assert(model:GetAttribute("RigHipHeight")>.89,"feet height measured from uploaded model")
 assert(math.abs(Rig.GroundOffset(model,root)-(root.Size.Y/2+model:GetAttribute("RigHipHeight")))<.0001)
 local _,bodySize=Rig.BodyBounds(model,root)
 assert(bodySize.X<.5,"spawn clearance excludes authored T-pose arm span")
 local motors=0
 for _,p in ipairs(model:GetDescendants()) do
  if p:IsA("Motor6D") then motors+=1 end
  if p:IsA("BasePart") and p~=root then assert(not p.Anchored and not p.CanCollide) end
  assert(p.Name~="ZombieBodyWeld","articulated limbs cannot be rigidly welded to root")
 end
 assert(motors==11 and tags[model])
 local before=rolled
 Z.Assign(model,statRandom);prepare(model)
 assert(rolled==before and model:GetAttribute("ZombieAnimationType")==kind and model:GetAttribute("ZombieAttackSide")=="Left","sleep/wake preserves type and striking hand")
 model:SetAttribute("ActivityMode","Active")
 table.insert(models,model)
end
local viewerRoot={Position=models[1]:FindFirstChild("HumanoidRootPart").Position}
local viewer={Character={FindFirstChild=function() return viewerRoot end}}
local Players={}
local tick=signal()
local RunService={PreSimulation=tick}
'''
driver=(root/'src/shared/ZombieAnimationDriver.luau').read_text()
driver=re.sub(r'local (Players|Collection|RunService|Shared|Z|Pose)\s*=\s*[^\n]+\n','',driver)
s+='\nlocal Driver=(function()\n'+driver+'\nend)()\nDriver.Start(viewer,false)\n'
s+=r'''
tick:Fire(1/30)
for _,m in ipairs(models) do
 local waist=m:FindFirstChild("Waist",true)
 assert(waist.Transform and waist.Transform.UpVector.Z<0,"all three types hunch forward despite anchored roots")
 local rest=waist.Transform
 m:SetAttribute("ZombieAttackStartedAt",serverTime-Z.Contact(m:GetAttribute("ZombieAnimationType")))
 tick:Fire(1/30)
 assert(waist.Transform.UpVector.Z<rest.UpVector.Z,"attack leans forward at its contact")
 local before=waist.Transform
 m:SetAttribute("WorldDormant",true);tick:Fire(1/30);assert(waist.Transform==before)
 m:SetAttribute("WorldDormant",nil);m:SetAttribute("ActivityMode","AFK");tick:Fire(1/30);assert(waist.Transform==before)
 m:SetAttribute("ActivityMode","Active");m:SetAttribute("IsDead",true);tick:Fire(1/30);assert(waist.Transform==before)
 m:SetAttribute("IsDead",false)
end
local sample=Z.Sample(Vector3.new(.4,.7,.315),3,"Left",0,Z.Contact(3))
local later=Z.Sample(Vector3.new(.4,.7,.315),3,"Left",1,Z.Contact(3))
assert((sample.Left-later.Left).Magnitude==0 and (sample.Right-later.Right).Magnitude>0,"third type always attacks left and flops right")
viewerRoot.Position=viewerRoot.Position+Vector3.new(1000,0,0)
local waist=models[1]:FindFirstChild("Waist",true);local before=waist.Transform
tick:Fire(1/30);assert(waist.Transform==before,"far viewer performs no animation work")
Driver.Start(nil,true);tick:Fire(1/30);assert(waist.Transform~=before,"Studio server preview works without a local player")
for _,m in ipairs(models) do removed:Fire(m) end
before=waist.Transform;tick:Fire(1/30);assert(waist.Transform==before,"tag removal disconnects viewer records")
print("PASS: uploaded zombie rig, no hand asset, 11 joints, root-only anchor, stable variants, three poses, culling, dormancy, death and Studio preview")
'''
# Run the real damage guard/timing branch without a weapon model or equipment service.
branch=ai[ai.index('  if delta.Magnitude<=attackDistance and os.clock()>=ready then'):ai.index('  -- Being close across a wall/window')]
s+=r'''
local model=models[1]
local root=model:FindFirstChild("HumanoidRootPart")
local head=model:FindFirstChild("Head")
local humanoid=model:FindFirstChildOfClass("Humanoid")
local victimModel=Instance.new("Model",workspace);local victim=Instance.new("Humanoid",victimModel);victim.Health=100
local nearest=Instance.new("Part",victimModel);nearest.CFrame=root.CFrame*CFrame.new(0,0,-.5)
local dead=false
local weapon=Z.Weapon
local delta=Vector3.new(0,0,-.5)
local attackDistance=1.3
local ready=0
local now=0
local os={clock=function() return now end}
local jobs={}
task.delay=function(delay,fn) table.insert(jobs,{At=now+delay,Fn=fn}) end
local damage=0
local Damage={RollHit=function() return true end,Apply=function() damage+=1;return 1 end,Miss=function() end}
local Sight={Cast=function() return nil end}
local Sector={InSector=function() return true end}
local CombatRules={UnarmedDamage=function() return 5 end}
Players.GetPlayerFromCharacter=function() return nil end
local function attack()
'''+branch+r'''
end
local function advance(dt)
 now+=dt
 for i=#jobs,1,-1 do if jobs[i].At<=now then local fn=jobs[i].Fn;table.remove(jobs,i);fn() end end
end
for kind=1,3 do
 model:SetAttribute("ZombieAnimationType",kind);model:SetAttribute("ActivityMode","Active")
 now+=10;local count=damage
 attack();attack()
 assert(#jobs==1,"one attack per cooldown, no motor dependency")
 advance(Z.Contact(kind)-.01);assert(damage==count)
 advance(.02);assert(damage==count+1,"damage is tied to variant contact")
 now+=10;attack();model:SetAttribute("ActivityMode","AFK");advance(1);assert(damage==count+1,"sleep cancels delayed contact")
end
print("PASS: actual zombie attack works without old hand, per-type contact, cooldown and sleeping-target guard")
'''
with tempfile.TemporaryDirectory() as directory:
 p=Path(directory)/'zombie.luau';p.write_text(s)
 subprocess.run([sys.argv[1] if len(sys.argv)>1 else 'luau',str(p)],check=True)
