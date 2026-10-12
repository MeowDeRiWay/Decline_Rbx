local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Inventory = require(script.Parent.InventoryService)
local Rules = require(ReplicatedStorage.Shared.InventoryRules)
local Items = require(ReplicatedStorage.Shared.ItemConfig)
local Interaction = require(ReplicatedStorage.Shared.Interaction)
local Service = {}
local contents = setmetatable({}, {__mode = "k"})
local sessions = {}
local changed = Instance.new("BindableEvent")
Service.Changed = changed.Event
local function reachable(player, chest)
 if typeof(chest) ~= "Instance" or not chest:IsA("Model") or (chest.Name ~= "Chest" and chest:GetAttribute("IsCorpse") ~= true) or not chest:IsDescendantOf(workspace) or not chest:FindFirstChildWhichIsA("BasePart", true) then return false end
 local character = player.Character
 local humanoid = character and character:FindFirstChildOfClass("Humanoid")
 local root = character and character:FindFirstChild("HumanoidRootPart")
 if not root or not humanoid or humanoid.Health <= 0 or character:GetAttribute("Knockout") then return false end
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
 contents[model]=storage
 model:SetAttribute("IsCorpse",true)
 model:SetAttribute("CorpseType","Player")
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
function Service.Open(player, chest)
 if not reachable(player, chest) then return false end
 if not contents[chest] then contents[chest] = Rules.New() end
 sessions[player] = chest
 changed:Fire(player)
 return true
end
function Service.Close(player)
 sessions[player] = nil
 changed:Fire(player)
end
function Service.Snapshot(player)
 local chest = sessions[player]
 return {ChestOpen = chest ~= nil, Chest = chest, ChestReadOnly = chest ~= nil and chest:GetAttribute("IsCorpse") == true, ChestName = chest and (chest:GetAttribute("DisplayName") or chest.Name), ChestItems = chest and contents[chest] and table.clone(contents[chest].Items) or {}}
end
function Service.Transfer(player, id, requested, intoChest)
 local chest = sessions[player]
 if not reachable(player, chest) then Service.Close(player); return false end
 if intoChest and chest:GetAttribute("IsCorpse") == true then return false end
 if typeof(id) ~= "string" or not Items.Items[id] then return false end
 local storage = contents[chest]
 if not Inventory.Transfer(player, storage, id, requested, intoChest) then return false end
 notify(chest)
 return true
end
function Service.TakeAll(player)
 local chest=sessions[player]
 if not reachable(player,chest) then Service.Close(player); return false end
 if chest:GetAttribute("IsCorpse")~=true then return false end
 local storage=contents[chest]
 for id in pairs(table.clone(storage.Items)) do Inventory.Transfer(player,storage,id,"All",false) end
 notify(chest)
 if next(storage.Items)==nil then Service.Close(player) end
 return true
end
function Service.ValidateSessions()
 for player,chest in pairs(sessions) do if not reachable(player,chest) then Service.Close(player) end end
end
Players.PlayerRemoving:Connect(function(player) sessions[player] = nil end)
Players.PlayerAdded:Connect(function(player) player.CharacterRemoving:Connect(function() Service.Close(player) end) end)
return Service
