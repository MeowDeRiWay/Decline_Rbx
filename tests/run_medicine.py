"""Actual medical authority plus knockout/revival lifecycle against engine mocks."""
from pathlib import Path
import re,subprocess,sys,tempfile
root=Path(__file__).resolve().parents[1]
medicine=(root/'src/server/Medicine.server.luau').read_text().replace('local Literal=require(game:GetService("ReplicatedStorage").Shared.LocalizationRules)', 'local Literal={Protect=function(v) return v end}')
medicine=re.sub(r'local (Inventory|Progression|Life|Journal|Rules|Sight|Medical|Config|Hands)=require[^\n]+\n','',medicine)
life=(root/'src/server/Services/PlayerLifeService.luau').read_text().replace('require(script.Parent.HandActionService).Cancel(player)','')
life=life[life.index('function Service.Knockout'):life.index('function Service.Damage')]
setup='''
local Hands={Treat=function(_,_,apply) return apply() end}
local Animation={Cancel=function() end}
local Beds={Leave=function() end,Reposition=function() end}
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
local function use(mode,target) a.Character:SetAttribute("MedicalHeld",true);clock+=.6;remote.OnServerEvent:Fire(a,mode,target) end
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
local koXP=xp;local koStock=equipped
use("Bandage",b);assert(b.Character:GetAttribute("Knockout") and equipped==koStock-1 and b.Character.Humanoid.Health==13,"bandages treat KO without waking")
xp=koXP;b.Character.Humanoid.Health=1
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
a.Character:SetAttribute("Knockout",false);a.Character:SetAttribute("MedicineItem","SterileBandage")
a:SetAttribute("SkillFirstAid",100);a:SetAttribute("FirstAidMultiplier",1);a:SetAttribute("MedicalHealingBonus",0);a:SetAttribute("Luck",10);b:SetAttribute("Luck",10);b:SetAttribute("Endurance",5)
b.Character:SetAttribute("Knockout",false);b.Character:SetAttribute("Sick",35);b.Character:SetAttribute("Poisoned",true)
b.Character.Humanoid.MaxHealth=100;b.Character.Humanoid.Health=50;equipped=5;roll=.5
use("Bandage",b)
assert(b.Character.Humanoid.Health==70 and b.Character:GetAttribute("Sick")==5 and b.Character:GetAttribute("Poisoned") and equipped==4,"sterile heals2END+2per20, removes30Sick and50% remains fixed despite Luck10")
b.Character.Humanoid.Health=100;roll=.499
local priorXP=xp
use("Bandage",b)
assert(b.Character.Humanoid.Health==100 and b.Character:GetAttribute("Sick")==0 and not b.Character:GetAttribute("Poisoned") and equipped==3 and xp==priorXP,"full HP permits actual debuff treatment, no fictitious healing XP")
use("Bandage",b);assert(equipped==3,"healthy full-HP target consumes nothing")
b.Character:SetAttribute("Poisoned",true);equipped=0
use("Bandage",b);assert(b.Character:GetAttribute("Poisoned"),"no item means no cure roll")
equipped=3;b.Character:SetAttribute("Knockout",false);Life.Knockout(b,b.Character);b.Character:SetAttribute("Sick",40)
b.Character.Humanoid.Health=30;roll=.1
use("Bandage",b);assert(equipped==2 and b.Character:GetAttribute("Sick")==10 and b.Character.Humanoid.Health==50 and b.Character:GetAttribute("Knockout"),"sterile treats KO without waking")
b.Character:SetAttribute("Poisoned",true);b.Character:SetAttribute("Sick",100);b.Character.Humanoid.Health=40
a.Character:SetAttribute("MedicineItem","Antiseptic");a:SetAttribute("Paramedic",true);a:SetAttribute("MedicalHealingBonus",10)
equipped=5;roll=.75
use("Bandage",b);assert(b.Character:GetAttribute("Sick")==75 and b.Character:GetAttribute("Poisoned") and b.Character.Humanoid.Health==40 and equipped==4,"failed antiseptic still removes25 Sick at FirstAid100; Paramedic adds no HP or Sick reduction")
roll=.749;use("Bandage",b);assert(b.Character:GetAttribute("Sick")==50 and not b.Character:GetAttribute("Poisoned") and b.Character:GetAttribute("Knockout"),"Luck10 has75% cure, not100%, and never wakes KO")
a:SetAttribute("Luck",0);b.Character:SetAttribute("Poisoned",true);b.Character:SetAttribute("Sick",100);roll=.25
use("Bandage",b);assert(b.Character:GetAttribute("Poisoned") and b.Character:GetAttribute("Sick")==75,"base25% exclusive boundary")
roll=.249;use("Bandage",b);assert(not b.Character:GetAttribute("Poisoned") and b.Character:GetAttribute("Sick")==50)
a.Character:SetAttribute("MedicineItem","SterileBandage");equipped=3;b.Character.Humanoid.Health=40;b.Character:SetAttribute("Sick",100)
use("Bandage",b);assert(b.Character.Humanoid.Health==70 and b.Character:GetAttribute("Sick")==60 and b.Character:GetAttribute("Knockout"),"Paramedic adds10 HP and10 extra Sick removal only to sterile")
b:SetAttribute("ReviveLockedUntil",0);clock+=10;a:SetAttribute("SkillDoctor",200);a:SetAttribute("MedicalHealingBonus",0);b:SetAttribute("ReviveHealthBonus",0)
use("Doctor",b);assert(not b.Character:GetAttribute("Knockout") and b.Character.Humanoid.Health==70,"doctor preserves accumulated bandage HP")
a:SetAttribute("Paramedic",false)
Life.Knockout(b,b.Character);b:SetAttribute("ReviveLockedUntil",0);b.Character:SetAttribute("HospitalResting",true);b.Character:SetAttribute("Sick",0);b.Character:SetAttribute("Poisoned",false)
b.Character.Humanoid.Health=49;assert(not Life.Revive(b,0,0),"doctor cannot bypass bed50% requirement")
b.Character.Humanoid.Health=50;b.Character:SetAttribute("Sick",1);assert(not Life.Revive(b,0,0))
b.Character:SetAttribute("Sick",0);b.Character:SetAttribute("Poisoned",true);assert(not Life.Revive(b,0,0))
b.Character:SetAttribute("Poisoned",false);assert(Life.Revive(b,0,0) and b.Character.Humanoid.Health==50)
b.Character:SetAttribute("HospitalResting",false)
b.Character:SetAttribute("Knockout",false)
a.Character.Humanoid.Health=50;a.Character.Humanoid.MaxHealth=100;a.Character:SetAttribute("Sick",30);a:SetAttribute("Endurance",5)
priorXP=xp;use("Bandage",a)
assert(a.Character.Humanoid.Health==70 and a.Character:GetAttribute("Sick")==0 and xp==priorXP,"self-treatment preserves the no-self-XP rule")

local pending
Hands.Treat=function(_,_,apply) pending=apply;return true end
a.Character:SetAttribute("MedicineItem","Bandage");a.Character:SetAttribute("Knockout",false)
b.Character.Humanoid.Health=20;equipped=2
use("Bandage",b);assert(pending and equipped==2 and b.Character.Humanoid.Health==20,"treatment never consumes or heals at animation start")
b.Character.HumanoidRootPart.Position=Vector3.new(4,0,0);pending()
assert(equipped==2 and b.Character.Humanoid.Health==20,"range rechecked at medical contact")
b.Character.HumanoidRootPart.Position=Vector3.zero
use("Bandage",b);wall=true;pending();wall=false
assert(equipped==2 and b.Character.Humanoid.Health==20,"wall appearing during animation cancels effect")
use("Bandage",b);a.Character:SetAttribute("Knockout",true);pending();a.Character:SetAttribute("Knockout",false)
assert(equipped==2 and b.Character.Humanoid.Health==20,"incapacitation before contact spends no item")
use("Bandage",b);pending();assert(equipped==1 and b.Character.Humanoid.Health>20,"valid medical contact applies the normal effect once")
print("PASS: sterile healing, fixed50% sterile and25%+Luck antiseptic cure boundaries, scaled Sick clamp, item consumption, full-HP debuff treatment, KO treatment without waking, retained HP and self-treatment")
print("PASS: medical authority, self/other actual HP XP, medicine consumption, overheal, wall/range guards; doctor chance, both cooldowns, restoration and stale knockout timer safety")
'''
parts=[(root/'tests/fixtures/town_mock.luau').read_text(),'local Medical=(function()\n'+(root/'src/shared/MedicalRules.luau').read_text()+'\nend)()\nlocal Config=(function()\n'+(root/'src/shared/MedicalConfig.luau').read_text()+'\nend)()\nlocal Rules=(function()\n'+(root/'src/shared/ProgressionRules.luau').read_text()+'\nend)()',setup.replace('LIFE',life),medicine,cases]
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'test.luau';p.write_text('\n'.join(parts));subprocess.run([sys.argv[1],str(p)],check=True)
