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
function methods:SetAttribute(k,v) local old=self.attrs[k];self.attrs[k]=v;if old~=v then self:GetAttributeChangedSignal(k):Fire() end end
function methods:GetAttributeChangedSignal(k) return self:GetPropertyChangedSignal('attr:'..k) end
local Instance={new=function(c)
 return setmetatable({props={ClassName=c,Name=c,Volume=.5,RollOffMinDistance=10,RollOffMaxDistance=100,Playing=true,SourceName="Output",Curve={[0]=1,[100]=0},DistanceAttenuationBounds={Min=10,Max=100},DistanceAttenuationMode="Preset",AncestryChanged=signal(),Destroying=signal(),DescendantAdded=signal()},signals={},children={},attrs={}},meta)
end}
local Enum={DistanceAttenuationMode={Custom="Custom"},RollOffMode={InverseTapered="InverseTapered"}}
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
footsteps=(root/'src/client/Footsteps.client.luau').read_text()
footsteps=footsteps[footsteps.index('local watched='):footsteps.index('local connections=')]
cases='''
flush();assert(wire.SourceInstance==listener and foreignWire.SourceInstance==listener,"hearing must never rewrite the user's audio mix")
attention(10)
assert(sound.Volume==.5 and sound.RollOffMaxDistance==200 and sound.RollOffMinDistance==10)
assert(copy.Volume==.5 and original.Volume==.5 and template.Volume==.5,"Attention never amplifies centered copies, spatial sources or templates")
assert(emitter.DistanceAttenuationBounds.Max==200 and custom.Curve[200]==0)
attention(10);assert(sound.Volume==.5 and emitter.DistanceAttenuationBounds.Max==200,"no compounding")
attention(1);assert(sound.Volume==.5 and sound.RollOffMaxDistance==20)
assert(emitter.DistanceAttenuationBounds.Max==20 and custom.Curve[20]==0)
sound.Playing=false;assert(sound.Volume==.5 and sound.RollOffMaxDistance==100)
sound.Playing=true;assert(sound.Volume==.5)
sound.Volume=.3;assert(sound.Volume==.3,"authored live volume is untouched at low Attention")
attention(10);assert(sound.Volume==.3,"authored volume untouched at high Attention too")
sound.Name="Running";sound.Volume=.08;sound.RollOffMaxDistance=5
attention(5);assert(sound.RollOffMaxDistance==5 and sound.Volume==.08)
attention(10);assert(sound.RollOffMaxDistance==10 and sound.Volume==.08)
sound.attrs.FootstepBaseDistance=10;sound:GetAttributeChangedSignal("FootstepBaseDistance"):Fire()
attention(5);assert(sound.RollOffMaxDistance==10 and sound.Volume==.08)
attention(10);assert(sound.RollOffMaxDistance==20)
player.attrs.HearingAttention=12;player:GetAttributeChangedSignal("HearingAttention"):Fire();flush()
assert(sound.RollOffMaxDistance==24 and sound.Volume==.08)
assert(wire.SourceInstance==listener,"range-only hearing creates no gain faders")
player.attrs.HearingAttention=nil;attention(5)
Config.FootstepMinDistance=2;Config.FootstepMaxDistance=5;Config.RunFootstepMaxDistance=10
FOOTSTEPS
player.attrs.SkillSneak=0;configure(sound,player,player.Character)
assert(sound.RollOffMaxDistance==5 and sound.Volume==.15)
attention(10);assert(sound.RollOffMaxDistance==10 and sound.Volume==.15)
player.Character.attrs.Running=true;player.Character:GetAttributeChangedSignal("Running"):Fire()
assert(sound.RollOffMaxDistance==20 and sound.Volume==.15,"run base10 overrides previously scaled walk10 without feedback")
sound.Volume=.65;assert(sound.Volume==.15,"Roblox default sound script cannot reset footstep source gain")
player.attrs.SkillSneak=30;player.Character.attrs.Running=false;player.Character:GetAttributeChangedSignal("Running"):Fire()
assert(sound.RollOffMaxDistance==4 and math.abs(sound.Volume-.06)<1e-9,"Sneak quiet source combines with range-only hearing")
print("PASS: Attention changes range only for legacy/centered audio and voice emitters; authored volumes and audio mix untouched, walking5/run10 scale with hearing")
'''
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'test.luau';p.write_text(mock+'\nlocal R=(function()\n'+(root/'src/shared/SensesRules.luau').read_text()+'\nend)()\n'+s+'\n'+cases.replace('FOOTSTEPS','local Noise=(function()\n'+(root/'src/shared/NoiseRules.luau').read_text()+'\nend)()\n'+footsteps));subprocess.run([sys.argv[1],str(p)],check=True)
