local Stations={}
local supported={Stove=true,CuttingBoard=true,Workstation=true,ArmsBench=true,Furnace=true}
function Stations.Kind(model)
 if not model or not model:IsA("Model") then return nil end
 local kind=model:GetAttribute("CraftStation") or model.Name
 return supported[kind] and kind or nil
end
function Stations.Matches(recipe,kind)
 if recipe.Station==kind then return true end
 return recipe.Stations~=nil and table.find(recipe.Stations,kind)~=nil
end
function Stations.WorkshopLevel(model)
 local ancestor=model
 while ancestor do
  if ancestor:GetAttribute("BuildingID")=="Workbench" then return ancestor:GetAttribute("BuildingLevel") or 1 end
  ancestor=ancestor.Parent
 end
 return 0
end
function Stations.Allowed(model,recipe)
 return not recipe.WorkshopLevel or Stations.WorkshopLevel(model)>=recipe.WorkshopLevel
end
return Stations
