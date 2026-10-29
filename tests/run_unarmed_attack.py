"""Exercise accepted/rejected punches through the real server attack handler."""
from pathlib import Path
import re,subprocess,sys,tempfile
root=Path(__file__).resolve().parents[1]
source=(root/'tests/rig_math.fixture.luau').read_text()
source+='\nlocal Punch=(function()\n'+(root/'src/shared/UnarmedPose.luau').read_text()+'\nend)()'
source+='\nlocal CombatRules=(function()\n'+(root/'src/shared/CombatRules.luau').read_text()+'\nend)()'
source+='''
local function signal() return {Connect=function(self,fn) self.callback=fn end} end
local time=0
local os={clock=function() return time end}
local jobs={}
task={delay=function(delay,fn) table.insert(jobs,{At=time+delay,Fn=fn}) end}
local function advance(dt)
 time+=dt
 for i=#jobs,1,-1 do if jobs[i].At<=time then local fn=jobs[i].Fn;table.remove(jobs,i);fn() end end
end
local c={attrs={}}
function c:GetAttribute(k) return self.attrs[k] end
function c:SetAttribute(k,v) self.attrs[k]=v end
local hp={Health=100}
local body={Size=Vector3.new(.4,.7,.315),CFrame=CFrame.identity,Position=Vector3.zero}
function c:FindFirstChild(name) if name=="HumanoidRootPart" then return body end end
function c:FindFirstChildOfClass() return hp end
local player={Character=c,attrs={AttributesConfirmed=true}}
function player:GetAttribute(k) return self.attrs[k] end
local currentWeapon=CombatRules.Unarmed
local Inventory={GetWeapon=function() return currentWeapon end}
local Motion={Play=function() end,HitDelay=function() return .25 end}
local contacts=0
local Audio={Play=function() contacts+=1 end}
local Damage,Resources,Progression,Items={},{},{},{}
local Players={PlayerRemoving=signal()}
local action
Instance={new=function() action={OnServerEvent=signal()};return action end}
game={GetService=function(_,name) return name=="Players" and Players or {} end}
Random={new=function() return {} end}
OverlapParams={new=function() return {} end}
Enum={RaycastFilterType={Exclude=1}}
workspace={GetServerTimeNow=function() return 100+time end,GetPartBoundsInBox=function() return {} end}
'''
server=(root/'src/server/Combat.server.luau').read_text()
server=re.sub(r'local (CombatRules|Motion|Punch|Audio|Damage|Inventory|Resources|Progression|Items)\s*=\s*require[^\n]+\n','',server)
source+='\n'+server
source+='''
local fire=action.OnServerEvent.callback
player.attrs.AttributesConfirmed=false;fire(player);assert(c.attrs.PunchSequence==nil)
player.attrs.AttributesConfirmed=true;c.attrs.Knockout=true;fire(player);assert(c.attrs.PunchSequence==nil)
c.attrs.Knockout=false;player.attrs.TradeOpen=true;fire(player);assert(c.attrs.PunchSequence==nil)
player.attrs.TradeOpen=false;fire(player)
assert(c.attrs.PunchSequence==1 and c.attrs.PunchStartedAt==100)
fire(player);assert(c.attrs.PunchSequence==1,"cooldown rejection cannot restart pose or alternate hand")
advance(.24);assert(contacts==0)
advance(.01);assert(contacts==1,"damage query/miss occurs at animation contact, not pose start")
advance(.75);fire(player);assert(c.attrs.PunchSequence==2 and c.attrs.PunchStartedAt==101)
advance(1);c.attrs.HandsItem="Knife";Items.Knife={Weapon=true};currentWeapon={AttacksPerMinute=40}
fire(player);assert(c.attrs.PunchSequence==2,"armed attacks cannot publish fist animation")
assert(CombatRules.Unarmed.AttacksPerMinute==60,"punch animation preserves attack rate")
print("PASS: accepted-only punch timestamps, cooldown/KO/trade/creation rejection, contact timing and armed isolation")
'''
with tempfile.TemporaryDirectory() as directory:
 p=Path(directory)/'unarmed.luau';p.write_text(source)
 subprocess.run([sys.argv[1] if len(sys.argv)>1 else 'luau',str(p)],check=True)
