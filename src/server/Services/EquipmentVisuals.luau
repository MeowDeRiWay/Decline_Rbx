local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Items = require(ReplicatedStorage.Shared.ItemConfig)
local Visuals = {}
local function findTemplate(folder,id)
 if not folder then return nil end
 -- Recurse through category folders only, never into a different item's model.
 -- For example Axe/Handle is a component, not the craftable Handle template.
 for _,child in ipairs(folder:GetChildren()) do
  if child.Name==id and (child:IsA("Model") or child:IsA("BasePart"))
   and (child:IsA("BasePart") or child:FindFirstChildWhichIsA("BasePart",true)) then return child end
 end
 for _,child in ipairs(folder:GetChildren()) do
  if child:IsA("Folder") then
   local template=findTemplate(child,id)
   if template then return template end
  end
 end
end
local function templateFor(id)
 return findTemplate(ServerStorage:FindFirstChild("Items"),id)
end
Visuals.Template=templateFor
-- Hand-authored world tools can supply their own reusable equipment template.
-- Called by server registration before a world pickup is consumed.
function Visuals.CaptureTemplate(item, id)
 local definition=Items.Items[id]
 if not definition or definition.Slot~="Hands" or templateFor(id) then return end
 if not item:IsA("Model") and not item:IsA("BasePart") then return end
 if item:IsA("Model") and not item:FindFirstChildWhichIsA("BasePart",true) then return end
 local clone=item:Clone()
 if not clone then return end
 local folder=ServerStorage:FindFirstChild("Items")
 if not folder then folder=Instance.new("Folder"); folder.Name="Items"; folder.Parent=ServerStorage end
 local invalid=folder:FindFirstChild(id)
 if invalid and not invalid:IsA("Folder") then invalid:Destroy() end
 clone.Name=id
 clone:SetAttribute("Quantity",nil)
 clone.Parent=folder
end
function Visuals.Validate(id)
 local definition = Items.Items[id]
 if not definition or definition.Slot ~= "Hands" then return true end
 if not templateFor(id) then
  warn("[Decline] Missing equipment template: ServerStorage/Items/" .. id)
  return false
 end
 return true
end
function Visuals.Apply(character, id)
 if not character then return end
 local existing = character:FindFirstChild("HeldItem")
 if existing and existing:GetAttribute("Item_ID") == id then return end
 if existing then existing:Destroy() end
 character:SetAttribute("HandsItem", id or "")
 if not id then return end
 local root = character:FindFirstChild("HumanoidRootPart")
 local template = templateFor(id)
 if not root or not template then return end
 local definition = Items.Items[id]
 local held = template:Clone()
 held.Name = "HeldItem"
 held:SetAttribute("Item_ID",id)
 local grip = root:FindFirstChild("HandsGrip")
 local offset = definition.HeldOffset or CFrame.new(root.Size.X / 2 + 0.1, root.Size.Y * 0.15, -root.Size.Z / 2 - 0.1)
 local target = grip and grip:IsA("Attachment") and grip.WorldCFrame or root.CFrame * offset
 -- The model pivot is the point held in the hand. Place it at the handle in Studio.
 held:PivotTo(target)
 local parts = {}
 if held:IsA("BasePart") then table.insert(parts,held) end
 for _, part in ipairs(held:GetDescendants()) do if part:IsA("BasePart") then table.insert(parts,part) end end
 -- Strip template joints so a single movable grip controls the whole knife.
 for _,joint in ipairs(held:GetDescendants()) do
  if joint:IsA("JointInstance") or joint:IsA("WeldConstraint") then joint:Destroy() end
 end
 local gripPart = held:IsA("Model") and (held.PrimaryPart or parts[1]) or held
 for _, part in ipairs(parts) do
  part.Anchored = false
  part.CanCollide,part.CanTouch,part.CanQuery = false,false,false
  part.Massless = true
  if part ~= gripPart then
   local weld = Instance.new("WeldConstraint")
   weld.Part0,weld.Part1,weld.Parent = gripPart,part,part
  end
 end
 local motor = Instance.new("Motor6D")
 motor.Name,motor.Part0,motor.Part1 = "WeaponGrip",root,gripPart
 motor.C0 = root.CFrame:ToObjectSpace(gripPart.CFrame)
 motor:SetAttribute("RestC0",motor.C0)
 motor.Parent = held
 held.Parent = character
end
return Visuals
