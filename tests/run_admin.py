"""Exercise the actual admin remote: authorization, validation and target isolation."""
from pathlib import Path
import re, subprocess, sys, tempfile
root=Path(__file__).resolve().parents[1]
authority=(root/'src/server/Admin.server.luau').read_text()
authority=re.sub(r'local (Rules|Clock|Progression|Inventory|Life|Items|Journal)=require[^\n]+\n','',authority)
authority=authority.replace('local Services=script.Parent.Services\n','')
setup='''
local Rules=(function()\nADMIN_RULES\nend)()
local InventoryRules=(function()\nINVENTORY_RULES\nend)()
local Items=(function()\nITEMS\nend)().Items
local clockCalls=0
local Clock={Start=function() end,SetHour=function(v) clockCalls+=1;workspace:SetAttribute("DayClockHour",v) end,SetSpeed=function(v) clockCalls+=1 end,SetPaused=function(v) clockCalls+=1 end}
local grants=0
local Progression={GrantLevels=function(p,count) grants+=count;return p:GetAttribute("AttributesConfirmed")==true,count end,ResetProgression=function(p) p:SetAttribute("CharacterLevel",1);return true end}
local inventory={}
local Inventory={Add=function(p,id,count) inventory[p]=inventory[p] or InventoryRules.New();return InventoryRules.Add(inventory[p],Items,id,count) end}
local notices={}
local Journal={Send=function(p,text) table.insert(notices,{p,text}) end}
local revivals=0
local Life={Revive=function(p,seconds)
 assert(p:GetAttribute("ReviveLockedUntil")==0 and seconds==0)
 revivals+=1;p.Character:SetAttribute("Knockout",false);return true
end}
local admin=player(8335513512);admin:LoadCharacterAsync()
local second=player(4455566626);second:LoadCharacterAsync()
b:LoadCharacterAsync()
'''
cases='''
local remote=ReplicatedStorage.AdminAction
local function call(p,command,data) clock+=.3;return remote.OnServerInvoke(p,command,data) end
assert(admin:GetAttribute("AdminAccess") and second:GetAttribute("AdminAccess") and not a:GetAttribute("AdminAccess"))
a:SetAttribute("AdminAccess",true)
for _,command in ipairs({"SetHour","SetSpeed","Pause","GiveItem","Heal","Levels","ResetProgression","Revive","Needs","Request"}) do
 assert(not call(a,command,{Value=12,ID="TreeLog",Count=5,Target=b.UserId}).OK,"forged client admin flag cannot authorize "..command)
end
assert(clockCalls==0 and grants==0 and inventory[a]==nil)
assert(call(admin,"Request").OK and call(second,"Request").OK)
assert(not call(admin,"SetHour",{Value=0/0}).OK)
assert(not call(admin,"SetHour",{Value=math.huge}).OK)
assert(not call(admin,"SetHour",{Value="12"}).OK)
assert(not call(admin,"Pause",{Value=1}).OK)
assert(not call(admin,"SetSpeed",{Value=-2}).OK)
assert(not call(admin,"SetSpeed",{Value=101}).OK)
assert(call(admin,"SetHour",{Value=23.5}).OK and workspace:GetAttribute("DayClockHour")==23.5)
assert(call(second,"Pause",{Value=true}).OK)
assert(call(admin,"SetSpeed",{Value=2}).OK)
assert(not call(admin,"GiveItem",{ID="missing",Count=1}).OK)
for _,count in ipairs({0,-1,1.5,1001,math.huge,"5"}) do assert(not call(admin,"GiveItem",{ID="TreeLog",Count=count}).OK) end
assert(not call(admin,"GiveItem",{ID="TreeLog",Count=0/0}).OK)
assert(call(admin,"GiveItem",{ID="TreeLog",Count=3,Target=b.UserId}).OK)
assert(inventory[admin].Items.TreeLog==3 and inventory[b]==nil,"items always go to invoking admin")
assert(call(second,"GiveItem",{ID="Bandage",Count=5}).OK and inventory[second].Items.Bandage==5)
assert(not call(admin,"Levels",{Target=9999999,Count=2}).OK)
assert(not call(admin,"Levels",{Target=b.UserId,Count=1.5}).OK)
assert(not call(admin,"Levels",{Target=b.Character,Count=2}).OK)
assert(call(admin,"Levels",{Target=b.UserId,Count=2}).OK and grants==2)
assert(call(admin,"ResetProgression",{Target=b.UserId}).OK and b:GetAttribute("CharacterLevel")==1)
assert(not call(admin,"ResetProgression",{Target=9999999}).OK)
b.Character.Humanoid.Health=4;b.Character:SetAttribute("Sick",80)
assert(call(admin,"Heal",{Target=b.UserId}).OK and b.Character.Humanoid.Health==100 and b.Character:GetAttribute("Sick")==0)
b.Character:SetAttribute("Food",1);b.Character:SetAttribute("Water",2)
assert(call(second,"Needs",{Target=b.UserId}).OK and b.Character:GetAttribute("Food")==100 and b.Character:GetAttribute("Water")==100)
b.Character:SetAttribute("Knockout",true);b.Character.Humanoid.Health=1
assert(not call(admin,"Heal",{Target=b.UserId}).OK)
b:SetAttribute("ReviveLockedUntil",clock+600)
assert(call(admin,"Revive",{Target=b.UserId}).OK and revivals==1 and b.Character.Humanoid.Health==100 and not b.Character:GetAttribute("Knockout"))
b.Character:SetAttribute("IsDead",true)
assert(not call(admin,"Heal",{Target=b.UserId}).OK and not call(admin,"Revive",{Target=b.UserId}).OK)
admin.Character:SetAttribute("Knockout",true)
assert(not call(admin,"GiveItem",{ID="Bandage",Count=1}).OK)
local response=remote.OnServerInvoke(admin,"SetHour",{Value=6})
assert(not response.OK,"rapid requests are limited")
assert(not call(admin,"Unknown",{}).OK and not call(admin,"Heal","bad").OK)
print("PASS: admin identity, forged access flags, both admins, malformed inputs, rate limit, self-only items, online player targets, healing, needs and KO revival")
'''
setup=setup.replace('ADMIN_RULES',(root/'src/server/Services/AdminRules.luau').read_text()).replace('INVENTORY_RULES',(root/'src/shared/InventoryRules.luau').read_text()).replace('ITEMS',(root/'src/shared/ItemConfig.luau').read_text())
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'admin.luau';p.write_text((root/'tests/fixtures/town_mock.luau').read_text()+'\n'+setup+'\n'+authority+'\n'+cases)
 subprocess.run([sys.argv[1],str(p)],check=True)
