"""Actual local hearing script with reactive Sound/Emitter/Wire properties."""
from pathlib import Path
import re,subprocess,sys,tempfile
root=Path(__file__).resolve().parents[1]
s=(root/'src/client/Hearing.client.luau').read_text();s=re.sub(r'local (R|Config)=require[^\n]+\n','',s)
mock='''
local Config={FootstepVolume=.15}
local function signal()
 local handlers={};local e={}
 function e:Connect(fn) local r={fn=fn};table.insert(handlers,r);return {Disconnect=function() r.fn=nil end} end
 function e:Once(fn) local c;c=self:Connect(function(...) c:Disconnect();fn(...) end);return c end
 function e:Fire(...) for _,r in ipairs(table.clone(handlers)) do if r.fn then r.fn(...) end end end
 return e
end
local deferred={};local task={defer=function(fn,...) table.insert(deferred,{fn,{...}}) end}
local function flush() while #deferred>0 do local q=table.remove(deferred,1);q[1](table.unpack(q[2])) end end
local methods={};local meta={}
local game
function meta.__index(o,k) return methods[k] or o.props[k] end
function meta.__newindex(o,k,v)
 local old=o.props[k];if old==v then return end;o.props[k]=v
 if k=="Parent" then
  if old then local i=table.find(old.children,o);if i then table.remove(old.children,i) end end
  if v then table.insert(v.children,o) end
  o.AncestryChanged:Fire()
  if v and game then game.DescendantAdded:Fire(o) end
 end
 if o.signals[k] then o.signals[k]:Fire() end
end
function methods:IsA(c) return self.ClassName==c end
function methods:IsDescendantOf(p) local a=self.Parent;while a do if a==p then return true end;a=a.Parent end;return false end
function methods:GetDescendants() local r={};for _,c in ipairs(self.children) do table.insert(r,c);for _,n in ipairs(c:GetDescendants()) do table.insert(r,n) end end;return r end
function methods:GetPropertyChangedSignal(k) self.signals[k]=self.signals[k] or signal();return self.signals[k] end
function methods:Destroy() self.Destroying:Fire();self.Parent=nil;self.Destroyed=true end
function methods:GetDistanceAttenuation() return self.Curve end
function methods:SetDistanceAttenuation(curve) self.Curve=curve end
function methods:GetAttribute(k) return self.attrs[k] end
function methods:GetAttributeChangedSignal(k) return self:GetPropertyChangedSignal('attr:'..k) end
local Instance={new=function(c)
 return setmetatable({props={ClassName=c,Name=c,Volume=.5,RollOffMinDistance=10,RollOffMaxDistance=100,Playing=true,SourceName="Output",Curve={[0]=1,[100]=0},DistanceAttenuationBounds={Min=10,Max=100},DistanceAttenuationMode="Preset",AncestryChanged=signal(),Destroying=signal(),DescendantAdded=signal()},signals={},children={},attrs={}},meta)
end}
local Enum={DistanceAttenuationMode={Custom="Custom"}}
local NumberRange={new=function(a,b) return {Min=a,Max=b} end}
game=Instance.new("DataModel")
local workspace=Instance.new("Workspace");workspace.Parent=game
local SoundService=Instance.new("SoundService");SoundService.Parent=game
local storage=Instance.new("ReplicatedStorage");storage.Parent=game
local player=Instance.new("Player");player.Character=Instance.new("Model");player.Character.Parent=workspace;player.CharacterAdded=signal();player.attrs.Attention=5
local Players={LocalPlayer=player}
function game:GetService(k) return ({Players=Players,SoundService=SoundService,ReplicatedStorage=storage})[k] end
local sound=Instance.new("Sound");sound.Parent=workspace
local template=Instance.new("Sound");template.Parent=storage
local original=Instance.new("Sound");original.Name="PlayingShotSound";original.Parent=player.Character
local copy=Instance.new("Sound");copy.Name="OwnerPlayingShotSound";copy.Parent=SoundService
local emitter=Instance.new("AudioEmitter");emitter.Parent=workspace
local custom=Instance.new("AudioEmitter");custom.DistanceAttenuationMode="Custom";custom.Parent=workspace
local listener=Instance.new("AudioListener");listener.Parent=workspace
local output=Instance.new("AudioDeviceOutput");output.Parent=SoundService
local wire=Instance.new("Wire");wire.SourceInstance=listener;wire.TargetInstance=output;wire.Parent=output
local foreignOutput=Instance.new("AudioDeviceOutput");foreignOutput.Player={};foreignOutput.Parent=SoundService
local foreignWire=Instance.new("Wire");foreignWire.SourceInstance=listener;foreignWire.TargetInstance=foreignOutput;foreignWire.Parent=foreignOutput
local function attention(v) player.attrs.Attention=v;player:GetAttributeChangedSignal("Attention"):Fire();flush() end
'''
cases='''
flush();local fader=wire.SourceInstance
assert(fader:IsA("AudioFader") and fader.Volume==1 and foreignWire.SourceInstance==listener)
attention(10)
assert(sound.Volume==1 and sound.RollOffMaxDistance==200 and sound.RollOffMinDistance==20)
assert(copy.Volume==1 and original.Volume==.5 and template.Volume==.5,"own centered copies only, never muted owner source or templates")
assert(fader.Volume==2 and emitter.DistanceAttenuationBounds.Max==200 and custom.Curve[200]==0)
attention(10);assert(sound.Volume==1 and emitter.DistanceAttenuationBounds.Max==200,"no compounding")
attention(1);assert(sound.Volume==.1 and sound.RollOffMaxDistance==20 and fader.Volume==.2)
assert(emitter.DistanceAttenuationBounds.Max==20 and custom.Curve[20]==0)
sound.Playing=false;assert(sound.Volume==.5 and sound.RollOffMaxDistance==100,"stopped sound restores authored properties")
sound.Playing=true;assert(sound.Volume==.1)
sound.Volume=1;assert(sound.Volume==.2,"authored runtime volume remains hearing scaled")
wire:Destroy();assert(fader.Destroyed and wire.SourceInstance==listener,"wire cleanup restores source and deletes local mix nodes")
attention(5);assert(sound.Volume==1 and sound.RollOffMaxDistance==100)
sound.Name="Running";sound.Volume=.65;attention(10)
assert(sound.Volume==.3,"footstep cap does not cancel200% hearing")
sound.attrs.FootstepNoiseMultiplier=.5;sound:GetAttributeChangedSignal("FootstepNoiseMultiplier"):Fire()
assert(sound.Volume==.15,"quiet source multiplier and listener hearing compose")
sound.attrs.FootstepNoiseMultiplier=1/6;sound:GetAttributeChangedSignal("FootstepNoiseMultiplier"):Fire()
sound.RollOffMaxDistance=2
assert(math.abs(sound.Volume-.05)<1e-9 and sound.RollOffMaxDistance==4,"Sneak100 at Attention10 stays quiet and reaches4")
print("PASS: actual hearing20/100/200%, legacy volume/range, voice emitter curves, output gain, owner/template separation, no compounding and wire cleanup")
'''
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'test.luau';p.write_text(mock+'\nlocal R=(function()\n'+(root/'src/shared/SensesRules.luau').read_text()+'\nend)()\n'+s+'\n'+cases);subprocess.run([sys.argv[1],str(p)],check=True)
