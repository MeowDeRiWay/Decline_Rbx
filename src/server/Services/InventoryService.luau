local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemConfig = require(ReplicatedStorage.Shared.ItemConfig)
local Rules = require(ReplicatedStorage.Shared.InventoryRules)
local CombatRules = require(ReplicatedStorage.Shared.CombatRules)
local Visuals = require(script.Parent.EquipmentVisuals)
local Service = {}
local states = {}
local holstered = {}
local Journal=require(script.Parent.JournalService)
local function rememberedPresent(player,state)
 local remembered=holstered[player]
 if not remembered then return false end
 for _,data in ipairs(state.Weapons[remembered.ID] or {}) do if data.UID==remembered.UID then return true end end
 return false
end
local changed = Instance.new("BindableEvent")
Service.Changed = changed.Event
local function update(player)
 local state = states[player]
 if not state then return end
 local absorption,resistance=0,0
 for _,id in pairs(state.Equipment) do
  local armor=ItemConfig.Items[id].Armor
  if armor then absorption+=armor.Absorption or 0;resistance+=armor.Resistance or 0 end
 end
 player:SetAttribute("ArmorAbsorption",absorption);player:SetAttribute("ArmorResistance",math.clamp(resistance,0,.9))
 if player.Character then
  player.Character:SetAttribute("LoadKg", Rules.Weight(state, ItemConfig.Items,player:GetAttribute("AmmoWeightMultiplier") or 1))
  Visuals.Apply(player.Character, state.Equipment.Hands)
  player.Character:SetAttribute("MedicineItem",state.Equipment.Medicine or "")
  player.Character:SetAttribute("MedicineCount",(state.Items.Bandage or 0)+(state.Equipment.Medicine=="Bandage" and 1 or 0))
  player.Character:SetAttribute("WeaponCondition", state.EquipmentCondition.Hands or 0)
 end
 changed:Fire(player)
end
function Service.Reset(player)
 holstered[player]=nil
 states[player] = Rules.New()
 update(player)
end
function Service.ExtractAll(player)
 holstered[player]=nil
 local state=states[player] or Rules.New()
 for _,slot in ipairs(ItemConfig.Slots) do
  if state.Equipment[slot] then Rules.Unequip(state,ItemConfig.Items,ItemConfig.Slots,slot) end
 end
 states[player]=Rules.New()
 update(player)
 return state
end
function Service.RemovePlayer(player) states[player] = nil;holstered[player]=nil end
function Service.Add(player, id, count, conditions,weaponData)
 local state = states[player]
 if not state or not Rules.Add(state, ItemConfig.Items, id, count, conditions,weaponData) then return false end
 update(player)
 return true
end
function Service.Remove(player, id, count,key)
 local state = states[player]
 if not state then return false end
 local ok, conditions,data = Rules.Remove(state, id, count,key)
 if not ok then return false end
 if holstered[player] and not rememberedPresent(player,state) then holstered[player]=nil end
 update(player)
 return true, conditions,data
end
function Service.Equip(player, id,key,uid)
 if typeof(id) ~= "string" or not ItemConfig.Items[id] or not Visuals.Validate(id) then return false end
 local requirements=ItemConfig.Items[id].Requirements
 if requirements and not require(script.Parent.ProgressionService).Meets(player,requirements) then return false end
 local state = states[player]
 if not state or not Rules.Equip(state, ItemConfig.Items, ItemConfig.Slots, id,key,uid) then return false end
 update(player)
 return true
end
function Service.Unequip(player, slot)
 local state = states[player]
 if not state or not Rules.Unequip(state, ItemConfig.Items, ItemConfig.Slots, slot) then return false end
 update(player)
 return true
end
function Service.UseMedicine(player)
 local state=states[player]
 if not state or state.Equipment.Medicine~="Bandage" then return false end
 state.Equipment.Medicine=nil;state.EquipmentCondition.Medicine=nil
 if (state.Items.Bandage or 0)>0 then Rules.Equip(state,ItemConfig.Items,ItemConfig.Slots,"Bandage") end
 update(player)
 return true
end
function Service.ToggleHolster(player)
 local state=states[player]
 if not state then return false end
 local held=state.Equipment.Hands
 if held then
  if not Service.Unequip(player,"Hands") then return false end
  holstered[player]={ID=held,UID=state.Weapons[held][#state.Weapons[held]].UID}
  return true
 end
 local remembered=holstered[player]
 if not remembered then return false end
 local id=remembered.ID
 for index,data in ipairs(state.Weapons[id] or {}) do
  if data.UID==remembered.UID then
   local key=Rules.StackKey(id,state.Conditions[id][index],data)
   if Service.Equip(player,id,key,remembered.UID) then holstered[player]=nil;return true end
  end
 end
 holstered[player]=nil
 return false
end
function Service.Transfer(player, storage, id, requested, intoStorage,key)
 local own = states[player]
 if not own then return false end
 local source, target = own, storage
 if not intoStorage then source, target = storage, own end
 if not Rules.Transfer(source, target, ItemConfig.Items, id, requested,key) then return false end
 if intoStorage and holstered[player] and not rememberedPresent(player,own) then holstered[player]=nil end
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
function Service.GetMagazine(player)
 local state=states[player]
 return state and state.EquipmentWeapon.Hands
end
function Service.SaveMagazine(player,loaded,kind,mode,ready)
 local data=Service.GetMagazine(player)
 if not data then return end
 data.Loaded=loaded;data.Type=kind;data.Mode=mode
 if ready then data.ReadyAt=ready end
 update(player)
end
function Service.ReloadMagazine(player)
 local state=states[player];local data=Service.GetMagazine(player)
 local gun=state and ItemConfig.Items[state.Equipment.Hands].Firearm
 if not data or not gun then return end
 local ammo="Ammo"..gun.Caliber..data.Type
 local count=math.min(gun.Magazine-data.Loaded,state.Items[ammo] or 0)
 if count>0 then Rules.Remove(state,ammo,count);data.Loaded+=count;update(player) end
end
function Service.UnloadMagazine(player,kind)
 local state=states[player];local data=Service.GetMagazine(player)
 if not data then return end
 local gun=ItemConfig.Items[state.Equipment.Hands].Firearm
 if data.Loaded>0 then Rules.Add(state,ItemConfig.Items,"Ammo"..gun.Caliber..data.Type,data.Loaded) end
 data.Loaded=0;data.Type=kind;update(player)
end
function Service.GetWeapon(player)
 local state = states[player]
 return state and CombatRules.GetWeapon(state,ItemConfig.Items)
end
function Service.UseWeapon(player)
 local state = states[player]
 if not state then return nil end
 local id=state.Equipment.Hands
 local before=state.EquipmentCondition.Hands or 0
 local weapon = CombatRules.Use(state,ItemConfig.Items)
 if not weapon then return nil end
 if before>0 and (state.EquipmentCondition.Hands or 0)<=0 then Journal.Send(player,(ItemConfig.Items[id].Name or id).." broke.") end
 update(player)
 return weapon
end
function Service.Snapshot(player)
 local state = states[player]
 if not state then return {Items = {}, Equipment = {}, Weight = 0, CraftTools = {}} end
 return {Items = table.clone(state.Items), Equipment = table.clone(state.Equipment), Stacks=Rules.Stacks(state,ItemConfig.Items), Weight = Rules.Weight(state, ItemConfig.Items,player:GetAttribute("AmmoWeightMultiplier") or 1), CraftTools = craftTools(state)}
end
function Service.Start()
 if Service.Started then return end
 Service.Started = true
 local function added(player)
  player:GetAttributeChangedSignal("AmmoWeightMultiplier"):Connect(function() update(player) end)
  player.CharacterAdded:Connect(function() Service.Reset(player) end)
  Service.Reset(player)
 end
 Players.PlayerAdded:Connect(added)
 Players.PlayerRemoving:Connect(Service.RemovePlayer)
 for _, player in ipairs(Players:GetPlayers()) do added(player) end
end
return Service
