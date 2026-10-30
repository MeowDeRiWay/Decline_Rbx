local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Inventory = require(script.Parent.InventoryService)
local Rules = require(ReplicatedStorage.Shared.InventoryRules)
local Items = require(ReplicatedStorage.Shared.ItemConfig)
local Interaction = require(ReplicatedStorage.Shared.Interaction)
local Animation=require(script.Parent.InteractionAnimationService)
local Service = {}
local contents = setmetatable({}, {__mode = "k"})
local sessions = {}
local knockoutOwners=setmetatable({},{__mode="k"})
local changed = Instance.new("BindableEvent")
Service.Changed = changed.Event
local function reachable(player, chest)
 if typeof(chest) ~= "Instance" or not chest:IsA("Model") or (chest.Name ~= "Chest" and chest:GetAttribute("IsCorpse") ~= true and chest:GetAttribute("Knockout")~=true) or not chest:IsDescendantOf(workspace) or not chest:FindFirstChildWhichIsA("BasePart", true) then return false end
 local ownerID=knockoutOwners[chest]
 if ownerID then
  local owner=Players:GetPlayerByUserId(ownerID)
  if not chest:GetAttribute("Knockout") or not owner or owner.Character~=chest or (contents[chest] and Inventory.Export(owner)~=contents[chest]) then return false end
 end
 local character = player.Character
 local humanoid = character and character:FindFirstChildOfClass("Humanoid")
 local root = character and character:FindFirstChild("HumanoidRootPart")
 if not root or not humanoid or humanoid.Health <= 0 or character:GetAttribute("Knockout") or character:GetAttribute("CarryingUserId") or chest:GetAttribute("CarriedByUserId") then return false end
 local nearest = Interaction.NearestPoint(chest,root.Position)
 local delta = nearest - root.Position
 if delta.Magnitude > Items.PickupDistance then return false end
 local params = RaycastParams.new()
 params.FilterType = Enum.RaycastFilterType.Exclude
 params.FilterDescendantsInstances = {character}
 local hit = workspace:Raycast(root.Position, delta, params)
 return not hit or hit.Instance:IsDescendantOf(chest)
end
local function notify(chest)
 for player, current in pairs(sessions) do if current == chest then changed:Fire(player) end end
end
function Service.CreatePlayerCorpse(model,storage)
 if contents[model] then return end
 contents[model]=storage
 model:SetAttribute("IsCorpse",true)
 model:SetAttribute("CorpseType","Player")
 local createdAt=os.clock()
 local emptySince=next(storage.Items)==nil and createdAt or nil
 -- Deferred: callers finish parenting the corpse after registering its inventory.
 task.defer(function()
  while model:IsDescendantOf(workspace) do
   local now=os.clock()
   if next(storage.Items)==nil then emptySince=emptySince or now else emptySince=nil end
   if now-createdAt>=1200 or (emptySince and now-emptySince>=60) then
    for player,current in pairs(sessions) do if current==model then Service.Close(player) end end
    contents[model]=nil
    model:Destroy()
    return
   end
   task.wait(1)
  end
 end)
end
function Service.CreateCorpse(model,items)
 if contents[model] then return end
 local storage = Rules.New()
 for id,count in pairs(items) do if count > 0 and Items.Items[id] and Items.Items[id].Lootable ~= false then Rules.Add(storage,Items.Items,id,count) end end
 contents[model] = storage
 model:SetAttribute("IsCorpse",true)
 local diedAt=os.clock()
 task.spawn(function()
  while model:IsDescendantOf(workspace) do
   local age=os.clock()-diedAt
   if age>=120 or (age>=20 and next(storage.Items)==nil) then
    for player,current in pairs(sessions) do if current==model then Service.Close(player) end end
    contents[model]=nil
    model:Destroy()
    return
   end
   task.wait(.25)
  end
 end)
end
function Service.OpenKnockout(player,patient)
 local character=patient.Character
 if player==patient or not character or not character:GetAttribute("Knockout") or character:GetAttribute("CarriedByUserId") then return false end
 if not reachable(player,character) then return false end
 knockoutOwners[character]=patient.UserId
 character:SetAttribute("DisplayName",patient.DisplayName)
 return Service.Open(player,character)
end
local function refreshOwner(chest)
 local id=knockoutOwners[chest];local owner=id and Players:GetPlayerByUserId(id)
 if owner then Inventory.Refresh(owner) end
end
function Service.Open(player, chest)
 if not reachable(player, chest) then return false end
 if sessions[player]==chest then return true end
 if player.Character:GetAttribute("InteractionLocked") and player.Character:GetAttribute("InteractionMode")~="Reach" then return false end
 local function opened()
  if not reachable(player,chest) then return false end
  if chest:GetAttribute("Knockout") then
   local owner=knockoutOwners[chest] and Players:GetPlayerByUserId(knockoutOwners[chest]) or Players:GetPlayerFromCharacter(chest)
   if not owner or owner.Character~=chest then return false end
   local storage=Inventory.Export(owner)
   if not storage then return false end
   knockoutOwners[chest]=owner.UserId
   contents[chest]=storage
  end
  if not contents[chest] then contents[chest]=Rules.New() end
  sessions[player]=chest
  changed:Fire(player)
  return true
 end
 if chest:GetAttribute("IsCorpse") or chest:GetAttribute("Knockout") then return Animation.BeginLoot(player,chest,Items.PickupDistance,opened) end
 return opened()
end
function Service.Close(player)
 sessions[player]=nil
 Animation.EndLoot(player)
 changed:Fire(player)
end

local function lootStacks(chest)
 local storage=chest and contents[chest]
 if not storage then return {} end
 return chest:GetAttribute("Knockout") and Rules.LootStacks(storage,Items.Items,true) or Rules.Stacks(storage,Items.Items)
end
function Service.Snapshot(player)
 local chest = sessions[player]
 return {ChestOpen = chest ~= nil, Chest = chest, ChestReadOnly = chest ~= nil and (chest:GetAttribute("IsCorpse") == true or chest:GetAttribute("Knockout")==true), ChestName = chest and (chest:GetAttribute("DisplayName") or chest.Name), ChestStacks=lootStacks(chest), ChestItems = chest and contents[chest] and table.clone(contents[chest].Items) or {}}
end
function Service.Transfer(player, id, requested, intoChest,key)
 local chest = sessions[player]
 if not reachable(player, chest) then Service.Close(player); return false end
 if intoChest and (chest:GetAttribute("IsCorpse") == true or chest:GetAttribute("Knockout")) then return false end
 if typeof(id) ~= "string" or not Items.Items[id] then return false end
 local storage = contents[chest]
 local equipped=not intoChest and chest:GetAttribute("Knockout") and typeof(key)=="string" and key:sub(1,9)=="Equipped|"
 if equipped then
  if not Inventory.TakeEquippedLoot(player,storage,id,requested,key) then return false end
 elseif not Inventory.Transfer(player,storage,id,requested,intoChest,key) then return false end
 refreshOwner(chest);notify(chest)
 return true
end
function Service.TakeAll(player)
 local chest=sessions[player]
 if not reachable(player,chest) then Service.Close(player); return false end
 if chest:GetAttribute("IsCorpse")~=true and chest:GetAttribute("Knockout")~=true then return false end
 local storage=contents[chest]
 for id in pairs(table.clone(storage.Items)) do Inventory.Transfer(player,storage,id,"All",false) end
 if chest:GetAttribute("Knockout") then
  for _,stack in ipairs(Rules.LootStacks(storage,Items.Items,true)) do
   if stack.EquipmentSlot and not stack.LootLocked then Inventory.TakeEquippedLoot(player,storage,stack.ID,1,stack.Key) end
  end
 end
 refreshOwner(chest);notify(chest)
  local available=false
 for _,stack in ipairs(lootStacks(chest)) do if not stack.LootLocked then available=true;break end end
 if not available then Service.Close(player) end
 return true
end
function Service.ValidateSessions()
 for player,chest in pairs(sessions) do if not reachable(player,chest) then Service.Close(player) end end
end
Players.PlayerRemoving:Connect(function(player) sessions[player] = nil end)
Players.PlayerAdded:Connect(function(player) player.CharacterRemoving:Connect(function() Service.Close(player) end) end)
return Service
