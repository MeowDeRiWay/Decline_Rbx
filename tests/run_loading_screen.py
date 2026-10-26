"""Exercise the real splash lifecycle: selected asset, timing, fallback and cleanup."""
from pathlib import Path
import subprocess,sys,tempfile
root=Path(__file__).resolve().parents[1]
source=(root/'src/first/Loading.client.luau').read_text()
mock='''
local now=0;local os={clock=function() return now end}
local objects,tweens,waits={},{},{}
local mode="MODE"
Instance={new=function(class)
 local o={ClassName=class}
 function o:Destroy() self.Destroyed=true end
 table.insert(objects,o);return o
end}
local function value(...) return {...} end
Vector2={new=value};UDim2={new=value,fromScale=value}
Color3={fromRGB=value};TweenInfo={new=function(duration) return duration end}
Enum={Font={RobotoMono=1},ScaleType={Fit=1},AssetFetchStatus={Success=1,Failure=2}}
Random={new=function() return {NextInteger=function(_,_,last) return last end} end}
local player={attrs={},PlayerGui={}}
function player:WaitForChild(name) assert(name=="PlayerGui");return self.PlayerGui end
function player:SetAttribute(k,v) self.attrs[k]=v end
local removed=false;local preloadCount=0
local function entry(name,id) return {Name=name,Value=id,IsA=function(_,class) return class=="StringValue" end} end
local entries=mode=="empty" and {} or {entry("Splash01","123"),entry("Splash02","rbxassetid://456"),entry("Splash03","0"),entry("Splash04","bad"),entry("Other","789")}
local services={Players={LocalPlayer=player},ReplicatedFirst={RemoveDefaultLoadingScreen=function() removed=true end,WaitForChild=function(_,name) assert(name=="SplashImages");return {GetChildren=function() return entries end} end},ContentProvider={PreloadAsync=function(_,assets,callback)
 preloadCount+=1;assert(#assets==1 and assets[1]=="rbxassetid://456","only selected valid image preloaded")
 callback(assets[1],mode=="fail" and Enum.AssetFetchStatus.Failure or Enum.AssetFetchStatus.Success)
end},TweenService={Create=function(_,o,duration,props)
 table.insert(tweens,{Object=o,Duration=duration,Properties=props})
 return {Play=function() for k,v in pairs(props) do o[k]=v end end,Completed={Wait=function() now+=duration end}}
end}}
game={GetService=function(_,name) return services[name] end}
task={spawn=function(fn) if mode~="timeout" then fn() end end,wait=function(seconds) table.insert(waits,seconds);now+=seconds end}
'''
cases='''
local gui,picture,fallback
for _,o in ipairs(objects) do
 if o.Name=="DeclineLoading" then gui=o end
 if o.ClassName=="ImageLabel" then picture=o end
 if o.ClassName=="TextLabel" then fallback=o end
end
assert(removed and gui.Destroyed and not player.attrs.LoadingScreenOpen)
assert(table.find(waits,3),"full three-second hold")
assert(#tweens==3 and tweens[1].Duration==.45 and tweens[2].Duration==.45 and tweens[3].Duration==.35)
if mode=="success" then
 assert(picture.Image=="rbxassetid://456" and tweens[1].Object==picture and fallback.TextTransparency==1)
else assert(picture.Image=="" and tweens[1].Object==fallback) end
if mode=="empty" then assert(preloadCount==0) end
if mode=="timeout" then assert(now>=9.25 and now<9.4,"preload wait bounded") else assert(math.abs(now-4.25)<1e-6) end
print("PASS: splash "..mode..", random pool validation, timed fades/hold and cleanup")
'''
with tempfile.TemporaryDirectory() as d:
 for mode in ['success','empty','fail','timeout']:
  p=Path(d)/'splash.luau';p.write_text(mock.replace('MODE',mode)+'\n'+source+'\n'+cases)
  subprocess.run([sys.argv[1],str(p)],check=True)
