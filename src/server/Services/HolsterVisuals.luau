local Pose=require(game:GetService("ReplicatedStorage").Shared.HandActionPose)
local Visuals={}
function Visuals.Apply(character,slot,id,templateFor)
 local name="Holstered"..slot
 local existing=character:FindFirstChild(name)
 if existing and existing:GetAttribute("Item_ID")==id then return true end
 if existing then existing:Destroy() end
 if not id then return true end
 local template=templateFor(id)
 local root=character:FindFirstChild("HumanoidRootPart")
 local torso=character:FindFirstChild(slot=="SecondaryWeapon" and "LowerTorso" or "UpperTorso") or root
 if not template or not root or not torso then return false end
 local model=Instance.new("Model");model.Name=name;model:SetAttribute("Item_ID",id)
 local source=template:GetPivot();local target=Pose.StorageFrame(character,root,slot)
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
  local weld=Instance.new("WeldConstraint");weld.Name="HolsterWeld";weld.Part0=torso;weld.Part1=copy;weld.Parent=copy
 end
 model.Parent=character;return true
end
return Visuals
