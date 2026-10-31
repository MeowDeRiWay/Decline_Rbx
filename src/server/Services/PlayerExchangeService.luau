local Players=game:GetService("Players")
local Replicated=game:GetService("ReplicatedStorage")
local Rules=require(Replicated.Shared.ExchangeRules)
local MoneyRules=require(Replicated.Shared.EconomyRules)
local Items=require(Replicated.Shared.ItemConfig).Items
local Inventory=require(script.Parent.InventoryService)
local Wallet=require(script.Parent.EconomyService)
local Journal=require(script.Parent.JournalService)
local Service={}
local sessions,last,invited={},{},{}
local stateRemote,serial
serial=0
local function root(player)
 if player.Parent~=Players or player:GetAttribute("AttributesConfirmed")~=true then return nil end
 local c=player.Character;local hp=c and c:FindFirstChildOfClass("Humanoid")
 if not hp or hp.Health<=0 or c:GetAttribute("Knockout") or c:GetAttribute("IsDead") or c:GetAttribute("HospitalResting") or c:GetAttribute("CarryingUserId") or c:GetAttribute("CarriedByUserId") then return nil end
 return c:FindFirstChild("HumanoidRootPart")
end
local function valid(s)
 local a,b=s.Players[1],s.Players[2]
 local ra,rb=root(a),root(b)
 if not ra or not rb or a.Character~=s.Characters[1] or b.Character~=s.Characters[2] or Inventory.Export(a)~=s.Inventories[1] or Inventory.Export(b)~=s.Inventories[2] or (ra.Position-rb.Position).Magnitude>Rules.Distance then return false end
 local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude
 params.FilterDescendantsInstances={a.Character,b.Character};params.RespectCanCollide=true
 return workspace:Raycast(ra.Position,rb.Position-ra.Position,params)==nil
end
local function stacks(player,offer)
 local result={}
 for _,stack in ipairs(Inventory.Snapshot(player).Stacks or {}) do
  if not offer or offer[stack.Key] then
   local entry=table.clone(stack)
   if offer then entry.Count=offer[stack.Key].Count end
   table.insert(result,entry)
  end
 end
 return result
end
local function signature(player)
 local parts={}
 for _,stack in ipairs(Inventory.Snapshot(player).Stacks or {}) do table.insert(parts,stack.Key..":"..stack.Count) end
 return table.concat(parts,"\n")
end
local function send(s,message)
 if not stateRemote then return end
 for i,player in ipairs(s.Players) do
  stateRemote:FireClient(player,{Open=true,ID=s.ID,Phase=s.Phase,Incoming=i==2,PartnerName=s.Players[3-i].Name,
   ConfirmAt=workspace:GetServerTimeNow()+math.max(0,s.ChangedAt+Rules.ConfirmDelay-os.clock()),Revision=s.Revision,Money=Wallet.Balance(player),Cash=s.Cash[i],OtherCash=s.Cash[3-i],
   Inventory=stacks(player),Offer=stacks(player,s.Offers[i]),OtherOffer=stacks(s.Players[3-i],s.Offers[3-i]),
   Confirmed=s.Confirmed[i]==true,OtherConfirmed=s.Confirmed[3-i]==true,Message=message})
 end
end
local function close(s,message)
 if s.Closed then return end;s.Closed=true
 for _,player in ipairs(s.Players) do
  if sessions[player]==s then sessions[player]=nil end
  if stateRemote and player.Parent==Players then stateRemote:FireClient(player,{Open=false,Message=message}) end
  if message and player.Parent==Players then Journal.Send(player,message) end
 end
end
local function revise(s)
 s.Revision+=1;s.Confirmed={};s.ChangedAt=os.clock()
 if s.Phase=="Offer" then s.Expires=os.clock()+Rules.SessionSeconds end
end
function Service.Invite(player,target)
 if typeof(target)~="Instance" or not target:IsA("Player") or target==player or sessions[player] or sessions[target] then return false end
 if os.clock()-(invited[player] or -math.huge)<3 then return false end
 local ra,rb=root(player),root(target)
 if not ra or not rb or not Inventory.Export(player) or not Inventory.Export(target) or player:GetAttribute("MoneyReady")~=true or target:GetAttribute("MoneyReady")~=true then return false end
 serial+=1
 local s={ID=serial,Players={player,target},Characters={player.Character,target.Character},Inventories={Inventory.Export(player),Inventory.Export(target)},Phase="Invite",Offers={{},{}},Cash={0,0},Confirmed={},Revision=1,ChangedAt=os.clock(),Expires=os.clock()+Rules.InviteSeconds}
 if not valid(s) then return false end
 s.Pockets={signature(player),signature(target)}
 invited[player]=os.clock();sessions[player]=s;sessions[target]=s
 send(s);return true
end
function Service.Command(player,command,id,key,count)
 local s=sessions[player]
 if not s or s.ID~=id or s.Busy then return false end
 if command=="Cancel" then close(s,"Exchange cancelled.");return true end
 if not valid(s) or os.clock()>=s.Expires then close(s,"Exchange cancelled.");return false end
 local i=s.Players[1]==player and 1 or 2
 if s.Phase=="Invite" then
  if command~="Join" or i~=2 then return false end
  s.Phase="Offer";revise(s);send(s);return true
 end
 if command=="Cash" then
  if not MoneyRules.Integer(key,0,MoneyRules.Maximum) or key>Wallet.Balance(player) or player:GetAttribute("MoneyReady")~=true then return false end
  if s.Cash[i]~=key then s.Cash[i]=key;revise(s) end
 elseif command=="Offer" then
  if type(key)~="string" or #key>200 or not MoneyRules.Integer(count,0,1000000000) then return false end
  local found
  for _,stack in ipairs(Inventory.Snapshot(player).Stacks or {}) do if stack.Key==key then found=stack;break end end
  if count>0 then
   local item=found and Items[found.ID]
   if not item or item.Lootable==false or item.Currency or count>found.Count then return false end
   local n=0;for _ in pairs(s.Offers[i]) do n+=1 end
   if not s.Offers[i][key] and n>=Rules.MaxStacks then return false end
   s.Offers[i][key]={ID=found.ID,Key=key,Count=count}
  else s.Offers[i][key]=nil end
  revise(s)
 elseif command=="Confirm" then
  if key~=s.Revision or os.clock()-s.ChangedAt<Rules.ConfirmDelay then return false end
  if not next(s.Offers[1]) and not next(s.Offers[2]) and s.Cash[1]==0 and s.Cash[2]==0 then return false end
  s.Confirmed[i]=true
  if s.Confirmed[1] and s.Confirmed[2] then
   s.Busy=true
   local a,b=s.Players[1],s.Players[2]
   local ok=Wallet.Exchange(a,b,s.Cash[1],s.Cash[2],function()
    return valid(s) and Inventory.Exchange(a,b,s.Offers[1],s.Offers[2],s.Inventories[1],s.Inventories[2])
   end)
   s.Busy=false
   if ok then close(s,"Exchange completed.");return true end
   revise(s);send(s,"Exchange failed. Check the offered items and money.");return false
  end
 else return false end
 send(s);return true
end
function Service.Step()
 local seen={}
 for _,s in pairs(sessions) do
  if not seen[s] then
   seen[s]=true
   if not s.Busy and (os.clock()>=s.Expires or not valid(s)) then close(s,"Exchange cancelled.") end
  end
 end
end
function Service.Start()
 if Service.Started then return end;Service.Started=true
 Wallet.Start()
 local folder=Instance.new("Folder");folder.Name="PlayerExchangeRemotes";folder.Parent=Replicated
 local action=Instance.new("RemoteEvent");action.Name="Action";action.Parent=folder
 stateRemote=Instance.new("RemoteEvent");stateRemote.Name="State";stateRemote.Parent=folder
 action.OnServerEvent:Connect(function(player,command,id,key,count)
  local now=os.clock();if command~="Cancel" and now-(last[player] or -math.huge)<.1 then return end;last[player]=now
  Service.Command(player,command,id,key,count)
 end)
 Inventory.Changed:Connect(function(player)
  local s=sessions[player]
  if s and not s.Busy then
   local i=s.Players[1]==player and 1 or 2
   local changed=signature(player)
   if changed==s.Pockets[i] then return end
   s.Pockets[i]=changed
   local current={}
   for _,stack in ipairs(Inventory.Snapshot(player).Stacks or {}) do current[stack.Key]=stack.Count end
   local invalid=false
   for key,entry in pairs(s.Offers[i]) do if (current[key] or 0)<entry.Count then s.Offers[i][key]=nil;invalid=true end end
   -- Pocket changes always reset consent; no equipped items enter the offer.
   revise(s);send(s,invalid and "Offer changed. Confirm again." or nil)
  end
 end)
 Players.PlayerRemoving:Connect(function(player)
  if sessions[player] then close(sessions[player],"Exchange cancelled.") end
  last[player]=nil;invited[player]=nil
 end)
 task.spawn(function() while true do task.wait(.5);Service.Step() end end)
end
return Service
