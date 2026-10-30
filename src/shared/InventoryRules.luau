local Rules = {}
local serial=0
function Rules.HandSlot(state) return state.ActiveWeaponSlot or "Hands" end
function Rules.HandItem(state) return state.Equipment[Rules.HandSlot(state)] end
function Rules.New()
 return {Items = {}, Equipment = {}, Conditions = {}, EquipmentCondition = {}, Weapons = {}, EquipmentWeapon = {}}
end
local function quantity(value)
 return typeof(value) == "number" and value == value and value > 0 and value < math.huge and value == math.floor(value)
end
function Rules.DropAmount(available, requested)
 if not quantity(available) then return nil end
 if requested == "All" then return available end
 if requested == nil then requested = 1 end
 if not quantity(requested) or requested > available then return nil end
 return requested
end
function Rules.StackKey(id,condition,data)
 data=data or {}
 return string.format("%s|%d|%d|%s",id,condition or 0,data.Loaded or 0,data.Type or "FMJ")
end
function Rules.Stacks(state,definitions)
 local result,groups={},{}
 for id,count in pairs(state.Items) do
  if definitions[id].Weapon then
   for index,condition in ipairs(state.Conditions[id] or {}) do
    local data=state.Weapons and state.Weapons[id] and state.Weapons[id][index] or {}
    local key=Rules.StackKey(id,condition,data)
    if not groups[key] then
     groups[key]={ID=id,Key=key,Count=0,Condition=condition,Loaded=data.Loaded or 0,AmmoType=data.Type or "FMJ"}
     table.insert(result,groups[key])
    end
    groups[key].Count+=1
   end
  else table.insert(result,{ID=id,Key=id,Count=count}) end
 end
 table.sort(result,function(a,b) return a.Key<b.Key end)
 return result
end
function Rules.Available(state,id,key)
 if not key then return state.Items[id] or 0 end
 if not state.Conditions[id] then return key==id and (state.Items[id] or 0) or 0 end
 local count=0
 for index,condition in ipairs(state.Conditions[id]) do
  local data=state.Weapons and state.Weapons[id] and state.Weapons[id][index]
  if Rules.StackKey(id,condition,data)==key then count+=1 end
 end
 return count
end
function Rules.Add(state, definitions, id, amount, conditions, weaponData)
 if typeof(id) ~= "string" or not definitions[id] or not quantity(amount) then return false end
 local weapon = definitions[id].Weapon
 if weapon then
  if conditions then
   if typeof(conditions) ~= "table" or #conditions ~= amount then return false end
   for _,value in ipairs(conditions) do
    if typeof(value) ~= "number" or value ~= value or value < 0 or value > weapon.MaxUses or value ~= math.floor(value) then return false end
   end
  end
  if weaponData then
   if typeof(weaponData)~="table" or #weaponData~=amount then return false end
   for _,data in ipairs(weaponData) do
    if typeof(data)~="table" or (data.Type~="FMJ" and data.Type~="AP") or typeof(data.Loaded)~="number" or data.Loaded~=math.floor(data.Loaded) or data.Loaded<0 or data.Loaded>(definitions[id].Firearm and definitions[id].Firearm.Magazine or 0) then return false end
   end
  end
  state.Weapons=state.Weapons or {};state.Weapons[id]=state.Weapons[id] or {}
  state.Conditions[id] = state.Conditions[id] or {}
  for i=1,amount do
   serial+=1
   local data=weaponData and table.clone(weaponData[i]) or {Loaded=0,Type="FMJ",Mode="Auto"}
   if definitions[id].Firearm and definitions[id].Firearm.SingleOnly then data.Mode="Single" end
   data.UID=data.UID or serial
   table.insert(state.Weapons[id],data)
   table.insert(state.Conditions[id], conditions and conditions[i] or weapon.MaxUses)
  end
 end
 state.Items[id] = (state.Items[id] or 0) + amount
 return true
end
function Rules.Remove(state,id,amount,key,uid)
 if typeof(id)~="string" or not quantity(amount) or Rules.Available(state,id,key)<amount then return false end
 if uid then
  local found=false
  for index,data in ipairs(state.Weapons[id] or {}) do
   if data.UID==uid and (not key or Rules.StackKey(id,state.Conditions[id][index],data)==key) then found=true end
  end
  if not found or amount~=1 then return false end
 end
 local removed,data=nil,nil
 if state.Conditions[id] then
  removed,data={},{}
  local list=state.Weapons and state.Weapons[id] or {}
  for index=#state.Conditions[id],1,-1 do
   if #removed>=amount then break end
   if (not uid or list[index].UID==uid) and (not key or Rules.StackKey(id,state.Conditions[id][index],list[index])==key) then
    table.insert(removed,table.remove(state.Conditions[id],index))
    table.insert(data,table.remove(list,index) or {Loaded=0,Type="FMJ"})
   end
  end
  if #state.Conditions[id]==0 then state.Conditions[id]=nil;state.Weapons[id]=nil end
 end
 local remaining=state.Items[id]-amount
 state.Items[id]=remaining>0 and remaining or nil
 return true,removed,data
end
function Rules.Equip(state, definitions, slots, id, key,uid)
 local item = typeof(id) == "string" and definitions[id]
 if not item or not table.find(slots, item.Slot) or Rules.Available(state,id,key) < 1 then return false end
 local previous = state.Equipment[item.Slot]
 local previousCondition = state.EquipmentCondition[item.Slot]
 local previousData=state.EquipmentWeapon and state.EquipmentWeapon[item.Slot]
 local ok,removed,data = Rules.Remove(state, id, 1,key,uid)
 if not ok then return false end
 if previous then Rules.Add(state, definitions, previous, 1, previousCondition ~= nil and {previousCondition} or nil,previousData and {previousData}) end
 state.EquipmentWeapon=state.EquipmentWeapon or {}
 state.EquipmentWeapon[item.Slot]=data and data[1] or nil
 state.EquipmentCondition[item.Slot] = removed and removed[1] or nil
 state.Equipment[item.Slot] = id
 return true
end
function Rules.Unequip(state, definitions, slots, slot)
 if typeof(slot) ~= "string" or not table.find(slots, slot) then return false end
 local id = state.Equipment[slot]
 if not id then return false end
 Rules.Add(state, definitions, id, 1, state.EquipmentCondition[slot] ~= nil and {state.EquipmentCondition[slot]} or nil,state.EquipmentWeapon and state.EquipmentWeapon[slot] and {state.EquipmentWeapon[slot]})
 if state.EquipmentWeapon then state.EquipmentWeapon[slot]=nil end
 state.EquipmentCondition[slot] = nil
 state.Equipment[slot] = nil
 return true
end
-- Return items from retired slots to inventory without losing their metadata.
function Rules.ReconcileEquipment(state,definitions,slots)
 -- Migrate an older session's held weapon without copying its unique magazine.
 local held=state.Equipment.Hands
 local target=held and definitions[held] and definitions[held].Slot
 if target=="PrimaryWeapon" or target=="SecondaryWeapon" then
  if not state.Equipment[target] then
   state.Equipment[target]=held;state.EquipmentCondition[target]=state.EquipmentCondition.Hands
   state.EquipmentWeapon[target]=state.EquipmentWeapon.Hands;state.ActiveWeaponSlot=target
   state.Equipment.Hands=nil;state.EquipmentCondition.Hands=nil;state.EquipmentWeapon.Hands=nil
  else Rules.Unequip(state,definitions,slots,"Hands") end
 end
 if state.ActiveWeaponSlot and not state.Equipment[state.ActiveWeaponSlot] then state.ActiveWeaponSlot=nil end
 for slot,id in pairs(state.Equipment) do
  if not table.find(slots,slot) and definitions[id] then
   local condition=state.EquipmentCondition[slot]
   local data=state.EquipmentWeapon and state.EquipmentWeapon[slot]
   if Rules.Add(state,definitions,id,1,condition~=nil and {condition} or nil,data and {data} or nil) then
    state.Equipment[slot]=nil;state.EquipmentCondition[slot]=nil
    if state.EquipmentWeapon then state.EquipmentWeapon[slot]=nil end
   end
  end
 end
end
function Rules.Weight(state, definitions, ammoMultiplier,equippedMultiplier)
 local total = 0
 for id, count in pairs(state.Items) do total += (definitions[id].Weight or 0) * count * (definitions[id].Ammo and (ammoMultiplier or 1) or 1) end
 for slot, id in pairs(state.Equipment) do total += (definitions[id].Weight or 0)*(definitions[id].Weapon and slot==Rules.HandSlot(state) and (equippedMultiplier or 1) or 1) end
 local function magazine(id,data)
  local gun=definitions[id].Firearm
  local ammo=gun and definitions["Ammo"..gun.Caliber..(data.Type or "FMJ")]
  if ammo then total+=(data.Loaded or 0)*ammo.Weight*(ammoMultiplier or 1) end
 end
 for id,list in pairs(state.Weapons or {}) do for _,data in ipairs(list) do magazine(id,data) end end
 for slot,data in pairs(state.EquipmentWeapon or {}) do magazine(state.Equipment[slot],data) end
 return total
end
local function equippedStack(state,definitions,slot,id)
 local item=definitions[id]
 if not item or item.Lootable==false then return nil end
 local condition=state.EquipmentCondition[slot]
 local data=state.EquipmentWeapon and state.EquipmentWeapon[slot] or {}
 return {ID=id,Key="Equipped|"..slot.."|"..Rules.StackKey(id,condition,data).."|"..tostring(data.UID or ""),Count=1,EquipmentSlot=slot,Condition=condition,Loaded=data.Loaded or 0,AmmoType=data.Type or "FMJ"}
end
-- Read-only presentation: worn equipment never enters the patient's pockets.
function Rules.LootStacks(state,definitions)
 local stacks=Rules.Stacks(state,definitions)
 for slot,id in pairs(state.Equipment) do
  local stack=equippedStack(state,definitions,slot,id)
  if stack then table.insert(stacks,stack) end
 end
 return stacks
end
function Rules.TransferEquipment(source,target,definitions,id,requested,key)
 if typeof(id)~="string" or typeof(key)~="string" or not Rules.DropAmount(1,requested) or source==target then return false end
 for slot,current in pairs(source.Equipment) do
  local stack=equippedStack(source,definitions,slot,current)
  if current==id and stack and stack.Key==key then
   local condition=source.EquipmentCondition[slot]
   local data=source.EquipmentWeapon and source.EquipmentWeapon[slot]
   -- No yields between granting the exact item and clearing its original slot.
   if not Rules.Add(target,definitions,id,1,condition~=nil and {condition} or nil,data and {data} or nil) then return false end
   source.Equipment[slot]=nil;source.EquipmentCondition[slot]=nil
   if source.EquipmentWeapon then source.EquipmentWeapon[slot]=nil end
   if source.ActiveWeaponSlot==slot then source.ActiveWeaponSlot=nil end
   if slot=="Medicine" then source.MedicalHeld=nil end
   return true
  end
 end
 return false
end
function Rules.Transfer(source, target, definitions, id, requested,key)
 if typeof(id) ~= "string" or not definitions[id] then return false end
 local count = Rules.DropAmount(Rules.Available(source,id,key), requested)
 if not count then return false end
 -- Both states are server-owned. No yields or partial public updates.
 local ok, conditions, data = Rules.Remove(source, id, count,key)
 if not ok then return false end
 if not Rules.Add(target, definitions, id, count, conditions,data) then
  Rules.Add(source, definitions, id, count, conditions,data)
  return false
 end
 return true
end
return Rules
