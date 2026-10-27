local Players=game:GetService("Players")
local R=require(game:GetService("ReplicatedStorage").Shared.EconomyRules)
local Service={}
local balances,nextIncome={},{}
local function idOf(owner) return typeof(owner)=="number" and owner or owner.UserId end
local function sync(id)
 local player=Players:GetPlayerByUserId(id)
 if player then player:SetAttribute("Money",balances[id] or 0) end
end
function Service.Balance(owner) return balances[idOf(owner)] or 0 end
function Service.Credit(owner,amount)
 local id=idOf(owner)
 if not R.Integer(id,1,R.Maximum) or not R.Integer(amount,1,R.Maximum) or Service.Balance(id)+amount>R.Maximum then return false end
 balances[id]=Service.Balance(id)+amount;sync(id);return true
end
-- The item transfer callback must not yield. Failed transfers never charge money.
function Service.Transfer(from,to,amount,transferItems)
 local a,b=idOf(from),idOf(to)
 if a==b or not R.Integer(a,1,R.Maximum) or not R.Integer(b,1,R.Maximum) or not R.Integer(amount,1,R.Maximum) or Service.Balance(a)<amount or Service.Balance(b)+amount>R.Maximum then return false end
 if transferItems and not transferItems() then return false end
 balances[a]=Service.Balance(a)-amount;balances[b]=Service.Balance(b)+amount
 sync(a);sync(b);return true
end
function Service.Step()
 local now=os.clock()
 for _,player in ipairs(Players:GetPlayers()) do
  if now>=(nextIncome[player.UserId] or math.huge) then
   nextIncome[player.UserId]=now+R.IncomeInterval
   local level=player:GetAttribute("CharacterLevel") or 0
   if player:GetAttribute("AttributesConfirmed")==true and R.Integer(level,1,30) then Service.Credit(player,level) end
  end
 end
end
function Service.Start()
 if Service.Started then return end;Service.Started=true
 local function added(player) nextIncome[player.UserId]=os.clock()+R.IncomeInterval;sync(player.UserId) end
 Players.PlayerAdded:Connect(added)
 Players.PlayerRemoving:Connect(function(player) nextIncome[player.UserId]=nil end)
 for _,player in ipairs(Players:GetPlayers()) do added(player) end
 task.spawn(function() while true do task.wait(1);Service.Step() end end)
end
return Service
