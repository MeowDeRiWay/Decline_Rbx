local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Items=require(ReplicatedStorage.Shared.ItemConfig)
local Rules=require(ReplicatedStorage.Shared.InventoryRules)
local MoneyRules=require(ReplicatedStorage.Shared.EconomyRules)
local Interaction=require(ReplicatedStorage.Shared.Interaction)
local Config=require(ReplicatedStorage.Shared.GameConfig)
local Inventory=require(script.Parent.InventoryService)
local Wallet=require(script.Parent.EconomyService)
local Towns=require(script.Parent.TownService)
local Service={}
local posts,sessions,offline,last={},{},{},{}
local stateRemote
local ownerNames={}
local nextTax=os.clock()+MoneyRules.TaxInterval
local function isPost(object) return object:IsA("Model") and (object.Name=="TradePost" or object:GetAttribute("TradePost")==true) end
local function townID(object)
 while object and object~=workspace do
  local id=object:GetAttribute("TownID");if id~=nil then return id end
  object=object.Parent
 end
end
local function visual(record)
 local active=record.Owner>0 or record.Inherited
 for _,entry in ipairs(record.Visuals) do
  local shown=entry.Active==active
  local p=entry.Part
  if p.Parent then
   p.Transparency=shown and entry.Transparency or 1
   p.CanCollide=shown and entry.CanCollide or false;p.CanQuery=shown and entry.CanQuery or false;p.CanTouch=shown and entry.CanTouch or false
   if shown then p:SetAttribute("BlocksVision",entry.BlocksVision) else p:SetAttribute("BlocksVision",false) end
  end
 end
 record.Model:SetAttribute("TradeOwnerID",record.Owner)
 record.Model:SetAttribute("TradeInherited",record.Inherited)
 record.Model:SetAttribute("TradeHasStock",next(record.Storage.Items)~=nil)
end
function Service.Register(object)
 if not isPost(object) or posts[object] or not object:FindFirstChildWhichIsA("BasePart",true) then return end
 local parent=object.Parent
 while parent and parent~=workspace do if isPost(parent) then return end;parent=parent.Parent end
 local record={Model=object,Owner=0,Inherited=false,Storage=Rules.New(),Prices={},Visuals={}}
 for _,name in ipairs({"Active","Inactive"}) do
  local model=object:FindFirstChild(name)
  if model then
   local parts=model:IsA("BasePart") and {model} or model:GetDescendants()
   for _,p in ipairs(parts) do if p:IsA("BasePart") then table.insert(record.Visuals,{Part=p,Active=name=="Active",Transparency=p.Transparency,CanCollide=p.CanCollide,CanQuery=p.CanQuery,CanTouch=p.CanTouch,BlocksVision=p:GetAttribute("BlocksVision")}) end end
  end
 end
 posts[object]=record;visual(record)
end
local function near(player,post)
 local c=player.Character;local root=c and c:FindFirstChild("HumanoidRootPart");local hp=c and c:FindFirstChildOfClass("Humanoid")
 if player:GetAttribute("AttributesConfirmed")~=true or not root or not hp or hp.Health<=0 or c:GetAttribute("Knockout") or c:GetAttribute("IsDead") or c:GetAttribute("HospitalResting") or c:GetAttribute("CraftingLocked") or not post:IsDescendantOf(workspace) then return false end
 local point=Interaction.NearestPoint(post,root.Position)
 if (point-root.Position).Magnitude>Items.PickupDistance then return false end
 local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances={c}
 local hit=workspace:Raycast(root.Position,point-root.Position,params)
 return not hit or hit.Instance:IsDescendantOf(post)
end
function Service.Snapshot(player)
 local record=sessions[player]
 if not record or not near(player,record.Model) then sessions[player]=nil;player:SetAttribute("TradeOpen",false);return {Open=false} end
 local stock=Rules.Stacks(record.Storage,Items.Items)
 for _,stack in ipairs(stock) do stack.Price=record.Prices[stack.Key] or 0 end
 local town=Towns.TradeTown(townID(record.Model))
 return {Open=true,Post=record.Model,OwnerID=record.Owner,OwnerName=ownerNames[record.Owner] or ("Seller #"..record.Owner),Inherited=record.Inherited,CanClaim=record.Owner==0 and not record.Inherited and town~=nil and player:GetAttribute("TownID")==town.ID,
  Stock=stock,Inventory=record.Owner==player.UserId and Inventory.Snapshot(player).Stacks or {},Money=Wallet.Balance(player),Tax=town and town.Tax or 0}
end
function Service.Publish(record,message,recipient)
 if not stateRemote then return end
 for player,current in pairs(sessions) do
  if not record or current==record then
   local snapshot=Service.Snapshot(player);if recipient==player then snapshot.Message=message end
   stateRemote:FireClient(player,snapshot)
  end
 end
end
function Service.Open(player,post)
 if not posts[post] then return false end
 if not near(player,post) then return false end
 sessions[player]=posts[post];player:SetAttribute("TradeOpen",true);Service.Publish(posts[post]);return true
end
function Service.Close(player)
 sessions[player]=nil
 player:SetAttribute("TradeOpen",false)
 if stateRemote and player.Parent==Players then stateRemote:FireClient(player,{Open=false}) end
end
local function inherit(record)
 local town=Towns.TradeTown(townID(record.Model))
 record.Owner=town and town.LeaderID or 0;record.Inherited=true
 visual(record);Service.Publish(record)
end
function Service.ReassignUser(userID,id)
 for _,record in pairs(posts) do if record.Owner==userID and townID(record.Model)==id then inherit(record) end end
end
function Service.Command(player,command,key,amount)
 local record=sessions[player]
 if not record or not near(player,record.Model) then Service.Close(player);return false end
 if record.Busy then return false end
 local town=Towns.TradeTown(townID(record.Model))
 if not town then return false end
 if record.Owner==player.UserId and player:GetAttribute("TownID")~=town.ID then inherit(record);return false end
 if command=="Claim" then
  if record.Owner~=0 or record.Inherited or player:GetAttribute("TownID")~=town.ID then return false end
  record.Owner=player.UserId;visual(record);Service.Publish(record);return true
 end
 if command=="Release" then
  if record.Owner~=player.UserId or next(record.Storage.Items) then return false end
  record.Owner=0;record.Inherited=false;visual(record);Service.Publish(record);return true
 end
 if typeof(key)~="string" or #key>200 then return false end
 if command=="Put" then
  if record.Owner~=player.UserId then return false end
  local stack
  for _,s in ipairs(Inventory.Snapshot(player).Stacks or {}) do if s.Key==key then stack=s;break end end
  if not stack or Items.Items[stack.ID].Currency then return false end
  record.Busy=true
  local ok=Inventory.Transfer(player,record.Storage,stack.ID,amount,true,key)
  record.Busy=false;visual(record);Service.Publish(record);return ok
 end
 local stack
 for _,s in ipairs(Rules.Stacks(record.Storage,Items.Items)) do if s.Key==key then stack=s;break end end
 if not stack then return false end
 if command=="Price" then
  if record.Owner~=player.UserId or not MoneyRules.Integer(amount,1,1000000000) then return false end
  record.Prices[key]=amount;Service.Publish(record);return true
 elseif command=="Take" then
  if record.Owner~=player.UserId then return false end
  record.Busy=true;local ok=Inventory.Transfer(player,record.Storage,stack.ID,amount,false,key);record.Busy=false
  visual(record);Service.Publish(record);return ok
 elseif command=="Buy" then
  if record.Owner<=0 or record.Owner==player.UserId then return false end
  local count=Rules.DropAmount(stack.Count,amount)
  local price=record.Prices[key]
  if not count or not MoneyRules.Integer(price,1,1000000000) or count*price>MoneyRules.Maximum then return false end
  record.Busy=true
  local ok=Wallet.Transfer(player.UserId,record.Owner,count*price,function() return Inventory.Transfer(player,record.Storage,stack.ID,count,false,key) end)
  record.Busy=false;visual(record);Service.Publish(record,ok and "Purchase complete." or "Purchase failed: check your balance and available stock.",player);return ok
 end
 return false
end
function Service.Step()
 local now=os.clock()
 for id,record in pairs(offline) do
  if now>=record.Until then offline[id]=nil;Service.ReassignUser(id,record.TownID) end
 end
 for model in pairs(posts) do if not model:IsDescendantOf(workspace) then posts[model]=nil end end
 if now>=nextTax then
  nextTax=now+MoneyRules.TaxInterval
  local sellers={}
  for _,record in pairs(posts) do
   local town=Towns.TradeTown(townID(record.Model))
   if town and record.Owner>0 and town.LeaderID>0 and record.Owner~=town.LeaderID then
    local key=tostring(town.ID)..":"..record.Owner
    if not sellers[key] then
     sellers[key]=true
     local amount=math.min(town.Tax,Wallet.Balance(record.Owner))
     if amount>0 then Wallet.Transfer(record.Owner,town.LeaderID,amount) end
    end
   end
  end
 end
 for player,record in pairs(sessions) do if not near(player,record.Model) then Service.Close(player) end end
end
function Service.Start()
 if Service.Started then return end;Service.Started=true;Wallet.Start()
 local folder=Instance.new("Folder");folder.Name="TradeRemotes";folder.Parent=ReplicatedStorage
 stateRemote=Instance.new("RemoteEvent");stateRemote.Name="State";stateRemote.Parent=folder
 local action=Instance.new("RemoteEvent");action.Name="Action";action.Parent=folder
 action.OnServerEvent:Connect(function(player,command,value,amount)
  if command=="Close" then Service.Close(player);return end
  if os.clock()-(last[player] or -math.huge)<.1 then return end;last[player]=os.clock()
  if command=="Open" then Service.Open(player,value) else local ok=Service.Command(player,command,value,amount);if not ok then Service.Publish(sessions[player],"Action unavailable: check ownership, quantity, price and stock.",player) end end
 end)
 local function track(object)
  while object and object~=workspace do if isPost(object) then Service.Register(object);return end;object=object.Parent end
 end
 for _,object in ipairs(workspace:GetDescendants()) do track(object) end
 workspace.DescendantAdded:Connect(function(object) task.defer(track,object) end)
 local function added(player)
  ownerNames[player.UserId]=player.Name
  local record=offline[player.UserId]
  if record and os.clock()>=record.Until then Service.ReassignUser(player.UserId,record.TownID) end
  offline[player.UserId]=nil
  player:GetAttributeChangedSignal("TownID"):Connect(function()
   for _,r in pairs(posts) do if r.Owner==player.UserId and townID(r.Model)~=player:GetAttribute("TownID") then inherit(r) end end
  end)
 end
 Players.PlayerAdded:Connect(added)
 Players.PlayerRemoving:Connect(function(player)
  sessions[player]=nil;last[player]=nil
  offline[player.UserId]={TownID=player:GetAttribute("TownID"),Until=os.clock()+Config.ReconnectGraceSeconds}
 end)
 for _,player in ipairs(Players:GetPlayers()) do added(player) end
 Towns.OnMarketEvent(function(kind,id,userID)
  if kind=="Leave" then Service.ReassignUser(userID,id)
  elseif kind=="Leader" then for _,r in pairs(posts) do if r.Inherited and townID(r.Model)==id then r.Owner=userID;visual(r);Service.Publish(r) end end end
 end)
 Inventory.Changed:Connect(function(player) local record=sessions[player];if record and not record.Busy then Service.Publish(record) end end)
 task.spawn(function() while true do task.wait(.5);Service.Step() end end)
end
return Service
