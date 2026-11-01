"""Actual crafting + chest services: pooled reservation, sequential completion and refunds."""
from pathlib import Path
import re,subprocess,sys,tempfile
root=Path(__file__).resolve().parents[1]
def module(path):return '(function()\n'+(root/path).read_text()+'\nend)()'
source=(root/'tests/fixtures/town_mock.luau').read_text()
source+='\nlocal Items='+module('src/shared/ItemConfig.luau')
source+='\nlocal Amounts='+module('src/shared/InventoryRules.luau')
source+='\nlocal Recipes='+module('src/shared/CraftConfig.luau')
source+='\nlocal Rules='+module('src/shared/CraftRules.luau')
source+='\nlocal Stations='+module('src/shared/CraftStations.luau')
source+='\nlocal ProgressionRules='+module('src/shared/ProgressionRules.luau')
source+='\nlocal Supply=(function()\n'+(root/'src/shared/CraftSupply.luau').read_text().replace('local Inventory=require(script.Parent.InventoryRules)','local Inventory=Amounts')+'\nend)()'
source+='''
local callbacks,durations={},{}
function task.delay(duration,fn) table.insert(callbacks,fn);table.insert(durations,duration) end
workspace.DescendantAdded=event()
local oldNew=Instance.new
function Instance.new(kind)
 local o=oldNew(kind)
 if kind=="BindableEvent" then o.Event=event();o.Fire=function(self,...) self.Event:Fire(...) end end
 return o
end
for _,p in ipairs({a,b}) do p:LoadCharacterAsync();p.Character.HumanoidRootPart.Anchored=false end
local own={[a]=Amounts.New(),[b]=Amounts.New()}
local Inventory={Export=function(p) return own[p] end,Refresh=function() end}
function Inventory.Add(p,id,count,conditions,data) return Amounts.Add(own[p],Items.Items,id,count,conditions,data) end
local xp={[a]=0,[b]=0}
local Progression={CanStation=function() return true end,Meets=function() return true end,
 CraftEffects=function() return {DurationMultiplier=1} end,Loot=function(_,out) return out end,
 CraftXP=function(p,recipe,count) xp[p]+=ProgressionRules.CraftExperience(recipe,count) end}
local Interaction={NearestPoint=function(object) return object:GetPivot().Position end}
local Animation={EndLoot=function() end}
local Journal={Send=function() end}
local WorldActivity={IsDormant=function() return false end}
local blocked=false
local wall=make("Part","Wall",workspace)
function workspace:Raycast() return blocked and {Instance=wall} or nil end
local function model(name,x,attrs)
 local m=make("Model",name,workspace,attrs);m:PivotTo(CFrame.new(Vector3.new(x or 0,0,0)))
 make("Part","Surface",m);workspace.DescendantAdded:Fire(m);return m
end
'''
chests=(root/'src/server/Services/ChestService.luau').read_text()
chests=re.sub(r'local (Inventory|Rules|Items|Interaction|Animation)\s*=\s*require[^\n]+\n','',chests).replace('Rules.','Amounts.')
source+='\nlocal Chests=(function()\n'+chests+'\nend)()'
craft=(root/'src/server/Services/CraftingService.luau').read_text()
craft=re.sub(r'local (Inventory|Items|Recipes|Rules|Amounts|Interaction|Progression|ProgressionRules|Stations|Supply|Chests|Journal|WorldActivity)\s*=\s*require[^\n]+\n','',craft)
source+='\nlocal Service=(function()\n'+craft+'\nend)()'
source+='''
local bench=model("Bench",0,{Workstation=true})
local chest=model("Chest",4)
local distant=model("Chest",5.01)
local corpse=model("Chest",1,{IsCorpse=true})
local knocked=model("Chest",1,{Knockout=true})
local sources=Chests.CraftSources(a,bench)
assert(#sources==1 and sources[1].Chest==chest,"ordinary chest within5, not far chests or bodies")
local storage=sources[1].State
Amounts.Add(storage,Items.Items,"TreeLog",2);Amounts.Add(own[a],Items.Items,"TreeLog",1)
assert(Service.Open(a,bench))
local snap=Service.Snapshot(a)
assert(snap.CookingItems.TreeLog==3 and snap.CookingNearbyChests==1)
assert(not Service.Cook(a,"MakePlanks",{Batch=1,Repeats=4}) and storage.Items.TreeLog==2 and own[a].Items.TreeLog==1,"reject unaffordable whole queue atomically")
assert(not Service.Cook(a,"MakePlanks",{Batch=1,Repeats=0/0}))
assert(not Service.Cook(a,"MakePlanks",{Batch=1,Repeats=1001}))
assert(Service.Cook(a,"MakePlanks",{Batch=1,Repeats=3}))
assert(not storage.Items.TreeLog and not own[a].Items.TreeLog and a.Character.HumanoidRootPart.Anchored,"reserve once across pockets + chest")
snap=Service.Snapshot(a)
assert(snap.CookingQueueTotal==3 and snap.CookingCompleted==0 and snap.CookingEndsAt==clock+30 and #callbacks==1)
local first=callbacks[1];first()
assert(own[a].Items.Plank==3 and xp[a]==75 and #callbacks==2,"first cycle auto delivers before queue finishes")
first();assert(own[a].Items.Plank==3 and #callbacks==2,"duplicate callback cannot duplicate results")
assert(Service.Open(b,bench) and not Service.Cancel(b),"another viewer cannot cancel owned queue")
assert(not Service.Cook(b,"MakePlanks",{Batch=1,Repeats=1}),"one station cannot double-spend reserved stock")
assert(Service.Cancel(a) and storage.Items.TreeLog==2 and not own[a].Items.TreeLog,"refund only unfinished inputs to exact origins")
assert(not a.Character.HumanoidRootPart.Anchored and not a.Character:GetAttribute("CraftingLocked"))
callbacks[2]();assert(own[a].Items.Plank==3 and xp[a]==75,"cancelled timer grants nothing")
-- Auto-reserve all repeats and finish progressively.
assert(Service.Cook(b,"MakePlanks",{Batch=1,Repeats="All"}))
local nextCallback=#callbacks;callbacks[nextCallback]();callbacks[#callbacks]()
assert(own[b].Items.Plank==6 and xp[b]==150 and not Service.Snapshot(b).CookingRecipe and not b.Character.HumanoidRootPart.Anchored)
-- Nearby supplies are visible without opening/holding a tool.
Amounts.Add(storage,Items.Items,"Rags",4);Amounts.Add(storage,Items.Items,"SewingKit",1)
local med=model("Med",0,{MedStation=true})
assert(Service.Open(a,med) and Service.Snapshot(a).CookingTools.SewingKit==1)
assert(Service.Cook(a,"MakeBandage",{Batch=1,Repeats=2}) and storage.Items.SewingKit==1 and not storage.Items.Rags)
local stale=callbacks[#callbacks]
storage.Items.SewingKit=nil;Service.ValidateSessions()
assert(storage.Items.Rags==4 and not Service.Snapshot(a).CookingRecipe,"removing reusable tool cancels and refunds")
stale();assert(not own[a].Items.Bandage and xp[a]==75)
Amounts.Add(storage,Items.Items,"SewingKit",1)
assert(Service.Cook(a,"MakeBandage",{Batch=1,Repeats=2}))
callbacks[#callbacks]();assert(own[a].Items.Bandage==1 and storage.Items.SewingKit==1)
callbacks[#callbacks]();assert(own[a].Items.Bandage==2 and storage.Items.SewingKit==1,"reusable chest kit is not consumed")
-- A completed product becomes stock immediately; failed/removed structures refund.
assert(Service.Open(a,bench));Amounts.Add(storage,Items.Items,"TreeLog",2)
assert(Service.Cook(a,"MakePlanks",{Batch=1,Repeats=2}))
chest:Destroy();assert(Service.Cancel(a) and own[a].Items.TreeLog==2,"destroyed source refunds to creator's pockets")
assert(Service.Cook(a,"MakePlanks",{Batch=1,Repeats=2}))
bench:Destroy();Service.ValidateSessions()
assert(own[a].Items.TreeLog==2 and not a.Character.HumanoidRootPart.Anchored,"destroyed station refunds and releases crafter")
-- Stove processes once, waits for manual pickup and forbids queued repeats.
local stove=model("Stove",0)
Amounts.Add(own[a],Items.Items,"Potato",5);Amounts.Add(own[a],Items.Items,"CleanWater",1)
assert(Service.Open(a,stove))
assert(not Service.Cook(a,"BoilPotatoes",{Batch=1,Repeats=2}))
assert(Service.Cook(a,"BoilPotatoes",1))
assert(own[a].Items.TreeLog==1 and not own[a].Items.Potato and not own[a].Items.CleanWater)
Service.Close(a);callbacks[#callbacks]()
assert(not own[a].Items.BoiledPotato and not own[b].Items.BoiledPotato)
assert(Service.Open(a,stove) and Service.Snapshot(a).CookingReady.BoiledPotato==5)
assert(Service.CollectAll(a) and own[a].Items.BoiledPotato==5 and own[a].Items.Coal==1)
-- Shared storage refresh is changed-only, not every half second while typing.
assert(Service.Open(a,stove));Service.Snapshot(a)
local updates=0;Service.Changed:Connect(function(p) if p==a then updates+=1 end end)
Service.ValidateSessions();assert(updates==0)
Amounts.Add(own[a],Items.Items,"Potato",5);Service.ValidateSessions();assert(updates==1)
Service.Snapshot(a);Service.ValidateSessions();assert(updates==1)
-- Disconnect also cancels an unattended queue before inventory is detached.
Amounts.Add(own[a],Items.Items,"CleanWater",1);Amounts.Add(own[a],Items.Items,"TreeLog",1)
assert(Service.Cook(a,"BoilPotatoes",{Batch=1,Repeats=1}));local offline=callbacks[#callbacks]
Players.PlayerRemoving:Fire(a)
assert(own[a].Items.Potato==5 and own[a].Items.CleanWater==1 and own[a].Items.TreeLog==2)
offline();assert(own[a].Items.BoiledPotato==5,"offline stale callback cannot grant into a new session")
-- Wall-blocked and out-of-radius chest supplies are never included.
local far=model("Chest",5);assert(#Chests.CraftSources(b,stove)==1,"exact radius5 included")
blocked=true;assert(#Chests.CraftSources(b,stove)==0,"wall blocks material access")
blocked=false;far:PivotTo(CFrame.new(Vector3.new(5.001,0,0)));assert(#Chests.CraftSources(b,stove)==0)
-- Rejected transactions restore unique metadata, not just weapon counts.
local original=Amounts.New();Amounts.Add(original,Items.Items,"IronKnife",1,{321},{{UID=909,Loaded=0,Type="FMJ"}})
local cycles={{Ingredients={IronKnife=1}},{Ingredients={TreeLog=1}}}
assert(not Supply.Reserve(cycles,{{State=original}},Items.Items))
assert(original.Items.IronKnife==1 and original.Conditions.IronKnife[1]==321 and original.Weapons.IronKnife[1].UID==909)
print("PASS: sequential queues, bounded requests, atomic pooled chest reservation, per-cycle auto delivery/XP/fuel, shared stock, reused tools, exact refunds, station/source destruction, disconnect and stale timers")
'''
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'queue.luau';p.write_text(source);subprocess.run([sys.argv[1],str(p)],check=True)
