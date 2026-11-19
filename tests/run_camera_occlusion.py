"""Run the camera occlusion controller against a simulated local scene."""
from pathlib import Path
import subprocess
import sys
import tempfile

root = Path(__file__).resolve().parents[1]
source = (root / "tests/rig_math.fixture.luau").read_text()
source += r'''
local function signal()
 local callback
 return {Connect=function(_,fn) callback=fn end,Fire=function() if callback then callback() end end}
end
local function object(kind,parent)
 local o={ClassName=kind,Parent=parent,Name=kind,Children={}}
 function o:GetAttribute(name) return self.Attributes and self.Attributes[name] end
 function o:IsA(name) return name==self.ClassName or name=="BasePart" and self.ClassName=="Part" end
 function o:FindFirstChild(name) for _,child in ipairs(self.Children) do if child.Name==name then return child end end end
 function o:FindFirstChildOfClass(kind) for _,child in ipairs(self.Children) do if child.ClassName==kind then return child end end end
 function o:IsDescendantOf(parent) local p=self.Parent;while p do if p==parent then return true end;p=p.Parent end;return false end
 if parent then table.insert(parent.Children,o) end
 return o
end
workspace=object("Workspace")
local character=object("Model",workspace)
local rootPart=object("Part",character)
rootPart.Name="HumanoidRootPart";rootPart.Position=Vector3.zero;rootPart.Size=Vector3.new(.4,.7,.3)
local head=object("Part",character);head.Name="Head";head.Position=Vector3.new(0,.5,0)
local player={Character=character,CharacterRemoving=signal()}
local callback,priority,calls= nil,nil,0
local sceneHits={}
local camera={CFrame=CFrame.identity}
function camera:GetPartsObscuringTarget(points,ignore)
 calls+=1
 assert(ignore[1]==character,"ignore the full local character, including equipment")
 assert(#points>=4,"sample the head, body and silhouette")
 return sceneHits
end
workspace.CurrentCamera=camera
local RunService={}
function RunService:BindToRenderStep(name,p,fn) assert(name=="DeclineCameraOcclusion");callback=fn;priority=p end
function RunService:UnbindFromRenderStep(name) callback=nil end
game={GetService=function(_,name) if name=="Players" then return {LocalPlayer=player} end;return RunService end}
Enum={RenderPriority={Camera={Value=200}}}
script={Destroying=signal()}
local function wall(original,parent)
 local part=object("Part",parent or workspace)
 part.LocalTransparencyModifier=original or 0
 part.Transparency=0;part.CanCollide=true
 return part
end
local front=wall(.2)
local rear=wall()
local glass=wall();glass.Transparency=.98
local npc=object("Model",workspace);object("Humanoid",npc)
local npcPart=wall(1,npc)
local mannequin=object("Model",workspace);mannequin.Name="Mannikin"
local mannequinPart=wall(1,mannequin)
local roadModel=object("Model",workspace);roadModel.Attributes={Road=true}
local road=wall(0,roadModel)
local roadPart=wall(.1);roadPart.Attributes={Road=true}
local nestedModel=object("Model",roadModel)
local nestedRoad=wall(0,nestedModel)
local car=object("Model",workspace);car.Attributes={Vehicle=true}
local carPart=wall(0,car)
local items=object("Folder",workspace);items.Name="Items"
local itemPart=wall(0,object("Model",items))
local dropped=object("Model",workspace);dropped.Attributes={Item_ID="Rifle223"}
local droppedPart=wall(0,dropped)
local collision,transparency=front.CanCollide,front.Transparency
'''
source += "\nlocal Stations=(function()\n" + (root / "src/shared/CraftStations.luau").read_text() + "\nend)()\n"
source += "\nlocal Occlusion=(function()\n" + (root / "src/client/CameraOcclusionState.luau").read_text().replace('local Stations=require(game:GetService("ReplicatedStorage").Shared.CraftStations)', '') + "\nend)()\n"
source += "\nlocal controller=(function()\n" + (root / "src/client/CameraOcclusion.client.luau").read_text().replace("local Occlusion=require(script.Parent.CameraOcclusionState)", "") + "\nend)()\n"
source += r'''
assert(priority>200,"obstruction checks run after the scripted camera")
local function frames(fps,seconds)
 for _=1,math.ceil(fps*seconds) do callback(1/fps) end
end
for _,fps in ipairs({30,60,144}) do
 sceneHits={front,rear,glass,npcPart,mannequinPart,road,roadPart,nestedRoad,carPart,itemPart,droppedPart}
 local before=calls
 frames(fps,1)
 assert(front.LocalTransparencyModifier>.84 and rear.LocalTransparencyModifier>.84,"all blocking layers fade")
 assert(Occlusion.CursorPasses(front) and Occlusion.CursorPasses(rear),"only camera-faded blockers pass the cursor")
 assert(not Occlusion.CursorPasses(npcPart) and not Occlusion.CursorPasses(road),"other visibility systems and roads stay untouched")
 front.Attributes={Door=true};assert(not Occlusion.CursorPasses(front),"faded doors remain targets");front.Attributes=nil
 local bench=object("Model",workspace);bench.Attributes={Workstation=true}
 front.Parent=bench;assert(not Occlusion.CursorPasses(front),"faded workbench remains selectable");front.Parent=workspace
 assert(road.LocalTransparencyModifier==0 and roadPart.LocalTransparencyModifier==.1 and nestedRoad.LocalTransparencyModifier==0,"Road attributes on parts or ancestors exclude all road geometry")
 assert(carPart.LocalTransparencyModifier==0 and itemPart.LocalTransparencyModifier==0 and droppedPart.LocalTransparencyModifier==0,"cars and Items never fade")
 assert(glass.LocalTransparencyModifier==0,"authored transparent geometry stays unchanged")
 assert(npcPart.LocalTransparencyModifier==1 and mannequinPart.LocalTransparencyModifier==1,"creature visibility retains ownership")
 assert(front.Transparency==transparency and front.CanCollide==collision,"occlusion changes presentation only")
 assert(calls-before<=32,"geometry queries stay within the 30Hz budget")
 sceneHits={rear}
 frames(fps,1)
 assert(not Occlusion.CursorPasses(front),"restored walls block the cursor again")
 assert(front.LocalTransparencyModifier==.2 and rear.LocalTransparencyModifier>.84,"only geometry still blocking stays faded")
 sceneHits={}
 frames(fps,1)
 assert(rear.LocalTransparencyModifier==0,"clear geometry restores its original modifier")
end
sceneHits={front}
frames(60,.4)
front.Parent=nil
frames(60,.1)
assert(front.LocalTransparencyModifier==.2,"streamed-out walls restore before tracking is dropped")
front.Parent=workspace
frames(60,.4)
assert(front.LocalTransparencyModifier>.84)
player.CharacterRemoving:Fire()
assert(front.LocalTransparencyModifier==.2 and not Occlusion.CursorPasses(front),"respawn restores walls and cursor tracking")
frames(60,.4)
workspace.CurrentCamera=nil
frames(60,.1)
assert(front.LocalTransparencyModifier==.2,"missing cameras restore all affected walls")
workspace.CurrentCamera=camera
frames(60,.4)
script.Destroying:Fire()
assert(front.LocalTransparencyModifier==.2 and callback==nil,"controller destruction restores and unbinds")
print("PASS: layered occlusion, NPC isolation, smooth restoration, streaming, respawn, camera loss, cleanup and 30/60/144Hz")
'''
with tempfile.TemporaryDirectory() as directory:
    path = Path(directory) / "camera_occlusion.luau"
    path.write_text(source)
    subprocess.run([sys.argv[1] if len(sys.argv) > 1 else "luau", str(path)], check=True)
