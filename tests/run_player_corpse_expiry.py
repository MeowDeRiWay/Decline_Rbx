"""Actual chest authority: deferred player corpse cleanup, loot and viewer lifecycle."""
from pathlib import Path
import re,subprocess,sys,tempfile
root=Path(__file__).resolve().parents[1]
s=(root/'src/server/Services/ChestService.luau').read_text()
s=re.sub(r'local (Inventory|Rules|Items|Interaction) = require[^\n]+\n','',s)
setup='''
local baseNew=Instance.new
function Instance.new(kind)
 local o=baseNew(kind)
 if kind=="BindableEvent" then o.Event=event();o.Fire=function(self,...) self.Event:Fire(...) end end
 return o
end
local deferred={}
function task.defer(fn) table.insert(deferred,fn) end
local function flush() local current=deferred;deferred={};for _,fn in ipairs(current) do task.spawn(fn) end end
local function advance(seconds)
 clock+=seconds
 for _,co in ipairs(loops) do
  if coroutine.status(co)~="dead" then local ok,err=coroutine.resume(co);assert(ok,err) end
 end
end
local Inventory={}
'''
cases='''
a:LoadCharacterAsync()
local function corpse(loot)
 local model=make("Model","Body");make("Part","Part",model)
 local storage=Rules.New();if loot then Rules.Add(storage,Items.Items,"TreeLog",1) end
 Service.CreatePlayerCorpse(model,storage)
 model.Parent=workspace
 flush()
 return model,storage
end
local loaded,storage=corpse(true)
assert(Service.Open(a,loaded))
advance(1199);assert(not loaded.destroyed,"loot persists until20minutes")
Service.CreatePlayerCorpse(loaded,storage);flush()
advance(1);assert(loaded.destroyed and not Service.Snapshot(a).ChestOpen,"hard cap closes viewers and cannot be reset by duplicate registration")
local empty=corpse(false)
advance(59);assert(not empty.destroyed)
advance(1);assert(empty.destroyed,"initially empty corpse expires at1minute")
local looted,items=corpse(true)
advance(100);items.Items={};advance(0)
advance(59);assert(not looted.destroyed,"empty minute starts after looting")
advance(1);assert(looted.destroyed)
local old,oldItems=corpse(true)
advance(1190);oldItems.Items={};advance(0)
advance(10);assert(old.destroyed,"becoming empty cannot extend20minute total cap")
local zombie=make("Model","Zombie",workspace);make("Part","Part",zombie)
Service.CreateCorpse(zombie,{TreeLog=1});advance(119);assert(not zombie.destroyed);advance(1);assert(zombie.destroyed,"zombie corpse lifetime unchanged")
print("PASS: actual player corpses20min hard cap/60s empty grace, deferred parenting, duplicate registration, viewer cleanup and unchanged zombie120s lifetime")
'''
parts=[(root/'tests/fixtures/town_mock.luau').read_text(),setup]
for name,file in [('Rules','InventoryRules'),('Items','ItemConfig')]:parts.append('local '+name+'=(function()\n'+(root/f'src/shared/{file}.luau').read_text()+'\nend)()')
parts.extend(['local Service=(function()\n'+s+'\nend)()',cases])
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'test.luau';p.write_text('\n'.join(parts));subprocess.run([sys.argv[1],str(p)],check=True)
