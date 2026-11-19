-- Road surfaces support both characters and the scripted vehicle suspension.
local Ground={}
local function roadSurface(part)
 local object=part
 while object and object~=workspace do
  if object:GetAttribute("Road")==true or object.Name:lower()=="roads" then return true end
  object=object.Parent
 end
 return false
end
function Ground.Marked(part)
 local object=part
 while object and object~=workspace do
  local name=object.Name:lower()
  if object:GetAttribute("Road")==true or object:GetAttribute("Floor")==true
   or name=="floor" or name=="floors" or name=="roads" or name=="space" then return true end
  object=object.Parent
 end
 return false
end
function Ground.Supports(part)
 if part:IsA("Terrain") then return true end
 if not part:IsA("BasePart") then return false end
 local ancestor=part
 while ancestor and ancestor~=workspace do
  if ancestor:GetAttribute("Vehicle")==true or ancestor:GetAttribute("Item_ID")~=nil
   or ancestor:IsA("Model") and ancestor:FindFirstChildOfClass("Humanoid") then return false end
  ancestor=ancestor.Parent
 end
 return part.CanCollide or Ground.Marked(part) and part.Transparency<.95
end
local function params(excluded,physical)
 local result=RaycastParams.new();result.FilterType=Enum.RaycastFilterType.Exclude
 result.FilterDescendantsInstances=excluded;result.RespectCanCollide=physical;result.IgnoreWater=true
 return result
end
function Ground.Cast(origin,direction,excluded)
 local ignored=table.clone(excluded)
 for _=1,24 do
  local hit=workspace:Raycast(origin,direction,params(ignored,false))
  if not hit then return end
  if Ground.Supports(hit.Instance) then return hit end
  table.insert(ignored,hit.Instance)
 end
end
local function top(part)
 if not part:IsA("BasePart") then return math.huge end
 return part.Position.Y+(math.abs(part.CFrame.RightVector.Y)*part.Size.X+math.abs(part.CFrame.UpVector.Y)*part.Size.Y+math.abs(part.CFrame.LookVector.Y)*part.Size.Z)/2
end
-- Scripted vehicles also collide with queryable scenery and other scripted cars,
-- even when those objects disable native Roblox physics.
function Ground.Blocks(part,groundY,maxStep)
 if part:IsA("Terrain") then return false end
 if not part:IsA("BasePart") then return false end
 if Ground.Supports(part) and top(part)<=groundY+maxStep then return false end
 return part.CanCollide or part.Transparency<.95
end
function Ground.Overlap(frame,size,excluded,groundY,maxStep)
 local query=OverlapParams.new();query.FilterType=Enum.RaycastFilterType.Exclude
 query.FilterDescendantsInstances=excluded;query.RespectCanCollide=false
 for _,part in ipairs(workspace:GetPartBoundsInBox(frame,size,query)) do
  if Ground.Blocks(part,groundY,maxStep) then return part end
 end
end
function Ground.Sweep(frame,size,direction,excluded,groundY,maxStep)
 local ignored=table.clone(excluded)
 for _=1,12 do
  local hit=workspace:Blockcast(frame,size,direction,params(ignored,false))
  if not hit then return end
  local surface=Ground.Supports(hit.Instance)
  if not Ground.Blocks(hit.Instance,groundY,maxStep) or surface and hit.Normal.Y>.55 and hit.Position.Y<=groundY+maxStep then
   table.insert(ignored,hit.Instance)
  else return hit end
 end
end
function Ground.Start()
 if Ground.Started then return end
 Ground.Started=true
 local function prepare(object)
  if not object:IsA("BasePart") or object.Transparency>=.95 then return end
  if Ground.Marked(object) then object.CanQuery=true end
  if roadSurface(object) and Ground.Supports(object) then object.CanCollide=true end
 end
 for _,object in ipairs(workspace:GetDescendants()) do prepare(object) end
 workspace.DescendantAdded:Connect(function(object) task.defer(function() prepare(object) end) end)
end
return Ground
