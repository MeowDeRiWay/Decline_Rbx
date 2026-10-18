local HttpService = game:GetService("HttpService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemConfig = require(ReplicatedStorage.Shared.ItemConfig)
local Inventory = require(script.Parent.InventoryService)
local Rules = require(ReplicatedStorage.Shared.InventoryRules)
local Interaction = require(ReplicatedStorage.Shared.Interaction)
local Service = {}
local fallbackItems = {TreeLog = true, Scrap = true, Rags = true}
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
 item:SetAttribute("Item_ID",id)
 if item:GetAttribute("Quantity")==nil then item:SetAttribute("Quantity",1) end
 queryable(item)
end
local function consider(object)
 if object:IsA("Model") and (object.Name=="Chest" or object.Name=="Stove" or object.Name=="CuttingBoard" or object.Name=="Workstation") then queryable(object) end
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
   if ancestor.Name=="Chest" or ancestor.Name=="Stove" or ancestor.Name=="CuttingBoard" or ancestor.Name=="Workstation" or (ancestor.Parent==folder and ItemConfig.Items[ancestor:GetAttribute("Item_ID") or ancestor.Name]) then queryable(object) end
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
 local hit = workspace:Raycast(root.Position, delta, params)
 if hit and hit.Instance ~= item and not hit.Instance:IsDescendantOf(item) then return false end
 -- No yields between inventory grant and destruction: only one player can win.
 local conditions = nil
 local encoded = item:GetAttribute("Conditions")
 if encoded then
  local ok,value = pcall(function() return HttpService:JSONDecode(encoded) end)
  if not ok then return false end
  conditions = value
 end
 if not Inventory.Add(player, id, count, conditions) then return false end
 item:Destroy()
 return true
end
local function makeItem(id)
 local templates = ServerStorage:FindFirstChild("Items")
 local source = templates and templates:FindFirstChild(id)
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
 item.Material = id == "TreeLog" and Enum.Material.Wood or (id == "Scrap" and Enum.Material.Metal or Enum.Material.Fabric)
 item.Color = id == "TreeLog" and Color3.fromRGB(120,85,50) or (id == "Scrap" and Color3.fromRGB(110,110,110) or Color3.fromRGB(150,135,105))
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
function Service.Drop(player, id, requested)
 if typeof(id) ~= "string" or not ItemConfig.Items[id] then return false end
 local count = Rules.DropAmount(Inventory.Snapshot(player).Items[id], requested)
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
 local ok,conditions = Inventory.Remove(player, id, count)
 if not ok then item:Destroy(); return false end
 if conditions then item:SetAttribute("Conditions",HttpService:JSONEncode(conditions)) end
 item.Parent = folder
 -- World drops remain until collected or until this server closes.
 return true
end
return Service
