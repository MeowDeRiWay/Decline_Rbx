"""Run the actual early loading UI lifecycle without requiring a spawned character."""
from pathlib import Path
import subprocess,sys,tempfile
root=Path(__file__).resolve().parents[1]
source=(root/'src/first/Loading.client.luau').read_text()
mock='''
local function signal()
 local s={}
 function s:Connect(fn) self.fn=fn;return {Disconnect=function() self.fn=nil end} end
 function s:Once(fn) fn() end
 function s:Fire() if self.fn then self.fn() end end
 return s
end
local objects={}
Instance={new=function(class)
 local o={ClassName=class,Activated=signal()}
 function o:Destroy() self.Destroyed=true end
 table.insert(objects,o);return o
end}
local function value(...) return {...} end
Vector2={new=value};UDim2={new=value,fromScale=value,fromOffset=value}
Color3={fromRGB=value};TweenInfo={new=value};Enum={Font={RobotoMono=1}}
local now=0;local os={clock=function() return now end}
local loaded=false;local city=false
local player={attrs={},PlayerGui={}}
function player:WaitForChild(name) assert(name=="PlayerGui");return self.PlayerGui end
function player:SetAttribute(k,v) self.attrs[k]=v end
function player:GetAttribute(k) return self.attrs[k] end
workspace={GetAttribute=function(_,k) assert(k=="InitialCityReady");return city end}
local heartbeat=signal();local removed=false
local services={Players={LocalPlayer=player},ReplicatedFirst={RemoveDefaultLoadingScreen=function() removed=true end},RunService={Heartbeat=heartbeat},TweenService={Create=function(_,o,_,props) return {Play=function() for k,v in pairs(props) do o[k]=v end end,Completed=signal()} end}}
game={GetService=function(_,name) return services[name] end,IsLoaded=function() return loaded end}
'''
cases='''
assert(removed and player.attrs.LoadingScreenOpen)
local gui,skip
for _,o in ipairs(objects) do if o.Name=="DeclineLoading" then gui=o end;if o.Text=="Continue" then skip=o end end
assert(gui and gui.Parent==player.PlayerGui and skip and not skip.Visible)
heartbeat:Fire();assert(not gui.Destroyed)
loaded=true;heartbeat:Fire();assert(not gui.Destroyed)
city=true;heartbeat:Fire();assert(not gui.Destroyed,"town data must arrive before fade")
now=21;heartbeat:Fire();assert(skip.Visible,"slow startup has escape hatch")
SCENARIO
assert(gui.Destroyed and not player.attrs.LoadingScreenOpen and not heartbeat.fn,"fade removes UI and heartbeat")
print("PASS: loading gates, no character wait, delayed Continue, fade and cleanup")
'''
with tempfile.TemporaryDirectory() as d:
 for scenario in ['player.attrs.TownStateReady=true;heartbeat:Fire()', 'skip.Activated:Fire();skip.Activated:Fire()']:
  p=Path(d)/'loading.luau';p.write_text(mock+'\n'+source+'\n'+cases.replace('SCENARIO',scenario))
  subprocess.run([sys.argv[1],str(p)],check=True)
