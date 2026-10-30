local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemConfig = require(ReplicatedStorage.Shared.ItemConfig)
local Rules = require(ReplicatedStorage.Shared.InventoryRules)
local CombatRules = require(ReplicatedStorage.Shared.CombatRules)
local Visuals = require(script.Parent.EquipmentVisuals)
local ArmorVisuals=require(script.Parent.ArmorVisuals)
local BackVisuals=require(script.Parent.BackVisuals)
local HolsterVisuals=require(script.Parent.HolsterVisuals)
local Service = {}
local states = {}
local disconnected = {}
local Journal=require(script.Parent.JournalService)
local changed = Instance.new("BindableEvent")
Service.Changed = changed.Event
local function update(player)
 local state = states[player]
 if not state then return end
 Rules.ReconcileEquipment(state,ItemConfig.Items,ItemConfig.Slots)
 if not state.Equipment.Medicine then state.MedicalHeld=nil end
 local absorption,resistance=0,0
 local body=state.Equipment.Body and ItemConfig.Items[state.Equipment.Body]
 local armor=body and body.Armor
 if armor then absorption=armor.Absorption or 0;resistance=armor.Resistance or 0 end
 local handSlot=Rules.HandSlot(state)
 local handItem=state.MedicalHeld and state.Equipment.Medicine or Rules.HandItem(state)
 player:SetAttribute("HandsEquipped",handItem or "");player:SetAttribute("ArmorAbsorption",absorption);player:SetAttribute("ArmorResistance",math.clamp(resistance,0,.9))
 local back=state.Equipment.Back and ItemConfig.Items[state.Equipment.Back]
 local carryBonus=back and back.CarryBonusKg or 0
 local baseCarry=player:GetAttribute("BaseCarryLimitKg")
 if baseCarry==nil then baseCarry=player:GetAttribute("CarryLimitKg") or 20;player:SetAttribute("BaseCarryLimitKg",baseCarry) end
 player:SetAttribute("EquipmentCarryBonusKg",carryBonus)
 player:SetAttribute("CarryLimitKg",baseCarry+carryBonus)
 if player.Character then
  player.Character:SetAttribute("CarryLimitKg",baseCarry+carryBonus)
  BackVisuals.Apply(player.Character,state.Equipment.Back,state.Equipment.Back and Visuals.Template(state.Equipment.Back),back)
  player.Character:SetAttribute("LoadKg", Rules.Weight(state, ItemConfig.Items,player:GetAttribute("AmmoWeightMultiplier") or 1,player:GetAttribute("EquippedWeaponWeightMultiplier")))
  player.Character:SetAttribute("ActiveWeaponSlot",state.ActiveWeaponSlot)
  player.Character:SetAttribute("MedicalHeld",state.MedicalHeld==true and state.Equipment.Medicine~=nil)
  for _,slot in ipairs({"PrimaryWeapon","SecondaryWeapon"}) do
   player.Character:SetAttribute(slot.."Item",state.Equipment[slot] or "")
   HolsterVisuals.Apply(player.Character,slot,state.ActiveWeaponSlot~=slot and state.Equipment[slot] or nil,Visuals.Template)
  end
  Visuals.Apply(player.Character,handItem)
  ArmorVisuals.Apply(player.Character,state.Equipment.Body,state.Equipment.Body and Visuals.Template(state.Equipment.Body))
  player.Character:SetAttribute("MedicineItem",state.Equipment.Medicine or "")
  player.Character:SetAttribute("MedicineCount",(state.Items[state.Equipment.Medicine or ""] or 0)+(state.Equipment.Medicine and 1 or 0))
  player.Character:SetAttribute("WeaponCondition", state.EquipmentCondition[handSlot] or 0)
 end
 changed:Fire(player)
end
function Service.Reset(player)
 states[player] = Rules.New()
 update(player)
end
function Service.ExtractAll(player)
 local state=states[player] or Rules.New()
 Rules.ReconcileEquipment(state,ItemConfig.Items,ItemConfig.Slots)
 for _,slot in ipairs(ItemConfig.Slots) do
  if state.Equipment[slot] then Rules.Unequip(state,ItemConfig.Items,ItemConfig.Slots,slot) end
 end
 state.ActiveWeaponSlot=nil;state.MedicalHeld=nil
 states[player]=Rules.New()
 update(player)
 return state
end
function Service.RemovePlayer(player)
 -- Cancel/refund before detaching the inventory, regardless of event callback order.
 require(script.Parent.CraftingService).Close(player)
 disconnected[player.UserId]=states[player] or disconnected[player.UserId]
 states[player]=nil
end
function Service.Export(player) return states[player] or disconnected[player.UserId] end
function Service.ForgetOffline(userID,state)
 if disconnected[userID]==state then disconnected[userID]=nil end
end
function Service.CorpseStorage(state)
 state=state or Rules.New()
 Rules.ReconcileEquipment(state,ItemConfig.Items,ItemConfig.Slots)
 for _,slot in ipairs(ItemConfig.Slots) do
  if state.Equipment[slot] then Rules.Unequip(state,ItemConfig.Items,ItemConfig.Slots,slot) end
 end
 state.ActiveWeaponSlot=nil;state.MedicalHeld=nil
 return state
end
function Service.Add(player, id, count, conditions,weaponData)
 if ItemConfig.Items[id] and ItemConfig.Items[id].Currency then return require(script.Parent.EconomyService).Credit(player,count) end
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
 update(player)
 return true, conditions,data
end
function Service.Equip(player, id,key,uid)
 if player.Character and player.Character:GetAttribute("CarryingUserId") and ItemConfig.Items[id] and (ItemConfig.Items[id].Slot=="Hands" or ItemConfig.Items[id].Weapon) then return false end
 if player.Character and (player.Character:GetAttribute("InteractionLocked") or player.Character:GetAttribute("HandsBusy")) then return false end
 if typeof(id) ~= "string" or not ItemConfig.Items[id] or not Visuals.Validate(id) then return false end
 local requirements=ItemConfig.Items[id].Requirements
 if requirements and not require(script.Parent.ProgressionService).Meets(player,requirements) then Journal.Send(player,"Item requirements are not met.");return false end
 local state = states[player]
 if not state or Rules.Available(state,id,key)<1 then return false end
 local slot=ItemConfig.Items[id].Slot
 if state.ActiveWeaponSlot==slot or (slot=="Hands" and (state.ActiveWeaponSlot or state.MedicalHeld)) or (slot=="Medicine" and state.MedicalHeld) then
  return require(script.Parent.HandActionService).Stow(player,function() Service.Equip(player,id,key,uid) end)
 end
 if not Rules.Equip(state, ItemConfig.Items, ItemConfig.Slots, id,key,uid) then return false end
 update(player)
 return true
end
function Service.Unequip(player, slot)
 if player.Character and (player.Character:GetAttribute("InteractionLocked") or player.Character:GetAttribute("HandsBusy")) then return false end
 local state = states[player]
 if not state then return false end
 if state.ActiveWeaponSlot==slot or (slot=="Medicine" and state.MedicalHeld) then
  return require(script.Parent.HandActionService).Stow(player,function() Service.Unequip(player,slot) end)
 end
 if not Rules.Unequip(state, ItemConfig.Items, ItemConfig.Slots, slot) then return false end
 update(player)
 return true
end
-- Atomic container conversion: held buckets stay held; pocket bottles stay in pockets.
function Service.ReplaceOne(player,source,target)
 local state=states[player]
 if not state or not ItemConfig.Items[source] or not ItemConfig.Items[target] then return false end
 local held=state.Equipment.Hands==source
 if held then Rules.Unequip(state,ItemConfig.Items,ItemConfig.Slots,"Hands") end
 if not Rules.Remove(state,source,1) then return false end
 Rules.Add(state,ItemConfig.Items,target,1)
 if held then Rules.Equip(state,ItemConfig.Items,ItemConfig.Slots,target) end
 update(player);return true
end
function Service.UseMedicine(player)
 local state=states[player]
 if not state or (state.Equipment.Medicine~="Bandage" and state.Equipment.Medicine~="GreatBandage" and state.Equipment.Medicine~="SterileBandage" and state.Equipment.Medicine~="Antiseptic") then return false end
 local medicine=state.Equipment.Medicine
 state.Equipment.Medicine=nil;state.EquipmentCondition.Medicine=nil
 if medicine=="Antiseptic" then Rules.Add(state,ItemConfig.Items,"EmptyBottle",1) end
 if (state.Items[medicine] or 0)>0 then Rules.Equip(state,ItemConfig.Items,ItemConfig.Slots,medicine) end
 update(player)
 return true
end
-- Only HandActionService calls these commits, at the visual handoff point.
function Service.ClearHands(player)
 local state=states[player];if not state then return false end
 if state.ActiveWeaponSlot then state.LastWeaponSlot=state.ActiveWeaponSlot end
 state.ActiveWeaponSlot=nil;state.MedicalHeld=nil
 if state.Equipment.Hands then Rules.Unequip(state,ItemConfig.Items,ItemConfig.Slots,"Hands") end
 update(player);return true
end
function Service.CanActivateWeapon(player,slot)
 local state=states[player]
 if not state or (slot~="PrimaryWeapon" and slot~="SecondaryWeapon") or not state.Equipment[slot] then return false end
 local id=state.Equipment[slot];local definition=ItemConfig.Items[id]
 if definition.Slot~=slot or not Visuals.Validate(id) then return false end
 if definition.Requirements and not require(script.Parent.ProgressionService).Meets(player,definition.Requirements) then return false end
 return true
end
function Service.ActivateWeapon(player,slot)
 if not Service.CanActivateWeapon(player,slot) then return false end
 local state=states[player]
 state.MedicalHeld=nil;state.ActiveWeaponSlot=slot;state.LastWeaponSlot=slot
 update(player);return true
end
function Service.ActivateMedicine(player)
 local state=states[player];if not state or not state.Equipment.Medicine then return false end
 state.ActiveWeaponSlot=nil;state.MedicalHeld=true;update(player);return true
end
function Service.ToggleHolster(player)
 return require(script.Parent.HandActionService).Toggle(player)
end
function Service.Transfer(player, storage, id, requested, intoStorage,key)
 local own = states[player]
 if not own then return false end
 local source, target = own, storage
 if not intoStorage then source, target = storage, own end
 if not Rules.Transfer(source, target, ItemConfig.Items, id, requested,key) then return false end
 update(player)
 return true
end
function Service.TakeEquippedLoot(player,source,id,requested,key)
 local own=states[player]
 if not own or not source or not Rules.TransferEquipment(source,own,ItemConfig.Items,id,requested,key) then return false end
 update(player);return true
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
  if item and item.CraftTool then
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
 return state and state.EquipmentWeapon[Rules.HandSlot(state)]
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
 local definition=state and ItemConfig.Items[Rules.HandItem(state)]
 local gun=definition and definition.Firearm
 if not data or not gun then return end
 local ammo="Ammo"..gun.Caliber..data.Type
 local count=math.min(gun.Magazine-data.Loaded,state.Items[ammo] or 0)
 if count>0 then Rules.Remove(state,ammo,count);data.Loaded+=count;update(player) end
end
function Service.UnloadMagazine(player,kind)
 local state=states[player];local data=Service.GetMagazine(player)
 if not data then return end
 local definition=ItemConfig.Items[Rules.HandItem(state)]
 local gun=definition and definition.Firearm
 if not gun then return end
 if data.Loaded>0 then Rules.Add(state,ItemConfig.Items,"Ammo"..gun.Caliber..data.Type,data.Loaded) end
 data.Loaded=0;data.Type=kind;update(player)
end
function Service.Refresh(player) update(player) end
function Service.GetWeapon(player)
 if player.Character and (player.Character:GetAttribute("CarryingUserId") or player.Character:GetAttribute("HandsBusy") or player.Character:GetAttribute("MedicalHeld")) then return nil end
 local state = states[player]
 local definition=state and ItemConfig.Items[Rules.HandItem(state)]
 if definition and definition.Requirements and not require(script.Parent.ProgressionService).Meets(player,definition.Requirements) then return nil end
 return state and CombatRules.GetWeapon(state,ItemConfig.Items)
end
function Service.UseWeapon(player)
 -- Combat remains functional, with no condition mutation or wear notification.
 return Service.GetWeapon(player)
end
function Service.Snapshot(player)
 local state = states[player]
 if not state then return {Items = {}, Equipment = {}, Weight = 0, CraftTools = {}} end
 return {Items = table.clone(state.Items), Equipment = table.clone(state.Equipment), ActiveWeaponSlot=state.ActiveWeaponSlot, MedicalHeld=state.MedicalHeld, Stacks=Rules.Stacks(state,ItemConfig.Items), Weight = Rules.Weight(state, ItemConfig.Items,player:GetAttribute("AmmoWeightMultiplier") or 1,player:GetAttribute("EquippedWeaponWeightMultiplier")), CraftTools = craftTools(state)}
end
function Service.Start()
 if Service.Started then return end
 Service.Started = true
 local function added(player)
  player:GetAttributeChangedSignal("AmmoWeightMultiplier"):Connect(function() update(player) end)
  player:GetAttributeChangedSignal("EquippedWeaponWeightMultiplier"):Connect(function() update(player) end)
  player.CharacterAdded:Connect(function(character)
   if character:GetAttribute("ReturningSession") then update(player) else Service.Reset(player) end
  end)
  if disconnected[player.UserId] then states[player]=disconnected[player.UserId];disconnected[player.UserId]=nil;update(player)
  else Service.Reset(player) end
 end
 Players.PlayerAdded:Connect(added)
 Players.PlayerRemoving:Connect(Service.RemovePlayer)
 for _, player in ipairs(Players:GetPlayers()) do added(player) end
end
return Service
