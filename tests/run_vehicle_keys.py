"""Run real key lifecycle, inventory metadata and trade rules without Studio."""
from pathlib import Path
import re,subprocess,sys,tempfile
root=Path(__file__).resolve().parents[1]
def module(path,imports=""):
 text=(root/path).read_text()
 text=re.sub(r"^local \w+\s*=\s*require[^\n]*\n","",text,flags=re.MULTILINE)
 return "(function()\n"+imports+"\n"+text+"\nend)()"
code=(root/'tests/rig_math.fixture.luau').read_text()+'\n'+(root/'tests/vehicle_runtime.fixture.luau').read_text()
code+='\nlocal Rules='+module('src/shared/InventoryRules.luau')
code+='\nlocal Exchange='+module('src/shared/ExchangeRules.luau','local Inventory=Rules')
code+=r'''
local guid=0
local Http={GenerateGUID=function() guid+=1;return "vehicle-key-"..guid end}
local oldGet=game.GetService
game.GetService=function(self,name) if name=="HttpService" then return Http end;return oldGet(self,name) end
local definitions={VehicleKey={Unique=true,Weight=.05}}
local states,disconnected,contents={},{},{}
local canGrant=true
local Inventory={Export=function(p) return states[p] end}
function Inventory.Add(player,id,count,conditions,data)
 if not canGrant then return false end
 states[player]=states[player] or Rules.New()
 return Rules.Add(states[player],definitions,id,count,conditions,data)
end
local Chests={}
local WorldItems={}
local encoded={}
function Http:JSONDecode(text) return assert(encoded[text],"invalid serialized metadata") end
local folder=create("Folder",workspace)
'''
# Exercise the production inventory/corpse/world presence readers, not replacements.
for service,file,nextfn in [
 ('Inventory','InventoryService.luau','function Service.Export'),
 ('Chests','ChestService.luau','function Service.CreatePlayerCorpse'),
 ('WorldItems','WorldItemService.luau','function Service.Pickup')]:
 text=(root/'src/server/Services'/file).read_text()
 fn=text[text.index('function Service.HasVehicleKey'):text.index(nextfn,text.index('function Service.HasVehicleKey'))]
 code+='\n'+fn.replace('Service.HasVehicleKey',service+'.HasVehicleKey')+'\n'
# world reader uses HttpService name
code=code.replace('local WorldItems={}','local WorldItems={}\nlocal HttpService=Http')
code+='\nlocal Keys='+module('src/server/Services/VehicleKeyService.luau')
code+=r'''
local a,b={},{}
states[a]=Rules.New();states[b]=Rules.New()
local car=create("Model",workspace);car:SetAttribute("DisplayName","Interceptor")
local record=Keys.Register(car)
assert(car:GetAttribute("PublicAccess") and Keys.Allowed(a,car),"new car awaits its first driver")
canGrant=false;assert(not Keys.Claim(a,car) and car:GetAttribute("PublicAccess"),"failed inventory grant cannot lock car")
canGrant=true;assert(Keys.Claim(a,car))
local token=states[a].Weapons.VehicleKey[1].VehicleKey
assert(Keys.Allowed(a,car) and not Keys.Allowed(b,car),"only exact key holder has access")
assert(Keys.Claim(a,car) and states[a].Items.VehicleKey==1,"repeated seating cannot duplicate key")
local other=create("Model",workspace);Keys.Register(other);assert(Keys.Claim(a,other))
local stacks=Rules.Stacks(states[a],definitions)
assert(#stacks==2 and stacks[1].Key~=stacks[2].Key,"keys for different cars never stack together")
local selected
for _,stack in ipairs(stacks) do if stack.VehicleID==record.ID then selected=stack end end
local left,right=Exchange.Stage(states[a],states[b],definitions,{[selected.Key]={ID="VehicleKey",Key=selected.Key,Count=1}},{})
assert(left and right,"normal player exchange accepts exact unique key")
states[a],states[b]=left,right
assert(Keys.Allowed(b,car) and not Keys.Allowed(a,car),"trade moves access without retaining seller rights")
local storage=Rules.New()
assert(Rules.Transfer(states[b],storage,definitions,"VehicleKey",1,selected.Key))
local corpse=create("Model",workspace);contents[corpse]=storage
Keys.Refresh(car);assert(not car:GetAttribute("PublicAccess") and not Keys.Allowed(b,car),"key in corpse keeps vehicle locked")
-- Drop through the same metadata arrays used by WorldItemService.Drop/Pickup.
local ok,conditions,data=Rules.Remove(storage,"VehicleKey",1,selected.Key)
assert(ok)
local drop=create("Part",folder);drop:SetAttribute("Item_ID","VehicleKey");drop:SetAttribute("WeaponData","drop")
encoded.drop=data
Keys.Refresh(car);assert(not car:GetAttribute("PublicAccess"),"key on ground is not lost")
assert(Rules.Add(states[b],definitions,"VehicleKey",1,conditions,Http:JSONDecode("drop")))
drop:Destroy()
Keys.Refresh(car);assert(Keys.Allowed(b,car),"pickup preserves car identity and access")
-- Offline body inventory remains a live location.
disconnected[42]=states[b];states[b]=Rules.New()
Keys.Refresh(car);assert(not car:GetAttribute("PublicAccess"),"offline inventory retains the key")
contents[corpse]=disconnected[42];disconnected[42]=nil
Keys.Refresh(car);assert(not car:GetAttribute("PublicAccess"),"offline death transfers key into corpse storage")
corpse:Destroy()
Keys.Refresh(car)
assert(car:GetAttribute("PublicAccess") and Keys.Allowed(a,car),"destroyed corpse releases car even if stale table references survive")
local oldToken=token
local staleKey=contents[corpse]
assert(Keys.Claim(a,car) and Keys.Allowed(a,car) and not Keys.Allowed(b,car),"first new driver gets replacement")
assert(record.Token~=oldToken,"lost key is revoked before replacement")
states[b]=staleKey
assert(not Keys.Allowed(b,car),"an old key reappearing later cannot unlock the replacement lock")
local count=states[a].Items.VehicleKey
assert(Keys.Claim(a,car) and states[a].Items.VehicleKey==count,"replacement also remains unique")
assert(not Rules.Add(states[b],definitions,"VehicleKey",1),"generic/admin item grant cannot mint a valid key without metadata")
assert(math.abs(Rules.Weight(states[a],definitions)-count*.05)<.00001,"key weight uses ordinary inventory rules")
Keys.Forget(car);assert(not Keys.Allowed(a,car),"destroyed vehicle revokes access registry")
print("PASS: first driver, failed grant, exact keys, trade, corpse, drop/pickup metadata, offline death, destroyed loot, reissue and duplicate prevention")
'''
with tempfile.TemporaryDirectory() as d:
 path=Path(d)/'keys.luau';path.write_text(code);subprocess.run([sys.argv[1],str(path)],check=True)
