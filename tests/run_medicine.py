"""Actual medical authority plus knockout/revival lifecycle against engine mocks."""
from pathlib import Path
import re,subprocess,sys,tempfile
root=Path(__file__).resolve().parents[1]
medicine=(root/'src/server/Medicine.server.luau').read_text().replace('local Literal=require(game:GetService("ReplicatedStorage").Shared.LocalizationRules)', 'local Literal={Protect=function(v) return v end}')
medicine=re.sub(r'local (Inventory|Progression|Life|Journal|Rules|Sight)=require[^\n]+\n','',medicine)
life=(root/'src/server/Services/PlayerLifeService.luau').read_text()
life=life[life.index('function Service.Knockout'):life.index('function Service.Damage')]
setup='''
local Animation={Cancel=function() end}
local Beds={Leave=function() end}
a:LoadCharacterAsync();b:LoadCharacterAsync();c:LoadCharacterAsync()
Enum.HumanoidStateType={GettingUp=1}
for _,p in ipairs({a,b,c}) do
 p.Character.Humanoid.ChangeState=function() end
 p.Character.HumanoidRootPart.Anchored=false;p.Character.HumanoidRootPart.CanCollide=true;p.Character.HumanoidRootPart.CanQuery=true
end
local timers={}
function task.delay(seconds,fn) table.insert(timers,{Seconds=seconds,Run=fn}) end
local finished,knocked={},{}
local Chests={Close=function() end}
local function freeze(c)
 for _,p in ipairs(c:GetDescendants()) do if p:IsA("BasePart") then p.Anchored=true;p.CanCollide=false;p.CanQuery=true end end
end
local BodyFall={Play=function(c,kind) c:SetAttribute("BodyPoseKind",kind);c:PivotTo(CFrame.new(Vector3.new(0,-1,0))) end,Restore=function(c) c:SetAttribute("BodyPoseKind",nil) end}
local finishedCount=0
local Service={Finish=function() finishedCount+=1 end}
LIFE
local Life=Service
local equipped=3
local Inventory={UseMedicine=function() if equipped==0 then return false end;equipped-=1;return true end}
local xp,notices=0,{}
local Progression={Award=function(_,amount) xp+=amount end}
local Journal={Send=function(_,text) table.insert(notices,text) end}
local wall=false
local Sight={Cast=function() return wall and {Instance={IsDescendantOf=function() return false end}} or nil end}
local roll=0
local Random={new=function() return {NextNumber=function() return roll end} end}
a:SetAttribute("Endurance",11);b:SetAttribute("Endurance",11);a.Character:SetAttribute("MedicineItem","Bandage")
a:SetAttribute("SkillFirstAid",25);a:SetAttribute("FirstAidMultiplier",1);a:SetAttribute("SkillDoctor",20)
'''
cases='''
local remote=ReplicatedStorage.MedicalAction
local function use(mode,target) clock+=.6;remote.OnServerEvent:Fire(a,mode,target) end
b.Character.Humanoid.Health=70
use("Bandage",b)
assert(b.Character.Humanoid.Health==82 and equipped==2 and xp==12,"actual healing, one bandage and HP-based XP")
use("Bandage",b);assert(b.Character.Humanoid.Health==94 and xp==24)
use("Bandage",b);assert(b.Character.Humanoid.Health==100 and xp==30 and equipped==0,"overheal awards only actual HP")
use("Bandage",b);assert(equipped==0 and xp==30,"full HP consumes nothing")
b.Character.Humanoid.Health=50;use("Bandage",b);assert(b.Character.Humanoid.Health==50 and xp==30,"no free healing without equipped medicine")
equipped=5
a.Character.Humanoid.Health=50;use("Bandage",a);assert(a.Character.Humanoid.Health==62 and xp==30,"self healing never awards XP")
a:SetAttribute("FirstAidMultiplier",2);use("Bandage",b);assert(b.Character.Humanoid.Health==74 and xp==54)
b.Character.HumanoidRootPart.Position=Vector3.new(4,0,0);local before=equipped;use("Bandage",b);assert(equipped==before,"range enforced by server")
b.Character.HumanoidRootPart.Position=Vector3.zero;wall=true;use("Bandage",b);assert(equipped==before,"cannot heal through walls");wall=false
b.Character.Humanoid.Health=99.5;use("Bandage",b);assert(xp==54.5,"fractional missing HP grants exact XP")
a.Character:SetAttribute("MedicineItem","GreatBandage");a:SetAttribute("FirstAidMultiplier",1)
b.Character.Humanoid.Health=50;local oldXP=xp;local oldCount=equipped
use("Bandage",b)
assert(b.Character.Humanoid.Health==74 and xp==oldXP+24 and equipped==oldCount-1,"great bandage doubles target Endurance and skill contribution")
xp=oldXP;b.Character.Humanoid.Health=99.5;equipped=oldCount
a.Character:SetAttribute("MedicineItem","Bandage")
local standing=b.Character:GetPivot()
Life.Knockout(b,b.Character);local oldTimer=function() end
assert(b.Character:GetAttribute("Knockout") and b.Character.HumanoidRootPart.Anchored and b.Character:GetAttribute("BodyPoseKind")=="Knockout")
use("Bandage",b);assert(b.Character:GetAttribute("Knockout") and equipped==before-1,"bandages cannot revive")
roll=.1;use("Doctor",b);assert(b.Character:GetAttribute("Knockout"),"20 Doctor misses at10% boundary")
local cooldown=a:GetAttribute("DoctorReadyAt")
roll=0;use("Doctor",b);assert(b.Character:GetAttribute("Knockout") and a:GetAttribute("DoctorReadyAt")==cooldown,"failed attempt also has10s cooldown")
clock+=10;use("Doctor",b)
assert(not b.Character:GetAttribute("Knockout") and b.Character.Humanoid.Health==2 and xp==154.5)
assert(b.Character:GetAttribute("BodyPoseKind")==nil,"revival releases the terminal pose")
assert(not b.Character.HumanoidRootPart.Anchored and b.Character.HumanoidRootPart.CanCollide and not b.Character.Humanoid.PlatformStand,"physical state restored")
assert(b.Character:GetPivot()==standing,"upright saved pose restored")
assert(b:GetAttribute("ReviveLockedUntil")==clock+600)
Life.Knockout(b,b.Character)
oldTimer();assert(finishedCount==0,"old knockout timeout cannot kill revived/re-knocked patient")
clock+=10;use("Doctor",b);assert(b.Character:GetAttribute("Knockout"),"patient10minute immunity to repeated revival")
clock=b:GetAttribute("ReviveLockedUntil")+1
a:SetAttribute("SkillDoctor",200);a:SetAttribute("ReviveLockSeconds",300);roll=.999
use("Doctor",b);assert(not b.Character:GetAttribute("Knockout") and b:GetAttribute("ReviveLockedUntil")==clock+300 and xp==254.5,"200 Doctor certain; field hospital sets5min patient lock")
clock=b:GetAttribute("ReviveLockedUntil")+1
Life.Knockout(b,b.Character)
a:SetAttribute("DoctorFortuneChance",.17);roll=.169
use("Doctor",b)
assert(not b.Character:GetAttribute("Knockout") and b.Character.Humanoid.Health==b.Character.Humanoid.MaxHealth and b:GetAttribute("ReviveLockedUntil")==0,"fortunate revival restores full HP and removes patient lock")
Life.Knockout(b,b.Character);clock+=10;roll=.17
use("Doctor",b)
assert(b.Character.Humanoid.Health==2 and b:GetAttribute("ReviveLockedUntil")==clock+300,"fortune boundary does not trigger")
clock=b:GetAttribute("ReviveLockedUntil")+1
Life.Knockout(b,b.Character);a:SetAttribute("MedicalHealingBonus",10);a:SetAttribute("DoctorFortuneChance",0);b:SetAttribute("ReviveHealthBonus",.2);b:SetAttribute("ReviveLockReduction",180);roll=.5
use("Doctor",b)
assert(b.Character.Humanoid.Health==32 and b:GetAttribute("ReviveLockedUntil")==clock+120,"patient gets +20percentHP plus healer paramedic10 and field hospital300 minus180 seconds")
a:SetAttribute("FirstAidMultiplier",1);equipped=2
b.Character.Humanoid.Health=50;use("Bandage",b)
assert(b.Character.Humanoid.Health==72,"paramedic adds ten to ordinary bandage")
a.Character:SetAttribute("MedicineItem","GreatBandage");b.Character.Humanoid.Health=50;use("Bandage",b)
assert(b.Character.Humanoid.Health==84,"paramedic adds ten, not twenty, to great bandage")
a.Character:SetAttribute("Knockout",true);b.Character.Humanoid.Health=50;before=equipped;use("Bandage",b);assert(equipped==before,"incapacitated healer denied")
print("PASS: medical authority, self/other actual HP XP, medicine consumption, overheal, wall/range guards; doctor chance, both cooldowns, restoration and stale knockout timer safety")
'''
parts=[(root/'tests/fixtures/town_mock.luau').read_text(),'local Rules=(function()\n'+(root/'src/shared/ProgressionRules.luau').read_text()+'\nend)()',setup.replace('LIFE',life),medicine,cases]
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'test.luau';p.write_text('\n'.join(parts));subprocess.run([sys.argv[1],str(p)],check=True)
