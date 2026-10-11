local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Items = require(ReplicatedStorage.Shared.ItemConfig)
local Visuals = {}
local function templateFor(id)
 local items = ServerStorage:FindFirstChild("Items")
 local template = items and items:FindFirstChild(id)
 if not template or (not template:IsA("Model") and not template:IsA("BasePart")) then return nil end
 if template:IsA("Model") and not template:FindFirstChildWhichIsA("BasePart",true) then return nil end
 return template
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
 for _, part in ipairs(parts) do
  part.Anchored = false
  part.CanCollide,part.CanTouch,part.CanQuery = false,false,false
  part.Massless = true
  local weld = Instance.new("WeldConstraint")
  weld.Name,weld.Part0,weld.Part1 = "HeldWeld",root,part
  weld.Parent = part
 end
 held.Parent = character
end
return Visuals
