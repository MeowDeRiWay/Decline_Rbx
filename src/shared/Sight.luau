local Sight = {}
function Sight.Cast(origin,delta,character)
 local excluded = {character}
 local params = RaycastParams.new()
 params.FilterType = Enum.RaycastFilterType.Exclude
 params.IgnoreWater = true
 for _=1,32 do
  params.FilterDescendantsInstances = excluded
  local hit = workspace:Raycast(origin,delta,params)
  if not hit then return nil end
  local object,setting = hit.Instance,nil
  local ancestor = object
  while ancestor and ancestor ~= workspace do
   local value = ancestor:GetAttribute("BlocksVision")
   if typeof(value) == "boolean" then setting = value end
   ancestor = ancestor.Parent
  end
  if setting == true then return hit end
  if setting == false or (object:IsA("BasePart") and (object.Transparency >= .95 or not object.CanCollide)) then table.insert(excluded,object)
  else return hit end
 end
 return workspace:Raycast(origin,delta,params)
end
return Sight
