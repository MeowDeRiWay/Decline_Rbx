local Players=game:GetService("Players")
local R=require(game:GetService("ReplicatedStorage").Shared.EconomyRules)
local Store=require(script.Parent.MoneyStore)
local Service={}
local nextIncome={}
local function idOf(owner) return typeof(owner)=="number" and owner or owner.UserId end
local function sync(id)
 local player=Players:GetPlayerByUserId(id)
 if player then
  local account=Store.Peek(id)
  player:SetAttribute("MoneyReady",account~=nil)
  player:SetAttribute("MoneyStatus",Store.Status(id))
  if account then player:SetAttribute("Money",account.Balance) end
 end
end
function Service.Balance(owner) return Store.Cached(idOf(owner)) end
-- A new character restarts the income timer, never the account balance.
function Service.Reset(player)
 nextIncome[player.UserId]=os.clock()+R.IncomeInterval;sync(player.UserId)
end
function Service.Credit(owner,amount)
 local id=idOf(owner)
 if not R.Integer(id,1,R.Maximum) or not R.Integer(amount,1,R.Maximum) then return false end
 local account=Store.Peek(id)
 if not account or account.Balance+amount>R.Maximum then return false end
 return Store.Set(account,account.Balance+amount)
end
-- Loading may yield BEFORE validation. The transfer callback and both balance
-- changes must not yield; callers revalidate their item transfer after loading.
function Service.Transfer(from,to,amount,transferItems)
 local a,b=idOf(from),idOf(to)
 if a==b or not R.Integer(a,1,R.Maximum) or not R.Integer(b,1,R.Maximum) or not R.Integer(amount,1,R.Maximum) then return false end
 local function finish(ok)
  for _,id in ipairs({a,b}) do if not Players:GetPlayerByUserId(id) then task.spawn(Store.Release,id) end end
  return ok
 end
 local sender=Store.Open(a)
 if not sender or sender.Balance<amount then return finish(false) end
 local recipient=Store.Open(b)
 if not recipient or Store.Peek(a)~=sender or Store.Peek(b)~=recipient or recipient.Balance+amount>R.Maximum then return finish(false) end
 if transferItems and not transferItems() then return finish(false) end
 assert(Store.Set(sender,sender.Balance-amount))
 assert(Store.Set(recipient,recipient.Balance+amount))
 return finish(true)
end
-- Local barter: both accounts must already be loaded. No yields between the
-- item callback and the two cash changes; each side must own its full offer.
function Service.Exchange(a,b,offerA,offerB,transferItems)
 local x,y=idOf(a),idOf(b)
 if x==y or not R.Integer(offerA,0,R.Maximum) or not R.Integer(offerB,0,R.Maximum) then return false end
 local left,right=Store.Peek(x),Store.Peek(y)
 if not left or not right or left.Balance<offerA or right.Balance<offerB then return false end
 local balanceA,balanceB=left.Balance-offerA+offerB,right.Balance-offerB+offerA
 if balanceA>R.Maximum or balanceB>R.Maximum then return false end
 if transferItems and not transferItems() then return false end
 if offerA~=offerB then
  assert(Store.Set(left,balanceA));assert(Store.Set(right,balanceB))
 end
 return true
end
function Service.Step()
 local now=os.clock()
 for _,player in ipairs(Players:GetPlayers()) do
  if Store.Peek(player.UserId) and now>=(nextIncome[player.UserId] or math.huge) then
   nextIncome[player.UserId]=now+R.IncomeInterval
   local level=player:GetAttribute("CharacterLevel") or 0
   if player:GetAttribute("AttributesConfirmed")==true and R.Integer(level,1,30) then Service.Credit(player,level) end
  end
 end
 Store.Step()
end
function Service.Start()
 if Service.Started then return end;Service.Started=true
 Store.Start();Store.Changed:Connect(sync)
 local function added(player)
  player:SetAttribute("MoneyReady",false);player:SetAttribute("MoneyStatus","Loading")
  task.spawn(function()
   while player.Parent==Players do
    local account=Store.Open(player.UserId)
    if account then
     if player.Parent~=Players then Store.Release(player.UserId);return end
     nextIncome[player.UserId]=os.clock()+R.IncomeInterval;sync(player.UserId);return
    end
    task.wait(10)
   end
  end)
 end
 Players.PlayerAdded:Connect(added)
 Players.PlayerRemoving:Connect(function(player) nextIncome[player.UserId]=nil;Store.Release(player.UserId) end)
 for _,player in ipairs(Players:GetPlayers()) do added(player) end
 task.spawn(function() while true do task.wait(1);Service.Step() end end)
end
return Service
