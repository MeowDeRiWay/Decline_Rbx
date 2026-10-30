"""Hospital bed authority, healing cadence and lifecycle using actual service code."""
from pathlib import Path
import re, subprocess, sys, tempfile
root=Path(__file__).resolve().parents[1]
source=(root/'src/server/Services/HospitalBedService.luau').read_text()
source=re.sub(r'local (Items|Interaction|Journal|Debuffs)=require[^\n]+\n','',source)
source=source.replace('require(script.Parent.BodyFallService)','BodyFall').replace('require(script.Parent.PlayerLifeService)','Life')
setup='''
local Debuffs={Treat=function(c,dt) local sick=math.max(0,(c:GetAttribute("Sick") or 0)-2*dt);c:SetAttribute("Sick",sick);if sick==0 then c:SetAttribute("Poisoned",false) end;return sick==0 end}
local BodyFall={Restore=function() end}
local Life={Revive=function(p) p.Character:SetAttribute("Knockout",false);return true end}
local regenMessages={}
local Journal={Send=function(_,text) table.insert(regenMessages,text) end}
local Items={PickupDistance=2}
local Interaction={NearestPoint=function(object) return object.Position or Vector3.zero end}
local oldNew=CFrame.new
function CFrame.new(x,y,z) return oldNew(type(x)=="number" and Vector3.new(x,y,z) or x) end
function CFrame.Angles(x,y,z) assert(x==-math.pi/2 and y==0 and z==0);return oldNew() end
local oldIndex=cfmeta.__index
cfmeta.__index=function(a,k)
 if k=="Inverse" then return function(self) return oldNew(Vector3.new(-self.Position.X,-self.Position.Y,-self.Position.Z)) end end
 return oldIndex(a,k)
end
for _,p in ipairs({a,b}) do
 p:LoadCharacterAsync();p.Character.HumanoidRootPart.Anchored=false;p.Character.HumanoidRootPart.CanCollide=true
 p.Character.Humanoid.AutoRotate=true;p.Character:SetAttribute("Regeneration",6);p.Character:SetAttribute("Sick",40)
 p.Character.Humanoid.Health=20;p.Character.Humanoid.MaxHealth=50
end
local bed=make("Model","Any hospital bed name",workspace,{HospitalBed=true})
local surface=make("Part","BedSurface",bed)
local wall=make("Part","Wall",workspace)
local blocked=false
function workspace:Raycast() return blocked and {Instance=wall} or nil end
'''
cases='''
local originalRay=workspace.Raycast
function workspace:Raycast(_,_,params)
 if not table.find(params.FilterDescendantsInstances,b.Character) then return {Instance=b.Character.HumanoidRootPart} end
end
b.Character:SetAttribute("Knockout",true)
assert(Beds.PlacePatient(a,b,bed),"the carried patient must not block LOS to their own bed")
assert(Beds.Leave(b));b.Character:SetAttribute("Knockout",false);b.Character.HumanoidRootPart.Anchored=false
workspace.Raycast=originalRay
blocked=true;assert(not Beds.Use(a,bed),"wall blocks entering bed")
blocked=false;bed.Position=Vector3.new(3,0,0);assert(not Beds.Use(a,bed),"two-stud reach enforced")
bed.Position=Vector3.zero
a.Character:SetAttribute("Knockout",true);assert(not Beds.Use(a,bed));a.Character:SetAttribute("Knockout",false)
local start=a.Character:GetPivot()
assert(Beds.Use(a,bed) and a.Character:GetAttribute("HospitalResting") and a.Character.HumanoidRootPart.Anchored)
assert(not a.Character.HumanoidRootPart.CanCollide and bed:GetAttribute("HospitalBedUserId")==a.UserId)
assert(not Beds.Use(b,bed),"one patient per bed")
a.Character:SetAttribute("Poisoned",true)
clock+=19;Beds.Step();assert(a.Character.Humanoid.Health==20 and a.Character:GetAttribute("Sick")==2)
clock+=1;Beds.Step();assert(a.Character:GetAttribute("Sick")==0 and not a.Character:GetAttribute("Poisoned") and a.Character.Humanoid.Health==20,"clear consequences before HP regeneration")
clock+=20;Beds.Step();assert(a.Character.Humanoid.Health==26)
assert(regenMessages[#regenMessages]=="Regeneration restored 6 HP.")
a.Character.Humanoid.Health=49;clock+=20;Beds.Step()
assert(regenMessages[#regenMessages]=="Regeneration restored 1 HP.")
local messageCount=#regenMessages
clock+=20;Beds.Step();assert(#regenMessages==messageCount)
assert(Beds.Use(a,nil) and a.Character:GetPivot()==start and not a.Character.HumanoidRootPart.Anchored)
assert(a.Character.HumanoidRootPart.CanCollide and a.Character.Humanoid.AutoRotate and not bed:GetAttribute("HospitalBedUserId"),"get up restores pose, controls and vacancy")
bed:SetAttribute("HospitalRegenMultiplier",6)
assert(Beds.Use(a,bed));a.Character.Humanoid.Health=20;clock+=9;Beds.Step();assert(a.Character.Humanoid.Health==20)
clock+=1;Beds.Step();assert(a.Character.Humanoid.Health==26,"configured6x ticks every10seconds")
Beds.Leave(a);assert(Beds.Use(b,bed));b.Character:SetAttribute("Sick",2)
clock+=10;Beds.Step();assert(b.Character:GetAttribute("Sick")==0,"Sick clamps at zero")
b.Character.Humanoid.Health=0;assert(Beds.Leave(b,true))
assert(not b.Character.HumanoidRootPart.Anchored,"KO transition restores upright state before knockout captures pose")
b.Character.Humanoid.Health=20;assert(Beds.Use(b,bed));b.Character:SetAttribute("Knockout",true)
b.Character.Humanoid.Health=1;b.Character:SetAttribute("Sick",2);b.Character:SetAttribute("Poisoned",true)
clock+=10;Beds.Step();assert(b.Character:GetAttribute("Knockout") and b.Character.Humanoid.Health==1,"bed clears debuffs before accumulating HP")
for _,expected in ipairs({7,13,19}) do clock+=10;Beds.Step();assert(b.Character:GetAttribute("Knockout") and b.Character.Humanoid.Health==expected,"bed does not revive below50%") end
clock+=10;Beds.Step();assert(bed:GetAttribute("HospitalBedUserId")==b.UserId and not b.Character:GetAttribute("Knockout") and b.Character.Humanoid.Health==25,"bed revives at exact50% with no debuffs and retains HP")
Beds.Leave(b)
b.Character:SetAttribute("Knockout",false);b.Character.HumanoidRootPart.Anchored=false
assert(Beds.Use(b,bed));bed:SetAttribute("HospitalBed",false);Beds.Step()
assert(not b.Character:GetAttribute("HospitalResting") and not b.Character.HumanoidRootPart.Anchored,"disabled bed releases patient")
bed:SetAttribute("HospitalBed",true);assert(Beds.Use(a,bed));Players.PlayerRemoving:Fire(a)
assert(not bed:GetAttribute("HospitalBedUserId") and not a.Character:GetAttribute("HospitalResting"),"disconnect frees bed and restores character before session capture")
local oldCharacter=a.Character
assert(Beds.Use(a,bed));a.Character=make("Model","Replacement",workspace);Beds.Step()
assert(not bed:GetAttribute("HospitalBedUserId") and not oldCharacter:GetAttribute("HospitalResting"),"character replacement releases old patient")
a.Character=oldCharacter;assert(Beds.Use(a,bed));bed:Destroy();Beds.Step()
assert(not a.Character:GetAttribute("HospitalResting") and not a.Character.HumanoidRootPart.Anchored,"removed bed releases and unanchors patient")
print("PASS: bed reach/LOS/occupancy, default/configured timing, equal HP/Sick treatment, full HP, get up, KO, disabled bed and disconnect cleanup")
'''
with tempfile.TemporaryDirectory() as directory:
    path=Path(directory)/'hospital.luau'
    path.write_text((root/'tests/fixtures/town_mock.luau').read_text()+'\n'+setup+'\nlocal Beds=(function()\n'+source+'\nend)()\n'+cases)
    subprocess.run([sys.argv[1] if len(sys.argv)>1 else 'luau',str(path)],check=True)
