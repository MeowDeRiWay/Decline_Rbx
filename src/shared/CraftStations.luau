local Stations={}
local supported={Stove=true,CuttingBoard=true,Workstation=true,MedStation=true,ArmorStation=true,ChemistryStation=true,ArmsBench=true,Furnace=true}
local attributes={"MedStation","ArmorStation","WeaponStation","ChemistryStation","Workstation","Stove","CuttingBoard","Furnace"}
local function canonical(kind) return kind=="WeaponStation" and "ArmsBench" or kind end
function Stations.Kind(model)
 if not model or not model:IsA("Model") then return nil end
 for _,attribute in ipairs(attributes) do
  if model:GetAttribute(attribute)==true then return canonical(attribute) end
 end
 -- Keep existing named stations and CraftStation strings working.
 local kind=canonical(model:GetAttribute("CraftStation") or model.Name)
 return supported[kind] and kind or nil
end
function Stations.Label(model)
 local kind=Stations.Kind(model)
 local names={ArmsBench="Weapons station",MedStation="Medical station",ArmorStation="Armor station",ChemistryStation="Chemistry station"}
 return names[kind] or kind or model.Name
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
