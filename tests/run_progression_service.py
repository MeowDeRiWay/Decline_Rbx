"""Exercise actual progression authority, regeneration and session lifecycle."""
from pathlib import Path
import re,subprocess,tempfile,sys
root=Path(__file__).resolve().parents[1]
s=(root/'src/server/Services/ProgressionService.luau').read_text()
s=re.sub(r'local (Rules|Config|Journal)=require[^\n]+\n','',s)
cases='''
local notices={};local Journal={Send=function(p,text) table.insert(notices,{p,text}) end}
SERVICE
Service.Start();a:LoadCharacterAsync()
local action=ReplicatedStorage.ProgressionRemotes.Action
local function send(command,value) clock+=.2;action.OnServerEvent:Fire(a,command,value) end
assert(not Service.Snapshot(a).Confirmed and not Service.CanStation(a,"Stove"))
Service.Award(a,100);assert(Service.Snapshot(a).Level==0 and #notices==0)
assert(a.Character.HumanoidRootPart.Anchored and a.Character.CreationProtection and a.Character:GetAttribute("CreatingCharacter"),"server creation lock and shield")
local draft=table.clone(Service.Snapshot(a).Stats);draft.Intelligence=10;draft.Endurance=6
send("Confirm",draft)
assert(a:GetAttribute("AttributesConfirmed") and a:GetAttribute("CarryLimitKg")==25 and a.Character.Humanoid.MaxHealth==60)
assert(not a.Character.HumanoidRootPart.Anchored and not a.Character:FindFirstChild("CreationProtection") and a.Character.Humanoid.Health==60,"confirmation releases and fills health")
assert(a:GetAttribute("SkillUnarmed")==65 and a:GetAttribute("SkillRepair")==50)
send("Spend","Strength");send("Choose","Hunter");send("Talent","Automatics")
assert(a:GetAttribute("Strength")==5 and a:GetAttribute("CriticalChance")==.05 and a:GetAttribute("AutomaticAccuracyBonus")==0)
draft.Strength=10;send("Confirm",draft);assert(a:GetAttribute("Strength")==5)
Service.Award(a,100);assert(a:GetAttribute("CharacterLevel")==1 and a:GetAttribute("SkillPoints")==15)
send("Skill","Repair");assert(a:GetAttribute("SkillRepair")==51 and a:GetAttribute("SkillPoints")==14)
send("Skill","Miner");assert(a:GetAttribute("SkillPoints")==14)
for _=1,10 do Service.Harvest(a,"StoneVein") end
assert(Service.Snapshot(a).Practice.Miner.Value==1 and Service.Snapshot(a).Practice.Lumberjack.Value==0)
assert(Service.CanBuild(a,"Kitchen") and Service.CanStation(a,"Stove"))
Config.StationRequirements.Stove={Skills={Repair=52}}
assert(not Service.CanStation(a,"Stove"));send("Skill","Repair");assert(Service.CanStation(a,"Stove"))
local hp=a.Character.Humanoid;hp.Health=22;send("Request");assert(hp.Health==22,"request cannot repeat confirmation heal")
hp.Health=10
clock+=60;assert(coroutine.resume(loops[1]));assert(hp.Health==22,"END6 heals12 per minute")
a.Character:SetAttribute("Knockout",true);clock+=60;assert(coroutine.resume(loops[1]));assert(hp.Health==22,"regeneration cannot revive knockout")
a.Character:SetAttribute("Knockout",false);hp.Health=59;assert(coroutine.resume(loops[1]));assert(hp.Health==60,"heal capped at max")
hp.Health=0;assert(coroutine.resume(loops[1]));assert(hp.Health==0,"cannot revive dead")
a:LoadCharacterAsync();assert(Service.Snapshot(a).Confirmed and a:GetAttribute("Strength")==5 and a.Character.Humanoid.MaxHealth==60,"immutable creation survives respawn")
assert(Service.Loot(a,{Rags=1}).Rags==1)
print("PASS: actual immutable creation, forbidden legacy commands, INT skill points, derived stats, requirements, passive practice, minute regeneration, no revival, and respawn")
'''
parts=[(root/'tests/fixtures/town_mock.luau').read_text()]
for name,module in [('Rules','ProgressionRules'),('Config','ProgressionConfig')]:parts.append('local '+name+'=(function()\n'+(root/f'src/shared/{module}.luau').read_text()+'\nend)()')
parts.append(cases.replace('SERVICE','local Service=(function()\n'+s+'\nend)()'))
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'test.luau';p.write_text('\n'.join(parts));subprocess.run([sys.argv[1],str(p)],check=True)
