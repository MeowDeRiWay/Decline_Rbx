local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local items = require(ReplicatedStorage.Shared.ItemConfig).Items
local gui = Instance.new("ScreenGui")
gui.Name,gui.ResetOnSpawn = "WeaponHUD",false
gui.Parent = player:WaitForChild("PlayerGui")
local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(1,1)
panel.Position = UDim2.new(1,-16,1,-96)
panel.Size = UDim2.fromOffset(200,210)
panel.BackgroundColor3 = Color3.fromRGB(21,25,30)
panel.BackgroundTransparency = .12
panel.Visible = false
panel.Parent = gui
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0,10)
corner.Parent = panel
local viewport = Instance.new("ViewportFrame")
viewport.Position = UDim2.fromOffset(8,8)
viewport.Size = UDim2.new(1,-16,0,105)
viewport.BackgroundTransparency = 1
viewport.Ambient = Color3.fromRGB(190,190,190)
viewport.LightColor = Color3.new(1,1,1)
viewport.LightDirection = Vector3.new(-1,-1,-1)
viewport.Parent = panel
local camera = Instance.new("Camera")
camera.FieldOfView = 30
camera.Parent = viewport
viewport.CurrentCamera = camera
local world = Instance.new("WorldModel")
world.Parent = viewport
local function label(y,color,size)
 local text = Instance.new("TextLabel")
 text.Position = UDim2.fromOffset(8,y)
 text.Size = UDim2.new(1,-16,0,25)
 text.BackgroundTransparency = 1
 text.Font = Enum.Font.GothamMedium
 text.TextSize = size or 15
 text.TextColor3 = color
 text.Parent = panel
 return text
end
local name = label(114,Color3.fromRGB(235,238,242),18)
local damage = label(140,Color3.fromRGB(242,78,78))
local condition = label(165,Color3.new(1,1,1))
local speed = label(188,Color3.fromRGB(160,171,183),12)
local character,held,connections
connections = {}
local function preview(model)
 world:ClearAllChildren()
 if not model then return end
 local copy = model:Clone()
 for _,object in ipairs(copy:GetDescendants()) do
  if object:IsA("LuaSourceContainer") or object:IsA("JointInstance") or object:IsA("WeldConstraint") then object:Destroy() end
 end
 local parts = copy:GetDescendants()
 if copy:IsA("BasePart") then table.insert(parts,copy) end
 for _,part in ipairs(parts) do if part:IsA("BasePart") then part.Anchored = true end end
 copy:PivotTo(CFrame.identity)
 copy.Parent = world
 local box,size
 if copy:IsA("Model") then box,size = copy:GetBoundingBox() else box,size = copy.CFrame,copy.Size end
 -- View the authored model from its right (+X) side.
 local extent = math.max(size.Y,size.Z*105/184,.1)
 local distance = extent/(2*math.tan(math.rad(camera.FieldOfView/2))) + size.X/2
 camera.CFrame = CFrame.lookAt(box.Position+Vector3.new(distance*1.15,0,0),box.Position,Vector3.yAxis)
end
local function refresh()
 local id = character and character:GetAttribute("HandsItem")
 local definition = id and items[id]
 local weapon = definition and definition.Weapon
 local currentHeld = character and character:FindFirstChild("HeldItem")
 panel.Visible = weapon ~= nil
 if not weapon then held = nil; world:ClearAllChildren(); return end
 if held ~= currentHeld then held = currentHeld; preview(held) end
 name.Text = definition.Name or id
 damage.Text = string.format("Damage %d · %s",weapon.Damage,weapon.DamageType)
 local uses = math.clamp(character:GetAttribute("WeaponCondition") or 0,0,weapon.MaxUses)
 condition.Text = string.format("Condition %d / %d",uses,weapon.MaxUses)
 local fraction = uses/weapon.MaxUses
 condition.TextColor3 = Color3.fromRGB(100,12,20):Lerp(Color3.fromRGB(80,220,110),fraction)
 speed.Text = string.format("%d attacks/min · %.1f kg",weapon.AttacksPerMinute,definition.Weight or 0)
end
local function bind(model)
 for _,connection in ipairs(connections) do connection:Disconnect() end
 table.clear(connections)
 character,held = model,nil
 for _,attribute in ipairs({"HandsItem","WeaponCondition"}) do table.insert(connections,model:GetAttributeChangedSignal(attribute):Connect(refresh)) end
 table.insert(connections,model.ChildAdded:Connect(refresh))
 table.insert(connections,model.ChildRemoved:Connect(refresh))
 refresh()
end
player.CharacterAdded:Connect(bind)
if player.Character then bind(player.Character) end
