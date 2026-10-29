"""Exercise actual door service permissions, passage approval and part restoration without Studio."""
from pathlib import Path
import subprocess,sys,tempfile
root=Path(__file__).resolve().parents[1]
rules=(root/'src/shared/TownRules.luau').read_text()
access=(root/'src/shared/DoorRules.luau').read_text()
service=(root/'src/server/Services/TownDoors.luau').read_text().replace('local WorldActivity=require(script.Parent.WorldActivityService)', 'local WorldActivity={Register=function() end,IsDormant=function() return false end,Ensure=function() end,DormantNPCs=function() return {} end,Raycast=function() return nil end}')
service=service.replace('local Animation=require(script.Parent.InteractionAnimationService)', 'local Animation={Reach=function(_,_,_,fn) fn();return true end}')
for key in ['Rules','Access','Interaction','Config']:
 import re
 service=re.sub(r'local '+key+r' = require\([^\n]+\)', 'local '+key+' = TEST_'+key, service)
mock='''
local TEST_Rules=(function() RULES end)()
local TEST_Access=(function() ACCESS end)()
local TEST_Config={InteractionDistance=1}
local TEST_Interaction={Distance=function() return 0 end,NearestPoint=function(_,p) return p end}
local baseTypeof=typeof
typeof=function(value) if type(value)=="table" and value.ClassName then return "Instance" end;return baseTypeof(value) end
local events={}
local function signal() return {Connect=function(self,fn) self.callback=fn end} end
local function object(class,name)
 local o={ClassName=class,Name=name,attributes={},children={}}
 function o:IsA(c) return c==self.ClassName end
 function o:GetAttribute(k) return self.attributes[k] end
 function o:SetAttribute(k,v) self.attributes[k]=v end
 function o:GetDescendants() return self.children end
 function o:FindFirstChild(name) for _,c in ipairs(self.children) do if c.Name==name then return c end end end
 function o:IsDescendantOf(parent) local p=self.Parent while p do if p==parent then return true end;p=p.Parent end;return false end
 return o
end
workspace=object("Workspace","Workspace");workspace.DescendantAdded=signal()
local time=100
local os={clock=function() return time end}
function workspace:GetServerTimeNow() return time end
function workspace:Raycast() return nil end
local storage=object("ServerStorage","ServerStorage")
local replicated=object("ReplicatedStorage","ReplicatedStorage")
local players={PlayerRemoving=signal()}
game={GetService=function(_,name) return ({ServerStorage=storage,ReplicatedStorage=replicated,Players=players})[name] end}
Instance={new=function(class) local o=object(class,"");if class=="RemoteEvent" then o.OnServerEvent=signal();events[#events+1]=o end;return o end}
Enum={RaycastFilterType={Exclude=1}}
RaycastParams={new=function() return {} end}
local ticker
task={spawn=function(fn) ticker=coroutine.create(fn);assert(coroutine.resume(ticker)) end,wait=function() coroutine.yield() end,defer=function(fn) fn() end}
local flag=object("Model","Flag");flag.Parent=workspace;flag:SetAttribute("TownID",1);flag:SetAttribute("LeaderID",10)
local gate=object("Model","GateDoor");gate.Parent=workspace;gate:SetAttribute("TownID",1);gate:SetAttribute("TownGate",true);gate:SetAttribute("Door",true)
local part=object("BasePart","Part");part.Parent=gate;part.Transparency=.25;part.CanCollide=true;part.CanQuery=true;part.CanTouch=false;part:SetAttribute("BlocksVision",true);gate.children={part}
workspace.children={flag,gate,part}
local player=object("Player","Guest");player.UserId=20;player:SetAttribute("AttributesConfirmed",true)
local position=setmetatable({}, {__sub=function(a,b) return a end})
local character=object("Model","Character");character.children={{Name="HumanoidRootPart",Position=position}}
function character:FindFirstChildOfClass() return {Health=100} end
player.Character=character
'''.replace('RULES',rules).replace('ACCESS',access)
cases='''
local requests=0
Service.Start(function(p,d,id) assert(p==player and d==gate and id==1);requests+=1 end,function() end)
local fire=events[1].OnServerEvent.callback
fire(player,gate);assert(requests==1 and not gate:GetAttribute("DoorOpen"),"guest requests rather than opens")
assert(Service.Admit(player,gate,2)==false,"cannot approve a different town")
assert(Service.Admit(player,gate,1)==true and gate:GetAttribute("DoorOpen"))
assert(part.Transparency==1 and not part.CanCollide and not part.CanQuery and not part:GetAttribute("BlocksVision"))
time=119;assert(coroutine.resume(ticker));assert(gate:GetAttribute("DoorOpen"),"still open before deadline")
time=120;assert(coroutine.resume(ticker));assert(not gate:GetAttribute("DoorOpen") and part.CanCollide,"auto closes after exactly 20 seconds")
assert(Service.Admit(player,gate,1));player:SetAttribute("TownID",1);time+=1
fire(player,gate)
assert(gate:GetAttribute("DoorOpen"),"authorized activation opens door")
time+=4;assert(coroutine.resume(ticker));assert(gate:GetAttribute("DoorOpen"))
time+=1;assert(coroutine.resume(ticker))
assert(not gate:GetAttribute("DoorOpen") and part.Transparency==.25 and part.CanCollide and part.CanQuery and not part.CanTouch and part:GetAttribute("BlocksVision"),"authorized opening auto closes and restores authored properties")
gate:SetAttribute("TownGate",false);gate:SetAttribute("OwnerID",30)
assert(not Service.Allowed(player,gate),"town membership alone cannot open private buildings")
gate:SetAttribute("Co-OwnerID","20");assert(Service.Allowed(player,gate))
gate:SetAttribute("Co-OwnerID","");player.UserId=10;assert(Service.Allowed(player,gate),"mayor access")
player.UserId=30;assert(Service.Allowed(player,gate),"owner access")
player:SetAttribute("TownID",2);assert(not Service.Allowed(player,gate),"other faction rejected")
assert(Service.MaximumWallLevel(1)==0,"no built walls gives zero tax cap")
local builtWall=object("Model","WallModelT1 (wood)");builtWall.Parent=workspace;builtWall:SetAttribute("TownID",1);builtWall:SetAttribute("WallLevel",1)
workspace.DescendantAdded.callback(builtWall)
assert(Service.MaximumWallLevel(1)==1,"T1 wall allows one-dollar cap")
builtWall:SetAttribute("WallLevel",2);time+=1.1
assert(Service.MaximumWallLevel(1)==2,"higher wall level updates cached cap")
assert(Service.MaximumWallLevel(2)==0,"other town walls cannot raise cap")
builtWall.Parent=nil;time+=1.1;assert(Service.MaximumWallLevel(1)==0,"removing wall lowers cap")
print("PASS: guest requests, exact gate/town approval, hidden collision/query/vision, property restoration, owner/co-owner/mayor and faction access")
'''
with tempfile.TemporaryDirectory() as directory:
 p=Path(directory)/'doors.luau';p.write_text(mock+'\nlocal Service=(function()\n'+service+'\nend)()\n'+cases)
 subprocess.run([sys.argv[1] if len(sys.argv)>1 else 'luau',str(p)],check=True)
