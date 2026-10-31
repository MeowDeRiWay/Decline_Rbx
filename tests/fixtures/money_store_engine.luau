-- Shared persistent fake database survives fresh MoneyStore/Economy module loads.
local MoneyDatabase,MoneyCloseHandlers={},{}
local MoneyFailures,MoneyWrites,MoneyGuid=0,0,0
local MoneyHook
local function moneyCopy(value)
 if type(value)~="table" then return value end
 local result={};for k,v in pairs(value) do result[k]=moneyCopy(v) end;return result
end
local moneyDataStore={}
function moneyDataStore:UpdateAsync(key,transform)
 if MoneyFailures>0 then MoneyFailures-=1;error("temporary storage outage") end
 if MoneyHook then local hook=MoneyHook;MoneyHook=nil;hook() end
 local result=transform(moneyCopy(MoneyDatabase[key]))
 if result==nil then return nil end
 MoneyWrites+=1;MoneyDatabase[key]=moneyCopy(result);return moneyCopy(result)
end
local moneyGetService=game.GetService
function game:GetService(name)
 if name=="DataStoreService" then return {GetDataStore=function(_,storeName) assert(storeName=="DeclineMoney_v1");return moneyDataStore end} end
 if name=="HttpService" then return {GenerateGUID=function() MoneyGuid+=1;return "wallet-test-"..MoneyGuid end} end
 return moneyGetService(self,name)
end
function game:BindToClose(fn) table.insert(MoneyCloseHandlers,fn) end
os.time=function() return math.floor(clock) end
local moneyNewInstance=Instance.new
function Instance.new(kind)
 local instance=moneyNewInstance(kind)
 if kind=="BindableEvent" then instance.Event=event();instance.Fire=function(self,...) self.Event:Fire(...) end end
 return instance
end
