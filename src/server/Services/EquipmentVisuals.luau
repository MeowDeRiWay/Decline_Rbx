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
 if id:find("Shovel",1,true) then
  local folder=ServerStorage:FindFirstChild("Items")
  local template=findTemplate(folder,id) or findTemplate(folder,(id:gsub("Shovel","Showel")))
  if template then return template end
 end
 return findTemplate(ServerStorage:FindFirstChild("Items"),id) or (Items.Items[id] and Items.Items[id].TemplateID and findTemplate(ServerStorage:FindFirstChild("Items"),Items.Items[id].TemplateID))
end
Visuals.Template=templateFor
-- Hand-authored world tools can supply their own reusable equipment template.
-- Called by server registration before a world pickup is consumed.
function Visuals.CaptureTemplate(item, id)
 local definition=Items.Items[id]
 if not definition or (definition.Slot~="Hands" and definition.Slot~="PrimaryWeapon" and definition.Slot~="SecondaryWeapon") or templateFor(id) then return end
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
 if not definition or (definition.Slot ~= "Hands" and definition.Slot~="Body" and definition.Slot~="Back" and definition.Slot~="PrimaryWeapon" and definition.Slot~="SecondaryWeapon") then return true end
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
 if definition.Firearm then
  -- Preserve authored grip X/Z and rotation, but raise rifles to the shoulder.
  local height=root.CFrame:PointToObjectSpace(target.Position).Y
  target=target+root.CFrame.UpVector*(root.Size.Y*(definition.Firearm.HoldHeightRatio or .4)-height)
 end
 -- Keep the inward shoulder fit, but preserve the original forward distance.
 if definition.Firearm and definition.Firearm.Category~="Pistol" then
  local p=root.CFrame:PointToObjectSpace(target.Position)
  local inset=math.min(math.abs(p.X),root.Size.X*.15)
  local x=p.X>0 and -inset or (p.X<0 and inset or 0)
  target=target+root.CFrame:VectorToWorldSpace(Vector3.new(x,0,0))
 end
 -- Pistol grip is forward of the chest so both arms can extend toward it.
 if definition.Firearm and definition.Firearm.Category=="Pistol" then
  local p=root.CFrame:PointToObjectSpace(target.Position)
  target=target+root.CFrame:VectorToWorldSpace(Vector3.new(-p.X,root.Size.Y*.4-p.Y,-root.Size.Y*1.1-p.Z))
 end
 if definition.Slot=="Medicine" then target=root.CFrame*CFrame.new(root.Size.X*.25,root.Size.Y*.25,-root.Size.Z/2-.22) end
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
 local handGrip=Instance.new("Attachment")
 handGrip.Name="_HandGrip";handGrip.CFrame=gripPart.CFrame:ToObjectSpace(target);handGrip.Parent=gripPart
 if definition.Firearm then
  local muzzle=held:FindFirstChild("Muzzle",true)
  if muzzle and (muzzle:IsA("Model") or muzzle:IsA("BasePart") or muzzle:IsA("Attachment")) then
   local frame=muzzle:IsA("Attachment") and muzzle.WorldCFrame or muzzle:GetPivot()
   local origin=Instance.new("Attachment");origin.Name="_ShotOrigin"
   origin.CFrame=gripPart.CFrame:ToObjectSpace(frame);origin.Parent=gripPart
  end
 end
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
