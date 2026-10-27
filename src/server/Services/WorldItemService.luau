local HttpService = game:GetService("HttpService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemConfig = require(ReplicatedStorage.Shared.ItemConfig)
local Inventory = require(script.Parent.InventoryService)
local Rules = require(ReplicatedStorage.Shared.InventoryRules)
local Interaction = require(ReplicatedStorage.Shared.Interaction)
local EquipmentVisuals = require(script.Parent.EquipmentVisuals)
local AmmoRules=require(ReplicatedStorage.Shared.FirearmRules)
local Stations=require(ReplicatedStorage.Shared.CraftStations)
local random=Random.new()
local Service = {}
local fallbackItems = {TreeLog = true, Scrap = true, Rags = true, Stone = true, Ammo223FMJ=true, Ammo223AP=true}
local warned = {}
local folder = workspace:FindFirstChild("WorldItems")
if not folder then
 folder = Instance.new("Folder")
 folder.Name, folder.Parent = "WorldItems", workspace
end
local function queryable(object)
 if object:IsA("BasePart") then object.CanQuery=true end
 for _,part in ipairs(object:GetDescendants()) do if part:IsA("BasePart") then part.CanQuery=true end end
end
local function register(item)
 if not item:IsA("Model") and not item:IsA("BasePart") then return end
 local id=item:GetAttribute("Item_ID") or item.Name
 if not ItemConfig.Items[id] then return end
 if ItemConfig.Items[id].Currency and not require(ReplicatedStorage.Shared.EconomyRules).Banknote(item) then
  if not warned[item] then warn("[Decline] Money model needs a positive integer BanknoteValue attribute: "..item:GetFullName());warned[item]=true end
  return
 end
 EquipmentVisuals.CaptureTemplate(item,id)
 local box=ItemConfig.Items[id].AmmoBox
 if box and item:GetAttribute("AmmoCount")==nil then
  local count=AmmoRules.BoxCount(item:GetAttribute("MaxAmmo") or box.Maximum,random:NextNumber())
  if not count then return end
  item:SetAttribute("AmmoCount",count)
 end
 item:SetAttribute("Item_ID",id)
 if item:GetAttribute("Quantity")==nil then item:SetAttribute("Quantity",1) end
 queryable(item)
end
local function consider(object)
 if object:IsA("Model") and (object.Name=="Chest" or Stations.Kind(object)) then queryable(object) end
 if object.Parent==folder then register(object); return end
 if not object:IsA("Model") and not object:IsA("BasePart") then return end
 -- Pick-up items placed directly on the map (or in organizational folders)
 -- are normalized into WorldItems. Never pull parts out of props or creatures.
 local ancestor=object.Parent
 while ancestor and ancestor~=workspace do
  if ancestor==folder then
   if object:IsA("BasePart") then object.CanQuery=true end
   return
  end
  if ancestor:IsA("Model") then
   if ancestor.Name=="Chest" or Stations.Kind(ancestor) or (ancestor.Parent==folder and ItemConfig.Items[ancestor:GetAttribute("Item_ID") or ancestor.Name]) then queryable(object) end
   return
  end
  ancestor=ancestor.Parent
 end
 if ancestor~=workspace then return end
 local id=object:GetAttribute("Item_ID") or object.Name
 if ItemConfig.Items[id] then object.Parent=folder; register(object) end
end
for _,item in ipairs(folder:GetChildren()) do register(item) end
folder.ChildAdded:Connect(register)
for _,object in ipairs(workspace:GetDescendants()) do consider(object) end
workspace.DescendantAdded:Connect(consider)
local function aliveRoot(player)
 local character = player.Character
 local humanoid = character and character:FindFirstChildOfClass("Humanoid")
 local root = character and character:FindFirstChild("HumanoidRootPart")
 if not humanoid or humanoid.Health <= 0 or character:GetAttribute("Knockout") or not root then return end
 return root, character
end
local function furnitureAncestor(part)
 local furniture
 local ancestor=part
 while ancestor and ancestor~=workspace do
  if ancestor:GetAttribute("Furniture")==true or
   (ancestor:IsA("Folder") and (ancestor.Name=="GeneratedFurniture" or ancestor.Name=="Furniture" or ancestor.Name=="StoreFurniture")) then
   furniture=ancestor
  end
  ancestor=ancestor.Parent
 end
 return furniture
end
function Service.Pickup(player, item)
 if typeof(item) ~= "Instance" or item.Parent ~= folder then return false end
 if not item:IsA("Model") and not item:IsA("BasePart") then return false end
 local id, count = item:GetAttribute("Item_ID"), item:GetAttribute("Quantity")
 if typeof(id) ~= "string" or not ItemConfig.Items[id] or typeof(count) ~= "number" or count < 1 or count >= math.huge or count ~= math.floor(count) then return false end
 local root, character = aliveRoot(player)
 if not root then return false end
 local position = Interaction.NearestPoint(item,root.Position)
 local delta = position - root.Position
 if delta.Magnitude > ItemConfig.PickupDistance then return false end
 local params = RaycastParams.new()
 params.FilterType = Enum.RaycastFilterType.Exclude
 params.FilterDescendantsInstances = {character}
 local function clearFrom(origin,target)
  target = target or Interaction.NearestPoint(item,origin)
  local excluded={character}
  for _=1,32 do
   params.FilterDescendantsInstances=excluded
   local hit = workspace:Raycast(origin, target-origin, params)
   if not hit or hit.Instance == item or hit.Instance:IsDescendantOf(item) then return true end
   local furniture=furnitureAncestor(hit.Instance)
   if not furniture then return false end
   table.insert(excluded,furniture)
  end
  return false
 end
 -- A tabletop may block the waist-height ray while the item is in plain sight.
 -- Keep the root-based reach limit and require an unobstructed ray from the
 -- body or head. Try exposed item points too: the nearest bounding-box edge
 -- can touch the shelf even when the center or top of the item is accessible.
 if not clearFrom(root.Position) then
  local head = character:FindFirstChild("Head")
  if not head or not head:IsA("BasePart") then return false end
  if not clearFrom(head.Position) then
   local frame,size
   if item:IsA("Model") then frame,size=item:GetBoundingBox() else frame,size=item.CFrame,item.Size end
   local up=frame.UpVector
   local top=frame.Position+Vector3.new(up.X*size.Y*.5,up.Y*size.Y*.5,up.Z*size.Y*.5)
   if not clearFrom(head.Position,frame.Position) and not clearFrom(head.Position,top) then return false end
  end
 end
 -- No yields between inventory grant and destruction: only one player can win.
 if ItemConfig.Items[id].Currency then
  local value=require(ReplicatedStorage.Shared.EconomyRules).Banknote(item)
  if not value or not require(script.Parent.EconomyService).Credit(player,value*count) then return false end
  item:Destroy();return true
 end
 local conditions = nil
 local encoded = item:GetAttribute("Conditions")
 if encoded then
  local ok,value = pcall(function() return HttpService:JSONDecode(encoded) end)
  if not ok then return false end
  conditions = value
 end
 local weaponData
 local encodedWeapons=item:GetAttribute("WeaponData")
 if encodedWeapons then
  local ok,value=pcall(function() return HttpService:JSONDecode(encodedWeapons) end)
  if not ok then return false end
  weaponData=value
 end
 local box=ItemConfig.Items[id].AmmoBox
 if box then
  local caliber=item:GetAttribute("Caliber") or box.Caliber
  local kind=item:GetAttribute("AmmoType") or box.Type
  local ammo=AmmoRules.AmmoID(caliber,kind)
  local rounds=item:GetAttribute("AmmoCount")
  if not ammo or typeof(rounds)~="number" or rounds<1 or rounds>10000 or rounds~=math.floor(rounds) then return false end
  if not Inventory.Add(player,ammo,rounds) then return false end
 elseif not Inventory.Add(player, id, count, conditions,weaponData) then return false end
 item:Destroy()
 return true
end
local function makeItem(id)
 local source = EquipmentVisuals.Template(id)
 local ammo=ItemConfig.Items[id] and ItemConfig.Items[id].Ammo
 if not source and ammo then source=EquipmentVisuals.Template("AmmoBox"..ammo.Caliber..ammo.Type) end
 if source and (source:IsA("Model") or source:IsA("BasePart")) then
  local item = source:Clone()
  if item:IsA("Model") and not item:FindFirstChildWhichIsA("BasePart",true) then item:Destroy()
  else return item end
 end
 -- Resource loot must remain recoverable even before its art is supplied.
 if not fallbackItems[id] then return nil end
 if not warned[id] then warn("[Decline] Using a temporary loot block; add ServerStorage/Items/"..id); warned[id] = true end
 local item = Instance.new("Part")
 item.Name = id
 item.Size = id == "TreeLog" and Vector3.new(1,.2,.2) or Vector3.new(.3,.1,.3)
 item.Material = id == "Stone" and Enum.Material.Slate or id == "TreeLog" and Enum.Material.Wood or (id == "Scrap" and Enum.Material.Metal or Enum.Material.Fabric)
 item.Color = id == "Stone" and Color3.fromRGB(125,125,125) or id == "TreeLog" and Color3.fromRGB(120,85,50) or (id == "Scrap" and Color3.fromRGB(110,110,110) or Color3.fromRGB(150,135,105))
 return item
end
local function place(item,position,count,id)
 local bounds,size
 if item:IsA("Model") then bounds,size = item:GetBoundingBox() else bounds,size = item.CFrame,item.Size end
 local pivot = item:GetPivot()
 local bottom = bounds.Position.Y-size.Y/2
 item:PivotTo(CFrame.new(position+Vector3.new(0,pivot.Position.Y-bottom+.05,0))*pivot.Rotation)
 local function anchor(part) part.Anchored,part.CanQuery = true,true end
 if item:IsA("BasePart") then anchor(item) end
 for _,part in ipairs(item:GetDescendants()) do if part:IsA("BasePart") then anchor(part) end end
 item.Name = id
 item:SetAttribute("Item_ID",id)
 item:SetAttribute("Quantity",count)
 item:SetAttribute("Conditions",nil)
 item:SetAttribute("WeaponData",nil)
end
-- A loot-pool point spawns exactly one authored model, preserving its box attributes.
function Service.SpawnTemplate(source,id,position)
 if not ItemConfig.Items[id] or not source or (not source:IsA("Model") and not source:IsA("BasePart")) then return nil end
 local item=source:Clone()
 if not item or (item:IsA("Model") and not item:FindFirstChildWhichIsA("BasePart",true)) then if item then item:Destroy() end;return nil end
 place(item,position,1,id)
 if ItemConfig.Items[id].AmmoBox then item:SetAttribute("AmmoCount",nil) end
 item.Parent=folder
 return item
end
function Service.SpawnLoot(loot,position,ignored)
 local ids,prepared = {},{}
 for id,count in pairs(loot) do
  if not ItemConfig.Items[id] or not Rules.DropAmount(count,"All") then return false end
  table.insert(ids,id)
 end
 table.sort(ids)
 for index,id in ipairs(ids) do
  local item = makeItem(id)
  if not item then
   for _,entry in ipairs(prepared) do entry:Destroy() end
   return false
  end
  local offset = Vector3.new((index-(#ids+1)/2)*.4,0,0)
  local destination = position+offset
  local params = RaycastParams.new()
  params.FilterType = Enum.RaycastFilterType.Exclude
  params.FilterDescendantsInstances = {folder,table.unpack(ignored or {})}
  params.RespectCanCollide = true
  local hit = workspace:Raycast(destination+Vector3.new(0,2,0),Vector3.new(0,-16,0),params)
  place(item,hit and hit.Position or destination,loot[id],id)
  table.insert(prepared,item)
 end
 -- All entries are prepared before becoming public; no inventory grant occurs.
 for _,item in ipairs(prepared) do item.Parent = folder end
 return true
end
local function dropHeld(state,model)
 local id=state and state.Equipment.Hands
 local definition=id and ItemConfig.Items[id]
 if not definition or not definition.Weapon or id=="ZombieHand" or not model then return false end
 local root=model:FindFirstChild("HumanoidRootPart")
 if not root then return false end
 local item=makeItem(id)
 if not item then return false end
 local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances={model,folder}
 local hit=workspace:Raycast(root.Position+Vector3.new(0,2,0),Vector3.new(0,-12,0),params)
 if not hit then item:Destroy();return false end
 place(item,hit.Position,1,id)
 item:SetAttribute("Conditions",HttpService:JSONEncode({state.EquipmentCondition.Hands or definition.Weapon.MaxUses}))
 local data=state.EquipmentWeapon and state.EquipmentWeapon.Hands
 if data then item:SetAttribute("WeaponData",HttpService:JSONEncode({data})) end
 state.Equipment.Hands=nil;state.EquipmentCondition.Hands=nil
 if state.EquipmentWeapon then state.EquipmentWeapon.Hands=nil end
 EquipmentVisuals.Apply(model,nil)
 item.Parent=folder
 return true
end
function Service.DisarmCreature(model)
 if model:GetAttribute("OfflineUserId") then
  local state=require(script.Parent.PlayerSessionService).OfflineInventory(model)
  return dropHeld(state,model)
 end
 local id=model:GetAttribute("HandsItem")
 if not id or id=="ZombieHand" then return false end
 return dropHeld({Equipment={Hands=id},EquipmentCondition={},EquipmentWeapon={}},model)
end
function Service.Disarm(player)
 if not dropHeld(Inventory.Export(player),player.Character) then return false end
 Inventory.Refresh(player)
 return true
end
function Service.Drop(player, id, requested,key)
 if typeof(id) ~= "string" or not ItemConfig.Items[id] then return false end
 local snapshot=Inventory.Snapshot(player)
 local available=snapshot.Items[id]
 if key then
  available=0
  for _,stack in ipairs(snapshot.Stacks or {}) do if stack.Key==key and stack.ID==id then available=stack.Count end end
 end
 local count = Rules.DropAmount(available, requested)
 if not count then return false end
 local root, character = aliveRoot(player)
 if not root then return false end
 local item = makeItem(id)
 if not item then
  warn("[Decline] Missing world item template: ServerStorage/Items/" .. id)
  return false
 end
 -- Drop straight below the character, without a forward throw.
 local destination = root.Position
 local params = RaycastParams.new()
 params.FilterType = Enum.RaycastFilterType.Exclude
 params.FilterDescendantsInstances = {character, folder}
 local hit = workspace:Raycast(destination + Vector3.new(0, 2, 0), Vector3.new(0, -12, 0), params)
 if not hit then item:Destroy(); return false end
 place(item,hit.Position,count,id)
 local ok,conditions,weaponData = Inventory.Remove(player, id, count,key)
 if not ok then item:Destroy(); return false end
 if conditions then item:SetAttribute("Conditions",HttpService:JSONEncode(conditions)) end
 if weaponData then item:SetAttribute("WeaponData",HttpService:JSONEncode(weaponData)) end
 item.Parent = folder
 -- World drops remain until collected or until this server closes.
 return true
end
return Service
