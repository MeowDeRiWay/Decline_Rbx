"""Actual map UI lifecycle, tile sizes, fog, zoom/pan, and movement cleanup."""
from pathlib import Path
import subprocess,sys,tempfile
root=Path(__file__).resolve().parents[1]
s=(root/'src/client/Map.client.luau').read_text().replace('local Theme=require(ReplicatedStorage.Shared.UITheme)','').replace('local Rules=require(ReplicatedStorage.Shared.MapRules)','')
mock=r'''
local function signal()
 local f={};return {Connect=function(_,fn) table.insert(f,fn) end,Fire=function(_,...) for _,fn in ipairs(f) do fn(...) end end}
end
local function vec(x,y,z) return setmetatable({X=x,Y=y,Z=z},{__sub=function(a,b) return vec(a.X-b.X,a.Y-b.Y,(a.Z or 0)-(b.Z or 0)) end}) end
Vector2={new=vec};Vector3={zero={}}
local function val(...) return {...} end
UDim2={new=val,fromScale=val,fromOffset=val};Color3={new=val,fromRGB=val}
local function enum() return setmetatable({Value=100},{__index=function(t,k) local v=enum();rawset(t,k,v);return v end}) end
Enum=enum()
local objects={}
Instance={new=function(kind) local o={ClassName=kind,Activated=signal(),InputBegan=signal(),AbsoluteSize=vec(868,464),AbsolutePosition=vec(16,56)};table.insert(objects,o);return o end}
local root={Position={X=10,Y=0,Z=10},CFrame={LookVector={X=0,Z=-1}}}
local hp={Move=function(self) self.Stopped=true end}
local character={attrs={},GetAttribute=function(self,k) return self.attrs[k] end,FindFirstChild=function() return root end,FindFirstChildOfClass=function() return hp end}
local player={attrs={AttributesConfirmed=true},Character=character,CharacterRemoving=signal()}
function player:GetAttribute(k) return self.attrs[k] end
function player:SetAttribute(k,v) self.attrs[k]=v end
function player:WaitForChild() return {} end
local packets={OnClientEvent=signal()};local requests=0
local request={FireServer=function() requests+=1 end}
local Input={InputBegan=signal(),InputChanged=signal(),InputEnded=signal(),WindowFocusReleased=signal(),GetFocusedTextBox=function() return nil end,GetMouseLocation=function() return vec(100,100) end}
local Context={Bindings={},BindActionAtPriority=function(self,k,f) self.Bindings[k]=f end,UnbindAction=function(self,k) self.Bindings[k]=nil end}
local Run={RenderStepped=signal()}
local services={Players={LocalPlayer=player},ReplicatedStorage={WaitForChild=function(_,k) return k=="MapState" and packets or request end},UserInputService=Input,ContextActionService=Context,RunService=Run,GuiService={}}
game={GetService=function(_,k) return services[k] end}
workspace={CurrentCamera={ViewportSize=vec(1280,720)}}
local Theme={Font=1,Text=1,Accent=2,Button=3,Panel=4,Bevel=function() end}
'''
cases=r'''
local function press() Input.InputBegan:Fire({KeyCode=Enum.KeyCode.M},false) end
assert(not gui.Enabled and requests==1)
packets.OnClientEvent:Fire({Reset=true,OriginX=0,OriginZ=0,Cells={{X=0,Z=0,Kind="House"},{X=1,Z=0,Kind="Infrastructure"},{X=2,Z=0,Kind="Forest"},{X=3,Z=0,Kind="Ground",RoadMask=65535}}})
press();Run.RenderStepped:Fire()
assert(gui.Enabled and player.attrs.MapOpen and hp.Stopped and Context.Bindings.MapBlockInput)
assert(#pool==4,"no frames for fogged cells")
assert(pool[1].Frame.Size[1]==20 and pool[1].Frame.Size[2]==20,"one cell is exactly 20x20 pixels at 100%")
assert(arrow.Rotation==0 and arrow.Visible)
assert(#pool[4].Roads==1 and pool[4].Roads[1].Size[1]==1 and pool[4].Roads[1].Size[2]==1,"square road fills tile without center stripes")
packets.OnClientEvent:Fire({OriginX=0,OriginZ=0,Cells={{X=3,Z=0,Kind="Ground",RoadMask=255}}})
Run.RenderStepped:Fire();assert(pool[4].Roads[1].Size[2]==.5,"road-only updates repaint cached terrain")
Input.InputChanged:Fire({UserInputType=Enum.UserInputType.MouseWheel,Position=vec(0,0,1)})
Run.RenderStepped:Fire();assert(math.abs(zoom-1.2)<.001 and pool[1].Frame.Size[1]==24)
local down={UserInputType=Enum.UserInputType.MouseButton1,Position=vec(100,100)}
view.InputBegan:Fire(down)
local before=focusX
Input.InputChanged:Fire({UserInputType=Enum.UserInputType.MouseMovement,Position=vec(124,100)})
assert(focusX<before and not explored["4:4"],"drag pans without creating markers")
Input.InputEnded:Fire(down);assert(dragging==nil)
center.Activated:Fire();assert(focusX==10 and focusZ==10)
press();assert(not gui.Enabled and not player.attrs.MapOpen and not Context.Bindings.MapBlockInput)
player.attrs.InventoryOpen=true;press();assert(not gui.Enabled)
player.attrs.InventoryOpen=false;press();character.attrs.Knockout=true;Run.RenderStepped:Fire();assert(not gui.Enabled)
character.attrs.Knockout=false
packets.OnClientEvent:Fire({Reset=true,OriginX=0,OriginZ=0,Cells={}})
press();Run.RenderStepped:Fire();for _,t in ipairs(pool) do assert(not t.Frame.Visible) end
player.CharacterRemoving:Fire();assert(not gui.Enabled)
print("PASS: M open/close, exact tile size, fog-only rendering, zoom/pan without markers, center, modal cleanup, KO and character reset")
'''
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'mapui.luau';p.write_text(mock+'\nlocal Rules=(function()\n'+(root/'src/shared/MapRules.luau').read_text()+'\nend)()\n'+s+'\n'+cases)
 subprocess.run([sys.argv[1],str(p)],check=True)
