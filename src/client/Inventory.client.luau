local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local ItemConfig = require(ReplicatedStorage.Shared:WaitForChild("ItemConfig"))
local remotes = ReplicatedStorage:WaitForChild("InventoryRemotes")
local action = remotes:WaitForChild("Action")
local stateRemote = remotes:WaitForChild("State")
local snapshot = {Items = {}, Equipment = {}, Weight = 0}
local dropAmounts = {}
local selectedItem = nil
local chestOpen = false
local chestReadOnly = false
local gui = Instance.new("ScreenGui")
gui.Name, gui.ResetOnSpawn, gui.Enabled = "InventoryUI", false, false
gui.Parent = player:WaitForChild("PlayerGui")
local window = Instance.new("Frame")
window.Name = "Window"
window.AnchorPoint = Vector2.new(0.5, 0.5)
window.Position = UDim2.fromScale(0.5, 0.45)
window.Size = UDim2.fromScale(0.84, 0.7)
window.BackgroundColor3 = Color3.fromRGB(22, 28, 33)
window.BorderSizePixel = 0
window.Parent = gui
local constraint = Instance.new("UISizeConstraint")
constraint.MaxSize = Vector2.new(900, 600)
constraint.Parent = window
local function text(parent, caption, position, size)
 local t = Instance.new("TextLabel")
 t.Text, t.Position, t.Size = caption, position, size
 t.BackgroundTransparency = 1
 t.TextColor3 = Color3.fromRGB(235, 240, 244)
 t.Font, t.TextSize = Enum.Font.GothamMedium, 18
 t.TextXAlignment = Enum.TextXAlignment.Left
 t.TextWrapped = true
 t.Parent = parent
 return t
end
local function button(parent, caption, position, size)
 local b = Instance.new("TextButton")
 b.Text, b.Position, b.Size = caption, position, size
 b.BackgroundColor3 = Color3.fromRGB(42, 53, 62)
 b.BorderSizePixel = 0
 b.TextColor3 = Color3.fromRGB(235, 240, 244)
 b.Font, b.TextSize, b.TextWrapped = Enum.Font.Gotham, 15, true
 b.Parent = parent
 return b
end
text(window, "Inventory", UDim2.fromOffset(20, 12), UDim2.new(0.5, -30, 0, 32))
local rightTitle = text(window, "Equipment", UDim2.new(0.5, 12, 0, 12), UDim2.new(0.5, -65, 0, 32))
local close = button(window, "×", UDim2.new(1, -44, 0, 12), UDim2.fromOffset(28, 28))
local weight = text(window, "Weight 0.0 kg", UDim2.new(0, 20, 1, -44), UDim2.new(0.5, -30, 0, 32))
text(window, "Q — Close", UDim2.new(0.5, 12, 1, -44), UDim2.new(0.5, -30, 0, 32))
local divider = Instance.new("Frame")
divider.Position, divider.Size = UDim2.new(0.5, 0, 0, 52), UDim2.new(0, 1, 1, -108)
divider.BorderSizePixel, divider.BackgroundColor3, divider.Parent = 0, Color3.fromRGB(63, 73, 82), window
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
local inventory = column("Items", UDim2.fromOffset(20, 56))
local equipment = column("Slots", UDim2.new(0.5, 12, 0, 56))
local function clear(frame)
 for _, child in ipairs(frame:GetChildren()) do if child:IsA("GuiObject") then child:Destroy() end end
end
local takeAll = button(window,"Take all",UDim2.new(.5,12,1,-88),UDim2.new(.5,-32,0,32))
takeAll.Visible=false
takeAll.Activated:Connect(function() action:FireServer("TakeAll") end)
local redraw
local tooltip = text(gui, "", UDim2.new(), UDim2.fromOffset(270, 110))
tooltip.Name = "ItemTooltip"
tooltip.BackgroundTransparency = 0.05
tooltip.BackgroundColor3 = Color3.fromRGB(20, 26, 31)
tooltip.TextSize = 15
tooltip.TextXAlignment = Enum.TextXAlignment.Center
tooltip.ZIndex = 20
tooltip.Visible = false
local function effectText(definition)
 local effects = definition.Consume
 if definition.Weapon then
  local w = definition.Weapon
  return string.format("Damage %d · %s\n%d attacks/min · Resource %d hits",w.Damage,w.DamageType,w.AttacksPerMinute,w.MaxUses)
 end
 if not effects then return "No consumable effects" end
 return string.format("Food %+.0f\nSickness %+.0f", effects.Food or 0, effects.Sick or 0)
end
RunService.RenderStepped:Connect(function()
 if not gui.Enabled then tooltip.Visible = false end
 if not tooltip.Visible then return end
 local mouse = UserInputService:GetMouseLocation()
 local inset = game:GetService("GuiService"):GetGuiInset()
 local position = mouse - inset
 local viewport = workspace.CurrentCamera.ViewportSize
 tooltip.Position = UDim2.fromOffset(math.clamp(position.X + 16,0,math.max(0,viewport.X-270)),math.clamp(position.Y+16,0,math.max(0,viewport.Y-inset.Y-110)))
end)
local function renderItems(frame, items, side)
 local cards = {}
 local ids = {}
 for id in pairs(items) do table.insert(ids, id) end
 table.sort(ids, function(a,b) return (ItemConfig.Items[a].Name or a) < (ItemConfig.Items[b].Name or b) end)
 if #ids == 0 then text(frame, side == "Chest" and "Chest is empty" or "Inventory is empty", UDim2.new(), UDim2.new(1, -8, 0, 50)) end
 for order, id in ipairs(ids) do
  local definition = ItemConfig.Items[id]
  local key = side .. ":" .. id
  local caption = string.format("%s ×%d\n%.1f kg%s", definition.Name or id, items[id], (definition.Weight or 0) * items[id], "")
  local available = items[id]
  local selected = math.clamp(dropAmounts[key] or 1, 1, available)
  local container = Instance.new("Frame")
  container.Size = UDim2.new(1, -8, 0, 68)
  container.BackgroundColor3 = Color3.fromRGB(30, 38, 45)
  container.BorderSizePixel = 0
  container.LayoutOrder = order
  container.Parent = frame
  local row = button(container, caption, UDim2.fromOffset(6, 6), UDim2.new(1, -12, 0, 56))
  row.MouseEnter:Connect(function()
   tooltip.Text = (definition.Name or id) .. "\n" .. effectText(definition) .. string.format("\nWeight %.1f kg", definition.Weight or 0)
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
   entry.row.BackgroundColor3 = expanded and Color3.fromRGB(57, 78, 87) or Color3.fromRGB(42, 53, 62)
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
  amount.BackgroundColor3 = Color3.fromRGB(20, 26, 31)
  amount.BorderSizePixel = 0
  amount.TextColor3 = Color3.fromRGB(235, 240, 244)
  amount.Font, amount.TextSize = Enum.Font.GothamMedium, 15
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
  drop.Activated:Connect(function() readAmount(); action:FireServer(chestOpen and (side == "Chest" and "TransferOut" or "TransferIn") or "Drop", id, selected) end)
  all.Activated:Connect(function() action:FireServer(chestOpen and (side == "Chest" and "TransferOut" or "TransferIn") or "Drop", id, "All") end)
  if definition.Consume and not chestOpen then
   local eat = button(actions, "Eat", UDim2.fromOffset(6, 74), UDim2.new(1, -12, 0, 32))
   eat.Activated:Connect(function() action:FireServer("Eat", id) end)
  elseif definition.Slot and not chestOpen then
   local equip = button(actions, "Equip", UDim2.fromOffset(6, 74), UDim2.new(1, -12, 0, 32))
   equip.Activated:Connect(function() action:FireServer("Equip", id) end)
  end
 end
end
redraw = function()
 tooltip.Visible = false
 local selectedId = selectedItem and selectedItem:match("^Player:(.+)$")
 if selectedId and not snapshot.Items[selectedId] then selectedItem,selectedId = nil,nil end
 clear(inventory)
 clear(equipment)
 weight.Text = string.format("Weight %.1f kg", snapshot.Weight)
 takeAll.Visible = chestOpen and chestReadOnly
 equipment.Size = UDim2.new(.5,-32,1,takeAll.Visible and -148 or -108)
 rightTitle.Text = chestOpen and (snapshot.ChestName or "Chest") or "Equipment"
 renderItems(inventory, snapshot.Items, "Player")
 if chestOpen then
  renderItems(equipment, snapshot.ChestItems or {}, "Chest")
  return
 end
 if selectedId then
  local definition = ItemConfig.Items[selectedId]
  rightTitle.Text = "Item details"
  text(equipment, definition.Name or selectedId, UDim2.new(), UDim2.new(1,-8,0,40)).LayoutOrder = 1
  local bonus = text(equipment, "Bonuses\n" .. (definition.Consume and string.format("Food %+.0f",definition.Consume.Food or 0) or (definition.Weapon and effectText(definition) or "None")), UDim2.new(), UDim2.new(1,-8,0,90))
  bonus.LayoutOrder,bonus.TextColor3 = 2,Color3.fromRGB(110,214,150)
  local debuff = text(equipment, "Debuffs\n" .. (definition.Consume and string.format("Sickness %+.0f",definition.Consume.Sick or 0) or (definition.Weapon and "Cannot damage structures" or "None")), UDim2.new(), UDim2.new(1,-8,0,64))
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
 if not open then
  selectedItem = nil
  if chestOpen then
   chestOpen = false
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
close.Activated:Connect(function() setOpen(false) end)
UserInputService.InputBegan:Connect(function(input, processed)
 if processed or UserInputService:GetFocusedTextBox() then return end
 if player.Character and player.Character:GetAttribute("Knockout") then return end
 if input.KeyCode == Enum.KeyCode.Q then setOpen(not gui.Enabled) end
end)
player.CharacterAdded:Connect(function() setOpen(false) end)
stateRemote.OnClientEvent:Connect(function(value)
 snapshot = value
 local wasChestOpen = chestOpen
 chestOpen = value.ChestOpen == true
 chestReadOnly = value.ChestReadOnly == true
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
