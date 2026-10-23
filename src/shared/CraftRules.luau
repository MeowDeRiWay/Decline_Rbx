local Rules = {}
function Rules.Discount(recipe,multiplier)
 local result=table.clone(recipe);result.Ingredients={}
 for id,amount in pairs(recipe.Ingredients) do result.Ingredients[id]=math.max(1,math.ceil(amount*(multiplier or 1))) end
 return result
end
function Rules.Batch(available,requested,maximum)
 if available < 1 then return nil end
 if requested == "All" then return math.min(available,maximum) end
 if typeof(requested)~="number" or requested~=requested or requested<1 or requested>maximum or requested>available or requested~=math.floor(requested) then return nil end
 return requested
end
function Rules.Count(items,id) return (items[id] or 0)+(items["Ramsay_"..id] or 0) end
function Rules.Available(items,recipe)
 local available=math.huge
 for id,count in pairs(recipe.Ingredients) do
  local reserve=recipe.Fuel and recipe.Fuel.ID==id and recipe.Fuel.Count or 0
  available=math.min(available,math.floor((Rules.Count(items,id)-reserve)/count))
 end
 if recipe.Fuel and (items[recipe.Fuel.ID] or 0)<recipe.Fuel.Count then return 0 end
 if recipe.Variants then
  local total=0
  for _,variant in ipairs(recipe.Variants) do total+=items[variant.Ingredient] or 0 end
  available=math.min(available,total)
 end
 return available==math.huge and 0 or available
end
function Rules.Plan(items,recipe,count)
 if not Rules.Batch(Rules.Available(items,recipe),count,recipe.MaxBatch) then return nil end
 local inputs,outputs={},{}
 for id,amount in pairs(recipe.Ingredients) do
  local needed=amount*count;local ordinary=math.min(needed,items[id] or 0)
  if ordinary>0 then inputs[id]=ordinary end
  if needed>ordinary then inputs["Ramsay_"..id]=needed-ordinary end
 end
 if recipe.Fuel then inputs[recipe.Fuel.ID]=(inputs[recipe.Fuel.ID] or 0)+recipe.Fuel.Count end
 if recipe.Variants then
  local remaining=count
  for _,variant in ipairs(recipe.Variants) do
   local used=math.min(remaining,items[variant.Ingredient] or 0)
   if used>0 then
    inputs[variant.Ingredient]=(inputs[variant.Ingredient] or 0)+used
    outputs[variant.Output]=(outputs[variant.Output] or 0)+used*(recipe.OutputCount or 1)
   end
   remaining-=used
  end
 else outputs[recipe.Output]=count*(recipe.OutputCount or 1) end
 for id,amount in pairs(recipe.Byproducts or {}) do outputs[id]=(outputs[id] or 0)+amount*count end
 for id,amount in pairs(recipe.FuelByproducts or {}) do outputs[id]=(outputs[id] or 0)+amount end
 return {Ingredients=inputs,Outputs=outputs}
end
function Rules.Outputs(recipe)
 local result={}
 if recipe.Variants then for _,variant in ipairs(recipe.Variants) do table.insert(result,variant.Output) end
 else table.insert(result,recipe.Output) end
 if recipe.Food then for index=#result,1,-1 do table.insert(result,"Ramsay_"..result[index]) end end
 local found={};for id in pairs(recipe.Byproducts or {}) do found[id]=true end
 for id in pairs(recipe.FuelByproducts or {}) do found[id]=true end
 local extra={};for id in pairs(found) do table.insert(extra,id) end;table.sort(extra)
 for _,id in ipairs(extra) do table.insert(result,id) end
 return result
end
function Rules.Speed(tools,recipe)
 if not recipe.Tool then return 1 end
 return tools[recipe.Tool]
end
return Rules
