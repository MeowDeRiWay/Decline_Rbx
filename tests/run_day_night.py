"""Run actual clock cycle and zombie transition stat application."""
from pathlib import Path
import subprocess,tempfile,sys
root=Path(__file__).resolve().parents[1]
cycle='local DayClock=(function()\n'+(root/'src/server/Services/DayClockService.luau').read_text()+'\nend)();DayClock.Start()'
zombie=(root/'src/server/Zombie.server.luau').read_text()
stats=zombie[zombie.index('local baseStats='):zombie.index('local function positive')]
rules=(root/'src/shared/ProgressionRules.luau').read_text()
mock='''
local clock=0
local beat
local Lighting={}
local workspace={attrs={}}
function workspace:GetServerTimeNow() return clock end
function workspace:GetAttribute(k) return self.attrs[k] end
function workspace:SetAttribute(k,v) local old=self.attrs[k];self.attrs[k]=v;if old~=v and self.changed and self.changed[k] then self.changed[k]() end end
function workspace:GetAttributeChangedSignal(k) return {Connect=function(_,fn) workspace.changed=workspace.changed or {};workspace.changed[k]=fn end} end
local Run={Heartbeat={Connect=function(_,fn) beat=fn end}}
local game={GetService=function(_,name) return name=="Lighting" and Lighting or Run end}
'''
cases='''
local function model()
 local m={attrs={},Parent=true};local hp={Health=40,MaxHealth=40}
 function m:GetAttribute(k) return self.attrs[k] end
 function m:SetAttribute(k,v) self.attrs[k]=v end
 function m:FindFirstChildOfClass() return hp end
 return m,hp
end
local m,hp=model();local base={Strength=4,Attention=4,Endurance=4,Intelligence=1,Agility=2,Luck=5}
baseStats[m]=base
applyDayStats(m,hp,base);assert(hp.MaxHealth==24 and m.attrs.Intelligence==1 and m.attrs.SkillUnarmed==112,"zombie has100 extra unarmed")
clock=1500;beat(1);assert(Lighting.ClockTime==18 and workspace.attrs.IsNight)
assert(hp.MaxHealth==36 and hp.Health==36 and m.attrs.Intelligence==3 and m.attrs.Luck==7 and m.attrs.Strength==6)
hp.Health=18
clock=3300;beat(1);assert(Lighting.ClockTime==6 and not workspace.attrs.IsNight)
assert(hp.MaxHealth==28 and hp.Health==14 and m.attrs.Intelligence==1,"transition preserves health fraction and base attributes")
clock=3600;beat(1);assert(Lighting.ClockTime==8 and workspace.attrs.WorldDay==2 and m.attrs.CharacterLevel==1 and m.attrs.DailyDamageBonus==1,"one-hour day adds level/HP and flat damage")
hp.Health=0;clock=5100;beat(1);assert(hp.Health==0,"night cannot revive a corpse")
print("PASS: one-hour day cycle, dawn/dusk, all zombie attributes +2, health fraction, no corpse revival")
'''
accuracy=(root/'src/shared/AccuracyRules.luau').read_text()
cases+='''
local a={AttributesConfirmed=true,SkillLightWeapons=100}
local p={GetAttribute=function(_,k) return a[k] end}
assert(Accuracy.Chance(Accuracy.ForWeapon(p,{Firearm={}}),0,20,0,Accuracy.NightMultiplier(p))==50)
assert(Accuracy.Chance(300,20,20,0,Accuracy.NightMultiplier(p))==90,"cap applies before night")
a.NightAccuracyMultiplier=.9;assert(Accuracy.Chance(Accuracy.ForWeapon(p,{Firearm={}}),0,20,0,Accuracy.NightMultiplier(p))==90)
workspace.attrs.IsNight=false;assert(Accuracy.ForWeapon(p,{Firearm={}})==100)
print("PASS: night accuracy half, cat eyes ten-percent penalty, day restoration")
DayClock.SetHour(23.5);assert(Lighting.ClockTime==23.5 and workspace.attrs.IsNight)
DayClock.SetPaused(true);clock+=1000;beat(1);assert(Lighting.ClockTime==23.5,"pause preserves time")
DayClock.SetSpeed(2);DayClock.SetPaused(false);clock+=75;beat(1)
assert(math.abs(Lighting.ClockTime-.5)<1e-9,"accelerated clock wraps midnight")
DayClock.SetSpeed(1);clock+=150;beat(1);assert(math.abs(Lighting.ClockTime-1.5)<1e-9)
DayClock.SetHour(6);assert(not workspace.attrs.IsNight,"admin time triggers day transition immediately")
assert(workspace.attrs.DayClockSpeed==1 and not workspace.attrs.DayClockPaused)
print("PASS: admin clock pause, speed, resume, midnight wrap and immediate day transition")
'''
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'night.luau'
 p.write_text(mock+'\nlocal Progression=(function()\n'+rules+'\nend)()\n'+cycle+'\n'+stats+'\nlocal Accuracy=(function()\n'+accuracy+'\nend)()\n'+cases)
 subprocess.run([sys.argv[1],str(p)],check=True)
