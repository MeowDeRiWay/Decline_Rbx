"""Execute actual recipe UI callbacks: structured queue requests and pooled stock/tools."""
from pathlib import Path
import subprocess,sys,tempfile
root=Path(__file__).resolve().parents[1]
def module(path):return '(function()\n'+(root/path).read_text()+'\nend)()'
s=''
for name,path in [('Recipes','CraftConfig'),('ItemConfig','ItemConfig'),('CraftRules','CraftRules'),('Stations','CraftStations'),('Categories','CraftCategories')]:s+='\nlocal '+name+'='+module('src/shared/'+path+'.luau')
s+='''
local function signal()
 local e={handlers={}}
 function e:Connect(fn) table.insert(self.handlers,fn) end
 function e:Fire(...) for _,fn in ipairs(self.handlers) do fn(...) end end
 return e
end
local objects={};local methods={}
local mt={__index=methods,__newindex=function(o,k,v) rawset(o,k,v);if k=="Parent" and v then table.insert(v.Children,o) end end}
local Instance={new=function(kind)
 local o=setmetatable({Kind=kind,Children={},Activated=signal(),FocusLost=signal()},mt);table.insert(objects,o);return o
end}
function methods:GetChildren() return self.Children end
function methods:IsA(kind) return self.Kind==kind end
local UDim2={new=function(xs,xo,ys,yo) return {X={Scale=xs,Offset=xo},Y={Scale=ys,Offset=yo}} end}
function UDim2.fromOffset(x,y) return UDim2.new(0,x,0,y) end
local function text(parent,value,pos,size) local o=Instance.new("TextLabel");o.Text=value;o.Position=pos;o.Size=size;o.Parent=parent;return o end
local function button(parent,value,pos,size) local o=Instance.new("TextButton");o.Text=value;o.Position=pos;o.Size=size;o.Parent=parent;return o end
local Theme={Accent=1,Muted=2,Card=3,Button=4,Background=5,Text=6,Font=7}
local selectedRecipe="MakePlanks"
local craftCategory="All"
local craftAmounts,craftRepeats,craftStatuses={},{},{}
local stoveFuelTab="Wood"
local player={UserId=99,GetAttribute=function(_,id) return id=="CraftCostMultiplier" and 1 or 300 end}
local snapshot={CookingStation="Workstation",CookingItems={TreeLog=3},Items={},CookingTools={},CraftTools={},CookingNearbyChests=1,CookingMaxQueue=1000}
local sent={}
local action={FireServer=function(_,...) table.insert(sent,{...}) end}
local equipment=Instance.new("Frame")
local function redraw() end
'''
code=(root/'src/client/Inventory.client.luau').read_text();s+=code[code.index('local function renderRecipes()'):code.index('local function foodDetails')]
s+='''
local function find(label)
 for _,o in ipairs(objects) do if o.Text==label then return o end end
end
local function input(y)
 for _,o in ipairs(objects) do if o.Kind=="TextBox" and o.Position.Y.Offset==y then return o end end
end
local function render() objects={};equipment=Instance.new("Frame");renderRecipes() end
render()
local start=find("Start queue");assert(start and start.Active,"merged chest stock enables recipe")
local repeats=input(254);repeats.Text="2";repeats.FocusLost:Fire()
assert(start.Active and find("2 processes · 20 seconds total\\nNearby chests: 1 · Results go to pockets"))
start.Activated:Fire()
assert(#sent==1 and sent[1][1]=="Cook" and sent[1][2]=="MakePlanks" and sent[1][3].Batch==1 and sent[1][3].Repeats==2)
find("Queue all").Activated:Fire();assert(sent[2][3].Repeats=="All")
repeats.Text="4";repeats.FocusLost:Fire();assert(not start.Active,"unaffordable repetitions disabled")
start.Activated:Fire();assert(#sent==2)
assert(not find("Collect") and not find("Collect all"),"no manual collection step")
snapshot.CookingEndsAt=100;snapshot.CookingOwner=99;render()
assert(find("Cancel queue"));find("Cancel queue").Activated:Fire();assert(sent[3][1]=="CancelCraft")
snapshot.CookingOwner=100;render();assert(not find("Cancel queue"),"only queue owner sees cancel")
snapshot.CookingEndsAt=0;snapshot.CookingStation="MedStation";snapshot.CookingItems={Rags=10};snapshot.CookingTools={SewingKit=1}
selectedRecipe="MakeBandage";render();assert(find("Start queue").Active,"chest sewing kit enables recipe without carrying it")
snapshot.CookingTools={};render();assert(not find("Start queue").Active,"missing tool disables queue")
snapshot.CookingStation="Stove";snapshot.CookingItems={Potato=5,CleanWater=1,TreeLog=1};snapshot.CookingTools={};snapshot.CookingReady={}
selectedRecipe="BoilPotatoes";render()
assert(not find("Start queue") and not find("Queue all") and not input(254),"no quantity or repeat fields on stove")
assert(find("Craft batch").Active);find("Craft batch").Activated:Fire()
assert(sent[#sent][3].Batch==1 and sent[#sent][3].Repeats==1)
snapshot.CookingReady={BoiledPotato=5,Coal=1};render()
assert(not find("Craft batch").Active and find("Collect all"),"finished products block restart and expose one collection action")
find("Collect all").Activated:Fire();assert(sent[#sent][1]=="CollectCrafted")
print("PASS: actual queue UI uses chest materials/tools, repeat count and total time, bounded affordability, structured repeat/all requests, automatic results and owner-only cancellation")
'''
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'ui.luau';p.write_text(s);subprocess.run([sys.argv[1],str(p)],check=True)
