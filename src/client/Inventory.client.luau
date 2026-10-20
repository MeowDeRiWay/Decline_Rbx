local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local Theme = require(ReplicatedStorage.Shared.UITheme)
local ItemConfig = require(ReplicatedStorage.Shared:WaitForChild("ItemConfig"))
local remotes = ReplicatedStorage:WaitForChild("InventoryRemotes")
local action = remotes:WaitForChild("Action")
local stateRemote = remotes:WaitForChild("State")
local snapshot = {Items = {}, Equipment = {}, Weight = 0}
local dropAmounts = {}
local selectedItem = nil
local chestOpen = false
local chestReadOnly = false
local cookingOpen=false
local Recipes=require(ReplicatedStorage.Shared.CraftConfig)
local CraftRules=require(ReplicatedStorage.Shared.CraftRules)
local selectedRecipe=nil
local craftAmounts={}
local craftStatuses={}
local gui = Instance.new("ScreenGui")
gui.Name, gui.ResetOnSpawn, gui.Enabled = "InventoryUI", false, false
gui.Parent = player:WaitForChild("PlayerGui")
local window = Instance.new("Frame")
window.Name = "Window"
window.AnchorPoint = Vector2.new(0.5, 0.5)
window.Position = UDim2.fromScale(0.5, 0.45)
window.Size = UDim2.fromOffset(1060, 600)
local windowScale = Instance.new("UIScale")
windowScale.Parent = window
window.BackgroundColor3 = Theme.Background
window.BorderSizePixel = 0
window.Parent = gui
local constraint = Instance.new("UISizeConstraint")
constraint.MaxSize = Vector2.new(1060, 600)
Theme.Bevel(window)
constraint.Parent = window
local function text(parent, caption, position, size)
 local t = Instance.new("TextLabel")
 t.Text, t.Position, t.Size = caption, position, size
 t.BackgroundTransparency = 1
 t.TextColor3 = Theme.Text
 t.Font, t.TextSize = Theme.Font, 18
 t.TextXAlignment = Enum.TextXAlignment.Left
 t.TextWrapped = true
 t.Parent = parent
 return t
end
local function button(parent, caption, position, size)
 local b = Instance.new("TextButton")
 b.Text, b.Position, b.Size = caption, position, size
 b.BackgroundColor3 = Theme.Button
 b.BorderSizePixel = 0
 b.TextColor3 = Theme.Text
 b.Font, b.TextSize, b.TextWrapped = Theme.Font, 15, true
 Theme.Bevel(b)
 b.Parent = parent
 return b
end
text(window, "Inventory", UDim2.fromOffset(20, 12), UDim2.new(0.5, -30, 0, 32))
local rightTitle = text(window, "Equipment", UDim2.new(0.5, 12, 0, 12), UDim2.new(0.5, -65, 0, 32))
local close = button(window, "×", UDim2.new(1, -44, 0, 12), UDim2.fromOffset(28, 28))
text(window, "Pockets", UDim2.fromOffset(180, 12), UDim2.fromOffset(310, 32))
text(window, "I — close", UDim2.new(0.5, 12, 1, -44), UDim2.new(0.5, -30, 0, 32))
local divider = Instance.new("Frame")
divider.Position, divider.Size = UDim2.new(0.5, 0, 0, 52), UDim2.new(0, 1, 1, -108)
divider.BorderSizePixel, divider.BackgroundColor3, divider.Parent = 0, Theme.Border, window
local function column(name, position)
 local frame = Instance.new("ScrollingFrame")
 frame.Name, frame.Position = name, position
 frame.Size = UDim2.new(0.5, -32, 1, -108)
 frame.BackgroundTransparency, frame.BorderSizePixel = 1, 0
 frame.ScrollBarThickness = 4
 frame.CanvasSize, frame.AutomaticCanvasSize = UDim2.new(), Enum.AutomaticSize.Y
 frame.Parent = window
 local layout = Instance.new("UIListLayout")
 layout.Padding, layout.SortOrder, layout.Parent = UDim.new(0, 8), Enum.SortOrder.LayoutOrder, frame
 return frame
end
local inventory = column("Items", UDim2.fromOffset(180, 56))
inventory.Size = UDim2.new(.5, -192, 1, -108)
local equipment = column("Slots", UDim2.new(0.5, 12, 0, 56))
local status = Instance.new("Frame")
status.Name = "SurvivalStatus"
status.Position, status.Size = UDim2.fromOffset(20,56), UDim2.new(0,140,1,-108)
status.BackgroundColor3 = Theme.Card
status.Parent = window
Theme.Bevel(status)
local statusEntries = {}
for index, entry in ipairs({{"Food","Food"},{"Water","Water"},{"Sickness","Sick"},{"Weight","LoadKg"}}) do
 local y = 16 + (index-1)*88
 local heading = text(status,entry[1],UDim2.fromOffset(12,y),UDim2.fromOffset(116,22))
 heading.TextSize=15
 local value = text(status,"—",UDim2.fromOffset(12,y+25),UDim2.fromOffset(116,24))
 value.TextSize=14
 local track=Instance.new("Frame")
 track.Position,track.Size=UDim2.fromOffset(12,y+56),UDim2.fromOffset(116,6)
 track.BackgroundColor3=Theme.Background;track.BorderSizePixel=0;track.Parent=status
 local fill=Instance.new("Frame")
 fill.Size=UDim2.fromScale(0,1);fill.BackgroundColor3=Theme.Green;fill.BorderSizePixel=0;fill.Parent=track
 statusEntries[index]={Attribute=entry[2],Value=value,Fill=fill}
end
local statusElapsed=0
RunService.RenderStepped:Connect(function(dt)
 local camera=workspace.CurrentCamera
 if camera then windowScale.Scale=math.min(1,camera.ViewportSize.X*.94/1060,camera.ViewportSize.Y*.85/600) end
 if not gui.Enabled then return end
 statusElapsed+=dt
 if statusElapsed<.1 then return end
 statusElapsed=0
 local character=player.Character
 for _,entry in ipairs(statusEntries) do
  local value=character and character:GetAttribute(entry.Attribute)
  local maximum=entry.Attribute=="LoadKg" and (player:GetAttribute("CarryLimitKg") or (character and character:GetAttribute("CarryLimitKg")) or 20) or 100
  if typeof(value)=="number" then
   entry.Value.Text=string.format(entry.Attribute=="LoadKg" and "%.1f / %.0f kg" or "%.0f / %.0f",value,maximum)
   entry.Fill.Size=UDim2.fromScale(math.clamp(value/math.max(1,maximum),0,1),1)
   entry.Fill.BackgroundColor3=(entry.Attribute=="Sick" or entry.Attribute=="LoadKg") and (value>(entry.Attribute=="Sick" and 0 or maximum) and Theme.Danger or Theme.Green) or Theme.Green
  else entry.Value.Text="—";entry.Fill.Size=UDim2.fromScale(0,1) end
 end
end)
local function clear(frame)
 for _, child in ipairs(frame:GetChildren()) do if child:IsA("GuiObject") then child:Destroy() end end
end
local takeAll = button(window,"Take all",UDim2.new(.5,12,1,-88),UDim2.new(.5,-32,0,32))
takeAll.Visible=false
takeAll.Activated:Connect(function() action:FireServer("TakeAll") end)
local redraw
local tooltip = text(gui, "", UDim2.new(), UDim2.fromOffset(300, 170))
tooltip.Name = "ItemTooltip"
tooltip.BackgroundTransparency = 0.05
tooltip.BackgroundColor3 = Theme.Card
tooltip.TextSize = 13
tooltip.TextXAlignment = Enum.TextXAlignment.Center
tooltip.ZIndex = 20
tooltip.Visible = false
local function returnText(definition)
 local names={}
 for id,count in pairs(definition.ReturnItems or {}) do
  local name=ItemConfig.Items[id] and ItemConfig.Items[id].Name or id
  table.insert(names,count>1 and (name.." ×"..count) or name)
 end
 table.sort(names)
 return #names>0 and ("Returns "..table.concat(names,", ")) or ""
end
local function effectText(definition)
 local effects = definition.Consume
 if definition.Armor then
  return string.format("Armor %g / %g%%\nAbsorption / resistance",definition.Armor.Absorption or 0,(definition.Armor.Resistance or 0)*100)
 end
 if definition.Weapon then
  local w = definition.Weapon
  return string.format("Damage %d · %s\n%d attacks/min",w.Damage,w.DamageType,w.AttacksPerMinute) .. (definition.CraftTool and string.format("\nCraft speed ×%g",definition.CraftSpeed or 1) or "")
 end
 if not effects then return "Crafting material" end
 return string.format("Food %+.0f\nWater %+.0f\nSickness %+.0f", effects.Food or 0, effects.Water or 0, effects.Sick or 0) .. (definition.ReturnItems and ("\n"..returnText(definition)) or "")
end
RunService.RenderStepped:Connect(function()
 if not gui.Enabled then tooltip.Visible = false end
 if not tooltip.Visible then return end
 local mouse = UserInputService:GetMouseLocation()
 local inset = game:GetService("GuiService"):GetGuiInset()
 local position = mouse - inset
 local viewport = workspace.CurrentCamera.ViewportSize
 tooltip.Position = UDim2.fromOffset(math.clamp(position.X + 16,0,math.max(0,viewport.X-300)),math.clamp(position.Y+16,0,math.max(0,viewport.Y-inset.Y-170)))
end)
local function renderItems(frame, items, side)
 local cards = {}
 local stacks=side=="Player" and snapshot.Stacks or snapshot.ChestStacks
 if not stacks then
  stacks={}
  for id,count in pairs(items) do table.insert(stacks,{ID=id,Key=id,Count=count}) end
 end
 table.sort(stacks,function(a,b)
  local x,y=ItemConfig.Items[a.ID].Name or a.ID,ItemConfig.Items[b.ID].Name or b.ID
  return x==y and a.Key<b.Key or x<y
 end)
 if #stacks==0 then text(frame,side=="Chest" and "Chest is empty" or "Inventory is empty",UDim2.new(),UDim2.new(1,-8,0,50)) end
 for order,stack in ipairs(stacks) do
  local id=stack.ID
  local definition=ItemConfig.Items[id]
  local multiplier=side=="Player" and (player:GetAttribute("AmmoWeightMultiplier") or 1) or 1
  local itemWeight=(definition.Weight or 0)*(definition.Ammo and multiplier or 1)
  local ammo=definition.Firearm and ItemConfig.Items["Ammo"..definition.Firearm.Caliber..(stack.AmmoType or "FMJ")]
  if ammo then itemWeight+=(stack.Loaded or 0)*ammo.Weight*multiplier end
  local key=side..":"..stack.Key
  local selection=definition.Weapon and {ID=id,Key=stack.Key} or id
  local caption=string.format("%s ×%d",definition.Name or id,stack.Count)
  local available=stack.Count
  local selected = math.clamp(dropAmounts[key] or 1, 1, available)
  local container = Instance.new("Frame")
  container.Size = UDim2.new(1, -8, 0, 68)
  container.BackgroundColor3 = Theme.Card
  container.BorderSizePixel = 0
  container.LayoutOrder = order
  container.Parent = frame
  local row = button(container, caption, UDim2.fromOffset(6, 6), UDim2.new(1, -12, 0, 56))
  row.MouseEnter:Connect(function()
   tooltip.Text = (definition.Name or id) .. "\n" .. effectText(definition)..(definition.Weapon and string.format("\nCondition %d / %d",stack.Condition or 0,definition.Weapon.MaxUses) or "")..(definition.Firearm and string.format("\nLoaded %d / %d · %s",stack.Loaded or 0,definition.Firearm.Magazine,stack.AmmoType or "FMJ") or "") .. string.format(definition.Ammo and "\nWeight %.3f kg" or "\nWeight %.1f kg", itemWeight)
   tooltip.Visible = true
  end)
  row.MouseLeave:Connect(function() tooltip.Visible = false end)
  if chestOpen and chestReadOnly and side == "Player" then continue end
  local extraAction = not chestOpen and (definition.Slot or definition.Consume)
  local actions = Instance.new("Frame")
  actions.Name = "ItemActions"
  actions.Position = UDim2.fromOffset(0, 68)
  actions.Size = UDim2.new(1, 0, 0, extraAction and 110 or 68)
  actions.BackgroundTransparency = 1
  actions.Parent = container
  local card = {container = container, actions = actions, row = row, expandedHeight = extraAction and 184 or 142}
  cards[key] = card
  local function showActions(entry, expanded)
   entry.actions.Visible = expanded
   entry.container.Size = UDim2.new(1, -8, 0, expanded and entry.expandedHeight or 68)
   entry.row.BackgroundColor3 = expanded and Theme.Button or Theme.Button
  end
  showActions(card, selectedItem == key)
  row.Activated:Connect(function()
   if selectedItem == key then selectedItem = nil else selectedItem = key end
   redraw()
  end)
  local minus = button(actions, "−", UDim2.fromOffset(6, 0), UDim2.fromOffset(32, 28))
  local plus = button(actions, "+", UDim2.new(1, -38, 0, 0), UDim2.fromOffset(32, 28))
  local amount = Instance.new("TextBox")
  amount.Name = "DropQuantity"
  amount.Position = UDim2.fromOffset(44, 0)
  amount.Size = UDim2.new(1, -88, 0, 28)
  amount.BackgroundColor3 = Theme.Card
  amount.BorderSizePixel = 0
  amount.TextColor3 = Theme.Text
  amount.Font, amount.TextSize = Theme.Font, 15
  amount.ClearTextOnFocus = false
  amount.PlaceholderText = "Quantity"
  amount.Text = tostring(selected)
  amount.Parent = actions
  local function selectAmount(value)
   selected = math.clamp(math.floor(value), 1, available)
   dropAmounts[key] = selected
   amount.Text = tostring(selected)
  end
  local function readAmount()
   local value = tonumber(amount.Text)
   if not value or value ~= value or math.abs(value) == math.huge then value = selected end
   selectAmount(value)
  end
  minus.Activated:Connect(function() readAmount(); selectAmount(selected - 1) end)
  plus.Activated:Connect(function() readAmount(); selectAmount(selected + 1) end)
  amount.FocusLost:Connect(readAmount)
  local drop = button(actions, chestOpen and (chestReadOnly and "Take" or "Transfer") or "Drop", UDim2.fromOffset(6, 36), UDim2.new(0.5, -9, 0, 32))
  local all = button(actions, chestOpen and (chestReadOnly and "Take all" or "Transfer all") or "Drop all", UDim2.new(0.5, 3, 0, 36), UDim2.new(0.5, -9, 0, 32))
  drop.Activated:Connect(function() readAmount(); action:FireServer(chestOpen and (side == "Chest" and "TransferOut" or "TransferIn") or "Drop", selection, selected) end)
  all.Activated:Connect(function() action:FireServer(chestOpen and (side == "Chest" and "TransferOut" or "TransferIn") or "Drop", selection, "All") end)
  if definition.Consume and not chestOpen then
   local eat = button(actions, definition.ConsumeAction or "Eat", UDim2.fromOffset(6, 74), UDim2.new(1, -12, 0, 32))
   eat.Activated:Connect(function() action:FireServer("Eat", id) end)
  elseif definition.Slot and not chestOpen then
   local equip = button(actions, "Equip", UDim2.fromOffset(6, 74), UDim2.new(1, -12, 0, 32))
   equip.Activated:Connect(function() action:FireServer("Equip", selection) end)
  end
 end
end
local function renderRecipes()
 table.clear(craftStatuses)
 local ids={}
 for id,recipe in pairs(Recipes) do if recipe.Station==snapshot.CookingStation then table.insert(ids,id) end end
 table.sort(ids)
 if #ids==0 then text(equipment,"No recipes available yet.",UDim2.fromOffset(8,8),UDim2.new(1,-16,0,50)) end
 for order,id in ipairs(ids) do
  local recipe=Recipes[id]
  local available=CraftRules.Available(snapshot.Items,recipe)
  local speed=CraftRules.Speed(snapshot.CraftTools or {},recipe)
  local card=Instance.new("Frame")
  local expanded=selectedRecipe==id
  card.Size=UDim2.new(1,-8,0,expanded and 370 or 56)
  card.BackgroundColor3=Theme.Card
  card.BorderSizePixel=0
  card.LayoutOrder=order
  card.Parent=equipment
  local title=button(card,recipe.Name,UDim2.fromOffset(6,6),UDim2.new(1,-12,0,44))
  title.TextSize=16
  title.BackgroundColor3=expanded and Theme.Button or Theme.Button
  title.Activated:Connect(function()
   if selectedRecipe==id then selectedRecipe=nil else selectedRecipe=id end
   redraw()
  end)
  -- Only the selected recipe creates its description and crafting controls.
  if not expanded then continue end
  local description=text(card,recipe.Description,UDim2.fromOffset(10,56),UDim2.new(1,-20,0,46))
  description.TextWrapped=true
  local ingredients={}
  for item,count in pairs(recipe.Ingredients) do table.insert(ingredients,string.format("%d %s (%d owned)",count,ItemConfig.Items[item].Name,snapshot.Items[item] or 0)) end
  if recipe.Variants then
   local names,total={},0
   for _,variant in ipairs(recipe.Variants) do
    table.insert(names,ItemConfig.Items[variant.Ingredient].Name)
    total+=snapshot.Items[variant.Ingredient] or 0
   end
   table.insert(ingredients,"1 "..table.concat(names," or ").." ("..total.." owned)")
  end
  table.sort(ingredients)
  local ingredientsText=text(card,table.concat(ingredients,"\n")..string.format("\n→ %d %s",recipe.OutputCount or 1,(recipe.Output and ItemConfig.Items[recipe.Output].Name or "Meal matching the plate")),UDim2.fromOffset(10,104),UDim2.new(1,-20,0,74))
  ingredientsText.TextSize=14; ingredientsText.TextWrapped=true
  local tool=recipe.Tool and (speed and string.format("Knife required · Speed ×%g",speed) or "Knife required · Missing usable knife") or "No tool required"
  text(card,string.format("Batch: 1–%d · Time: %g seconds\n%s",recipe.MaxBatch,recipe.Duration/(speed or 1),tool .. (recipe.RequiresPresence and " · Stay here" or "")),UDim2.fromOffset(10,181),UDim2.new(1,-20,0,44)).TextSize=14
  local amount=Instance.new("TextBox")
  amount.Size=UDim2.new(.4,-12,0,30)
  amount.Position=UDim2.new(.3,6,0,229)
  amount.BackgroundColor3=Theme.Background
  amount.TextColor3=Theme.Text
  amount.Font=Theme.Font
  amount.TextSize=16
  amount.ClearTextOnFocus=false
  amount.Text=tostring(craftAmounts[id] or 1)
  amount.Parent=card
  local function quantity()
   local value=tonumber(amount.Text) or craftAmounts[id] or 1
   if value~=value or math.abs(value)==math.huge then value=1 end
   value=math.clamp(math.floor(value),1,recipe.MaxBatch)
   craftAmounts[id]=value
   amount.Text=tostring(value)
   return value
  end
  button(card,"−",UDim2.fromOffset(10,229),UDim2.new(.3,-12,0,30)).Activated:Connect(function() amount.Text=tostring(quantity()-1); quantity() end)
  button(card,"+",UDim2.new(.7,6,0,229),UDim2.new(.3,-16,0,30)).Activated:Connect(function() amount.Text=tostring(quantity()+1); quantity() end)
  amount.FocusLost:Connect(quantity)
  local cook=button(card,"Craft",UDim2.fromOffset(10,267),UDim2.new(.5,-15,0,32))
  local all=button(card,string.format("Craft all (max %d)",recipe.MaxBatch),UDim2.new(.5,5,0,267),UDim2.new(.5,-15,0,32))
  local busy=(snapshot.CookingEndsAt or 0)>0
  local enabled=not busy and available>0 and speed~=nil
  cook.Active,all.Active=enabled,enabled
  cook.AutoButtonColor,all.AutoButtonColor=enabled,enabled
  cook.TextTransparency,all.TextTransparency=enabled and 0 or .5,enabled and 0 or .5
  cook.Activated:Connect(function() if enabled then action:FireServer("Cook",id,quantity()) end end)
  all.Activated:Connect(function() if enabled then action:FireServer("Cook",id,"All") end end)
  local ready=0
  for _,output in ipairs(CraftRules.Outputs(recipe)) do ready+=(snapshot.CookingReady or {})[output] or 0 end
  craftStatuses[id]=text(card,busy and "Station is busy" or string.format("Ready: %d · Available batches: %d",ready,available),UDim2.fromOffset(10,303),UDim2.new(1,-20,0,25))
  local collect=button(card,"Collect",UDim2.fromOffset(10,336),UDim2.new(.5,-15,0,27))
  local collectAll=button(card,"Collect all",UDim2.new(.5,5,0,336),UDim2.new(.5,-15,0,27))
  collect.Activated:Connect(function() if ready>0 then action:FireServer("CollectRecipe",id,math.min(quantity(),ready)) end end)
  collectAll.Activated:Connect(function() if ready>0 then action:FireServer("CollectRecipe",id,"All") end end)
 end
end
local function foodDetails(definition,bonus)
 local effects=definition.Consume
 if not effects then return bonus and (definition.Weapon and effectText(definition) or "None") or (definition.Weapon and "Cannot damage structures" or "None") end
 local lines={}
 for _,entry in ipairs({{"Food",effects.Food or 0},{"Water",effects.Water or 0},{"Sickness",effects.Sick or 0}}) do
  local isBonus=entry[1]=="Sickness" and entry[2]<0 or entry[1]~="Sickness" and entry[2]>0
  if entry[2]~=0 and isBonus==bonus then table.insert(lines,string.format("%s %+.0f",entry[1],entry[2])) end
 end
 if bonus and definition.ReturnItems then table.insert(lines,returnText(definition)) end
 return #lines>0 and table.concat(lines,"\n") or "None"
end
redraw = function()
 tooltip.Visible = false
 local selectedId,selectedStack
 for _,stack in ipairs(snapshot.Stacks or {}) do
  if selectedItem=="Player:"..stack.Key then selectedId=stack.ID;selectedStack=stack end
 end
 local validSelection=selectedId~=nil
 for _,stack in ipairs(snapshot.ChestStacks or {}) do if selectedItem=="Chest:"..stack.Key then validSelection=true end end
 if not validSelection then selectedItem=nil end
 clear(inventory)
 clear(equipment)

 takeAll.Visible = chestOpen and chestReadOnly and not cookingOpen
 equipment.Size = UDim2.new(.5,-32,1,takeAll.Visible and -148 or -108)
 rightTitle.Text = cookingOpen and "Recipes" or chestOpen and (snapshot.ChestName or "Chest") or "Equipment"
 renderItems(inventory, snapshot.Items, "Player")
 if cookingOpen then renderRecipes(); return end
 if chestOpen then
  renderItems(equipment, snapshot.ChestItems or {}, "Chest")
  return
 end
 if selectedId then
  local definition = ItemConfig.Items[selectedId]
  rightTitle.Text = "Item details"
  local stateText=definition.Weapon and string.format("\nCondition %d / %d",selectedStack.Condition or 0,definition.Weapon.MaxUses) or ""
  if definition.Firearm then stateText..=string.format("\nLoaded %d / %d · %s",selectedStack.Loaded or 0,definition.Firearm.Magazine,selectedStack.AmmoType or "FMJ") end
  if definition.Armor then stateText..=string.format("\nArmor %g / %g%%",definition.Armor.Absorption or 0,(definition.Armor.Resistance or 0)*100) end
  local ammo=definition.Firearm and ItemConfig.Items["Ammo"..definition.Firearm.Caliber..(selectedStack.AmmoType or "FMJ")]
  local multiplier=player:GetAttribute("AmmoWeightMultiplier") or 1
  local itemWeight=(definition.Weight or 0)*(definition.Ammo and multiplier or 1)+(ammo and (selectedStack.Loaded or 0)*ammo.Weight*multiplier or 0)
  stateText..=string.format(definition.Ammo and "\nWeight %.3f kg" or "\nWeight %.1f kg",itemWeight)
  text(equipment,(definition.Name or selectedId)..stateText,UDim2.new(),UDim2.new(1,-8,0,90)).LayoutOrder=1
  local bonus = text(equipment, "Bonuses\n" .. foodDetails(definition,true), UDim2.new(), UDim2.new(1,-8,0,90))
  bonus.LayoutOrder,bonus.TextColor3 = 2,Color3.fromRGB(110,214,150)
  local debuff = text(equipment, "Debuffs\n" .. foodDetails(definition,false), UDim2.new(), UDim2.new(1,-8,0,64))
  debuff.LayoutOrder,debuff.TextColor3 = 3,Color3.fromRGB(232,133,133)
  local description = text(equipment, "Description\n" .. (definition.Description or "No description available."), UDim2.new(), UDim2.new(1,-8,0,160))
  description.LayoutOrder,description.TextYAlignment = 4,Enum.TextYAlignment.Top
  return
 end
 for order, slot in ipairs(ItemConfig.Slots) do
  local id = snapshot.Equipment[slot]
  local definition = id and ItemConfig.Items[id]
  local caption = slot .. "\n" .. (definition and (definition.Name or id) .. "  •  Click to unequip" or "Empty")
  local row = button(equipment, caption, UDim2.new(), UDim2.new(1, -8, 0, 66))
  row.LayoutOrder = order
  row.AutoButtonColor = id ~= nil
  row.Activated:Connect(function() if id then action:FireServer("Unequip", slot) end end)
 end
end
local function setOpen(open)
 if open and (player:GetAttribute("TownMenuOpen") or (player.Character and player.Character:GetAttribute("Knockout"))) then return end
 if open and player:GetAttribute("ProgressionOpen") then return end
 if not open then
  selectedRecipe = nil
  selectedItem = nil
  if chestOpen then
   chestOpen = false
   cookingOpen=false
   action:FireServer("CloseChest")
  end
 end
 gui.Enabled = open
 player:SetAttribute("InventoryOpen", open)
 if open then
  ContextActionService:BindActionAtPriority("InventoryBlockMovement", function()
   return Enum.ContextActionResult.Sink
  end, false, Enum.ContextActionPriority.High.Value + 2,
   Enum.PlayerActions.CharacterForward, Enum.PlayerActions.CharacterBackward,
   Enum.PlayerActions.CharacterLeft, Enum.PlayerActions.CharacterRight,
   Enum.PlayerActions.CharacterJump)
  RunService:BindToRenderStep("InventoryStopMovement", Enum.RenderPriority.Camera.Value + 3, function()
   local character = player.Character
   local humanoid = character and character:FindFirstChildOfClass("Humanoid")
   if humanoid then humanoid:Move(Vector3.zero, false) end
  end)
  redraw()
  action:FireServer("Request")
 else
  ContextActionService:UnbindAction("InventoryBlockMovement")
  RunService:UnbindFromRenderStep("InventoryStopMovement")
 end
end
require(script.Parent.HUDLayout).Inventory.Event:Connect(function() setOpen(not gui.Enabled) end)
close.Activated:Connect(function() setOpen(false) end)
UserInputService.InputBegan:Connect(function(input, processed)
 if processed or UserInputService:GetFocusedTextBox() or player:GetAttribute("TownMenuOpen") then return end
 if player.Character and player.Character:GetAttribute("Knockout") then return end
 if input.KeyCode == Enum.KeyCode.I then setOpen(not gui.Enabled) end
end)
player.CharacterAdded:Connect(function() setOpen(false) end)
stateRemote.OnClientEvent:Connect(function(value)
 if value.CookingOpen~=true or snapshot.CookingOpen~=true or value.CookingStation~=snapshot.CookingStation then selectedRecipe=nil end
 snapshot = value
 local wasChestOpen = chestOpen
 cookingOpen=value.CookingOpen==true
 chestOpen = value.ChestOpen == true or cookingOpen
 chestReadOnly = value.ChestReadOnly == true or cookingOpen
 if chestOpen then
  if not wasChestOpen then selectedItem = nil end
  if not gui.Enabled then setOpen(true) else redraw() end
 elseif wasChestOpen then
  setOpen(false)
 elseif gui.Enabled then redraw() end
end)
action:FireServer("Request")

RunService.RenderStepped:Connect(function()
 if gui.Enabled and player.Character and player.Character:GetAttribute("Knockout") then setOpen(false) end
end)

RunService.RenderStepped:Connect(function()
 local craftStatus=snapshot.CookingRecipe and craftStatuses[snapshot.CookingRecipe]
 if cookingOpen and craftStatus and craftStatus.Parent and (snapshot.CookingEndsAt or 0)>0 then
  local remaining=math.max(0,math.ceil(snapshot.CookingEndsAt-workspace:GetServerTimeNow()))
  craftStatus.Text=string.format("Cooking %d · %02d:%02d remaining",snapshot.CookingCount or 0,math.floor(remaining/60),remaining%60)
 end
end)
