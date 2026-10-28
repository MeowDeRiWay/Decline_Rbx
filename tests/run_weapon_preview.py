"""Run actual HUD with a staged replica: empty model, late parts, switch and respawn."""
from pathlib import Path
import re,subprocess,sys,tempfile
root=Path(__file__).resolve().parents[1]
source=(root/'src/client/WeaponHUD.client.luau').read_text()
source=re.sub(r'local (Theme|items|layout)\s*=\s*require[^\n]+\n','',source)
setup='''
function vm.__mul(a,b) if type(a)=="number" then a,b=b,a end;return Vector3.new(a.X*b,a.Y*b,a.Z*b) end
Enum.TextXAlignment={Left=1}
CFrame.identity=CFrame.new();Vector3.yAxis=Vector3.new(0,1,0)
local Vector2={new=function(x,y) return {X=x,Y=y} end}
local UDim2={fromOffset=function() return {} end,fromScale=function() return {} end}
local Color3={fromRGB=function() return {} end,new=function() return {} end}
local Theme={Panel={},Text={},Accent={},Danger={},Card={},Font=1,Bevel=function() end}
local items={GunA={Name="Gun A",Weapon=true,Firearm={Magazine=5,SingleOnly=true}},GunB={Name="Gun B",Weapon=true}}
local layout={Bar=make("Folder","Bar")}
local function signal()
 local handlers={}
 return {Connect=function(_,fn)
  handlers[fn]=true
  return {Disconnect=function() handlers[fn]=nil end}
 end,Fire=function(_,...) for fn in pairs(handlers) do fn(...) end end}
end
local originalNew=Instance.new
Instance.new=function(class)
 local o=originalNew(class)
 for _,name in ipairs({"MouseEnter","MouseLeave","DescendantAdded","DescendantRemoving","ChildAdded","ChildRemoved"}) do o[name]=signal() end
 return o
end
local originalClone=methods.Clone
local cloneCalls=0
function methods:Clone()
 cloneCalls+=1
 local copy=originalClone(self)
 copy.LocalTransparencyModifier=self.LocalTransparencyModifier
 copy.Transparency=self.Transparency
 return copy
end
function methods:ClearAllChildren() for _,child in ipairs(self:GetChildren()) do child:Destroy() end end
local baseService=game.GetService
function game:GetService(name)
 if name=="TextService" then return {GetTextSize=function() return Vector2.new(50,18) end} end
 return baseService(self,name)
end
local deferred={}
task.defer=function(fn) table.insert(deferred,fn) end
local function flush()
 local pending=deferred;deferred={}
 for _,fn in ipairs(pending) do fn() end
end
Players.LocalPlayer=a
a:LoadCharacterAsync()
a.Character.ChildAdded=event();a.Character.ChildRemoved=event()
a.Character:SetAttribute("HandsItem","GunA")
local held=make("Model","HeldItem",a.Character,{Item_ID="GunA"});held.CFrame=CFrame.new();held.Size=Vector3.new(3,1,1)
'''
cases='''
local panel=layout.Bar:GetChildren()[1]
local viewport=panel:FindFirstChildWhichIsA("ViewportFrame")
local world=viewport:FindFirstChildWhichIsA("WorldModel")
local function copy() return world:GetChildren()[1] end
flush();assert(copy() and #copy():GetDescendants()==0,"empty initial replica does not crash bounding box/camera setup")
local barrel=make("Part","Barrel",held);barrel.LocalTransparencyModifier=1;barrel.Transparency=.2
held.DescendantAdded:Fire(barrel)
local stock=make("Part","Stock",held);stock.LocalTransparencyModifier=.7
held.DescendantAdded:Fire(stock)
assert(#deferred==1,"one rebuild for the entire replication burst")
flush()
assert(copy():FindFirstChild("Barrel") and copy():FindFirstChild("Stock"),"late geometry replaces incomplete preview")
assert(copy().Barrel.LocalTransparencyModifier==0 and copy().Stock.LocalTransparencyModifier==0)
assert(copy().Barrel.Transparency==.2 and barrel.LocalTransparencyModifier==1,"preview restores local visibility without modifying authored transparency or live weapon")
held.DescendantRemoving:Fire(stock);stock.Parent=nil;flush()
assert(not copy():FindFirstChild("Stock"),"removed geometry is not left in preview")
local old=held
local newer=make("Model","HeldItem",nil,{Item_ID="GunB"});newer.CFrame=CFrame.new();newer.Size=Vector3.new(2,1,1)
make("Part","NewBarrel",newer)
-- An already queued callback must render the current weapon after a switch.
old.DescendantAdded:Fire(barrel);old.Parent=nil;newer.Parent=a.Character
a.Character:SetAttribute("HandsItem","GunB");a.Character.ChildAdded:Fire(newer)
flush();assert(copy():FindFirstChild("NewBarrel") and not copy():FindFirstChild("Barrel"))
local before=cloneCalls
old.DescendantAdded:Fire(barrel);flush();assert(cloneCalls==before,"old weapon listeners are disconnected")
newer.DescendantAdded:Fire(newer.NewBarrel)
a.Character:SetAttribute("HandsItem","");flush();assert(#world:GetChildren()==0,"pending rebuild cannot resurrect holstered preview")
a:LoadCharacterAsync();a.Character.ChildAdded=event();a.Character.ChildRemoved=event();a.CharacterAdded:Fire(a.Character)
flush();assert(#world:GetChildren()==0,"respawn clears preview and old held listeners")
print("PASS: empty replica, burst-coalesced late parts, removal, local transparency, fast switch, listener cleanup, holster and respawn")
'''
parts=[(root/'tests/fixtures/town_mock.luau').read_text(),(root/'tests/city_geometry.fixture.luau').read_text(),setup,source,cases]
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'preview.luau';p.write_text('\n'.join(parts));subprocess.run([sys.argv[1],str(p)],check=True)
