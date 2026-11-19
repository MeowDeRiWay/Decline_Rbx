-- Query-only road support does not change character collision or road materials.
local Ground={}
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
function Ground.Sweep(frame,size,direction,excluded,groundY,maxStep)
 local ignored=table.clone(excluded)
 for _=1,12 do
  local hit=workspace:Blockcast(frame,size,direction,params(ignored,true))
  if not hit then return end
  local surface=Ground.Supports(hit.Instance)
  if surface and (hit.Normal.Y>.55 and hit.Position.Y<=groundY+maxStep or Ground.Marked(hit.Instance) and top(hit.Instance)<=groundY+maxStep) then
   table.insert(ignored,hit.Instance)
  else return hit end
 end
end
function Ground.Start()
 if Ground.Started then return end
 Ground.Started=true
 local function prepare(object)
  if object:IsA("BasePart") and object.Transparency<.95 and Ground.Marked(object) and not object.CanQuery then object.CanQuery=true end
 end
 for _,object in ipairs(workspace:GetDescendants()) do prepare(object) end
 workspace.DescendantAdded:Connect(function(object) task.defer(function() prepare(object) end) end)
end
return Ground
