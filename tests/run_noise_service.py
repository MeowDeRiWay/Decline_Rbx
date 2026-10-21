"""Actual server shot/footstep noise, no client-supplied positions or source tracking."""
from pathlib import Path
import re,subprocess,sys,tempfile
root=Path(__file__).resolve().parents[1]
s=(root/'src/server/Services/NoiseService.luau').read_text();s=re.sub(r'local (Config|Rules|Activity)=require[^\n]+\n','',s)
setup='''
local heartbeat=event();local oldService=game.GetService
function game:GetService(name) if name=="RunService" then return {Heartbeat=heartbeat} end;return oldService(self,name) end
local Config={FootstepMaxDistance=12}
local alerts=0;local Activity={Alert=function() alerts+=1 end}
local Enum={Material={Air="Air"}}
'''
cases='''
Service.Emit(Vector3.zero,150,"Shot")
local heard,cursor=Service.Listen(Vector3.new(80,0,0),3,0);assert(heard and heard.Kind=="Shot")
assert(not Service.Listen(Vector3.new(91,0,0),3,0),"zombie Attention3 hears shot to90")
assert(not Service.Listen(Vector3.zero,5,cursor),"same sound consumed once")
clock+=4;assert(not Service.Listen(Vector3.zero,5,0),"stale noise expires")
Service.Start();a:LoadCharacterAsync();a:SetAttribute("SkillSneak",25)
local root=a.Character.HumanoidRootPart;root.Anchored=false
local before=alerts
heartbeat:Fire(.25);root.Position=Vector3.new(.1,0,0);heartbeat:Fire(.25);assert(alerts==before)
root.Position=Vector3.new(.2,0,0);heartbeat:Fire(.25);assert(alerts==before+1,"slow footsteps accumulate travel")
heard,cursor=Service.Listen(root.Position,5,cursor);assert(heard.Kind=="Footsteps" and heard.Radius==12)
a.Character:SetAttribute("Sneaking",true);root.Position=Vector3.new(.4,0,0);heartbeat:Fire(.25)
heard,cursor=Service.Listen(root.Position,5,cursor);assert(math.abs(heard.Radius-5.6)<1e-9)
root.Position=Vector3.new(100,0,0);before=alerts;heartbeat:Fire(.25);assert(alerts==before,"teleports emit no steps")
a:SetAttribute("AttributesConfirmed",false);root.Position=Vector3.new(101,0,0);heartbeat:Fire(.25);assert(alerts==before,"creation is silent")
print("PASS: actual bounded shot/footstep noise, listener Attention, one-shot cursor/expiry, slow travel, Sneak25 quiet radius, teleports and creation")
'''
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'test.luau';p.write_text((root/'tests/fixtures/town_mock.luau').read_text()+'\nlocal Rules=(function()\n'+(root/'src/shared/NoiseRules.luau').read_text()+'\nend)()\n'+setup+'\nlocal Service=(function()\n'+s+'\nend)()\n'+cases);subprocess.run([sys.argv[1],str(p)],check=True)
