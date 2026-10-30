"""Actual knockout/finish/restart authority, including the unchanged citizen path."""
from pathlib import Path
import re, subprocess, sys, tempfile
root=Path(__file__).resolve().parents[1]
source=(root/'src/server/Services/PlayerLifeService.luau').read_text()
source=re.sub(r'local (Defense|Inventory|Chests|Motion|Beds|BodyFall|Animation)\s*=\s*require[^\n]+\n','',source)
for module,alias in [('TownService','Towns'),('CraftingService','Crafting'),('ProgressionService','Progression'),('EconomyService','Economy')]:
 source=source.replace(f'require(script.Parent.{module})',alias)
setup='''
Players.RespawnTime=5
Enum.HumanoidStateType={GettingUp=1}
function methods:ChangeState() end
local timers={}
function task.delay(seconds,fn) table.insert(timers,{At=clock+seconds,Run=fn}) end
local function advance(seconds)
 clock+=seconds
 for _,timer in ipairs(table.clone(timers)) do if not timer.Done and timer.At<=clock then timer.Done=true;timer.Run() end end
end
local Animation={Cancel=function() end}
local BodyFall={Play=function(c,kind) c:SetAttribute("BodyPoseKind",kind) end,Cancel=function() end,Restore=function(c) c:SetAttribute("BodyPoseKind",nil) end}
local corpses={};local extracted=0;local resets=0;local fresh=0;local funds=0;local spawned=0;local creation=0
local Inventory={ExtractAll=function(p) extracted+=1;return {Items={Musket=1}} end,Reset=function(p) resets+=1 end}
local Chests={Close=function() end,CreatePlayerCorpse=function(c,items) corpses[c]=items end}
local Motion={Cancel=function() end};local Beds={Leave=function() end};local Defense={Resolve=function(a) return a end}
local Progression={NewCharacter=function(p) assert(p.Character==nil);fresh+=1;p:SetAttribute("CharacterLevel",0);p:SetAttribute("AttributesConfirmed",false) end}
local Economy={Reset=function(p) funds+=1;p:SetAttribute("Money",0) end}
local Crafting={Close=function() end}
local Towns={LoadCharacter=function(p) spawned+=1 end,ResetForCreation=function(p) creation+=1;p:SetAttribute("HasSpawned",nil) end}
local function prepare(p,town)
 p:SetAttribute("TownID",town);p:SetAttribute("OutcastEnd",nil);p:SetAttribute("AttributesConfirmed",true)
 p:LoadCharacterAsync()
 return p.Character
end
'''
cases='''
local body=prepare(a,nil)
Service.Knockout(a,body)
assert(body:GetAttribute("Knockout") and not a:GetAttribute("OutcastEnd"))
assert(not Service.RequestRespawn(a),"respawn locked before deadline")
advance(119);assert(not a:GetAttribute("OutcastEnd") and extracted==0 and spawned==0)
advance(1);assert(body:GetAttribute("Knockout") and extracted==0,"deadline cannot kill a patient")
assert(Service.RequestRespawn(a))
assert(a:GetAttribute("OutcastEnd") and extracted==1 and body:GetAttribute("IsDead"))
local corpse;for c,items in pairs(corpses) do corpse=c;assert(items.Items.Musket==1) end
assert(corpse and corpse.Parent==workspace.PlayerCorpses and corpse:GetAttribute("BodyPoseKind")=="Death","corpse changes from fetal KO to relaxed death")
advance(600);assert(spawned==0,"no default or town respawn before acknowledgement")
Service.Finish(a,body);assert(extracted==1,"exactly one loot transfer")
assert(not Service.RestartOutcast(b),"cannot request a free reset while alive")
a:SetAttribute("CharacterLevel",20);a:SetAttribute("Money",1000);a:SetAttribute("HasSpawned",true)
assert(Service.RestartOutcast(a))
assert(a.Character==nil and body.destroyed and not corpse.destroyed,"remove hidden shell but retain lootable corpse")
assert(fresh==1 and resets==1 and funds==1 and creation==1)
assert(not a:GetAttribute("OutcastEnd") and not a:GetAttribute("AttributesConfirmed") and a:GetAttribute("CharacterLevel")==0 and a:GetAttribute("Money")==0)
assert(not Service.RestartOutcast(a) and fresh==1,"replayed acknowledgement cannot reset the new character")
local citizen=prepare(b,1);Service.Knockout(b,citizen)
local moved=CFrame.new(Vector3.new(5,2,3));assert(Service.MoveKnockout(b,moved) and Service.KnockoutRecord(citizen).Pivot==moved)
advance(120)
assert(not b:GetAttribute("OutcastEnd") and spawned==0)
assert(citizen:GetAttribute("Knockout") and Service.RequestRespawn(b))
advance(5);assert(spawned==1,"town member keeps normal respawn")
local revived=prepare(c,nil);Service.Knockout(c,revived);local old={Run=function() end}
assert(Service.Revive(c,0,0));old.Run();assert(not c:GetAttribute("OutcastEnd"),"successful doctor revival cancels terminal death")
-- Reconnection can restore the authoritative ending attribute without an old shell.
d.Character=nil;d:SetAttribute("TownID",nil);d:SetAttribute("OutcastEnd",true)
assert(Service.RestartOutcast(d) and fresh==2,"ending can be acknowledged after reconnect")
print("PASS: outcast 120s deadline, no auto-respawn, single corpse/loot, authorized fresh restart, replay rejection, citizen respawn, revival and reconnect acknowledgement")
'''
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'outcast.luau'
 p.write_text((root/'tests/fixtures/town_mock.luau').read_text()+'\n'+setup+'\nlocal Service=(function()\n'+source+'\nend)()\n'+cases)
 subprocess.run([sys.argv[1],str(p)],check=True)
