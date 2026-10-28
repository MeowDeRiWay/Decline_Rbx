-- In-memory continuity for reconnecting to this SAME running server.
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Config=require(ReplicatedStorage.Shared.GameConfig)
local Inventory=require(script.Parent.InventoryService)
local Progression=require(script.Parent.ProgressionService)
local Life=require(script.Parent.PlayerLifeService)
local Towns=require(script.Parent.TownService)
local Beds=require(script.Parent.HospitalBedService)
local Service={}
local records={}
local transient={MapOpen=true,HelpOpen=true,HelpHidden=true,HelpPreferenceReady=true,HelpPreferenceStatus=true,Money=true,TradeOpen=true,InventoryOpen=true,ProgressionOpen=true,TownMenuOpen=true,GroupOpen=true,MedicalMode=true,CharacterLoading=true,Reconnecting=true,GroupID=true}
local function disconnect(record)
 if record.HealthConnection then record.HealthConnection:Disconnect();record.HealthConnection=nil end
end
local function corpse(record)
 if record.Returned or not record.Body then return end
 local body=record.Body;record.Body=nil
 disconnect(record)
 Inventory.ForgetOffline(record.UserID,record.Inventory)
 Life.OfflineCorpse(body,Inventory.CorpseStorage(record.Inventory),record.UserID,record.DisplayName)
 record.Inventory=nil
 -- Offline death of an unaffiliated character also ends that character's run.
 if not record.Attributes.TownID then record.Attributes.OutcastEnd=true end
end
local function leave(player)
 Beds.Leave(player)
 local record={UserID=player.UserId,DisplayName=player.DisplayName,Attributes=player:GetAttributes(),Team=player.Team,Inventory=Inventory.Export(player)}
 records[player.UserId]=record
 local character=player.Character
 local hp=character and character:FindFirstChildOfClass("Humanoid")
 if not character or not hp or character:GetAttribute("IsDead") or player:GetAttribute("AttributesConfirmed")~=true then return end
 -- A clone survives Roblox's destruction of the departing Player.Character.
 local flags={}
 local ko=Life.KnockoutRecord(character)
 for _,part in ipairs(character:GetDescendants()) do
  if part:IsA("BasePart") then
   local index=#flags+1
   flags[index]={Original=part,Anchored=part.Anchored,CanCollide=part.CanCollide,CanQuery=part.CanQuery,KO=ko and ko.Parts[part]}
   part:SetAttribute("ReconnectPartIndex",index)
  end
 end
 character.Archivable=true
 local body=character:Clone()
 for _,entry in ipairs(flags) do entry.Original:SetAttribute("ReconnectPartIndex",nil) end
 if not body then return end
 record.Parts={}
 if ko then record.Knockout={Pivot=ko.Pivot,Parts={},BlocksVision=ko.BlocksVision} end
 for _,part in ipairs(body:GetDescendants()) do
  if part:IsA("BasePart") then
   local entry=flags[part:GetAttribute("ReconnectPartIndex")]
   part:SetAttribute("ReconnectPartIndex",nil)
   if entry then
    record.Parts[part]=entry
    if entry.KO then record.Knockout.Parts[part]=entry.KO end
    entry.Original=nil
   end
   part.Anchored=true
   part.AssemblyLinearVelocity=Vector3.zero;part.AssemblyAngularVelocity=Vector3.zero
  elseif part:IsA("Sound") then part:Stop()
  elseif part:IsA("ForceField") then part:Destroy() end
 end
 for key,value in pairs(record.Attributes) do if not transient[key] then body:SetAttribute(key,value) end end
 body:SetAttribute("GroupID",nil);body:SetAttribute("Running",false);body:SetAttribute("Reloading",false)
 body:SetAttribute("CraftingLocked",false);body:SetAttribute("OfflineUserId",player.UserId)
 body:SetAttribute("OfflineUntil",workspace:GetServerTimeNow()+Config.ReconnectGraceSeconds)
 local folder=workspace:FindFirstChild("DisconnectedPlayers")
 if not folder then folder=Instance.new("Folder");folder.Name="DisconnectedPlayers";folder.Parent=workspace end
 record.Body=body
 body.Parent=folder
 local health=body:FindFirstChildOfClass("Humanoid")
 record.HealthConnection=health.HealthChanged:Connect(function(value)
  body:SetAttribute("Health",value)
  if value<=0 then corpse(record) end
 end)
 local timeout=Config.ReconnectGraceSeconds
 if record.Knockout then timeout=math.min(timeout,math.max(0,(body:GetAttribute("KnockoutEndsAt") or 0)-workspace:GetServerTimeNow())) end
 task.delay(timeout,function() if records[record.UserID]==record then corpse(record) end end)
 if health.Health<=0 then corpse(record) end
end
local function added(player)
 local record=records[player.UserId]
 if not record then return end
 player:SetAttribute("Reconnecting",true)
 -- Let normal PlayerAdded listeners establish inventory/progression/remotes first.
 task.defer(function()
  if player.Parent~=Players or records[player.UserId]~=record then return end
  if record.Body then
   local deadline=record.Body:GetAttribute("OfflineUntil") or 0
   if record.Knockout then deadline=math.min(deadline,record.Body:GetAttribute("KnockoutEndsAt") or 0) end
   local health=record.Body:FindFirstChildOfClass("Humanoid")
   if workspace:GetServerTimeNow()>=deadline or not health or health.Health<=0 then corpse(record) end
  end
  record.Returned=true;disconnect(record);records[player.UserId]=nil
  for key,value in pairs(record.Attributes) do if not transient[key] then player:SetAttribute(key,value) end end
  player.Team=record.Team;player.Neutral=record.Team==nil
  local body=record.Body
  if body and body.Parent and body:FindFirstChildOfClass("Humanoid").Health>0 then
   body:SetAttribute("ReturningSession",true);body:SetAttribute("OfflineUserId",nil);body:SetAttribute("OfflineUntil",nil)
   body.Parent=workspace
   for part,entry in pairs(record.Parts) do
    if part.Parent then part.Anchored=entry.Anchored;part.CanCollide=entry.CanCollide;part.CanQuery=entry.CanQuery end
   end
   player.Character=body
   if record.Knockout then Life.ResumeKnockout(player,body,record.Knockout) end
   local root=body:FindFirstChild("HumanoidRootPart")
   if root and not root.Anchored then pcall(function() root:SetNetworkOwner(player) end) end
   Progression.Sync(player)
   player:SetAttribute("Reconnecting",nil)
  else
   player:SetAttribute("Reconnecting",nil)
   if player:GetAttribute("TownID") then Towns.LoadCharacter(player) end
  end
  Towns.Publish()
 end)
end
function Service.OfflineInventory(model)
 local record=records[model:GetAttribute("OfflineUserId")]
 return record and not record.Returned and record.Body==model and record.Inventory or nil
end
function Service.OfflineCharacters()
 local result={}
 for _,record in pairs(records) do if record.Body and not record.Returned then table.insert(result,record.Body) end end
 return result
end
function Service.Start()
 if Service.Started then return end;Service.Started=true
 Inventory.Start();Progression.Start()
 Players.PlayerRemoving:Connect(leave);Players.PlayerAdded:Connect(added)
end
return Service
