local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local player = Players.LocalPlayer
local Config = require(ReplicatedStorage.Shared:WaitForChild("ItemConfig"))
local Interaction = require(ReplicatedStorage.Shared:WaitForChild("Interaction"))
local folder = workspace:WaitForChild("WorldItems")
local action = ReplicatedStorage:WaitForChild("InventoryRemotes"):WaitForChild("Action")
local highlight = Instance.new("Highlight")
highlight.Name = "ItemHover"
highlight.FillColor = Color3.fromRGB(220, 190, 90)
highlight.FillTransparency = 0.7
highlight.OutlineColor = Color3.fromRGB(255, 235, 155)
highlight.DepthMode = Enum.HighlightDepthMode.Occluded
highlight.Enabled = false
highlight.Parent = workspace
local gui = Instance.new("ScreenGui")
gui.Name, gui.ResetOnSpawn, gui.IgnoreGuiInset = "ItemHoverUI", false, true
gui.Parent = player:WaitForChild("PlayerGui")
local label = Instance.new("TextLabel")
label.Size = UDim2.fromOffset(200, 44)
label.BackgroundColor3 = Color3.fromRGB(22, 28, 33)
label.BackgroundTransparency = 0.1
label.BorderSizePixel = 0
label.TextColor3 = Color3.fromRGB(240, 240, 235)
label.Font, label.TextSize, label.Visible = Enum.Font.GothamMedium, 15, false
label.Parent = gui
local hovered, reachable, chestHovered = nil, false, false
local stoveHovered=false
RunService:BindToRenderStep("WorldItemHover", Enum.RenderPriority.Camera.Value + 4, function()
 hovered, reachable, chestHovered = nil, false, false
 stoveHovered=false
 highlight.Enabled, label.Visible = false, false
 local character = player.Character
 local root = character and character:FindFirstChild("HumanoidRootPart")
 local camera = workspace.CurrentCamera
 if not root or not camera or character:GetAttribute("Knockout") or (player:GetAttribute("InventoryOpen") or player:GetAttribute("TownMenuOpen") or (player:GetAttribute("ProgressionOpen") or player:GetAttribute("GroupOpen"))) or GuiService.MenuIsOpen or UserInputService:GetFocusedTextBox() then return end
 local mouse = UserInputService:GetMouseLocation()
 -- GetMouseLocation already matches ViewportPointToRay coordinates.
 local viewportMouse = mouse
 if viewportMouse.X < 0 or viewportMouse.Y < 0 or viewportMouse.X > camera.ViewportSize.X or viewportMouse.Y > camera.ViewportSize.Y then return end
 local ray = camera:ViewportPointToRay(viewportMouse.X, viewportMouse.Y)
 local params = RaycastParams.new()
 params.FilterType = Enum.RaycastFilterType.Exclude
 params.FilterDescendantsInstances = {character}
 local hit = workspace:Raycast(ray.Origin, ray.Direction * 1000, params)
 if not hit then return end
 local chest = hit.Instance
 while chest and chest ~= workspace do
  if chest:IsA("Model") and (chest.Name == "Chest" or (chest.Name == "Stove" or chest.Name == "CuttingBoard" or chest.Name == "Workstation") or chest:GetAttribute("IsCorpse") == true) then break end
  chest = chest.Parent
 end
 if chest and chest ~= workspace then
  if chest:GetAttribute("IsCorpse") and chest:GetAttribute("ClientVisible") ~= true then return end
  local nearest = Interaction.NearestPoint(chest,root.Position)
  hovered, chestHovered = chest, true
  stoveHovered=chest.Name=="Stove" or chest.Name=="CuttingBoard" or chest.Name=="Workstation"
  reachable = (nearest-root.Position).Magnitude <= Config.PickupDistance
  highlight.FillColor = Color3.fromRGB(80,190,110)
  highlight.OutlineColor = Color3.fromRGB(125,255,160)
  highlight.Adornee, highlight.Enabled = chest, true
  label.Text = (chest:GetAttribute("IsCorpse") and ((chest:GetAttribute("DisplayName") or "Zombie") .. " corpse") or (stoveHovered and (chest.Name=="CuttingBoard" and "Cutting Board" or chest.Name=="Workstation" and "Workstation" or "Stove") or "Chest")) .. (reachable and (chest:GetAttribute("IsCorpse") and "\n[E] Loot" or "\n[E] Open") or "\nToo far")
  if stoveHovered and chest.Name~="Workstation" and player:GetAttribute("Profession")~="Cook" then label.Text=chest.Name.."\nCook profession required" end
  label.Position = UDim2.fromOffset(math.clamp(mouse.X+16,0,math.max(0,camera.ViewportSize.X-200)),math.clamp(mouse.Y+16,0,math.max(0,camera.ViewportSize.Y-44)))
  label.Visible = true
  return
 end
 local item = hit.Instance
 while item and item.Parent ~= folder do item = item.Parent end
 if not item then return end
 local definition = Config.Items[item:GetAttribute("Item_ID") or item.Name]
 if not definition then return end
 hovered = item
 reachable = Interaction.Distance(item,root.Position) <= Config.PickupDistance
 highlight.FillColor = Color3.fromRGB(220,190,90)
 highlight.OutlineColor = Color3.fromRGB(255,235,155)
 highlight.Adornee, highlight.Enabled = item, true
 local count = item:GetAttribute("Quantity") or 1
 local caption = (definition.Name or item.Name) .. (count > 1 and " ×" .. tostring(count) or "")
 label.Text = caption .. (reachable and "\n[E] Pick up" or "\nToo far")
 label.Position = UDim2.fromOffset(math.clamp(mouse.X + 16, 0, math.max(0, camera.ViewportSize.X - 200)), math.clamp(mouse.Y + 16, 0, math.max(0, camera.ViewportSize.Y - 44)))
 label.Visible = true
end)
UserInputService.InputBegan:Connect(function(input, processed)
 if not processed and input.KeyCode == Enum.KeyCode.E and hovered and reachable and not (player:GetAttribute("InventoryOpen") or player:GetAttribute("TownMenuOpen") or (player:GetAttribute("ProgressionOpen") or player:GetAttribute("GroupOpen"))) then
  action:FireServer(stoveHovered and "OpenStove" or (chestHovered and "OpenChest" or "Pickup"), hovered)
 end
end)
