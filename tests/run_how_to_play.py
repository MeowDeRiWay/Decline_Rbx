"""Exercise actual help UI lifecycle, remembered preference and input cleanup."""
from pathlib import Path
import subprocess, sys, tempfile
root=Path(__file__).resolve().parents[1]
source=(root/'src/client/HowToPlay.client.luau').read_text()
mock=r'''
local mode="MODE"
local function signal()
 local listeners={}
 return {Connect=function(_,fn) table.insert(listeners,fn) end,Fire=function(_,...) for _,fn in ipairs(listeners) do fn(...) end end}
end
local objects={}
Instance={new=function(class) local o={ClassName=class,Activated=signal()};table.insert(objects,o);return o end}
local function value(...) return {...} end
UDim2={new=value,fromOffset=value,fromScale=value};UDim={new=value};Vector2={new=value};Vector3={zero={}};Color3={new=value}
local function enum() return setmetatable({Value=100},{__index=function(t,k) local v=enum();rawset(t,k,v);return v end}) end
Enum=enum()
local humanoid={Move=function(self) self.Stopped=true end}
local player={attrs={HelpPreferenceReady=true,HelpPreferenceStatus="Saved",HelpHidden=mode=="hidden",AttributesConfirmed=true,LoadingScreenOpen=true},signals={},Character={FindFirstChildOfClass=function() return humanoid end}}
function player:WaitForChild() return {} end
function player:GetAttribute(k) return self.attrs[k] end
function player:GetAttributeChangedSignal(k) if not self.signals[k] then self.signals[k]=signal() end;return self.signals[k] end
function player:SetAttribute(k,v) self.attrs[k]=v;self:GetAttributeChangedSignal(k):Fire() end
local calls={}
local remote={FireServer=function(_,v) table.insert(calls,v);player:SetAttribute("HelpHidden",v) end}
local Layout={Bar={}}
local Theme={Bevel=function() end}
local services={Players={LocalPlayer=player},ReplicatedStorage={Shared={UITheme="theme"},WaitForChild=function() return remote end},
 ContextActionService={Bindings={},BindActionAtPriority=function(self,k,fn) self.Bindings[k]=fn end,UnbindAction=function(self,k) self.Bindings[k]=nil end},
 RunService={RenderStepped=signal(),Bindings={},BindToRenderStep=function(self,k,_,fn) self.Bindings[k]=fn end,UnbindFromRenderStep=function(self,k) self.Bindings[k]=nil end}}
game={GetService=function(_,k) return services[k] end}
script={Parent={HUDLayout="layout"}}
local require=function(k) return k=="theme" and Theme or Layout end
local jobs={};local waited=0
task={spawn=function(fn) table.insert(jobs,fn) end,wait=function()
 waited+=1
 if waited==2 then player:SetAttribute("LoadingScreenOpen",false);player:SetAttribute("ProgressionOpen",true) end
 if waited==4 then player:SetAttribute("ProgressionOpen",false) end
 assert(waited<10,"startup must not hang")
end}
workspace={CurrentCamera={ViewportSize={X=1280,Y=720}}}
'''
cases=r'''
local gui,check,help,done
for _,o in ipairs(objects) do
 if o.Name=="HowToPlay" then gui=o end
 if o.Name=="HowToPlayButton" then help=o end
 if o.Text=="Got it" then done=o end
 if o.ClassName=="TextButton" and string.find(o.Text or "","Don't show",1,true) then check=o end
end
assert(gui and check and help and done and not gui.Enabled)
for _,fn in ipairs(jobs) do fn() end
if mode=="hidden" then
 assert(not gui.Enabled,"remembered preference suppresses automatic help")
 player:SetAttribute("LoadingScreenOpen",false)
else
 assert(gui.Enabled and player.attrs.HelpOpen and waited==4,"wait for splash and creation")
 assert(services.ContextActionService.Bindings.HelpBlockInput)
 services.RunService.Bindings.HelpStopMovement();assert(humanoid.Stopped)
 services.RunService.RenderStepped:Fire();assert(scale.Scale==1)
 check.Activated:Fire();assert(calls[1]==true and string.sub(check.Text,1,3)=="[X]")
 done.Activated:Fire();assert(not gui.Enabled and not player.attrs.HelpOpen)
 assert(not services.ContextActionService.Bindings.HelpBlockInput and not services.RunService.Bindings.HelpStopMovement)
end
help.Activated:Fire();assert(gui.Enabled,"manual help always works, including hidden preference")
check.Activated:Fire();assert(calls[#calls]==false,"can reenable at next login")
help.Activated:Fire();assert(not gui.Enabled)
player:SetAttribute("InventoryOpen",true);help.Activated:Fire();assert(not gui.Enabled,"do not overlap another menu")
print("PASS: help UI "..mode..", startup ordering, movement blocking/cleanup, checkbox and manual reopen")
'''
with tempfile.TemporaryDirectory() as d:
 for mode in ['show','hidden']:
  p=Path(d)/'ui.luau';p.write_text(mock.replace('MODE',mode)+'\n'+source+'\n'+cases)
  subprocess.run([sys.argv[1],str(p)],check=True)
