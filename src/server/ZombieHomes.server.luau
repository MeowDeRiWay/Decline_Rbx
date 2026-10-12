local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Area = require(script.Parent.Services.AreaService)
local Rules = require(ReplicatedStorage.Shared.ResourceRules)
local random = Random.new()
local active = {}
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
local function spawn(home)
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
 for _=1,40 do
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
local function watch(home)
 if not home:IsA("Model") or active[home] then return end
 -- Home surfaces are queryable markers; physical collision is not required.
 for _,part in ipairs(home:GetDescendants()) do
  if part:IsA("BasePart") then part.CanQuery=true end
 end
 local token = {Occupied = false, AllowedAt = 0}
 active[home] = token
 task.spawn(function()
  local deadline = os.clock()+random:NextNumber(1,60)
  while home:IsDescendantOf(workspace) and active[home] == token do
   if enabled(home) then
    local now = os.clock()
    local permitted = Rules.Occupancy(token,Area.Occupied(home),now,180)
    -- Recheck occupancy throughout the wait, including immediately before spawn.
    if permitted and now >= deadline then
     spawn(home)
     deadline = os.clock()+random:NextNumber(1,60)
    end
   else
    Rules.Occupancy(token,Area.Occupied(home),os.clock(),180)
    deadline = os.clock()+random:NextNumber(1,60)
   end
   task.wait(.25)
  end
  if active[home] == token then active[home]=nil end
 end)
end
for _,object in ipairs(workspace:GetDescendants()) do
 if object:IsA("Model") and object:GetAttribute("Zombie_home") == true then watch(object) end
end
workspace.DescendantAdded:Connect(function(object)
 if object:IsA("Model") then
  if object:GetAttribute("Zombie_home") == true then watch(object) end
  object:GetAttributeChangedSignal("Zombie_home"):Connect(function()
   if object:GetAttribute("Zombie_home") == true then watch(object) end
  end)
 end
end)
-- Existing models may receive the attribute later in Studio or from another script.
for _,object in ipairs(workspace:GetDescendants()) do
 if object:IsA("Model") then
  object:GetAttributeChangedSignal("Zombie_home"):Connect(function()
   if object:GetAttribute("Zombie_home") == true then watch(object) end
  end)
 end
end
