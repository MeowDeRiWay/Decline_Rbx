from pathlib import Path
import re, subprocess, sys, tempfile

root = Path(__file__).resolve().parents[1]
source = (root / 'src/client/Main.client.luau').read_text()
source = re.sub(r'local (Config|ProgressionRules|MovementRules)\s*=\s*require[^\n]+\n', '', source)
mock = '''
local function signal()
 local s={}
 function s:Connect(fn) table.insert(self,fn) end
 function s:Fire(...) for _,fn in ipairs(self) do fn(...) end end
 return s
end
local Vector3={new=function(x,y,z) return {X=x,Y=y,Z=z} end}
local root={Position=setmetatable({X=10,Y=2,Z=20},{__add=function(a,b) return Vector3.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end})}
local CFrame={new=function(p) return {Position=p} end,lookAt=function(p,t,u) return {Position=p,Target=t,Up=u} end}
local player={CharacterAdded=signal(),CharacterRemoving=signal(),attrs={},signals={}}
function player:GetAttribute(n) return self.attrs[n] end
function player:GetAttributeChangedSignal(n) self.signals[n]=self.signals[n] or signal();return self.signals[n] end
function player:SetAttribute(n,v) self.attrs[n]=v;self:GetAttributeChangedSignal(n):Fire() end
local character={FindFirstChild=function(_,n) if n=="HumanoidRootPart" then return root end end}
local Input={InputBegan=signal(),InputChanged=signal(),InputEnded=signal(),WindowFocusReleased=signal(),MouseBehavior="Default"}
function Input:GetFocusedTextBox() return self.TextBox end
local gui={MenuIsOpen=false}
local render
local report
local time=0
local os={clock=function() time+=1;return time end}
local storage={FindFirstChild=function() return {FireServer=function(_,...) report={...} end} end}
local services={Players={LocalPlayer=player},ReplicatedStorage=storage,RunService={BindToRenderStep=function(_,_,_,fn) render=fn end},ContextActionService={BindActionAtPriority=function() end},UserInputService=Input,GuiService=gui}
local game={GetService=function(_,n) return services[n] end}
local Enum={CameraType={Scriptable="Scriptable"},UserInputType={MouseWheel="Wheel",MouseButton3="Middle",MouseMovement="Move"},MouseBehavior={LockCurrentPosition="Locked"},ContextActionResult={Sink=1},ContextActionPriority={High={Value=1}},PlayerActions={CharacterJump=1},RenderPriority={Input={Value=0},Camera={Value=100}}}
local Config={CameraHeight=30,CameraBack=5,CameraFieldOfView=40,CameraOrbitSensitivity=.006}
local ProgressionRules={ZoomBounds=function() return 18,60 end}
local camera={ViewportSize={X=1600,Y=900}}
local workspace={CurrentCamera=camera}
'''
cases = '''
player.Character=character
local function near(a,b) assert(math.abs(a-b)<1e-6,tostring(a).." ~= "..tostring(b)) end
local function middle(processed) Input.InputBegan:Fire({UserInputType="Middle"},processed) end
local function move(x) Input.InputChanged:Fire({UserInputType="Move",Delta={X=x}},false) end
render(1)
near(camera.CFrame.Position.X,10);near(camera.CFrame.Position.Z,25)
middle(true);assert(Input.MouseBehavior=="Default")
middle(false);assert(Input.MouseBehavior=="Locked")
move(-math.pi/2/.006);render(1)
near(camera.CFrame.Position.X,15);near(camera.CFrame.Position.Z,20)
near(camera.CFrame.Up.X,-1);near(camera.CFrame.Up.Z,0)
near(report[3],math.pi/2)
Input.InputEnded:Fire({UserInputType="Middle"})
assert(Input.MouseBehavior=="Default")
move(100);render(1);near(camera.CFrame.Position.X,15)
Input.InputChanged:Fire({UserInputType="Wheel",Position={Z=1}},false);render(1)
near(camera.CFrame.Position.Y,30+2*math.exp(-12))
for _,name in ipairs({"InventoryOpen","TownMenuOpen","ProgressionOpen","GroupOpen","AdminOpen","FarmMenuOpen","LoadingScreenOpen","MapOpen"}) do
 middle(false);player:SetAttribute(name,true);assert(Input.MouseBehavior=="Default")
 middle(false);assert(Input.MouseBehavior=="Default")
 player:SetAttribute(name,false)
end
middle(false);Input.WindowFocusReleased:Fire();assert(Input.MouseBehavior=="Default")
middle(false);player.CharacterRemoving:Fire();assert(Input.MouseBehavior=="Default")
middle(false);gui.MenuIsOpen=true;render(1);assert(Input.MouseBehavior=="Default")
gui.MenuIsOpen=false
Input.InputChanged:Fire({UserInputType="Wheel",Position={Z=1000}},false);render(2)
assert(camera.CFrame.Position.Y>=20,"ordinary player cannot zoom inside character")
player:SetAttribute("AdminAccess",true)
Input.InputChanged:Fire({UserInputType="Wheel",Position={Z=1000}},false);render(2)
assert(camera.CFrame.Position.Y<2.66,"admin can inspect character at 0.65 stud height")
player:SetAttribute("AdminAccess",false);render(2)
assert(camera.CFrame.Position.Y>19.99,"revoking access restores ordinary zoom minimum")
print("PASS: admin close inspection and normal-player zoom boundaries")
print("PASS: middle drag yaw and fixed tilt, unchanged wheel zoom, activity yaw report, processed input, menu/focus/respawn cursor release")
'''
with tempfile.TemporaryDirectory() as directory:
    path = Path(directory) / 'camera.luau'
    path.write_text(mock + '\n' + source + '\n' + cases)
    subprocess.run([sys.argv[1] if len(sys.argv)>1 else 'luau', str(path)], check=True)
