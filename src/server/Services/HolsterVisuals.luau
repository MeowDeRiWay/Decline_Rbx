local Pose=require(game:GetService("ReplicatedStorage").Shared.HandActionPose)
local Visuals={}
function Visuals.Apply(character,slot,id,templateFor)
 local name="Holstered"..slot
 local existing=character:FindFirstChild(name)
 if not id then if existing then existing:Destroy() end;return true end
 local template=templateFor(id)
 local root=character:FindFirstChild("HumanoidRootPart")
 local torso=character:FindFirstChild(slot=="SecondaryWeapon" and "LowerTorso" or "UpperTorso") or root
 if not template or not root or not torso then if existing then existing:Destroy() end;return false end
 local target=Pose.StorageFrame(character,root,slot,template)
 local offset=torso.CFrame:ToObjectSpace(target)
 local previous=existing and existing:GetAttribute("StorageOffset")
 if existing and existing:GetAttribute("Item_ID")==id and previous
  and (previous.Position-offset.Position).Magnitude<.0001
  and previous.LookVector:Dot(offset.LookVector)>.99999
  and previous.UpVector:Dot(offset.UpVector)>.99999 then return true end
 if existing then existing:Destroy() end
 local model=Instance.new("Model");model.Name=name;model:SetAttribute("Item_ID",id)
 model:SetAttribute("StorageOffset",offset)
 local source=template:GetPivot()
 local parts={}
 if template:IsA("BasePart") then table.insert(parts,template) end
 for _,part in ipairs(template:GetDescendants()) do if part:IsA("BasePart") then table.insert(parts,part) end end
 for _,part in ipairs(parts) do
  local copy=part:Clone()
  for _,child in ipairs(copy:GetDescendants()) do
   if child:IsA("BasePart") or child:IsA("JointInstance") or child:IsA("WeldConstraint") or child:IsA("LuaSourceContainer") then child:Destroy() end
  end
  copy.CFrame=target*source:ToObjectSpace(part.CFrame)
  copy.Anchored=false;copy.Massless=true;copy.CanCollide=false;copy.CanTouch=false;copy.CanQuery=false
  copy.Parent=model
  if not model.PrimaryPart then
   model.PrimaryPart=copy
   model:SetAttribute("HolsterPivotOffset",copy.CFrame:ToObjectSpace(target))
  end
  local weld=Instance.new("WeldConstraint");weld.Name="HolsterWeld";weld.Part0=torso;weld.Part1=copy;weld.Parent=copy
 end
 model.Parent=character;return true
end
return Visuals
