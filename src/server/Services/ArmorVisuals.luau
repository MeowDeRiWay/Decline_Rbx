-- Each named folder is welded to the matching articulated body section.
-- Optional Anchor parts preserve exact authored fit; otherwise fit the group's
-- center to the body section in the rig's authored T-pose axes. Helmets
-- retain their authored height above the head using the torso as a reference.
local Armor={}
local names={"Head","UpperTorso","LowerTorso","LeftUpperArm","LeftLowerArm","RightUpperArm","RightLowerArm","LeftUpperLeg","LeftLowerLeg","RightUpperLeg","RightLowerLeg"}
local function rotation(cf) return CFrame.new(-cf.Position)*cf end
local function authoredFrames(character,root)
 local frames={[root]=CFrame.identity}
 local joints={}
 for _,j in ipairs(character:GetDescendants()) do
  if j:IsA("Motor6D") and j:GetAttribute("AuthoredC0") and j.Part0 and j.Part1 then table.insert(joints,j) end
 end
 for _=1,#joints do
  local changed=false
  for _,j in ipairs(joints) do
   if frames[j.Part0] and not frames[j.Part1] then frames[j.Part1]=frames[j.Part0]*j:GetAttribute("AuthoredC0")*j.C1:Inverse();changed=true end
  end
  if not changed then break end
 end
 return frames
end
local function groupFrame(parts,axes)
 local low,high=Vector3.new(math.huge,math.huge,math.huge),Vector3.new(-math.huge,-math.huge,-math.huge)
 for _,p in ipairs(parts) do
  local cf=axes:ToObjectSpace(p.CFrame)
  local s=p.Size/2;local r,u,l=cf.RightVector,cf.UpVector,cf.LookVector
  local h=Vector3.new(math.abs(r.X)*s.X+math.abs(u.X)*s.Y+math.abs(l.X)*s.Z,math.abs(r.Y)*s.X+math.abs(u.Y)*s.Y+math.abs(l.Y)*s.Z,math.abs(r.Z)*s.X+math.abs(u.Z)*s.Y+math.abs(l.Z)*s.Z)
  local a,b=cf.Position-h,cf.Position+h
  low=Vector3.new(math.min(low.X,a.X),math.min(low.Y,a.Y),math.min(low.Z,a.Z))
  high=Vector3.new(math.max(high.X,b.X),math.max(high.Y,b.Y),math.max(high.Z,b.Z))
 end
 return axes*CFrame.new((low+high)/2)
end
local function headFrame(template,axes,authored,character)
 local torso=character:FindFirstChild("UpperTorso")
 local head=character:FindFirstChild("Head")
 local group=template:FindFirstChild("UpperTorso")
 if not torso or not group or not authored[torso] or not authored[head] then return nil end
 local anchor=group:FindFirstChild("Anchor")
 local source
 if anchor and anchor:IsA("BasePart") then source=anchor.CFrame
 else
  local parts={}
  for _,p in ipairs(group:GetDescendants()) do if p:IsA("BasePart") then table.insert(parts,p) end end
  if #parts==0 then return nil end
  source=groupFrame(parts,axes)*rotation(authored[torso])
 end
 -- The helmet bounds describe the shell, not the head it was modeled around.
 -- Reconstruct that head frame from the unanimated body proportions instead.
 return source*authored[torso]:ToObjectSpace(authored[head])
end
function Armor.Apply(character,id,template)
 local existing=character:FindFirstChild("EquippedArmor")
 if existing and existing:GetAttribute("Item_ID")==id then return true end
 if existing then existing:Destroy() end
 if not id then return true end
 local root=character:FindFirstChild("HumanoidRootPart")
 if not root or not template then return false end
 local authored=authoredFrames(character,root)
 local axes=rotation(template:GetPivot())
 local model=Instance.new("Model");model.Name="EquippedArmor";model:SetAttribute("Item_ID",id)
 local count=0
 for _,name in ipairs(names) do
  local body=character:FindFirstChild(name)
  local group=template:FindFirstChild(name)
  if body and body:IsA("BasePart") and group and (group:IsA("Folder") or group:IsA("Model")) then
   local parts={};local anchor=group:FindFirstChild("Anchor")
   for _,p in ipairs(group:GetDescendants()) do if p:IsA("BasePart") and p~=anchor then table.insert(parts,p) end end
   if #parts>0 then
    local source,destination
    if anchor and anchor:IsA("BasePart") then source=anchor.CFrame;destination=body.CFrame
    else
     source=name=="Head" and headFrame(template,axes,authored,character)
     if source then destination=body.CFrame
     else
      source=groupFrame(parts,axes)
      local rest=authored[body] or root.CFrame:ToObjectSpace(body.CFrame)
      destination=body.CFrame*rotation(rest):Inverse()
     end
    end
    local folder=Instance.new("Folder",model);folder.Name=name
    for _,p in ipairs(parts) do
     local copy=p:Clone()
     for _,child in ipairs(copy:GetDescendants()) do
      if child:IsA("BasePart") or child:IsA("JointInstance") or child:IsA("WeldConstraint") or child:IsA("LuaSourceContainer") then child:Destroy() end
     end
     copy.CFrame=destination*source:ToObjectSpace(p.CFrame)
     copy.Anchored=false;copy.Massless=true
     copy.CanCollide=false;copy.CanTouch=false;copy.CanQuery=false
     copy.Parent=folder
     local weld=Instance.new("WeldConstraint",copy)
     weld.Name="ArmorWeld";weld.Part0=body;weld.Part1=copy
     count+=1
    end
   end
  end
 end
 if count==0 then model:Destroy();warn("[Decline] Armor needs body-section folders: "..id);return false end
 model.Parent=character
 return true
end
return Armor
