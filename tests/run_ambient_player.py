"""Run the production playlist mixer and client mood selection against audio/tween events."""
from pathlib import Path
import subprocess,sys,tempfile
root=Path(__file__).resolve().parents[1]
s=(root/'tests/fixtures/town_mock.luau').read_text()
s+='''
local SoundService=make("SoundService","SoundService")
local pending,delayed={},{}
local warnings={}
local function warn(text) table.insert(warnings,text) end
local TweenService={}
local oldGetService=game.GetService
function game:GetService(name)
 if name=="SoundService" then return SoundService end
 if name=="TweenService" then return TweenService end
 return oldGetService(self,name)
end
Enum.EasingStyle={Sine=1};Enum.EasingDirection={InOut=1};Enum.PlaybackState={Completed=1,Cancelled=2}
local TweenInfo={new=function(seconds) return {Time=seconds} end}
function TweenService:Create(target,info,goals)
 local e=event()
 function e:Once(fn)
  local fired=false
  return self:Connect(function(...) if not fired then fired=true;fn(...) end end)
 end
 local tween={Completed=e,Target=target,Goals=goals}
 function tween:Cancel() self.Cancelled=true;self.Completed:Fire(Enum.PlaybackState.Cancelled) end
 function tween:Play() table.insert(pending,self) end
 return tween
end
local function finish()
 local tweens=pending;pending={}
 for _,t in ipairs(tweens) do
  if not t.Cancelled then
   for key,value in pairs(t.Goals) do t.Target[key]=value end
   t.Completed:Fire(Enum.PlaybackState.Completed)
  end
 end
end
function task.delay(_,fn) table.insert(delayed,fn) end
local function timeouts()
 local callbacks=delayed;delayed={}
 for _,fn in ipairs(callbacks) do fn() end
end
local originalNew=Instance.new
function Instance.new(class)
 local p=originalNew(class)
 if class=="Sound" then p.Loaded=event();p.Ended=event();p.Volume=.3;p.SoundId="";p.IsLoaded=true;p.PlayCount=0 end
 return p
end
function methods:Play() self.Playing=true;self.PlayCount+=1 end
function methods:Stop() self.Playing=false end
local originalClone=methods.Clone
function methods:Clone()
 local p=originalClone(self)
 if self:IsA("Sound") then
  p.SoundId=self.SoundId;p.Volume=self.Volume;p.IsLoaded=self.IsLoaded;p.Looped=self.Looped;p.PlayOnRemove=self.PlayOnRemove
 end
 return p
end
local sounds=make("Folder","Sounds",ReplicatedStorage)
local outside=make("Folder","OutsideAmbient",sounds)
local battle=make("Folder","BattleAmbient",sounds)
for _,folder in ipairs({outside,battle}) do
 for i=1,2 do
  local sound=make("Sound","Track"..i,folder);sound.SoundId="rbxassetid://"..i;sound.Volume=.25*i;sound.Looped=true
 end
end
'''
for variable,path in [('Config','src/shared/AmbientConfig.luau'),('AmbientPlayer','src/client/AmbientPlayer.luau')]:
 s+='\nlocal '+variable+'=(function()\n'+(root/path).read_text()+'\nend)()'
s+='''
local music=AmbientPlayer.new(Config)
music:SetMode("Outside")
local out,war=music.Channels.Outside,music.Channels.Battle
assert(out.Sound and out.Sound.Playing and out.Sound.SoundGroup==out.Group and out.Group.Volume==0)
assert(not out.Sound.Looped and out.Sound.TimePosition==0 and out.Sound.Volume==out.Last.Volume)
finish();assert(out.Group.Volume==1 and not war.Sound)
local first=out.Last
local old=out.Sound;old.Ended:Fire();finish()
assert(old.destroyed and out.Last~=first and out.Sound.Playing,"playlist continues without immediate repeats")
local original=out.Sound
music:SetMode("Battle");assert(war.Sound and out.Sound==original)
music:SetMode("Outside");finish()
assert(out.Sound==original and out.Sound.Playing and not war.Sound,"rapid re-entry cancels obsolete fades without restarting outside track")
music:SetMode("Battle");finish()
assert(not out.Sound and war.Sound.Playing and war.Group.Volume==1,"battle crossfades and releases outside audio")
music:SetMode(nil);finish()
assert(not out.Sound and not war.Sound and war.Group.Volume==0,"city/menu/KO fades to silence")
for _,sound in ipairs(battle:GetChildren()) do sound.IsLoaded=false end
music:SetMode("Battle")
local loading=war.Sound
finish();assert(war.Group.Volume==0,"unloaded music cannot fade in early")
loading.IsLoaded=true;loading.Loaded:Fire();finish();assert(war.Group.Volume==1)
music:SetMode(nil);finish();music:SetMode("Battle")
local missing=war.Sound;timeouts()
assert(missing.destroyed and not war.Sound and #warnings==1,"failed loading is cleaned up rather than blocking playlist")
clock+=2;music:SetMode("Battle");assert(war.Sound and war.Sound~=missing)
music:SetMode("Outside");finish()
assert(out.Sound and not war.Sound)
local container=music.Container
music:Destroy();finish();timeouts()
assert(container.destroyed and not out.Sound and not war.Sound,"shutdown cancels delayed callbacks and all playback")
local empty=AmbientPlayer.new(Config)
local saved=outside.Name;outside.Name="Unavailable"
empty:SetMode("Outside");assert(not empty.Channels.Outside.Sound)
outside.Name=saved;clock+=3;empty:SetMode("Outside");assert(empty.Channels.Outside.Sound,"folders added later can start playback")
empty:Destroy()
for _,folder in ipairs({outside,battle}) do for _,sound in ipairs(folder:GetChildren()) do
 assert(sound.Looped and sound.PlayCount==0 and sound.Parent==folder,"source assets are never played or mutated")
end end
print("PASS: actual mixer crossfades, non-repeating playlists, rapid reversal, load gating/timeout recovery, empty-folder retry, source isolation and destruction")
-- Exercise the shipped client's city/combat selection and timeout fallback.
local modes={}
AmbientPlayer={new=function() return {SetMode=function(_,mode) table.insert(modes,mode or "Silent") end,Destroy=function() end} end}
local RunService={Heartbeat=event()}
local getService=game.GetService
function game:GetService(name) if name=="RunService" then return RunService end;return getService(self,name) end
local script={Destroying=event()}
Players.LocalPlayer=a;a.CharacterRemoving=event();a:LoadCharacterAsync()
a.Character.Humanoid.Health=100
'''
client=(root/'src/client/Ambient.client.luau').read_text()
client='\n'.join(line for line in client.splitlines() if not line.startswith('local Config=require') and not line.startswith('local AmbientPlayer=require'))
s+='\n'+client+'\n'
s+='''
local function mode() RunService.Heartbeat:Fire(.2);return modes[#modes] end
assert(mode()=="Silent","wait for first territory resolution")
a:SetAttribute("TerritoryResolved",true);assert(mode()=="Outside")
a:SetAttribute("TerritoryTownID",99);assert(mode()=="Silent","any town suppresses outside playlist")
a:SetAttribute("BattleAmbientUntil",clock+30);assert(mode()=="Battle","combat overrides city silence")
clock+=31;assert(mode()=="Silent")
a:SetAttribute("TerritoryTownID",nil);assert(mode()=="Outside")
a:SetAttribute("BattleAmbientUntil",clock+30);assert(mode()=="Battle")
clock+=31;assert(mode()=="Outside","expired combat returns to outside")
a:SetAttribute("BattleAmbientUntil",clock+30);a.Character:SetAttribute("Knockout",true);assert(mode()=="Silent")
a.Character:SetAttribute("Knockout",false);a.Character:SetAttribute("IsDead",true);assert(mode()=="Silent")
a.CharacterRemoving:Fire(a.Character);assert(modes[#modes]=="Silent")
script.Destroying:Fire()
print("PASS: real client waits for territory, city silence, outside entry, battle priority, deadline fallback and KO/death/removal silence")
'''
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'ambient.luau';p.write_text(s);subprocess.run([sys.argv[1],str(p)],check=True)
