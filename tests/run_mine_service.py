"""Production mine service under deterministic players, time, inventory and ground."""
from pathlib import Path
import subprocess,re,sys,tempfile
root=Path(__file__).resolve().parents[1]
def module(p):return '(function()\n'+(root/p).read_text()+'\nend)()'
s=(root/'tests/fixtures/town_mock.luau').read_text()+'\n'+(root/'tests/rig_math.fixture.luau').read_text()
s+='\nlocal Interaction='+module('src/shared/Interaction.luau')
s+='\nlocal MineGeometry='+module('src/shared/MineGeometry.luau')
s+='\nlocal Rules='+module('src/shared/MineRules.luau')+'\nlocal ExplosionRules='+module('src/shared/ExplosionRules.luau')+'\nlocal Affiliation='+module('src/shared/AffiliationRules.luau')
s+='\nlocal Visibility=(function()\n'+(root/'src/shared/VisibilityRules.luau').read_text()+'\nend)()\nlocal Config={CreatureViewAngle=160}'
s+=r'''
local RunService={Heartbeat=event()}
workspace.DescendantAdded=event()
local oldGet=game.GetService
function game:GetService(name) return name=="RunService" and RunService or oldGet(self,name) end
Enum.Material={Metal=1};Color3={fromRGB=function() return {} end}
local roll=.99
local Random={new=function() return {NextNumber=function() return roll end} end}
local actualNew=Instance.new
Instance.new=function(class)
 local o=actualNew(class)
 if class=="RemoteEvent" then
  function o:FireClient(p,...) table.insert(self.sent,{player=p,args={...}}) end
  function o:FireAllClients(...) table.insert(self.sent,{args={...},all=true}) end
 end
 return o
end
local source=make("Part","Mine",ServerStorage)
source.Size=Vector3.new(.9,.16,.9);source.CFrame=CFrame.identity
local Visuals={Template=function(id) return id=="Mine" and source or nil end}
local Items={Mine={Explosion={KillRadius=5,BlastRadius=20}}}
local ItemConfig={Items=Items,PickupDistance=2}
local consumed,recovered=0,0
local Inventory={ConsumeHeld=function(p,id,refill)
 assert(refill==true,"mine placement must request pocket refill")
 if p.Character:GetAttribute("HandsItem")~=id then return false end
 p.Character:SetAttribute("HandsItem","");consumed+=1;return true
end,Add=function(_,id,n) assert(id=="Mine" and n==1);recovered+=1;return true end}
local pending={}
local Animation={Work=function(p,target,range,complete,cancel,planting)
 if pending[p] then return false end
 pending[p]={Complete=complete,Cancel=cancel,Target=target,Planting=planting}
 p.Character:SetAttribute("InteractionLocked",true);return true
end}
local function finish(p)
 local action=pending[p];assert(action)
 local ok=action.Complete()
 p.Character:SetAttribute("InteractionLocked",nil);pending[p]=nil;return ok
end
local function cancel(p)
 local action=pending[p];pending[p]=nil;p.Character:SetAttribute("InteractionLocked",nil)
 if action.Cancel then action.Cancel() end
 return action
end
local xpAwards,killCredits={},{}
local Progression={Award=function(p,xp) table.insert(xpAwards,{Player=p,XP=xp}) end,ZombieKillXP=function(model) table.insert(killCredits,model) end}
local notices={}
local Journal={Send=function(p,msg) table.insert(notices,{Player=p,Text=msg}) end}
local Towns={RelationBetween=function(first,second) return first:GetAttribute("TownID")==second:GetAttribute("TownID") and "Ally" or "Neutral" end,TradeTown=function(id) return id==1 and {LeaderID=c.UserId} or nil end}
local blasts={}
local Explosions={Detonate=function(point,settings,owner,character,id,damage,options)
 assert(options.FriendlyFire==true and options.OwnerUserId==a.UserId)
 table.insert(blasts,{Point=point,Settings=settings,Owner=owner,Options=options})
 local trigger=options.TriggerCharacter
 local victim
 for _,p in ipairs(Players:GetPlayers()) do if p.Character==trigger then victim=p end end
 if victim then
  local hp=trigger:FindFirstChildOfClass("Humanoid");hp.Health=0
  options.OnDamage(hp,100,victim)
 elseif trigger then
  local hp=trigger:FindFirstChildOfClass("Humanoid");hp.Health=0
  trigger:SetAttribute("LastDamagerID",options.OwnerUserId)
  options.OnDamage(hp,100,nil)
 end
end}
for _,p in ipairs(Players:GetPlayers()) do
 p.CharacterRemoving=event();p.LocaleId="uk-UA";p:SetAttribute("TeamID",p==b and 2 or 1);p:SetAttribute("TownID",p==b and 2 or 1)
 p:LoadCharacterAsync();p.Character.HumanoidRootPart.Size=Vector3.new(.5,1,.5)
end
local function move(p,x,z,y)
 local root=p.Character.HumanoidRootPart;root.Position=Vector3.new(x,y or 1,z);root.CFrame=CFrame.new(root.Position)
end
local function face(p,point)
 local root=p.Character.HumanoidRootPart;local delta=point-root.Position
 root.CFrame=CFrame.new(root.Position)*CFrame.Angles(0,math.atan2(-delta.X,-delta.Z),0)
end
for index,p in ipairs(Players:GetPlayers()) do move(p,index*100,0) end
function workspace:Raycast(origin,delta)
 if delta.Y==-7 then return {Position=Vector3.new(origin.X,0,origin.Z),Normal=Vector3.yAxis,Instance=source} end
 return nil
end
local function step(dt) tick(dt);RunService.Heartbeat:Fire(dt) end
local function ready(p,x)
 p.Character.Humanoid.Health=100;p.Character:SetAttribute("Knockout",nil);p.Character:SetAttribute("IsDead",nil);p.Character:SetAttribute("HandsItem","Mine");move(p,x,0)
end
'''
service=(root/'src/server/Services/MineService.luau').read_text()
service=re.sub(r'local (Progression|Visibility|Config|Rules|Items|ExplosionRules|Explosions|Inventory|Visuals|Animation|Journal|Towns|Affiliation|ItemConfig|MineGeometry|Interaction)=require[^\n]+\n','',service)
s+='\nlocal Mines=(function()\n'+service+'\nend)()'
s+=r'''
local remote=ReplicatedStorage:FindFirstChild("MineAction")
local function lastReveal(p)
 for i=#remote.sent,1,-1 do local e=remote.sent[i];if e.player==p and e.args[1]=="Reveal" then return e.args[2],e.args[3] end end
end
local function plant(x)
 ready(a,x);a:SetAttribute("SkillTraps",250)
 assert(Mines.Place(a));assert(pending[a].Planting)
 local stale=pending[a].Complete
 assert(finish(a))
 local count=consumed
 a.Character:SetAttribute("HandsItem","Mine") -- a replacement may already be drawn
 assert(not stale() and consumed==count,"stale callback cannot consume a freshly refilled mine")
 a.Character:SetAttribute("HandsItem","")
 RunService.Heartbeat:Fire(.1);return lastReveal(a)
end
-- Cancellation leaves the item owned and stale completion cannot consume it.
ready(a,0);assert(Mines.Place(a));local old=cancel(a)
assert(consumed==0 and not old.Complete() and a.Character:GetAttribute("HandsItem")=="Mine")
local id,frame=plant(10)
assert(consumed==1 and not Mines.Disarm(b,id),"unknown mine cannot be remotely disarmed")
move(a,frame.Position.X,frame.Position.Z)
step(4.9);assert(#blasts==0,"unarmed grace period")
step(.11);assert(#blasts==1 and a.Character.Humanoid.Health==0,"own mine kills its owner after exactly five seconds")
assert(not Mines.Disarm(a,id),"detonated mine cannot be recovered")
-- Owner defuses at 100%, even with the maximum adversarial random roll.
local own,ownFrame=plant(20);move(a,ownFrame.Position.X+1,ownFrame.Position.Z)
roll=1;assert(Mines.Disarm(a,own));assert(finish(a));assert(recovered==1 and #blasts==1)
assert(#xpAwards==0,"own defuse gives no XP")
-- Discovery is private, skill weighted, one notice per trap; lock concurrent work.
local other,otherFrame=plant(30)
b:SetAttribute("Attention",10);b:SetAttribute("SkillTraps",250);b.Character.Humanoid.Health=100
move(a,100,0);move(b,otherFrame.Position.X+1.2,otherFrame.Position.Z)
step(.1);assert(lastReveal(b)~=other,"mine outside forward sector is not discovered")
face(b,otherFrame.Position);step(.1);assert(lastReveal(b)==other)
local beforeNotices=#notices;step(.1);assert(#notices==beforeNotices,"discovery does not spam")
roll=.1;assert(Mines.Disarm(b,other));move(a,otherFrame.Position.X+1,otherFrame.Position.Z)
assert(not Mines.Disarm(a,other),"one disarmer at a time")
assert(finish(b));assert(recovered==2)
assert(#xpAwards==1 and xpAwards[1].Player==b and xpAwards[1].XP==250,"enemy defuse awards snapshotted planter skill")
-- Allied defuse recovers the item but cannot farm XP.
local allied,alliedFrame=plant(35);move(a,100,0)
b:SetAttribute("TeamID",1);b:SetAttribute("TownID",1)
move(b,alliedFrame.Position.X+1.2,alliedFrame.Position.Z);face(b,alliedFrame.Position);step(.1)
assert(Mines.Disarm(b,allied) and finish(b))
assert(#xpAwards==1,"allied defuse gives no XP")
-- Failure detonates and reports the planter even after disconnect, to victim/mayor.
local failed,failedFrame=plant(40);move(a,100,0)
b:SetAttribute("TeamID",1);b:SetAttribute("TownID",1);b:SetAttribute("SkillTraps",0)
move(b,failedFrame.Position.X+1.2,failedFrame.Position.Z);face(b,failedFrame.Position);step(.1)
assert(lastReveal(b)==failed)
roll=1;assert(Mines.Disarm(b,failed))
a.Parent=nil
assert(finish(b));assert(#blasts==2 and blasts[2].Owner==nil and b.Character.Humanoid.Health==0)
local toldVictim,toldMayor=false,false
for _,n in ipairs(notices) do
 if string.find(n.Text,"@"..a.Name,1,true) then
  if n.Player==b then toldVictim=true elseif n.Player==c then toldMayor=true end
 end
end
assert(toldVictim and toldMayor,"friendly victims and mayor learn the saved planter username")
a.Parent=Players
-- Swept pressure checks catch a fast runner between two samples, no ally immunity.
move(b,200,0);local swept,sweptFrame=plant(50);move(a,100,0)
b.Character.Humanoid.Health=100;move(b,sweptFrame.Position.X-3,sweptFrame.Position.Z)
step(5.1);local oldCount=#blasts
move(b,sweptFrame.Position.X+3,sweptFrame.Position.Z);step(.1)
assert(#blasts==oldCount+1 and b.Character.Humanoid.Health==0,"fast allied runner triggers exactly once")
step(.1);assert(#blasts==oldCount+1)
-- Own mines follow exactly the same discovery radius and have no auto reveal.
ready(a,60);a:SetAttribute("SkillTraps",0);a:SetAttribute("Attention",10)
local oldReveal=lastReveal(a)
assert(Mines.Place(a) and finish(a));move(a,70,-1.3);RunService.Heartbeat:Fire(.1)
assert(lastReveal(a)==oldReveal,"owner does not see their mine from ten studs with only five-stud detection")
a:SetAttribute("SkillTraps",300);face(a,Vector3.new(60,0,-1.3));RunService.Heartbeat:Fire(.1)
assert(lastReveal(a)~=oldReveal,"owner discovers it under the ordinary skill-weighted rule")
local noticesBefore=#notices
move(a,90,-1.3);step(.1)
move(a,70,-1.3);face(a,Vector3.new(60,0,-1.3));step(.1)
assert(#notices==noticesBefore+1 and notices[#notices].Text=="Помічена пастка","each new approach announces a previously known mine")
move(a,70,-1.3);step(.1);face(a,Vector3.new(60,0,-1.3));step(.1)
assert(#notices==noticesBefore+1,"turning away and back in the same approach does not spam")
-- Zombies spawned after service startup use the same armed/swept/height rules.
move(a,100,0);move(b,200,0)
local zombie=make("Model","Zombie",workspace)
local zh=make("Humanoid","Humanoid",zombie);zh.Health=20;zh.HipHeight=0
local zr=make("Part","HumanoidRootPart",zombie);zr.Size=Vector3.new(.5,1,.5)
local function zmove(x,z,y) zr.Position=Vector3.new(x,y or 1,z) end
workspace.DescendantAdded:Fire(zh)
local zid,zframe=plant(110);move(a,150,0);zmove(zframe.Position.X,zframe.Position.Z)
local count=#blasts
step(4.9);assert(#blasts==count,"zombies cannot trigger unarmed mines")
zh.Health=0;step(.2);assert(#blasts==count,"dead zombies cannot trigger mines")
zh.Health=20;zmove(zframe.Position.X,zframe.Position.Z,8);step(.1)
assert(#blasts==count,"zombie on another floor cannot trigger mine")
zmove(zframe.Position.X-3,zframe.Position.Z);step(.1)
zmove(zframe.Position.X+3,zframe.Position.Z);step(.1)
assert(#blasts==count+1 and blasts[#blasts].Options.TriggerCharacter==zombie,"fast zombie crossing detonates with its own model as trigger")
step(.1);assert(#blasts==count+1,"mine detonates only once")
assert(killCredits[#killCredits]==zombie,"mine death callback forwards zombie kill credit")
zh.Health=20
-- Custom names and late CreatureType assignment are supported.
local aid,aframe=plant(120);move(a,150,0)
zombie.Name="Walker";zmove(aframe.Position.X,aframe.Position.Z)
count=#blasts;step(5.1);assert(#blasts==count,"unrelated humanoids do not trigger zombie logic")
zombie:SetAttribute("CreatureType","Zombie");step(.1)
assert(#blasts==count+1,"late zombie identity works while standing on the armed mine")
zombie.Parent=nil;step(.1)
print("PASS: zombie pressure, arming grace, dead/other-floor rejection, swept crossings and late zombie initialization")
-- Formula endpoints and floor/teleport separation.
assert(Rules.DisarmChance(250,250,false)==.9 and Rules.DisarmChance(0,250,false)==.05)
assert(Rules.DisarmChance(0,300,true)==1)
assert(Rules.DetectionRadius(10,300)==20 and Rules.DetectionRadius(10,0)==5)
assert(not Rules.Crossed(Vector3.new(-3,8,0),Vector3.new(3,8,0),Vector3.zero,2))
assert(not Rules.Crossed(Vector3.new(-100,1,0),Vector3.new(100,1,0),Vector3.zero,2))
print("PASS: exact arming grace, owner/ally lethality, fast-run sweep, cancellation and stale callbacks")
print("PASS: private discovery/no spam, disarm odds/ownership, concurrent lock, recovery/failure and offline planter accountability")
'''
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'mines.luau';p.write_text(s)
 subprocess.run([sys.argv[1] if len(sys.argv)>1 else 'luau',str(p)],check=True)
