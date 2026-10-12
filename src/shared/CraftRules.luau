local Rules = {}
function Rules.Batch(available,requested,maximum)
 if available < 1 then return nil end
 if requested == "All" then return math.min(available,maximum) end
 if typeof(requested)~="number" or requested~=requested or requested<1 or requested>maximum or requested>available or requested~=math.floor(requested) then return nil end
 return requested
end
function Rules.Available(items,recipe)
 local available=math.huge
 for id,count in pairs(recipe.Ingredients) do available=math.min(available,math.floor((items[id] or 0)/count)) end
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
 for id,amount in pairs(recipe.Ingredients) do inputs[id]=amount*count end
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
 return {Ingredients=inputs,Outputs=outputs}
end
function Rules.Outputs(recipe)
 local result={}
 if recipe.Variants then for _,variant in ipairs(recipe.Variants) do table.insert(result,variant.Output) end
 else table.insert(result,recipe.Output) end
 return result
end
function Rules.Speed(tools,recipe)
 if not recipe.Tool then return 1 end
 return tools[recipe.Tool]
end
return Rules
