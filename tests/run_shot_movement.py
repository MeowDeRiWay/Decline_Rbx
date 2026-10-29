"""Run the actual sprint authority through shot deadlines and competing locks."""
from pathlib import Path
import re, subprocess, sys, tempfile
root=Path(__file__).resolve().parents[1]
source=(root/'src/server/Running.server.luau').read_text()
source=re.sub(r'local (Config|Rules|Sprint)\s*=\s*require[^\n]+\n','',source)
parts=[]
for name,path in [('Config','GameConfig'),('Rules','MovementRules'),('Sprint','SprintRules')]:
 parts.append('local '+name+'=(function()\n'+(root/('src/shared/'+path+'.luau')).read_text()+'\nend)()')
parts.append(r''' 
local function signal() return {Connect=function(self,fn) self.callback=fn end} end
local now=10
workspace={GetServerTimeNow=function() return now end}
local hp={Health=100,WalkSpeed=8,MoveDirection={Magnitude=1}}
local character={attrs={}}
function character:GetAttribute(key) return self.attrs[key] end
function character:SetAttribute(key,value) self.attrs[key]=value end
function character:FindFirstChildOfClass() return hp end
local player={Character=character,CharacterAdded=signal(),attrs={AttributesConfirmed=true,WalkBonus=8,RunBonus=12,Agility=0,CarryLimitKg=20}}
function player:GetAttribute(key) return self.attrs[key] end
local Players={PlayerAdded=signal(),PlayerRemoving=signal(),GetPlayers=function() return {player} end}
local RunService={Heartbeat=signal()}
local remote
Instance={new=function() remote={OnServerEvent=signal()};return remote end}
game={GetService=function(_,name) if name=="Players" then return Players elseif name=="RunService" then return RunService else return {} end end}
''')
parts.append(source)
parts.append(r'''
local tick=RunService.Heartbeat.callback
remote.OnServerEvent.callback(player,true)
tick(.1);assert(hp.WalkSpeed==12 and character.attrs.Running)
local reserve=character.attrs.SprintRemaining
character.attrs.ShotMovementUntil=10.2
tick(.1);assert(hp.WalkSpeed==0 and not character.attrs.Running)
assert(character.attrs.SprintRemaining>=reserve,"shot pause cannot burn sprint reserve")
now=10.1;character.attrs.ShotMovementUntil=10.3
tick(.1);assert(hp.WalkSpeed==0)
now=10.21;tick(.1);assert(hp.WalkSpeed==0,"previous shot expiry cannot unlock a new shot")
character.attrs.CraftingLocked=true
now=10.3;tick(.1);assert(hp.WalkSpeed==0,"shot expiry must preserve crafting lock")
character.attrs.CraftingLocked=nil;character.attrs.LoadKg=30
tick(.1);assert(hp.WalkSpeed==6,"resume uses current carry load and running request")
remote.OnServerEvent.callback(player,false);tick(.1);assert(hp.WalkSpeed==4)
character.attrs.ShotMovementUntil=11
player.CharacterAdded.callback();character.attrs={}
tick(.1);assert(hp.WalkSpeed==8,"new character does not inherit shot or sprint request")
print("PASS: shot pause, automatic extension, sprint reserve, competing locks, current carry speed and respawn")
''')
with tempfile.TemporaryDirectory() as directory:
 path=Path(directory)/'shot_movement.luau';path.write_text('\n'.join(parts))
 subprocess.run([sys.argv[1] if len(sys.argv)>1 else 'luau',str(path)],check=True)
