-- Account money, independent of characters. UpdateAsync leases prevent an old
-- server overwriting a newer session. Failed reads are never converted to zeros.
local DataStore=game:GetService("DataStoreService"):GetDataStore("DeclineMoney_v1")
local Http=game:GetService("HttpService")
local R=require(game:GetService("ReplicatedStorage").Shared.EconomyRules)
local Store={}
local records={}
local changed=Instance.new("BindableEvent")
Store.Changed=changed.Event
local closing=false
local LEASE,RENEW,RETRY,WRITE_DELAY=180,60,10,2
local function valid(data)
 return type(data)=="table" and R.Integer(data.Balance,0,R.Maximum)
end
local function publish(record,status)
 record.Status=status;changed:Fire(record.ID)
end
function Store.Peek(id)
 local r=records[id]
 return r and r.Ready and not r.Closing and not r.Closed and r or nil
end
function Store.Cached(id) local r=records[id];return r and r.Balance or 0 end
function Store.Status(id) local r=records[id];return r and r.Status or "Loading" end
function Store.Open(id)
 if closing or not R.Integer(id,1,R.Maximum) then return nil end
 local deadline=os.clock()+15
 local r=records[id]
 while r and (r.Loading or r.Closing or r.Saving and not r.Ready) do
  if os.clock()>=deadline then return nil end
  task.wait(.1);r=records[id]
 end
 if Store.Peek(id) then return records[id] end
 if r and (r.Saving or r.Blocked) then return nil end
 if r and os.clock()<(r.RetryAt or 0) then return nil end
 if not r or r.Closed then
  r={ID=id,Balance=r and r.Balance or 0,Revision=0,Token=Http:GenerateGUID(false),Ready=false,Dirty=false}
  records[id]=r
 end
 r.Loading=true;publish(r,"Loading")
 local reason="LoadFailed"
 local ok,data=pcall(function()
  return DataStore:UpdateAsync("User_"..id,function(previous)
   if previous~=nil and not valid(previous) then reason="InvalidData";return nil end
   local lease=previous and previous.Lease
   if type(lease)=="table" and lease.Token~=r.Token and type(lease.Expires)=="number" and lease.Expires>os.time() then reason="Locked";return nil end
   local nextData=previous and table.clone(previous) or {Balance=0,Version=1}
   nextData.Lease={Token=r.Token,Expires=os.time()+LEASE}
   return nextData
  end)
 end)
 r.Loading=false
 if ok and valid(data) and data.Lease and data.Lease.Token==r.Token then
  r.Balance=data.Balance;r.Ready=true;r.Owned=true;r.Dirty=false;r.Closed=false
  r.NextSave=os.clock()+RENEW;r.RetryAt=nil;publish(r,"Saved")
  if closing then Store.Release(id);return nil end
  if r.Closing then return nil end
  return r
 end
 r.Ready=false;r.RetryAt=os.clock()+RETRY;publish(r,ok and reason or "LoadFailed")
 return nil
end
function Store.Set(record,balance)
 if closing or Store.Peek(record.ID)~=record or not R.Integer(balance,0,R.Maximum) then return false end
 record.Balance=balance;record.Revision+=1;record.Dirty=true
 record.NextSave=math.min(record.NextSave or math.huge,os.clock()+WRITE_DELAY)
 publish(record,"Pending");return true
end
function Store.Save(id,release)
 local r=records[id]
 if not r or not r.Owned or r.Closed then return false end
 if release then r.Closing=true;r.Ready=false end
 if r.Saving then return false end
 r.Saving=true
 local revision,balance=r.Revision,r.Balance
 publish(r,"Saving")
 local releaseLease=release or r.Closing
 local ok,data=pcall(function()
  return DataStore:UpdateAsync("User_"..id,function(previous)
   if not valid(previous) or type(previous.Lease)~="table" or previous.Lease.Token~=r.Token then return nil end
   local result=table.clone(previous)
   result.Balance=balance;result.UpdatedAt=os.time()
   result.Lease=not releaseLease and {Token=r.Token,Expires=os.time()+LEASE} or nil
   return result
  end)
 end)
 r.Saving=false
 if ok and valid(data) and (releaseLease and data.Lease==nil or not releaseLease and data.Lease and data.Lease.Token==r.Token) then
  if r.Revision==revision then r.Dirty=false end
  if releaseLease then r.Ready=false;r.Owned=false;r.Closed=true;r.Closing=false end
  r.NextSave=os.clock()+(r.Dirty and WRITE_DELAY or RENEW)
  publish(r,r.Dirty and "Pending" or "Saved");return true
 end
 -- A successful cancelled update means ownership was lost; do not overwrite it.
 if ok then r.Ready=false;r.Blocked=true;publish(r,"Locked")
 else r.NextSave=os.clock()+RETRY;publish(r,"SaveFailed") end
 return false
end
function Store.Release(id)
 local r=records[id]
 if not r or r.Closed then return false end
 r.Closing=true;r.Ready=false
 local deadline=os.clock()+20
 while r.Loading or r.Saving do
  if os.clock()>=deadline then return false end
  task.wait(.1)
 end
 if not r.Owned then r.Closing=false;r.Closed=true;return true end
 return Store.Save(id,true)
end
function Store.Step()
 for id,r in pairs(records) do
  if r.Owned and not r.Saving and not r.Blocked and os.clock()>=(r.NextSave or math.huge) then
   task.spawn(Store.Save,id,r.Closing)
  end
 end
end
function Store.Start()
 if Store.Started then return end;Store.Started=true
 game:BindToClose(function()
  closing=true
  for id,r in pairs(records) do if not r.Closed then task.spawn(Store.Release,id) end end
  local deadline=os.clock()+25
  repeat
   local pending=false
   for _,r in pairs(records) do if r.Loading or r.Saving or r.Owned then pending=true;break end end
   if not pending then break end
   Store.Step();task.wait(.1)
  until os.clock()>=deadline
 end)
end
return Store
