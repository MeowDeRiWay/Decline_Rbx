-- Bullet-only filtering. Pickup, medical targeting and vision keep their own rays.
local Cast={}
function Cast.Ignored(part)
 local object=part
 local item
 local folder=workspace:FindFirstChild("WorldItems")
 while object and object~=workspace do
  if object:IsA("Model") and object:FindFirstChildOfClass("Humanoid") then
   return object:GetAttribute("Knockout") and object or nil
  end
  if typeof(object:GetAttribute("Item_ID"))=="string" then item=object end
  if folder and object.Parent==folder then item=object end
  object=object.Parent
 end
 return item
end
function Cast.Raycast(origin,delta,ignored)
 local excluded=table.clone(ignored or {})
 local folder=workspace:FindFirstChild("WorldItems")
 if folder then table.insert(excluded,folder) end
 local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude
 while true do
  params.FilterDescendantsInstances=excluded
  local hit=workspace:Raycast(origin,delta,params)
  if not hit then return nil end
  local skip=Cast.Ignored(hit.Instance)
  if not skip then return hit end
  table.insert(excluded,skip)
 end
end
return Cast
