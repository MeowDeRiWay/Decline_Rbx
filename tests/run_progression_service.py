"""Exercise server-owned progression and permissions with mock Players/remotes."""
from pathlib import Path
import subprocess
import tempfile
import sys
root=Path(__file__).resolve().parents[1]
service=(root/'src/server/Services/ProgressionService.luau').read_text()
for name,module in [('Rules','ProgressionRules'),('Config','ProgressionConfig')]:
 service=service.replace(f'local {name}=require(ReplicatedStorage.Shared.{module})','')
cases='''
Service.Start()
a:LoadCharacterAsync()
local action=ReplicatedStorage.ProgressionRemotes.Action
local function call(command,value) clock+=.2; action.OnServerEvent:Fire(a,command,value) end
assert(Service.Snapshot(a).Level==0 and Service.Snapshot(a).Points==5)
assert(not Service.CanStation(a,"Stove") and Service.CanStation(a,"Workstation"))
Service.Award(a,100)
call("Spend","Strength"); call("Spend","Endurance")
assert(a:GetAttribute("CarryLimitKg")==21 and a:GetAttribute("RunBonus")==.2 and a.Character.Humanoid.MaxHealth==105)
call("Choose","Cook")
assert(Service.CanStation(a,"Stove") and Service.CanStation(a,"CuttingBoard"))
assert(Service.CanBuild(a,"Kitchen") and not Service.CanBuild(a,"Workbench"))
Service.CraftXP(a,"Workstation"); assert(Service.Snapshot(a).XP==0)
Service.CraftXP(a,"Stove"); assert(Service.Snapshot(a).XP==10)
call("Choose","Other"); assert(Service.Snapshot(a).Profession=="Cook")
call("Spend","Forged"); assert(Service.Snapshot(a).Points==8)
call("Talent","Forged"); assert(Service.Snapshot(a).Points==8)
local points=Service.Snapshot(a).Points
call("Talent","SurpriseServing"); call("Talent","GrandmasMethod"); call("Talent","RamsayMethod")
assert(Service.Snapshot(a).Points==points,"talents do not spend attribute points")
assert(Service.CraftEffects(a,"Stove",5).BonusServing and Service.CraftEffects(a,"Stove",5).DurationMultiplier==.8)
assert(Service.CraftEffects(a,"CuttingBoard",1).DurationMultiplier==.8)
local zombie=make("Model","Zombie",workspace,{LastDamagerID=a.UserId})
Service.ZombieDied(zombie,{Scrap=1}); assert(Service.Snapshot(a).XP==20)
local old=a.Character
local fresh=make("Model","Character",workspace); local hp=make("Humanoid","Humanoid",fresh)
a.Character=fresh; a.CharacterAdded:Fire(fresh)
assert(hp.MaxHealth==105 and a:GetAttribute("Strength")==1,"progression survives respawn")
Players.PlayerRemoving:Fire(a)
assert(Service.Snapshot(a).Level==0,"state is session only")
print("PASS: server XP, stat allocation, Cook station/build permissions, specialty XP, invalid commands and respawn restoration")
'''
parts=[(root/'tests/fixtures/town_mock.luau').read_text(),'local Random={new=function() return {NextNumber=function() return 0 end} end}']
for name,module in [('Rules','ProgressionRules'),('Config','ProgressionConfig')]:
 parts.append('local '+name+'=(function()\n'+(root/f'src/shared/{module}.luau').read_text()+'\nend)()')
parts.extend(['local Service=(function()\n'+service+'\nend)()',cases])
with tempfile.TemporaryDirectory(prefix='decline-progression-') as directory:
 path=Path(directory)/'test.luau';path.write_text('\n'.join(parts))
 subprocess.run([sys.argv[1] if len(sys.argv)>1 else 'luau',str(path)],check=True)
