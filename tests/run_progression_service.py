"""Exercise actual progression authority, regeneration and session lifecycle."""
from pathlib import Path
import re,subprocess,tempfile,sys
root=Path(__file__).resolve().parents[1]
s=(root/'src/server/Services/ProgressionService.luau').read_text()
s=re.sub(r'local (Rules|Config|Journal)=require[^\n]+\n','',s)
s=s.replace('local definitions=require(ReplicatedStorage.Shared.ItemConfig).Items','local definitions=LootItems.Items')
cases='''
local notices={};local Journal={Send=function(p,text) table.insert(notices,{p,text}) end}
SERVICE
Service.Start();a:LoadCharacterAsync()
local action=ReplicatedStorage.ProgressionRemotes.Action
local function send(command,value) if command=="Confirm" then value={Stats=value,TaggedSkills={"LightWeapons","HeavyWeapons","Throwing"}} end;clock+=.2;action.OnServerEvent:Fire(a,command,value) end
assert(not Service.Snapshot(a).Confirmed and not Service.CanStation(a,"Stove"))
Service.Award(a,100);assert(Service.Snapshot(a).Level==0 and #notices==0)
assert(a.Character.HumanoidRootPart.Anchored and a.Character.CreationProtection and a.Character:GetAttribute("CreatingCharacter"),"server creation lock and shield")
local draft=table.clone(Service.Snapshot(a).Stats);draft.Intelligence=10;draft.Endurance=6
clock+=.2;action.OnServerEvent:Fire(a,"Confirm",{Stats=draft,TaggedSkills={"LightWeapons","LightWeapons","Doctor"}})
assert(not Service.Snapshot(a).Confirmed,"invalid duplicate main skills cannot unlock creation")
send("Confirm",draft)
assert(a:GetAttribute("AttributesConfirmed") and a:GetAttribute("CarryLimitKg")==25 and a.Character.Humanoid.MaxHealth==60)
assert(not a.Character.HumanoidRootPart.Anchored and not a.Character:FindFirstChild("CreationProtection") and a.Character.Humanoid.Health==60,"confirmation releases and fills health")
assert(a:GetAttribute("SkillUnarmed")==65 and a:GetAttribute("SkillRepair")==50)
send("Spend","Strength");send("Choose","Hunter");send("Talent","Automatics")
assert(a:GetAttribute("Strength")==5 and a:GetAttribute("CriticalChance")==.05 and a:GetAttribute("AutomaticAccuracyBonus")==0)
draft.Strength=10;send("Confirm",draft);assert(a:GetAttribute("Strength")==5)
assert(Service.Snapshot(a).NextXP==500)
Service.Award(a,500);assert(a:GetAttribute("CharacterLevel")==1 and a:GetAttribute("SkillPoints")==30)
assert(Service.Snapshot(a).NextXP==1000)
assert(math.abs(a:GetAttribute("CombatMovementMultiplier")-(1+a:GetAttribute("SkillUnarmed")/200))<1e-9)
send("Skill","Repair");assert(a:GetAttribute("SkillRepair")==51 and a:GetAttribute("SkillPoints")==29)
send("Skill","Miner");assert(a:GetAttribute("SkillPoints")==29)
for _=1,10 do Service.Harvest(a,"StoneVein",1) end
assert(Service.Snapshot(a).Practice.Miner.Value==1 and Service.Snapshot(a).Practice.Lumberjack.Value==0)
assert(not Service.CanBuild(a,"Kitchen") and not Service.CanBuild(a,"Workbench") and Service.CanStation(a,"Stove"))
assert(not Service.CanBuild(a,"Hospital"),"hospital requires BOTH medical skills")
Config.StationRequirements.Stove={Skills={Repair=52}}
assert(not Service.CanStation(a,"Stove"));send("Skill","Repair");assert(Service.CanStation(a,"Stove"))
local hp=a.Character.Humanoid;hp.Health=22;send("Request");assert(hp.Health==22,"request cannot repeat confirmation heal")
hp.Health=10
clock+=60;assert(coroutine.resume(loops[1]));assert(hp.Health==16,"END6 heals6 per minute")
a.Character:SetAttribute("Knockout",true);clock+=60;assert(coroutine.resume(loops[1]));assert(hp.Health==16,"regeneration cannot revive knockout")
a.Character:SetAttribute("Knockout",false);hp.Health=65;assert(coroutine.resume(loops[1]));assert(hp.Health==66,"heal capped at max")
hp.Health=0;assert(coroutine.resume(loops[1]));assert(hp.Health==0,"cannot revive dead")
a:LoadCharacterAsync();assert(Service.Snapshot(a).Confirmed and a:GetAttribute("Strength")==5 and a.Character.Humanoid.MaxHealth==66,"immutable creation survives respawn")
assert(Service.Loot(a,{Rags=1}).Rags==1)
b:LoadCharacterAsync()
local bd=table.clone(Service.Snapshot(b).Stats);bd.Strength=7;bd.Attention=7;bd.Luck=7
clock+=.2;action.OnServerEvent:Fire(b,"Confirm",{Stats=bd,TaggedSkills={"LightWeapons","HeavyWeapons","Throwing"}})
assert(Service.Snapshot(b).SkillPoints==10 and Service.Snapshot(b).PerkPoints==1)
clock+=.2;action.OnServerEvent:Fire(b,"Perk","RangedDamage")
assert(b:GetAttribute("RangedDamageBonus")==2 and b.Character:GetAttribute("RangedDamageBonus")==2 and Service.Snapshot(b).PerkPoints==0)
clock+=.2;action.OnServerEvent:Fire(b,"Perk","RangedDamage")
assert(Service.Snapshot(b).Perks.RangedDamage==1,"cannot spend an absent perk point")
local carry=Service.Snapshot(b)
Players.PlayerRemoving:Fire(b);b.Parent=nil
local rejoined=player(b.UserId);Players.PlayerAdded:Fire(rejoined)
assert(Service.Snapshot(rejoined).TagsConfirmed and Service.Snapshot(rejoined).TaggedSkills.Throwing and Service.Snapshot(rejoined).Confirmed and Service.Snapshot(rejoined).Perks.RangedDamage==1 and Service.Snapshot(rejoined).SkillPoints==carry.SkillPoints,"new Player object restores progression by UserId")
local zombie=make("Model","Zombie",workspace,{LastDamagerID=a.UserId});local zhp=make("Humanoid","Humanoid",zombie);zhp.MaxHealth=60
local oldXP=Service.Snapshot(a).XP;Service.ZombieDied(zombie,{})
assert(Service.Snapshot(a).XP==oldXP+150,"kill XP derives from max HP, not health remaining")
local med=player(700);Players.PlayerAdded:Fire(med);med:LoadCharacterAsync()
clock+=.2;action.OnServerEvent:Fire(med,"Confirm",{Stats={Strength=5,Attention=10,Endurance=5,Intelligence=10,Agility=5,Luck=1},TaggedSkills={"LightWeapons","HeavyWeapons","Throwing"}})
Service.Award(med,6000)
for _=1,30 do clock+=.2;action.OnServerEvent:Fire(med,"Skill","FirstAid") end
for _=1,19 do clock+=.2;action.OnServerEvent:Fire(med,"Skill","Doctor") end
assert(med:GetAttribute("SkillFirstAid")==100 and med:GetAttribute("SkillDoctor")==99 and not Service.CanBuild(med,"Hospital"))
clock+=.2;action.OnServerEvent:Fire(med,"Skill","Doctor");assert(Service.CanBuild(med,"Hospital"),"actual authority requires100 FirstAid AND100 Doctor")
assert(not Service.CanBuild(med,"Kitchen") and not Service.CanBuild(med,"Workbench"))
Service.Award(med,100000)
for _=1,50 do clock+=.2;action.OnServerEvent:Fire(med,"Skill","Repair") end
assert(Service.CanBuild(med,"Workbench") and not Service.CanBuild(med,"Kitchen"),"Repair100 unlocks workshop only")
for _=1,50 do clock+=.2;action.OnServerEvent:Fire(med,"Skill","Cook") end
assert(Service.CanBuild(med,"Kitchen"),"Cook100 unlocks kitchen")
a:SetAttribute("ScroungerMultiplier",1.25)
local extra=Service.ZombieDied(zombie,{Ammo9mmFMJ=4,Rags=3})
assert(extra.Ammo9mmFMJ==5 and extra.Rags==3,"scrounger changes ammo quantity only")
-- Administrative level grants must preserve XP and normal rewards, including Good student.
clock+=.2;action.OnServerEvent:Fire(a,"Perk","GoodStudent")
assert(Service.Snapshot(a).Perks.GoodStudent==1)
local beforeGrant=Service.Snapshot(a)
assert(Service.GrantLevels(a,1))
local afterGrant=Service.Snapshot(a)
assert(afterGrant.Level==beforeGrant.Level+1 and afterGrant.XP==beforeGrant.XP)
assert(afterGrant.SkillPoints==beforeGrant.SkillPoints+15 and afterGrant.PerkPoints==beforeGrant.PerkPoints+1)
assert(a:GetAttribute("CharacterLevel")==afterGrant.Level)
local finalGrant=30-afterGrant.Level
local ok,count=Service.GrantLevels(a,100);assert(ok and count==finalGrant)
local maxed=Service.Snapshot(a)
assert(maxed.Level==30 and maxed.XP==0 and maxed.NextXP==0 and maxed.MaxLevel==30 and maxed.Perks.Observant==1)
assert(maxed.SkillPoints==afterGrant.SkillPoints+15*finalGrant and maxed.PerkPoints==afterGrant.PerkPoints+finalGrant)
assert(a.Character.Humanoid.MaxHealth==240 and a:GetAttribute("CarryLimitKg")==55 and not Service.GrantLevels(a,1))
local minerXP=maxed.Practice.Miner.XP
Service.Harvest(a,"StoneVein",1)
assert(Service.Snapshot(a).Practice.Miner.XP==minerXP+2,"Good student practice continues at cap")
assert(Service.ResetProgression(a))
local reset=Service.Snapshot(a)
assert(reset.Level==1 and reset.XP==0 and reset.SkillPoints==30 and reset.PerkPoints==2 and next(reset.Perks)==nil)
assert(a:GetAttribute("SkillRepair")==50 and not a:GetAttribute("Observant") and a.Character.Humanoid.MaxHealth==66 and a:GetAttribute("CarryLimitKg")==26)
assert(reset.Practice.Miner.Value==0 and reset.Practice.Miner.XP==0 and reset.TaggedSkills.LightWeapons and reset.TagsConfirmed)
assert(not reset.Perks.GoodStudent and a:GetAttribute("ExperienceMultiplier")==1)
Service.Award(a,1000);assert(Service.Snapshot(a).Level==2 and a.Character.Humanoid.MaxHealth==72 and a:GetAttribute("CarryLimitKg")==27)
assert(not Service.GrantLevels(a,0) and not Service.GrantLevels(a,101) and not Service.GrantLevels(a,1.5) and not Service.GrantLevels(a,0/0))
local fresh=player(909);Players.PlayerAdded:Fire(fresh)
assert(not Service.GrantLevels(fresh,2),"creation must be confirmed")
print("PASS: exact admin levels, normal rewards, XP preserved, Good student ignored, automatic level30 perk")
print("PASS: actual immutable creation, forbidden legacy commands, INT skill points, derived stats, requirements, passive practice, minute regeneration, no revival, and respawn")
'''
parts=[(root/'tests/fixtures/town_mock.luau').read_text()]
for name,module in [('Rules','ProgressionRules'),('Config','ProgressionConfig'),('LootItems','ItemConfig')]:parts.append('local '+name+'=(function()\n'+(root/f'src/shared/{module}.luau').read_text()+'\nend)()')
parts.append(cases.replace('SERVICE','local Service=(function()\n'+s+'\nend)()'))
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'test.luau';p.write_text('\n'.join(parts));subprocess.run([sys.argv[1],str(p)],check=True)
