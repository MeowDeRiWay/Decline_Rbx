"""Exercise actual zombie sound-investigation branch independently of vision/chasing."""
from pathlib import Path
import subprocess,sys,tempfile
root=Path(__file__).resolve().parents[1]
s=(root/'src/server/Zombie.server.luau').read_text()
a=s.index('   if not lastSeenPosition and heardPosition then');b=s.index('   if lastSeenPosition then',a)
branch=s[a:b]
mock='''
local lastSeenPosition=nil
local heardPosition={X=12,Y=0,Z=9};local original=heardPosition
local heardUntil=60;local heardBlocked=0;local dt=1
local model={SetAttribute=function(self,k,v) self[k]=v end}
local humanoid={WalkSpeed=3};local time=1
local os={clock=function() return time end}
local arrived,blocked=false,false
local destination,calls=nil,0
local function navigate(point) destination=point;calls+=1;return arrived,blocked end
local IdleRules={New=function() return {} end};local idle,idlePhase
'''
cases='''
step();assert(calls==1 and destination==original and model.AIState=="InvestigatingSound","navigates to stored sound point, not player position")
blocked=true;step();step();step();assert(heardPosition==nil,"blocked investigation stops")
heardPosition=original;heardBlocked=0;blocked=false;arrived=true;step();assert(heardPosition==nil,"arrival finishes investigation")
heardPosition=original;arrived=false;time=61;step();assert(heardPosition==nil,"sound memory expires")
heardPosition=original;lastSeenPosition={};local before=calls;step();assert(calls==before,"visual memory takes priority")
print("PASS: actual anonymous sound-point navigation, arrival, blocked-route timeout, memory expiry and visual priority")
'''
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'test.luau';p.write_text(mock+'\nlocal function step()\n'+branch+'\nend\n'+cases);subprocess.run([sys.argv[1],str(p)],check=True)
