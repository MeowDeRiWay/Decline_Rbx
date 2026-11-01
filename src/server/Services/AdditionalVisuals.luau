-- Only the surgical kit uses this left-belt visual.
local Visuals={}
function Visuals.Apply(character,id,template)
 local existing=character:FindFirstChild("EquippedAdditional")
 if existing and existing:GetAttribute("Item_ID")==id then return true end
 if existing then existing:Destroy() end
 if id~="SurgicalKit" then return true end
 local torso=character:FindFirstChild("LowerTorso") or character:FindFirstChild("HumanoidRootPart")
 if not torso or not template then return false end
 local source=template:GetPivot()
 local bounds,size
 if template:IsA("Model") then bounds,size=template:GetBoundingBox() else bounds,size=template.CFrame,template.Size end
 -- Align the upper edge with the belt, and keep the kit outside the left hip.
 local mount=torso:FindFirstChild("SurgicalKitBelt")
 local target=mount and mount:IsA("Attachment") and mount.WorldCFrame or torso.CFrame*CFrame.new(-torso.Size.X/2-size.X/2-.05,torso.Size.Y/2-size.Y/2,0)
 target=target*(source:ToObjectSpace(bounds)):Inverse()
 local parts={}
 if template:IsA("BasePart") then table.insert(parts,template) end
 for _,p in ipairs(template:GetDescendants()) do if p:IsA("BasePart") then table.insert(parts,p) end end
 if #parts==0 then return false end
 local model=Instance.new("Model");model.Name="EquippedAdditional";model:SetAttribute("Item_ID",id)
 for _,p in ipairs(parts) do
  local copy=p:Clone()
  for _,child in ipairs(copy:GetDescendants()) do
   if child:IsA("BasePart") or child:IsA("JointInstance") or child:IsA("WeldConstraint") or child:IsA("LuaSourceContainer") then child:Destroy() end
  end
  copy.CFrame=target*source:ToObjectSpace(p.CFrame)
  copy.Anchored=false;copy.Massless=true
  copy.CanCollide=false;copy.CanTouch=false;copy.CanQuery=false
  copy.Parent=model
  local weld=Instance.new("WeldConstraint",copy)
  weld.Name="BeltWeld";weld.Part0=torso;weld.Part1=copy
 end
 model.Parent=character
 return true
end
return Visuals
