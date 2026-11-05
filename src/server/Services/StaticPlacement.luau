-- Place an anchored authored hierarchy from one snapshot of its reference frame.
-- Shared PrimaryParts and nested Models must not influence the order of movement.
local Service={}
function Service.Move(model,target,budget)
 local function checkpoint(index) if budget and index%32==0 then budget() end end
 local origin=model:GetPivot()
 local parts,pivots={},{}
 local function capture(object)
  if object:IsA("BasePart") then
   table.insert(parts,{Object=object,Local=origin:ToObjectSpace(object.CFrame)})
  elseif object:IsA("Model") and not object.PrimaryPart then
   table.insert(pivots,{Object=object,Local=origin:ToObjectSpace(object:GetPivot())})
  end
 end
 capture(model)
 for i,object in ipairs(model:GetDescendants()) do capture(object);checkpoint(i) end
 -- Anchor every physical part before changing any coordinates.
 for i,entry in ipairs(parts) do entry.Object.Anchored=true;checkpoint(i) end
 for i,entry in ipairs(parts) do entry.Object.CFrame=target*entry.Local;checkpoint(i) end
 -- Updating a no-PrimaryPart model's cached pivot never moves its geometry.
 for i,entry in ipairs(pivots) do entry.Object.WorldPivot=target*entry.Local;checkpoint(i) end
end
return Service
