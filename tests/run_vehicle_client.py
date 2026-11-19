"""Boot the actual vehicle LocalScript outside a seat to catch startup failures."""
from pathlib import Path
import re
import subprocess
import sys
import tempfile
root=Path(__file__).resolve().parents[1]
source=(root/'tests/rig_math.fixture.luau').read_text()+'\n'+(root/'tests/vehicle_runtime.fixture.luau').read_text()
source+=r'''
local player=create("Player",Players);player.UserId=7;Players.LocalPlayer=player
local character=create("Model",workspace);player.Character=character
local rootPart=create("Part",character);rootPart.Name="HumanoidRootPart"
local humanoid=create("Humanoid",character);humanoid.Health=100
local playerGui=create("Folder",player);playerGui.Name="PlayerGui"
create("Folder",workspace).Name="Vehicles"
local remotes=create("Folder",ReplicatedStorage);remotes.Name="VehicleRemotes"
for _,name in ipairs({"Action","Input","Effects"}) do create("RemoteEvent",remotes).Name=name end
local input={InputBegan=signal(),WindowFocusReleased=signal(),WindowFocused=signal(),
 GetFocusedTextBox=function() return nil end,IsKeyDown=function() return false end}
RunService.RenderStepped=signal();RunService.PreSimulation=signal()
local getService=game.GetService
game.GetService=function(self,name)
 if name=="UserInputService" then return input end
 if name=="GuiService" then return {MenuIsOpen=false} end
 if name=="Debris" then return {AddItem=function() end} end
 return getService(self,name)
end
Vector2={new=function(x,y) return {X=x,Y=y} end}
UDim2={new=function(...) return {...} end,fromOffset=function(...) return {...} end,fromScale=function(...) return {...} end}
Enum.Font={Code="Code"};Enum.TextXAlignment={Left="Left"};Enum.HighlightDepthMode={Occluded="Occluded"}
Enum.KeyCode={};for _,key in ipairs({"One","Two","Three","Four","Five","Six","Seven","Eight","Nine","N","R","E","X","V","L","W","A","S","D"}) do Enum.KeyCode[key]=key end
workspace.CurrentCamera={ViewportSize=Vector2.new(1280,720)}
local cursorCallback
local Cursor={Subscribe=function(_,_,callback) cursorCallback=callback end,Get=function() return nil end}
local Locale={Text=function(value) return value end,Language=function() return "uk" end}
local Config={};local Rules={};local Inspection={Read=function() return nil end};local Interaction={}
'''
client=(root/'src/client/Vehicles.client.luau').read_text()
client=re.sub(r'^local \w+\s*=\s*require[^\n]*\n','',client,flags=re.MULTILINE)
source+='\n(function()\n'+client+'\nend)()\n'
source+=r'''
assert(playerGui:FindFirstChild("VehicleHUD"),"vehicle interface boots before a player enters a car")
assert(cursorCallback,"startup reaches the hover/interaction subscription")
cursorCallback()
RunService.RenderStepped:Fire(.1)
RunService.PreSimulation:Fire(.1)
input.InputBegan:Fire({KeyCode=Enum.KeyCode.E},false)
print("PASS: actual vehicle client boots on foot, subscribes interactions and handles idle frames/input")
'''
with tempfile.TemporaryDirectory() as directory:
 path=Path(directory)/'vehicle_client.luau';path.write_text(source)
 subprocess.run([sys.argv[1] if len(sys.argv)>1 else 'luau',str(path)],check=True)
