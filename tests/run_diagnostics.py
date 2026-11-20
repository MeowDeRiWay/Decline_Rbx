"""Exercise actual admin diagnostics: pause/restore scene and local frame/decor tools."""
from pathlib import Path
import re,subprocess,sys,tempfile
r=Path(__file__).resolve().parents[1]
def module(path):
 s=(r/path).read_text();s=re.sub(r'^local \w+\s*=\s*require[^\n]*\n','',s,flags=re.MULTILINE)
 return '(function()\n'+s+'\nend)()'
code=(r/'tests/rig_math.fixture.luau').read_text()+'\n'+(r/'tests/vehicle_runtime.fixture.luau').read_text()
code+=r'''
workspace.DescendantRemoving=signal()
RunService.RenderStepped=signal()
local loops={}
task.spawn=function(fn) local co=coroutine.create(fn);table.insert(loops,co);assert(coroutine.resume(co)) end
task.wait=function() coroutine.yield() end
local suspended=0
local Activity={SuspendDiagnostics=function() suspended+=1 end,DiagnosticStats=function() return 2,0 end}
local admin=create("Player",Players);admin:SetAttribute("AdminAccess",true)
local stranger=create("Player",Players)
local creatures=create("Folder",workspace)
local zombie=create("Model",creatures);zombie.Name="Zombie"
local hp=create("Humanoid",zombie);hp.Health=37
local body=create("Part",zombie)
local corpse=create("Model",creatures);corpse.Name="Zombie"
local dead=create("Humanoid",corpse);dead.Health=0
'''
code+='\nlocal Server='+module('src/server/Services/DiagnosticsService.luau')+'\n'
code+=r'''
Server.Start()
assert(not Server.SetZombiesDisabled(stranger,true),"non-admin cannot change server diagnostics")
assert(Server.SetZombiesDisabled(admin,true))
assert(workspace:GetAttribute("DiagnosticsZombiesDisabled") and suspended==1)
assert(zombie.Parent.Name=="DiagnosticZombies" and hp.Health==37 and corpse.Parent==creatures,"live models are parked without killing them or removing corpses")
local added=create("Model",creatures);added.Name="Zombie";create("Humanoid",added).Health=42
workspace.DescendantAdded:Fire(added);tick(.01)
assert(added.Parent==zombie.Parent,"late live zombies are parked too")
assert(Server.SetZombiesDisabled(admin,false) and zombie.Parent==creatures and added.Parent==creatures and hp.Health==37,"restore preserves parents and HP")
Server.SetZombiesDisabled(admin,true)
Players.PlayerRemoving:Fire(admin)
assert(not workspace:GetAttribute("DiagnosticsZombiesDisabled") and zombie.Parent==creatures,"controller leaving automatically restores the server")
'''
code+='\nlocal Client='+module('src/client/AdminDiagnostics.luau')+'\n'
code+=r'''
Client.Start()
Client.Reset()
for _=1,60 do RunService.RenderStepped:Fire(1/60) end
local stats=Client.Snapshot()
assert(math.abs(stats.FPS-60)<.001 and stats.Slow50==0 and math.abs(stats.P95MS-1000/60)<.01)
RunService.RenderStepped:Fire(.12)
stats=Client.Snapshot()
assert(stats.MaxMS==120 and stats.Slow50==1 and stats.Slow100==1,"long frames counted independently of F6 visibility")
Client.Reset();assert(Client.Snapshot().MaxMS==0 and Client.Snapshot().Seconds==0)
local furniture=create("Model",workspace);furniture:SetAttribute("Furniture",true)
local part=create("Part",furniture);part.LocalTransparencyModifier=.15
local lamp=create("Light",furniture);lamp.Enabled=true
local worldItem=create("Model",furniture);worldItem:SetAttribute("Item_ID","Scrap")
local loot=create("Part",worldItem);loot.LocalTransparencyModifier=0
Client.HideDecor(true)
assert(part.LocalTransparencyModifier==1 and not lamp.Enabled and loot.LocalTransparencyModifier==0,"only furniture visuals are hidden")
assert(part.CanCollide and part.CanQuery,"local visual diagnostic does not change collision or queries")
local streamed=create("Part",furniture);streamed.LocalTransparencyModifier=.3
workspace.DescendantAdded:Fire(streamed)
assert(streamed.LocalTransparencyModifier==1,"newly streamed furniture is hidden")
workspace.DescendantRemoving:Fire(streamed)
assert(streamed.LocalTransparencyModifier==.3,"streaming removal restores local overrides")
streamed.Parent=nil
Client.HideDecor(false)
assert(part.LocalTransparencyModifier==.15 and lamp.Enabled,"restore exact authored local state")
print("PASS: authorized zombie pause/restore, HP, corpses, late arrivals, admin exit, FPS/P95/slow frames, reset and local streamed decor cleanup")
'''
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'diag.luau';p.write_text(code);subprocess.run([sys.argv[1],str(p)],check=True)
