local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Items = require(ReplicatedStorage.Shared.ItemConfig)
local Presentation=require(ReplicatedStorage.Shared.WeaponPresentation)
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
 local canonical=id:gsub("Showel","Shovel")
 if canonical~=id then
  local template=findTemplate(ServerStorage:FindFirstChild("Items"),canonical)
  if template then return template end
 end
 if id:find("Shovel",1,true) then
  local folder=ServerStorage:FindFirstChild("Items")
  local template=findTemplate(folder,id) or findTemplate(folder,(id:gsub("Shovel","Showel")))
  if template then return template end
 end
 local template=findTemplate(ServerStorage:FindFirstChild("Items"),id)
 if template then return template end
 local fallback=Items.Items[id] and Items.Items[id].TemplateID
 if fallback and fallback~=id then return templateFor(fallback) end
 return nil
end
Visuals.Template=templateFor
-- Hand-authored world tools can supply their own reusable equipment template.
-- Called by server registration before a world pickup is consumed.
function Visuals.CaptureTemplate(item, id)
 local definition=Items.Items[id]
 if not definition or (definition.Slot~="Hands" and definition.Slot~="PrimaryWeapon" and definition.Slot~="SecondaryWeapon" and id~="SurgicalKit" and not definition.AmmoBox) or templateFor(id) then return end
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
 clone:SetAttribute("Item_ID",id)
 clone.Parent=folder
end
function Visuals.Validate(id)
 local definition = Items.Items[id]
 if not definition or (definition.Slot ~= "Hands" and definition.Slot~="Body" and definition.Slot~="Back" and definition.Slot~="PrimaryWeapon" and definition.Slot~="SecondaryWeapon" and id~="SurgicalKit") then return true end
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
 local animationSet=Presentation.AnimationSet(held,definition)
 held:SetAttribute("AnimationSet",animationSet)
 held:SetAttribute("ReloadType",Presentation.ReloadType(held,definition,id))
 local grip = root:FindFirstChild("HandsGrip")
 local offset = definition.HeldOffset or CFrame.new(root.Size.X / 2 + 0.1, root.Size.Y * 0.15, -root.Size.Z / 2 - 0.1)
 local target = grip and grip:IsA("Attachment") and grip.WorldCFrame or root.CFrame * offset
 if definition.Firearm then
  -- Preserve authored grip X/Z and rotation, but raise rifles to the shoulder.
  local height=root.CFrame:PointToObjectSpace(target.Position).Y
  target=target+root.CFrame.UpVector*(root.Size.Y*(definition.Firearm.HoldHeightRatio or .4)-height)
 end
 -- Keep the inward shoulder fit, but preserve the original forward distance.
 if definition.Firearm and animationSet~="Pistol" then
  local p=root.CFrame:PointToObjectSpace(target.Position)
  local inset=math.min(math.abs(p.X),root.Size.X*.15)
  local x=p.X>0 and -inset or (p.X<0 and inset or 0)
  target=target+root.CFrame:VectorToWorldSpace(Vector3.new(x,0,0))
 end
 -- Pistol grip is forward of the chest so both arms can extend toward it.
 if definition.Firearm and animationSet=="Pistol" then
  local p=root.CFrame:PointToObjectSpace(target.Position)
  target=target+root.CFrame:VectorToWorldSpace(Vector3.new(-p.X,root.Size.Y*.4-p.Y,-root.Size.Y*1.1-p.Z))
 end
 if definition.Firearm and animationSet=="Launcher" then
  -- PrimaryPart is the authored alignment anchor; keep the tube parallel to -Z.
  target=root.CFrame*CFrame.new(root.Size.X*.62,root.Size.Y*.6,root.Size.Z*.15)
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
 if definition.Firearm and animationSet=="Launcher" then
  local frame,size=held:GetBoundingBox()
  local front,rear=math.huge,-math.huge
  for _,part in ipairs(parts) do
   local center=target:PointToObjectSpace(part.Position)
   local half=part.Size*.5
   for _,x in ipairs({-half.X,half.X}) do for _,y in ipairs({-half.Y,half.Y}) do for _,z in ipairs({-half.Z,half.Z}) do
    local point=target:PointToObjectSpace(part.CFrame:PointToWorldSpace(Vector3.new(x,y,z)))
    front=math.min(front,point.Z);rear=math.max(rear,point.Z)
   end end end
  end
  local function anchor(name,position)
   if held:FindFirstChild(name,true) then return end
   local a=Instance.new("Attachment");a.Name=name;a.CFrame=gripPart.CFrame:ToObjectSpace(target*CFrame.new(position));a.Parent=gripPart
  end
  anchor("Muzzle",Vector3.new(0,0,front))
  anchor("_BackblastOrigin",Vector3.new(0,0,rear))
  anchor("RightHandGrip",Vector3.new(0,-.12,front*.25))
  anchor("LeftHandGrip",Vector3.new(-.04,-.12,front*.7))
 end
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
