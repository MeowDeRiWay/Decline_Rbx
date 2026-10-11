local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local player = Players.LocalPlayer
local Config = require(ReplicatedStorage.Shared:WaitForChild("ItemConfig"))
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
local hovered, reachable = nil, false
RunService:BindToRenderStep("WorldItemHover", Enum.RenderPriority.Camera.Value + 4, function()
 hovered, reachable = nil, false
 highlight.Enabled, label.Visible = false, false
 local character = player.Character
 local root = character and character:FindFirstChild("HumanoidRootPart")
 local camera = workspace.CurrentCamera
 if not root or not camera or player:GetAttribute("InventoryOpen") or GuiService.MenuIsOpen or UserInputService:GetFocusedTextBox() then return end
 local mouse = UserInputService:GetMouseLocation()
 local inset = GuiService:GetGuiInset()
 local viewportMouse = mouse - inset
 if viewportMouse.X < 0 or viewportMouse.Y < 0 or viewportMouse.X > camera.ViewportSize.X or viewportMouse.Y > camera.ViewportSize.Y then return end
 local ray = camera:ViewportPointToRay(viewportMouse.X, viewportMouse.Y)
 local params = RaycastParams.new()
 params.FilterType = Enum.RaycastFilterType.Exclude
 params.FilterDescendantsInstances = {character}
 local hit = workspace:Raycast(ray.Origin, ray.Direction * 1000, params)
 if not hit then return end
 local item = hit.Instance
 while item and item.Parent ~= folder do item = item.Parent end
 if not item then return end
 local definition = Config.Items[item:GetAttribute("Item_ID")]
 if not definition then return end
 hovered = item
 reachable = (item:GetPivot().Position - root.Position).Magnitude <= Config.PickupDistance
 highlight.Adornee, highlight.Enabled = item, true
 label.Text = (definition.Name or item.Name) .. (reachable and "\n[E] Pick up" or "\nToo far")
 label.Position = UDim2.fromOffset(math.clamp(mouse.X + 16, 0, math.max(0, camera.ViewportSize.X - 200)), math.clamp(mouse.Y + 16, 0, math.max(0, camera.ViewportSize.Y + inset.Y - 44)))
 label.Visible = true
end)
UserInputService.InputBegan:Connect(function(input, processed)
 if not processed and input.KeyCode == Enum.KeyCode.E and hovered and reachable and not player:GetAttribute("InventoryOpen") then
  action:FireServer("Pickup", hovered)
 end
end)
