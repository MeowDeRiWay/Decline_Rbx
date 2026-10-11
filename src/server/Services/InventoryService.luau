local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemConfig = require(ReplicatedStorage.Shared.ItemConfig)
local Rules = require(ReplicatedStorage.Shared.InventoryRules)
local Visuals = require(script.Parent.EquipmentVisuals)
local Service = {}
local states = {}
local changed = Instance.new("BindableEvent")
Service.Changed = changed.Event
local function update(player)
 local state = states[player]
 if not state then return end
 if player.Character then
  player.Character:SetAttribute("LoadKg", Rules.Weight(state, ItemConfig.Items))
  Visuals.Apply(player.Character, state.Equipment.Hands)
 end
 changed:Fire(player)
end
function Service.Reset(player)
 states[player] = Rules.New()
 update(player)
end
function Service.RemovePlayer(player) states[player] = nil end
function Service.Add(player, id, count)
 local state = states[player]
 if not state or not Rules.Add(state, ItemConfig.Items, id, count) then return false end
 update(player)
 return true
end
function Service.Remove(player, id, count)
 local state = states[player]
 if not state or not Rules.Remove(state, id, count) then return false end
 update(player)
 return true
end
function Service.Equip(player, id)
 if typeof(id) ~= "string" or not ItemConfig.Items[id] or not Visuals.Validate(id) then return false end
 local state = states[player]
 if not state or not Rules.Equip(state, ItemConfig.Items, ItemConfig.Slots, id) then return false end
 update(player)
 return true
end
function Service.Unequip(player, slot)
 local state = states[player]
 if not state or not Rules.Unequip(state, ItemConfig.Items, ItemConfig.Slots, slot) then return false end
 update(player)
 return true
end
function Service.Transfer(player, storage, id, requested, intoStorage)
 local own = states[player]
 if not own then return false end
 local source, target = own, storage
 if not intoStorage then source, target = storage, own end
 if not Rules.Transfer(source, target, ItemConfig.Items, id, requested) then return false end
 update(player)
 return true
end
function Service.Snapshot(player)
 local state = states[player]
 if not state then return {Items = {}, Equipment = {}, Weight = 0} end
 return {Items = table.clone(state.Items), Equipment = table.clone(state.Equipment), Weight = Rules.Weight(state, ItemConfig.Items)}
end
function Service.Start()
 if Service.Started then return end
 Service.Started = true
 local function added(player)
  player.CharacterAdded:Connect(function() Service.Reset(player) end)
  Service.Reset(player)
 end
 Players.PlayerAdded:Connect(added)
 Players.PlayerRemoving:Connect(Service.RemovePlayer)
 for _, player in ipairs(Players:GetPlayers()) do added(player) end
end
return Service
