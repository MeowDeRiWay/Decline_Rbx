-- Stable category IDs; only relevant categories appear on the current station.
local Categories={Order={"All","Armor","Weapons","Ammunition","Tools","Materials","Medicine","Equipment","Food"}}
Categories.Labels={Food="Food recipes"}
function Categories.Kind(recipe,items)
 if recipe.Category then return recipe.Category end
 local item=items[recipe.Output] or {}
 if recipe.Food or recipe.Boiled or item.Consume then return "Food" end
 if item.Armor then return "Armor" end
 if item.HarvestTool or item.CraftTool then return "Tools" end
 if item.Ammo then return "Ammunition" end
 if item.Weapon then return "Weapons" end
 if item.Slot=="Medicine" then return "Medicine" end
 if item.Slot then return "Equipment" end
 return "Materials"
end
function Categories.Available(recipes,items,stations,kind,fuel)
 local present={All=true}
 for _,recipe in pairs(recipes) do
  if stations.Matches(recipe,kind) and (kind~="Stove" or not recipe.FuelTab or recipe.FuelTab==fuel) then
   present[Categories.Kind(recipe,items)]=true
  end
 end
 local result={}
 for _,id in ipairs(Categories.Order) do if present[id] then table.insert(result,id) end end
 return result
end
function Categories.Matches(recipe,items,category)
 return category=="All" or Categories.Kind(recipe,items)==category
end
return Categories
