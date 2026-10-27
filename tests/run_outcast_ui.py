"""Run the actual ending UI: server-controlled visibility, ack and replay guard."""
from pathlib import Path
import subprocess,sys,tempfile
root=Path(__file__).resolve().parents[1]
mock=r'''
local function signal()
 local callbacks={}
 return {Connect=function(_,f) table.insert(callbacks,f) end,Fire=function(_,...) for _,f in ipairs(callbacks) do f(...) end end}
end
local objects={}
Instance={new=function(class) local o={Activated=signal()};table.insert(objects,o);return o end}
local function value(...) return {...} end
UDim2={new=value,fromScale=value,fromOffset=value};Vector2={new=value};Color3={fromRGB=value}
local function enum() return setmetatable({Value=100},{__index=function(t,k) local v=enum();rawset(t,k,v);return v end}) end
Enum=enum()
local player={attrs={},signals={}}
function player:WaitForChild() return {} end
function player:GetAttribute(k) return self.attrs[k] end
function player:GetAttributeChangedSignal(k) self.signals[k]=self.signals[k] or signal();return self.signals[k] end
function player:SetAttribute(k,v) self.attrs[k]=v;self:GetAttributeChangedSignal(k):Fire() end
local requests=0
local remote={FireServer=function() requests+=1 end}
local Context={bound={},BindActionAtPriority=function(self,k,f) self.bound[k]=f end,UnbindAction=function(self,k) self.bound[k]=nil end}
local Run={RenderStepped=signal()}
local services={Players={LocalPlayer=player},ReplicatedStorage={WaitForChild=function() return remote end},ContextActionService=Context,RunService=Run}
game={GetService=function(_,k) return services[k] end}
workspace={CurrentCamera={ViewportSize={X=900,Y=600}}}
local delayed={};task={delay=function(_,f) table.insert(delayed,f) end}
'''
cases=r'''
local gui,button,title,copy
for _,o in ipairs(objects) do
 if o.Name=="OutcastEnd" then gui=o end
 if o.Name=="AcknowledgeEnd" then button=o end
 if o.Text=="THIS IS THE END" then title=o end
 if string.find(o.Text or "","empty shell",1,true) then copy=o end
end
assert(gui and button and title and copy and not gui.Enabled)
button.Activated:Fire();assert(requests==0)
player:SetAttribute("OutcastEnd",true)
assert(gui.Enabled and Context.bound.OutcastEndBlock and gui.DisplayOrder>1000)
button.Activated:Fire();button.Activated:Fire()
assert(requests==1 and gui.Enabled,"wait for authoritative reset, no double request")
for _,f in ipairs(delayed) do f() end
button.Activated:Fire();assert(requests==2,"can retry a dropped acknowledgement")
player:SetAttribute("OutcastEnd",nil)
assert(not gui.Enabled and not Context.bound.OutcastEndBlock)
button.Activated:Fire();assert(requests==2)
player:SetAttribute("OutcastEnd",true);assert(gui.Enabled,"ending restored after rejoin is visible")
Run.RenderStepped:Fire()
print("PASS: ending title/copy, modal, server-only dismissal, ack debounce/retry, input cleanup and reconnect display")
'''
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'ending.luau';p.write_text(mock+'\n'+(root/'src/client/OutcastEnd.client.luau').read_text()+'\n'+cases)
 subprocess.run([sys.argv[1],str(p)],check=True)
