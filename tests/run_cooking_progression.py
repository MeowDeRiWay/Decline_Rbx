"""Exercise the real crafting service's profession checks, completion XP and luck hook."""
from pathlib import Path
import re
import subprocess
import sys
import tempfile
root=Path(__file__).resolve().parents[1]
service=(root/'src/server/Services/CraftingService.luau').read_text()
for variable in ['Inventory','Items','Recipes','Rules','Amounts','Interaction','Progression','ProgressionRules']:
 service=re.sub(rf'local {variable}=require\([^\n]+\)\n','',service)
setup='''
local baseNew=Instance.new
function Instance.new(class)
 local object=baseNew(class)
 if class=="BindableEvent" then object.Event=event(); object.Fire=function(self,...) self.Event:Fire(...) end end
 return object
end

local callbacks,durations={},{}
function task.delay(duration,fn) table.insert(callbacks,fn); table.insert(durations,duration) end
local cookState={Profession="Cook",Talents={}}
local allowed=false
local xp,bonuses=0,0
local Progression={CraftEffects=function(_,station,count) return ProgressionRules.CraftEffects(cookState,station,count) end,CanStation=function(_,name) return name=="Workstation" or allowed end,
 CraftXP=function(_,name) if name=="Stove" or name=="CuttingBoard" then xp+=10 end end,
 Loot=function(_,items) bonuses+=1; return items end}
local stock={Potato=10,CleanWater=10,TreeLog=5}
function Inventory.Snapshot() return {Items=table.clone(stock),CraftTools={Knife=1}} end
function Inventory.ConsumeIngredients(_,recipe,count)
 for id,n in pairs(recipe.Ingredients) do if (stock[id] or 0)<n*count then return false end end
 for id,n in pairs(recipe.Ingredients) do stock[id]-=n*count end
 return true
end
function Inventory.Add(_,id,n) stock[id]=(stock[id] or 0)+n; return true end
'''
cases='''
a:LoadCharacterAsync()
local stove=make("Model","Stove",workspace); make("Part","Part",stove)
local bench=make("Model","Workstation",workspace); make("Part","Part",bench)
assert(not Service.Open(a,stove),"no Cook means no cooking station access")
assert(Service.Open(a,bench))
assert(Service.Cook(a,"MakePlanks",1))
Service.Close(a)
callbacks[1]()
assert(stock.TreeLog==5 and xp==0 and bonuses==0,"cancelled crafting refunds ingredients and grants no XP/bonus")
allowed=true
assert(Service.Open(a,stove))
assert(not Service.Cook(a,"BoilPotatoes",6))
assert(Service.Cook(a,"BoilPotatoes",5))
assert(not Service.Cook(a,"BoilPotatoes",1),"station remains single-job")
callbacks[2]()
assert(Service.Snapshot(a).CookingReady.BoiledPotato==5 and stock.Potato==5 and stock.CleanWater==5)
assert(xp==10 and bonuses==1,"one specialty XP award and loot roll at successful completion")
cookState.Talents={SurpriseServing=true,GrandmasMethod=true,RamsayMethod=true}
assert(Service.Cook(a,"BoilPotatoes",5))
assert(durations[3]==60,"retired talent cannot speed stove")
callbacks[3]()
assert(Service.Snapshot(a).CookingReady.BoiledPotato==10,"second full batch adds five")
stock.Potato=1; stock.CleanWater=1
assert(Service.Cook(a,"BoilPotatoes",1)); callbacks[4]()
assert(Service.Snapshot(a).CookingReady.BoiledPotato==11,"partial batch has no extra serving")
local board=make("Model","CuttingBoard",workspace); make("Part","Part",board)
stock.Sausage=1
assert(Service.Open(a,board) and Service.Cook(a,"SliceSausage",1))
assert(durations[5]==10,"retired talent cannot speed cutting board")
callbacks[5]()
assert(Service.Snapshot(a).CookingReady.SausageSlice==5,"stove serving talent must not affect board")
assert(xp==40 and bonuses==4)
cookState.Profession="Worker"; cookState.Talents={GoldenHands=10}
assert(Service.Open(a,bench) and Service.Cook(a,"MakePlanks",1))
assert(math.abs(durations[6]-6)<1e-6,"rank ten Golden Hands saves forty percent crafting time")
callbacks[6]()
assert(Service.Snapshot(a).CookingReady.Plank==3)
print("PASS: cook talents, correct station timing, full/partial batches, profession-gated cooking, general workstation, cancellation refunds, no cancellation rewards, batch five and specialty XP")
'''
parts=[(root/'tests/fixtures/town_mock.luau').read_text(),'local ProgressionRules=(function()\n'+(root/'src/shared/ProgressionRules.luau').read_text()+'\nend)()',setup]
for variable,file in [('Items','ItemConfig'),('Recipes','CraftConfig'),('Rules','CraftRules'),('Amounts','InventoryRules')]:
 parts.append(f'local {variable}=(function()\n'+(root/f'src/shared/{file}.luau').read_text()+'\nend)()')
parts.extend(['local Service=(function()\n'+service+'\nend)()',cases])
with tempfile.TemporaryDirectory(prefix='decline-cooking-') as directory:
 path=Path(directory)/'test.luau';path.write_text('\n'.join(parts))
 subprocess.run([sys.argv[1] if len(sys.argv)>1 else 'luau',str(path)],check=True)
