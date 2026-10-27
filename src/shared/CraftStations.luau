local Stations={}
local supported={Stove=true,CuttingBoard=true,Workstation=true,MedStation=true,ArmsBench=true,Furnace=true}
function Stations.Kind(model)
 if not model or not model:IsA("Model") then return nil end
 local kind=model:GetAttribute("CraftStation") or model.Name
 if typeof(kind)=="string" then kind=kind:match("^(.-) %(T%d+%)$") or kind end
 return supported[kind] and kind or nil
end
function Stations.Level(model)
 local level=model:GetAttribute("StationLevel")
 if level==nil then level=tonumber(model.Name:match(" %(T(%d+)%)$")) or 1 end
 if typeof(level)~="number" or level~=level or level==math.huge or level<1 then return 1 end
 return math.floor(level)
end
function Stations.Label(model)
 local kind=Stations.Kind(model)
 return string.format("%s (T%d)",kind=="ArmsBench" and "Arms Bench" or kind=="MedStation" and "Medical station" or kind or model.Name,Stations.Level(model))
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
 return (not recipe.StationLevel or Stations.Level(model)>=recipe.StationLevel)
  and (not recipe.WorkshopLevel or Stations.WorkshopLevel(model)>=recipe.WorkshopLevel)
end
return Stations
