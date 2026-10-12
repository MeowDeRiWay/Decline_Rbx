local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemConfig = require(ReplicatedStorage.Shared.ItemConfig)
local Rules = require(ReplicatedStorage.Shared.InventoryRules)
local CombatRules = require(ReplicatedStorage.Shared.CombatRules)
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
  player.Character:SetAttribute("WeaponCondition", state.EquipmentCondition.Hands or 0)
 end
 changed:Fire(player)
end
function Service.Reset(player)
 states[player] = Rules.New()
 update(player)
end
function Service.ExtractAll(player)
 local state=states[player] or Rules.New()
 for _,slot in ipairs(ItemConfig.Slots) do
  if state.Equipment[slot] then Rules.Unequip(state,ItemConfig.Items,ItemConfig.Slots,slot) end
 end
 states[player]=Rules.New()
 update(player)
 return state
end
function Service.RemovePlayer(player) states[player] = nil end
function Service.Add(player, id, count, conditions)
 local state = states[player]
 if not state or not Rules.Add(state, ItemConfig.Items, id, count, conditions) then return false end
 update(player)
 return true
end
function Service.Remove(player, id, count)
 local state = states[player]
 if not state then return false end
 local ok, conditions = Rules.Remove(state, id, count)
 if not ok then return false end
 update(player)
 return true, conditions
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
function Service.ConsumeIngredients(player,recipe,count)
 local state=states[player]
 if not state then return false end
 for id,needed in pairs(recipe.Ingredients) do
  if (state.Items[id] or 0)<needed*count then return false end
 end
 for id,needed in pairs(recipe.Ingredients) do Rules.Remove(state,id,needed*count) end
 update(player)
 return true
end
local function craftTools(state)
 local tools={}
 local function add(id,condition)
  local item=ItemConfig.Items[id]
  if item and item.CraftTool and (not item.Weapon or (condition or 0)>0) then
   tools[item.CraftTool]=math.max(tools[item.CraftTool] or 0,item.CraftSpeed or 1)
  end
 end
 for slot,id in pairs(state.Equipment) do add(id,state.EquipmentCondition[slot]) end
 for id in pairs(state.Items) do
  local item=ItemConfig.Items[id]
  if item and item.Weapon then for _,condition in ipairs(state.Conditions[id] or {}) do add(id,condition) end
  else add(id,nil) end
 end
 return tools
end
function Service.GetWeapon(player)
 local state = states[player]
 return state and CombatRules.GetWeapon(state,ItemConfig.Items)
end
function Service.UseWeapon(player)
 local state = states[player]
 if not state then return nil end
 local weapon = CombatRules.Use(state,ItemConfig.Items)
 if not weapon then return nil end
 update(player)
 return weapon
end
function Service.Snapshot(player)
 local state = states[player]
 if not state then return {Items = {}, Equipment = {}, Weight = 0, CraftTools = {}} end
 return {Items = table.clone(state.Items), Equipment = table.clone(state.Equipment), Weight = Rules.Weight(state, ItemConfig.Items), CraftTools = craftTools(state)}
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
