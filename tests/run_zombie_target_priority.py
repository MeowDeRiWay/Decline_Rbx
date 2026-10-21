"""Run actual sensory transition code: sound -> vision -> memory -> listening."""
from pathlib import Path
import subprocess,sys,tempfile
root=Path(__file__).resolve().parents[1]
s=(root/'src/server/Zombie.server.luau').read_text()
a=s.index('   if previousTarget and not nearest then')
b=s.index('   model:SetAttribute("DetectionReason"',a)
branch=s[a:b]
fixture='''
local previousTarget,nearest,lastSeenPosition,lastSeenCharacter
local heardPosition,heardUntil,heardBlocked,noiseCursor=nil,0,0,0
local searchStart,searchElapsed,searchBlocked
local heard={Position={Name="shot"},Kind="Shot"}
local Noise={Listen=function() return heard,1 end}
local root={Position={}}
local model={SetAttribute=function() end,GetAttribute=function() return 5 end}
local navigation={Cancel=function(self) self.Cancelled=true end,Route={}}
local function poll()
'''+branch+'''
end
poll();assert(heardPosition==heard.Position,"unoccupied zombie investigates noise")
nearest={Position={Name="prey"},Parent={Name="Player"}}
poll();assert(heardPosition==nil and lastSeenPosition==nearest.Position,"vision replaces noise")
assert(navigation.Cancelled and #navigation.Route==0,"acquisition discards old sound route")
previousTarget=nearest;nearest=nil;navigation.Cancelled=false
poll();assert(lastSeenPosition and heardPosition==nil,"lost visual contact retains memory and ignores noise")
assert(navigation.Cancelled,"lost contact cancels moving-target route")
previousTarget=nil;poll();assert(heardPosition==nil,"further noise cannot replace visual search")
lastSeenPosition,lastSeenCharacter=nil,nil
poll();assert(heardPosition==heard.Position,"fully lost prey restores listening")
print("PASS: heard -> seen -> hunting -> last seen search -> listening, with stale-route cancellation")
'''
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'test.luau';p.write_text(fixture);subprocess.run([sys.argv[1],str(p)],check=True)
