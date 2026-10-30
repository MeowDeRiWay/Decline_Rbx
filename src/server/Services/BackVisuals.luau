-- Shared pivot convention measured from StarterCharacter+Backpack1.rbxm.
-- New backpacks can keep the same pivot/orientation to reuse this exact fit.
local Back={}
local defaultOffset=CFrame.new(-.00836181640625,.000006198883056640625,.25269100069999695)
function Back.Apply(character,id,template,definition)
 local existing=character:FindFirstChild("EquippedBack")
 if existing and existing:GetAttribute("Item_ID")==id then return true end
 if existing then existing:Destroy() end
 if not id then return true end
 local torso=character:FindFirstChild("UpperTorso") or character:FindFirstChild("HumanoidRootPart")
 if not torso or not template then return false end
 local source=template:GetPivot()
 local target=torso.CFrame*((definition and definition.BackOffset) or defaultOffset)
 local parts={}
 if template:IsA("BasePart") then table.insert(parts,template) end
 for _,p in ipairs(template:GetDescendants()) do if p:IsA("BasePart") then table.insert(parts,p) end end
 if #parts==0 then return false end
 local model=Instance.new("Model");model.Name="EquippedBack";model:SetAttribute("Item_ID",id)
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
  weld.Name="BackWeld";weld.Part0=torso;weld.Part1=copy
 end
 model.Parent=character
 return true
end
return Back
