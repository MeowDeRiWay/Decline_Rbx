local WorldActivity=require(script.Parent.WorldActivityService)
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Area = require(script.Parent.AreaService)
local Rules = require(ReplicatedStorage.Shared.ResourceRules)
local HomeRules = require(ReplicatedStorage.Shared.ZombieHomeRules)
local random = Random.new()
local Players=game:GetService("Players")
local Service={}
local active,records,buckets,watched,pending={},{},{},{},{}
local lastWake=-math.huge
local warned = setmetatable({},{__mode="k"})
local creatures = workspace:FindFirstChild("Creatures")
if not creatures then
 creatures = Instance.new("Folder")
 creatures.Name,creatures.Parent = "Creatures",workspace
end
local function enabled(home)
 return home:IsA("Model") and home:IsDescendantOf(workspace) and home:GetAttribute("Zombie_home") == true
end
local function template()
 local folder = ServerStorage:FindFirstChild("Creatures")
 local zombie = folder and folder:FindFirstChild("Zombie")
 return zombie and zombie:IsA("Model") and zombie or nil
end
local function spawn(home,valid)
 -- Count living zombies by their source house, even after they wander outside.
 -- All Zombie_home floors inside one ZHouse share the same house-wide quota.
 if HomeRules.Count(home, creatures, workspace, WorldActivity.DormantNPCs()) >= HomeRules.Limit(home) then return false end
 local source = template()
 if not source then
  if not warned[home] then
   warn("[Decline] Put the Zombie template in ServerStorage/Creatures/Zombie")
   warned[home]=true
  end
  return false
 end
 local root = source:FindFirstChild("HumanoidRootPart") or source:FindFirstChild("Body")
 local head = source:FindFirstChild("Head")
 if not root or not root:IsA("BasePart") or not head or not head:IsA("BasePart") then return false end
 local floorBox,floorSize = home:GetBoundingBox()
 local bodyBox,bodySize = source:GetBoundingBox()
 local relativeBox = root.CFrame:ToObjectSpace(bodyBox)
 local floorParams = RaycastParams.new()
 floorParams.FilterType = Enum.RaycastFilterType.Include
 floorParams.FilterDescendantsInstances = {home}
 floorParams.RespectCanCollide = false
 local overlap = OverlapParams.new()
 overlap.FilterType = Enum.RaycastFilterType.Exclude
 overlap.FilterDescendantsInstances = {source}
 -- Try several places rather than forcing a spawn into a blocked position.
 for attempt=1,40 do
  if attempt>1 and (attempt-1)%HomeRules.SpawnAttemptsPerFrame==0 then
   task.wait()
   if not valid() then return false end
  end
  local point = floorBox:PointToWorldSpace(Vector3.new(random:NextNumber(-floorSize.X/2,floorSize.X/2),0,random:NextNumber(-floorSize.Z/2,floorSize.Z/2)))
  local above = Vector3.new(point.X,floorBox.Position.Y+floorSize.Magnitude/2+5,point.Z)
  local hit = workspace:Raycast(above,Vector3.new(0,-floorSize.Magnitude-10,0),floorParams)
  if not hit or hit.Normal.Y < .95 then continue end
  local position = hit.Position+Vector3.new(0,root.Size.Y/2+.03,0)
  local rootFrame = CFrame.new(position)*CFrame.Angles(0,random:NextNumber(-math.pi,math.pi),0)
  local supported = true
  for _,corner in ipairs({Vector3.new(-1,0,-1),Vector3.new(1,0,-1),Vector3.new(-1,0,1),Vector3.new(1,0,1)}) do
   local foot = rootFrame:PointToWorldSpace(Vector3.new(corner.X*root.Size.X*.48,-root.Size.Y/2,corner.Z*root.Size.Z*.48))
   local support = workspace:Raycast(foot+Vector3.new(0,.2,0),Vector3.new(0,-.4,0),floorParams)
   if not support or support.Normal.Y < .95 or math.abs(support.Position.Y-hit.Position.Y)>.08 then supported=false; break end
  end
  if not supported then continue end
  local clear = true
  local clearance = Vector3.new(math.max(.01,bodySize.X-.02),math.max(.01,bodySize.Y-.02),math.max(.01,bodySize.Z-.02))
  for _,part in ipairs(workspace:GetPartBoundsInBox(rootFrame*relativeBox,clearance,overlap)) do
   local ancestor = part:FindFirstAncestorOfClass("Model")
   if part.CanCollide or (ancestor and ancestor:FindFirstChildOfClass("Humanoid")) then clear=false; break end
  end
  if not clear then continue end
  -- A player can enter while a multi-frame placement search yields.
  if not valid() or Area.Occupied(home,records[home].Parts) then return false end
  if HomeRules.Count(home,creatures,workspace,WorldActivity.DormantNPCs())>=HomeRules.Limit(home) then return false end
  local zombie = source:Clone()
  zombie:SetAttribute("Zombie_home",nil)
  zombie:SetAttribute("IsDead",nil)
  zombie:SetAttribute("IsCorpse",nil)
  local humanoid = zombie:FindFirstChildOfClass("Humanoid")
  if humanoid then humanoid.Health=humanoid.MaxHealth end
  local homeReference = Instance.new("ObjectValue")
  homeReference.Name,homeReference.Value,homeReference.Parent = "ZombieHome",home,zombie
  zombie:PivotTo(rootFrame*root.CFrame:Inverse()*source:GetPivot())
  zombie.Parent = creatures
  return true
 end
 return false
end
local function clearBuckets(home,record)
 for _,key in ipairs(record.Keys or {}) do
  local bucket=buckets[key]
  if bucket then bucket[home]=nil;if not next(bucket) then buckets[key]=nil end end
 end
 record.Keys={}
end
local function rebuild(home,record)
 clearBuckets(home,record)
 for _,connection in ipairs(record.PartConnections or {}) do connection:Disconnect() end
 record.PartConnections={};record.Parts=Area.Parts(home)
 if #record.Parts==0 then record.Frame=nil;return end
 local cf,size=home:GetBoundingBox();record.Frame,record.Size=cf,size
 local ex=math.abs(cf.RightVector.X)*size.X/2+math.abs(cf.LookVector.X)*size.Z/2
 local ez=math.abs(cf.RightVector.Z)*size.X/2+math.abs(cf.LookVector.Z)*size.Z/2
 local cell=HomeRules.BucketSize
 for x=math.floor((cf.Position.X-ex)/cell),math.floor((cf.Position.X+ex)/cell) do
  for z=math.floor((cf.Position.Z-ez)/cell),math.floor((cf.Position.Z+ez)/cell) do
   local key=x..":"..z;buckets[key]=buckets[key] or {};buckets[key][home]=record;table.insert(record.Keys,key)
  end
 end
 for _,part in ipairs(record.Parts) do
  part.CanQuery=true
  for _,property in ipairs({"CFrame","Size"}) do
   table.insert(record.PartConnections,part:GetPropertyChangedSignal(property):Connect(function() pending[home]=true;lastWake=-math.huge end))
  end
 end
end
local function remove(home)
 local record=records[home]
 if WorldActivity.IsDormant(home) then
  if record then clearBuckets(home,record);Rules.Occupancy(record,false,os.clock(),180) end
  active[home],pending[home]=nil,nil
  return
 end
 if record then
  clearBuckets(home,record)
  for _,connection in ipairs(record.PartConnections or {}) do connection:Disconnect() end
  for _,connection in ipairs(record.Connections) do connection:Disconnect() end
 end
 records[home],active[home],pending[home]=nil,nil,nil
 local connection=watched[home];if connection then connection:Disconnect();watched[home]=nil end
end
local function watch(home)
 if not home:IsA("Model") then return end
 if watched[home] then
  if records[home] then pending[home]=true;lastWake=-math.huge end
  return
 end
 watched[home]=home:GetAttributeChangedSignal("Zombie_home"):Connect(function() pending[home]=true;lastWake=-math.huge end)
 if home:GetAttribute("Zombie_home")==true then pending[home]=true end
end
local function synchronize()
 for home in pairs(pending) do
  pending[home]=nil
  if not home:IsDescendantOf(workspace) then
   if not WorldActivity.IsDormant(home) then remove(home) end
   continue
  end
  if not records[home] and home:GetAttribute("Zombie_home")==true then
   local record={Occupied=false,AllowedAt=0,Connections={},Deadline=0};records[home]=record
   record.Connections={home.DescendantAdded:Connect(function() pending[home]=true;lastWake=-math.huge end),
    home.DescendantRemoving:Connect(function() pending[home]=true;lastWake=-math.huge end)}
  end
  local record=records[home]
  if record then rebuild(home,record) end
 end
end
local function subjects()
 local result={}
 for _,player in ipairs(Players:GetPlayers()) do
  local character=player.Character
  local root=character and character:FindFirstChild("HumanoidRootPart")
  local hp=character and character:FindFirstChildOfClass("Humanoid")
  if root and hp and hp.Health>0 and not character:GetAttribute("IsDead") then
   table.insert(result,{Root=root,Humanoid=hp})
  end
 end
 return result
end
local function near(record,players)
 if not record.Frame then return false end
 for _,subject in ipairs(players) do
  if HomeRules.Near(record.Frame,record.Size,subject.Root.Position,HomeRules.WakeRadius) then return true end
 end
 return false
end
local function wake(players,now)
 local candidates={};local cell=HomeRules.BucketSize;local radius=HomeRules.WakeRadius
 for _,subject in ipairs(players) do
  local point=subject.Root.Position
  for x=math.floor((point.X-radius)/cell),math.floor((point.X+radius)/cell) do
   for z=math.floor((point.Z-radius)/cell),math.floor((point.Z+radius)/cell) do
    for home,record in pairs(buckets[x..":"..z] or {}) do candidates[home]=record end
   end
  end
 end
 local awake={}
 for home,record in pairs(candidates) do
  if enabled(home) and near(record,players) then
   awake[home]=record
   if not active[home] then record.Deadline=now+random:NextNumber(1,60) end
  end
 end
 for home,record in pairs(active) do
  if not awake[home] then Rules.Occupancy(record,false,now,180) end
 end
 active=awake;lastWake=now
end
function Service.Step(now)
 synchronize()
 local players=subjects()
 if now-lastWake>=1 then wake(players,now) end
 local processed,spawns=0,0
 local due={}
 for home,record in pairs(active) do
  -- Refresh distance before occupancy even between coarse proximity updates.
  if not enabled(home) or not near(record,players) then
   Rules.Occupancy(record,false,now,180);active[home]=nil;continue
  end
  local permitted=Rules.Occupancy(record,Area.Occupied(home,record.Parts,players),now,180)
  if permitted and now>=record.Deadline then table.insert(due,{Home=home,Record=record}) end
  processed+=1
  if processed%HomeRules.HomesPerBatch==0 then task.wait() end
 end
 -- Oldest due homes go first, so a dense district cannot starve later entries.
 table.sort(due,function(a,b) return a.Record.Deadline<b.Record.Deadline end)
 for i=1,math.min(#due,HomeRules.SpawnsPerStep) do
  local home,record=due[i].Home,due[i].Record
  if records[home]==record and active[home]==record and enabled(home) and near(record,subjects()) then
   spawns+=1
   spawn(home,function() return records[home]==record and active[home]==record and enabled(home) and near(record,subjects()) end)
   record.Deadline=os.clock()+random:NextNumber(1,60)
   task.wait() -- At most one spawn attempt per frame, even when many houses wake.
  end
 end
 return processed,spawns
end
function Service.Start()
 if Service.Started then return end;Service.Started=true
 workspace.DescendantAdded:Connect(watch)
 workspace.DescendantRemoving:Connect(remove)
 for _,object in ipairs(workspace:GetDescendants()) do watch(object) end
 task.spawn(function() while true do Service.Step(os.clock());task.wait(.25) end end)
end
return Service
