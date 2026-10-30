local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Service = require(script.Parent.Services.InventoryService)
local WorldItems = require(script.Parent.Services.WorldItemService)
local Chests = require(script.Parent.Services.ChestService)
local Crafting = require(script.Parent.Services.CraftingService)
local Farming=require(script.Parent.Services.FarmingService)
local Beds=require(script.Parent.Services.HospitalBedService)
local Animation=require(script.Parent.Services.InteractionAnimationService)
local ItemConfig=require(ReplicatedStorage.Shared.ItemConfig)
local Hands=require(script.Parent.Services.HandActionService)
local Consumables = require(script.Parent.Services.ConsumableService)
local folder = Instance.new("Folder")
folder.Name, folder.Parent = "InventoryRemotes", ReplicatedStorage
local action = Instance.new("RemoteEvent")
action.Name, action.Parent = "Action", folder
local state = Instance.new("RemoteEvent")
state.Name, state.Parent = "State", folder
local function publish(player)
 if player.Parent ~= Players then return end
 local snapshot = Service.Snapshot(player)
 for key,value in pairs(Chests.Snapshot(player)) do snapshot[key] = value end
 for key,value in pairs(Crafting.Snapshot(player)) do snapshot[key]=value end
 state:FireClient(player, snapshot)
end
Service.Changed:Connect(publish)
Chests.Changed:Connect(publish)
Crafting.Changed:Connect(publish)
task.spawn(function()
 while true do task.wait(0.5); Chests.ValidateSessions(); Crafting.ValidateSessions() end
end)
Service.Start()
local lastAction = {}
Players.PlayerRemoving:Connect(function(player) lastAction[player] = nil end)
action.OnServerEvent:Connect(function(player, command, value, amount)
 if command == "CloseChest" then Crafting.Close(player); Chests.Close(player); return end
 local now = os.clock()
 if now - (lastAction[player] or -math.huge) < 0.1 then return end
 lastAction[player] = now
 if command == "Request" then publish(player); return end
 if player:GetAttribute("TradeOpen") then return end
 if player:GetAttribute("AttributesConfirmed")~=true then return end
 local character = player.Character
 local humanoid = character and character:FindFirstChildOfClass("Humanoid")
 if not humanoid or humanoid.Health <= 0 or character:GetAttribute("Knockout") then return end
 if character:GetAttribute("HandsBusy") then return end
 if character:GetAttribute("InteractionLocked") and command~="TakeAll" and command~="TransferOut" then return end
 if command=="HospitalBed" then Crafting.Close(player);Chests.Close(player);Beds.Use(player,value);return end
 if character:GetAttribute("HospitalResting") then return end
 local key
 if typeof(value)=="table" then
  if typeof(value.ID)~="string" or typeof(value.Key)~="string" or #value.Key>160 then return end
  key=value.Key;value=value.ID
 end
 if command == "Equip" then Service.Equip(player, value,key)
 elseif command == "WeaponSlot" then Hands.Switch(player,value)
 elseif command == "ReadyMedicine" then Hands.Medicine(player,value==true)
 elseif command == "Holster" then Service.ToggleHolster(player)
 elseif command == "Unequip" then Service.Unequip(player, value)
 elseif command == "Pickup" then Animation.Reach(player,value,ItemConfig.PickupDistance,function() WorldItems.Pickup(player,value) end)
 elseif command == "Drop" then WorldItems.Drop(player, value, amount,key)
 elseif command == "Farm" then Farming.Use(player,value)
 elseif command == "PlantCrop" and amount=="Potato" then Farming.Use(player,value,amount)
 elseif command == "Consume" or command == "Eat" then Consumables.Consume(player, value)
 elseif command == "PourOut" then Consumables.PourOut(player,value)
 elseif command == "OpenStove" then Chests.Close(player); Crafting.Open(player,value)
 elseif command == "Cook" then Crafting.Cook(player,value,amount)
 elseif command == "CollectRecipe" then Crafting.CollectRecipe(player,value,amount)
 elseif command == "CollectCooked" then Crafting.Collect(player,value,amount)
 elseif command == "OpenChest" then
  Crafting.Close(player)
  if typeof(value)=="Instance" and value:GetAttribute("IsCorpse") then Chests.Open(player,value)
  else Animation.Reach(player,value,ItemConfig.PickupDistance,function() Chests.Open(player,value) end) end
 elseif command == "TakeAll" then Chests.TakeAll(player)
 elseif command == "TransferIn" then Chests.Transfer(player, value, amount, true,key)
 elseif command == "TransferOut" then Chests.Transfer(player, value, amount, false,key) end
end)
