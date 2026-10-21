"""Test CoreGui startup retries, respawn, and Tab behavior without affecting text input."""
from pathlib import Path
import subprocess,sys,tempfile
root=Path(__file__).resolve().parents[1]
s=(root/'src/client/PlayerList.client.luau').read_text()
setup='''
local calls,waits=0,0
local focused=false
local characterAdded
local tab
local StarterGui={SetCoreGuiEnabled=function(_,kind,enabled) assert(kind=="PlayerList" and enabled==false);calls+=1;if calls<3 then error("core not ready") end end}
local player={CharacterAdded={Connect=function(_,fn) characterAdded=fn end}}
local Context={BindActionAtPriority=function(_,name,fn,touch,priority,key) assert(name=="DeclineHidePlayerList" and not touch and key=="Tab");tab=fn end}
local Input={GetFocusedTextBox=function() return focused and {} or nil end}
local GuiService={MenuIsOpen=false}
local services={GuiService=GuiService,Players={LocalPlayer=player},StarterGui=StarterGui,ContextActionService=Context,UserInputService=Input}
local game={GetService=function(_,name) return services[name] end}
local Enum={CoreGuiType={PlayerList="PlayerList"},ContextActionResult={Pass="Pass",Sink="Sink"},ContextActionPriority={High={Value=2000}},KeyCode={Tab="Tab"}}
local task={spawn=function(fn) fn() end,wait=function() waits+=1 end}
'''
cases='''
assert(calls==3 and waits==2,"CoreGui startup retries")
assert(tab()=="Sink")
focused=true;assert(tab()=="Pass","typing/autocomplete keeps Tab")
focused=false;GuiService.MenuIsOpen=true;assert(tab()=="Pass","Roblox menu keyboard navigation remains available")
characterAdded();assert(calls==4,"respawn reasserts disabled list")
print("PASS: startup retry, PlayerList-only disable, respawn, Tab sink and text-box pass")
'''
with tempfile.TemporaryDirectory() as folder:
 path=Path(folder)/'playerlist.luau';path.write_text(setup+s+cases);subprocess.run([sys.argv[1] if len(sys.argv)>1 else 'luau',str(path)],check=True)
