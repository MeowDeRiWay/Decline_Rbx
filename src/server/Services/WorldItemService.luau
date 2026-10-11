local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemConfig = require(ReplicatedStorage.Shared.ItemConfig)
local Inventory = require(script.Parent.InventoryService)
local Rules = require(ReplicatedStorage.Shared.InventoryRules)
local Service = {}
local folder = workspace:FindFirstChild("WorldItems")
if not folder then
 folder = Instance.new("Folder")
 folder.Name, folder.Parent = "WorldItems", workspace
end
local function register(item)
 if not item:IsA("Model") and not item:IsA("BasePart") then return end
 local id = item:GetAttribute("Item_ID") or item.Name
 if not ItemConfig.Items[id] then return end
 item:SetAttribute("Item_ID", id)
 if item:GetAttribute("Quantity") == nil then item:SetAttribute("Quantity", 1) end
end
for _, item in ipairs(folder:GetChildren()) do register(item) end
folder.ChildAdded:Connect(register)
local function aliveRoot(player)
 local character = player.Character
 local humanoid = character and character:FindFirstChildOfClass("Humanoid")
 local root = character and character:FindFirstChild("HumanoidRootPart")
 if not humanoid or humanoid.Health <= 0 or character:GetAttribute("Knockout") or not root then return end
 return root, character
end
function Service.Pickup(player, item)
 if typeof(item) ~= "Instance" or item.Parent ~= folder then return false end
 if not item:IsA("Model") and not item:IsA("BasePart") then return false end
 local id, count = item:GetAttribute("Item_ID"), item:GetAttribute("Quantity")
 if typeof(id) ~= "string" or not ItemConfig.Items[id] or typeof(count) ~= "number" or count < 1 or count >= math.huge or count ~= math.floor(count) then return false end
 local root, character = aliveRoot(player)
 if not root then return false end
 local position = item:GetPivot().Position
 local delta = position - root.Position
 if delta.Magnitude > ItemConfig.PickupDistance then return false end
 local params = RaycastParams.new()
 params.FilterType = Enum.RaycastFilterType.Exclude
 params.FilterDescendantsInstances = {character}
 local hit = workspace:Raycast(root.Position, delta, params)
 if hit and hit.Instance ~= item and not hit.Instance:IsDescendantOf(item) then return false end
 -- No yields between inventory grant and destruction: only one player can win.
 if not Inventory.Add(player, id, count) then return false end
 item:Destroy()
 return true
end
function Service.Drop(player, id, requested)
 if typeof(id) ~= "string" or not ItemConfig.Items[id] then return false end
 local count = Rules.DropAmount(Inventory.Snapshot(player).Items[id], requested)
 if not count then return false end
 local root, character = aliveRoot(player)
 if not root then return false end
 local templates = ServerStorage:FindFirstChild("Items")
 local template = templates and templates:FindFirstChild(id)
 if not template or (not template:IsA("Model") and not template:IsA("BasePart")) then
  warn("[Decline] Missing world item template: ServerStorage/Items/" .. id)
  return false
 end
 local item = template:Clone()
 if item:IsA("Model") and not item:FindFirstChildWhichIsA("BasePart", true) then item:Destroy(); return false end
 -- Drop straight below the character, without a forward throw.
 local destination = root.Position
 local params = RaycastParams.new()
 params.FilterType = Enum.RaycastFilterType.Exclude
 params.FilterDescendantsInstances = {character, folder}
 local hit = workspace:Raycast(destination + Vector3.new(0, 2, 0), Vector3.new(0, -12, 0), params)
 if not hit then item:Destroy(); return false end
 local bounds, size
 if item:IsA("Model") then bounds, size = item:GetBoundingBox() else bounds, size = item.CFrame, item.Size end
 local pivot = item:GetPivot()
 local bottom = bounds.Position.Y - size.Y / 2
 local position = hit.Position + Vector3.new(0, pivot.Position.Y - bottom + 0.05, 0)
 item:PivotTo(CFrame.new(position) * pivot.Rotation)
 local function anchor(part)
  part.Anchored, part.CanQuery = true, true
 end
 if item:IsA("BasePart") then anchor(item) end
 for _, descendant in ipairs(item:GetDescendants()) do if descendant:IsA("BasePart") then anchor(descendant) end end
 item.Name = id
 item:SetAttribute("Item_ID", id)
 item:SetAttribute("Quantity", count)
 if not Inventory.Remove(player, id, count) then item:Destroy(); return false end
 item.Parent = folder
 -- World drops remain until collected or until this server closes.
 return true
end
return Service
