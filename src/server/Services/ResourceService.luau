local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.ResourceConfig)
local Rules = require(ReplicatedStorage.Shared.ResourceRules)
local CombatRules = require(ReplicatedStorage.Shared.CombatRules)
local Area = require(script.Parent.AreaService)
local Inventory = require(script.Parent.InventoryService)
local WorldItems = require(script.Parent.WorldItemService)
local Items = require(ReplicatedStorage.Shared.ItemConfig)
local Progression = require(script.Parent.ProgressionService)
local Journal = require(script.Parent.JournalService)
local Service = {}
local random = Random.new()
local nodes, zones = {}, {}
local folder
-- Virtual chunks leave authored markers untouched. Only nearby chunks roll resources.
local CHUNK_SIZE, WAKE_RADIUS = 20, 180
local deadline = 0
local footprints = Rules.FootprintIndex(8)
local function budget()
 if os.clock() >= deadline then task.wait(); deadline = os.clock()+.002 end
end
local function chunkAt(state,position)
 for _,chunk in ipairs(state.Chunks) do
  if Area.Contains(chunk.Parts[1],position) then return chunk end
 end
end
local byName, byZone = {}, {}
for kind,definition in pairs(Config) do
 byZone[definition.Zone] = kind
 for _,name in ipairs(definition.Templates) do byName[name] = kind end
end
local function resourceKind(model)
 local attribute = model:GetAttribute("ResourceType")
 return Config[attribute] and attribute or byName[model.Name]
end
local function bottom(model)
 local box,size = model:GetBoundingBox()
 return Vector3.new(box.Position.X,box.Position.Y-size.Y/2,box.Position.Z)
end
local function contains(zone,position)
 for _,part in ipairs(Area.Parts(zone)) do
  if Area.Contains(part,position) then
   local localPoint = part.CFrame:PointToObjectSpace(position)
   if math.abs(localPoint.Y-part.Size.Y/2) <= 5 then return true end
  end
 end
 return false
end
local function attach(model,node)
 if node.Zone then return end
 for zone,state in pairs(zones) do
  if state.Kind == node.Kind and contains(zone,bottom(model)) then
   node.Zone = zone
   state.Nodes[model] = true
   node.Chunk = chunkAt(state,bottom(model))
   if node.Chunk then node.Chunk.Nodes[model] = true; node.Chunk.NextAt = nil end
   return
  end
 end
end
local function register(model,zone,chunk)
 if nodes[model] or not model:IsA("Model") or (not zone and not model:IsDescendantOf(workspace)) then return end
 local kind = resourceKind(model)
 if not kind or not model:FindFirstChildWhichIsA("BasePart",true) then return end
 local definition = Config[kind]
 local node = {Kind = kind, Health = definition.Health}
 nodes[model] = node
 model:SetAttribute("ResourceType",kind)
 model:SetAttribute("Health",node.Health)
 model:SetAttribute("MaxHealth",definition.Health)
 model:SetAttribute("ResourceMaterial",definition.Material)
 for _,part in ipairs(model:GetDescendants()) do
  if part:IsA("BasePart") then
   part.Anchored,part.CanQuery = true,true
   part:SetAttribute("ResourceMaterial",definition.Material)
   if kind == "Tree" then part.Material = Enum.Material.Wood end
  end
 end
 -- BlocksVision and other model settings are preserved. No Humanoid or highlight.
 if zone and chunk then
  node.Zone,node.Chunk = zone,chunk
  zones[zone].Nodes[model],chunk.Nodes[model] = true,true
 else attach(model,node) end
 local box,size=model:GetBoundingBox()
 node.Footprint=Rules.Footprint(box,size)
 footprints:Insert(node.Footprint)
end
local function marker(part)
 if not part:IsA("BasePart") then return end
 part.Transparency = 1
 part.Anchored,part.CanCollide,part.CanTouch,part.CanQuery = true,false,false,false
 part:SetAttribute("BlocksVision",false)
end
local function watchZone(zone)
 if zones[zone] or not zone:IsA("Model") or not byZone[zone.Name] then return end
 local state = {Kind = byZone[zone.Name], Nodes = {}, Chunks = {}}
 zones[zone] = state
 local function addSurface(part)
  if not part:IsA("BasePart") then return end
  marker(part)
  for x=0,math.ceil(part.Size.X/CHUNK_SIZE)-1 do
   for z=0,math.ceil(part.Size.Z/CHUNK_SIZE)-1 do
    local width,depth=math.min(CHUNK_SIZE,part.Size.X-x*CHUNK_SIZE),math.min(CHUNK_SIZE,part.Size.Z-z*CHUNK_SIZE)
    local surface={Size=Vector3.new(width,part.Size.Y,depth),CFrame=part.CFrame*CFrame.new(Vector3.new(-part.Size.X/2+x*CHUNK_SIZE+width/2,0,-part.Size.Z/2+z*CHUNK_SIZE+depth/2))}
    table.insert(state.Chunks,{Kind=state.Kind,Nodes={},NextAt=0,Parts={surface},Source=part})
   end
  end
 end
 for _,part in ipairs(Area.Parts(zone)) do addSurface(part) end
 state.Connection = zone.DescendantAdded:Connect(addSurface)
 for model,node in pairs(nodes) do attach(model,node) end
end
local function sources(kind)
 local resources = ServerStorage:FindFirstChild("Resources")
 local group = resources and resources:FindFirstChild(Config[kind].Folder)
 local result = {}
 for _,name in ipairs(Config[kind].Templates) do
  local source = group and group:FindFirstChild(name)
  if source and source:IsA("Model") and source:FindFirstChildWhichIsA("BasePart",true) then table.insert(result,source) end
 end
 return result
end
local function generate(zone,state)
 local definition = Config[state.Kind]
 local templates,parts = sources(state.Kind),state.Parts
 if #templates == 0 or #parts == 0 then
  if not zones[zone].Warned then
   warn("[Decline] Empty resource zone or missing templates for "..zone:GetFullName().."; use ServerStorage/Resources/"..definition.Folder)
   zones[zone].Warned = true
  end
  state.NextAt = os.clock()+5
  return
 end
 zones[zone].Warned = false
 local excluded = {folder}
 for markerZone in pairs(zones) do table.insert(excluded,markerZone) end
 local creatures = workspace:FindFirstChild("Creatures")
 local worldItems = workspace:FindFirstChild("WorldItems")
 if creatures then table.insert(excluded,creatures) end
 if worldItems then table.insert(excluded,worldItems) end
 for _,player in ipairs(game:GetService("Players"):GetPlayers()) do
  if player.Character then table.insert(excluded,player.Character) end
 end
 local params = RaycastParams.new()
 params.FilterType = Enum.RaycastFilterType.Exclude
 params.FilterDescendantsInstances = excluded
 params.RespectCanCollide = true
 local made = 0
 local zoneParts=Area.Parts(zone)
 for _,surface in ipairs(parts) do
  Rules.RollCells(surface.Size.X,surface.Size.Z,definition.SpawnChance,random,function(x,z)
   budget()
   if not zone:IsDescendantOf(workspace) or not state.Source:IsDescendantOf(zone) then return end
   local point=surface.CFrame:PointToWorldSpace(Vector3.new(x,surface.Size.Y/2,z))
   -- Overlapping markers in one zone must not get a second chance at the same area.
   for _,other in ipairs(zoneParts) do
    if other==state.Source then break end
    if Area.Contains(other,point) then return end
   end
   local source = templates[random:NextInteger(1,#templates)]
   local sourceBox,size = source:GetBoundingBox()
   local pivot = source:GetPivot()
   local rotation = CFrame.Angles(0,random:NextNumber(-math.pi,math.pi),0)*pivot.Rotation
   local ground = workspace:Raycast(point+Vector3.new(0,2,0),Vector3.new(0,-16,0),params)
   if not ground or ground.Normal.Y < .5 then return end
   local relativeBox = pivot:ToObjectSpace(sourceBox)
   local orientationBox = rotation*relativeBox
   -- Account for a pivot that is not at the bottom of the model.
   local halfHeight = math.abs(orientationBox.RightVector.Y)*size.X/2 + math.abs(orientationBox.UpVector.Y)*size.Y/2 + math.abs(orientationBox.LookVector.Y)*size.Z/2
   local position = ground.Position+Vector3.new(-orientationBox.Position.X,halfHeight-orientationBox.Position.Y+.02,-orientationBox.Position.Z)
   local target = CFrame.new(position)*rotation
   local targetBox = target*relativeBox
   if not Area.Contains(surface,targetBox.Position) then return end
   local footprint=Rules.Footprint(targetBox,size)
   if not footprints:Clear(footprint) then return end
   local clone = source:Clone()
   clone:PivotTo(target)
   register(clone,zone,state)
   if nodes[clone] then clone.Parent=folder;made+=1 else clone:Destroy() end
  end,budget)
 end
 -- A legitimate zero roll waits for the normal respawn, rather than rerolling every five seconds.
 state.NextAt = made == 0 and os.clock()+random:NextInteger(definition.RespawnMin,definition.RespawnMax) or nil
end
function Service.Find(part)
 local ancestor = part
 while ancestor and ancestor ~= workspace do
  if nodes[ancestor] then return ancestor end
  ancestor = ancestor.Parent
 end
 return nil
end
function Service.Hit(player,model,weapon)
 local node = nodes[model]
 if not node or node.Health <= 0 or not model:IsDescendantOf(workspace) then return false end
 local character = player.Character
 local id = character and character:GetAttribute("HandsItem")
 local definition = id and Items.Items[id]
 if Inventory.GetWeapon(player) ~= weapon then return false end
 local resource = Config[node.Kind]
 local damage
 if not definition then
  -- Empty hands use the same damage roll and bonuses as an unarmed combat hit.
  if node.Kind~="Tree" then return false end
  damage=CombatRules.UnarmedDamage(player:GetAttribute("MeleeBonus"),player:GetAttribute("UnarmedDamageBonus"),random:NextNumber())
 else
  if not definition.Weapon then return false end
  -- A real tool impact costs exactly one use, including an unsuitable tool.
  if not Inventory.UseWeapon(player) then return false end
  if not Rules.CanDamage(resource,definition) then return true end
  damage=Rules.HarvestDamage(resource,definition,player:GetAttribute("MeleeBonus"))
 end
 local previousHealth = node.Health
 node.Health = Rules.Damage(node.Health,damage)
 model:SetAttribute("Health",node.Health)
 if node.Health == 0 then
  local loot = {}
  for id,amount in pairs(resource.Loot) do loot[id] = random:NextInteger(amount.Min,amount.Max) end
  loot = Progression.Loot(player,loot)
  if not WorldItems.SpawnLoot(loot,bottom(model),{model,character}) then
   node.Health = previousHealth
   model:SetAttribute("Health",node.Health)
   return true
  end
  -- Invalidate before granting loot so a second strike cannot harvest twice.
  nodes[model] = nil
  footprints:Remove(node.Footprint)
  local resourceID=({Tree="TreeLog",StoneVein="Stone",ScrapPile="Scrap"})[node.Kind]
  Progression.Harvest(player,node.Kind,loot[resourceID] or 0)
  if node.Zone and zones[node.Zone] then
   local state = zones[node.Zone]
   state.Nodes[model] = nil
   local chunk=node.Chunk
   if chunk then
    chunk.Nodes[model]=nil
    if not next(chunk.Nodes) then chunk.NextAt=os.clock()+random:NextInteger(resource.RespawnMin,resource.RespawnMax) end
   end
  end
  model:Destroy()
 end
 if damage>0 then
  local name=({Tree="Tree",StoneVein="Stone vein",ScrapPile="Scrap pile"})[node.Kind] or "Resource"
  local remaining=math.ceil(node.Health/damage)
  Journal.Send(player,string.format("%s: %s%d hits remaining.",name,not definition and remaining>0 and "about " or "",remaining))
 end
 return true
end
local function tick()
 deadline=os.clock()+.002
 local positions={}
 for _,player in ipairs(Players:GetPlayers()) do
  local character=player.Character
  local root=character and character:FindFirstChild("HumanoidRootPart")
  local hp=character and character:FindFirstChildOfClass("Humanoid")
  if root and hp and hp.Health>0 then table.insert(positions,root.Position) end
 end
 for model,node in pairs(nodes) do
  if not model:IsDescendantOf(workspace) then
   footprints:Remove(node.Footprint);nodes[model]=nil
  end
  budget()
 end
 for zone,state in pairs(zones) do
  if not zone:IsDescendantOf(workspace) then
   state.Connection:Disconnect()
   for model in pairs(state.Nodes) do if nodes[model] then nodes[model].Zone,nodes[model].Chunk=nil,nil end end
   zones[zone]=nil
   continue
  end
  for _,chunk in ipairs(state.Chunks) do
   budget()
   for model in pairs(chunk.Nodes) do if not nodes[model] then chunk.Nodes[model],state.Nodes[model]=nil,nil end end
   if not chunk.Source:IsDescendantOf(zone) or next(chunk.Nodes) then continue end
   local near=false
   for _,position in ipairs(positions) do
    local surface=chunk.Parts[1]
    local point=surface.CFrame:PointToObjectSpace(position)
    local dx,dz=math.max(0,math.abs(point.X)-surface.Size.X/2),math.max(0,math.abs(point.Z)-surface.Size.Z/2)
    if dx*dx+dz*dz<=WAKE_RADIUS*WAKE_RADIUS then near=true;break end
   end
   if not near then continue end
   if not chunk.NextAt then
    local definition=Config[chunk.Kind]
    chunk.NextAt=os.clock()+random:NextInteger(definition.RespawnMin,definition.RespawnMax)
   end
   if os.clock()>=chunk.NextAt then generate(zone,chunk) end
  end
 end
end
function Service.Start()
 if Service.Started then return end
 Service.Started = true
 folder = workspace:FindFirstChild("Resources")
 if not folder then folder = Instance.new("Folder"); folder.Name,folder.Parent = "Resources",workspace end
 folder:SetAttribute("GenerationMode","NearbyChunks20")
 folder:SetAttribute("GenerationRadius",WAKE_RADIUS)
 -- Gather markers first, then associate hand-placed test resources with them.
 for _,object in ipairs(workspace:GetDescendants()) do if object:IsA("Model") and byZone[object.Name] then watchZone(object) end end
 for _,object in ipairs(workspace:GetDescendants()) do if object:IsA("Model") then register(object) end end
 workspace.DescendantAdded:Connect(function(object)
  if object:IsA("Model") then watchZone(object); register(object) end
  -- Models may be parented before their parts are inserted.
  local ancestor = object.Parent
  while ancestor and ancestor ~= workspace do
   if ancestor:IsA("Model") then register(ancestor) end
   ancestor = ancestor.Parent
  end
 end)
 task.spawn(function()
  while true do tick(); task.wait(1) end
 end)
end
return Service
