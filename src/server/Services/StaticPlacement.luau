-- Place an anchored authored hierarchy from one snapshot of its reference frame.
-- Shared PrimaryParts and nested Models must not influence the order of movement.
local Service={}
function Service.Move(model,target)
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
 for _,object in ipairs(model:GetDescendants()) do capture(object) end
 -- Anchor every physical part before changing any coordinates.
 for _,entry in ipairs(parts) do entry.Object.Anchored=true end
 for _,entry in ipairs(parts) do entry.Object.CFrame=target*entry.Local end
 -- Updating a no-PrimaryPart model's cached pivot never moves its geometry.
 for _,entry in ipairs(pivots) do entry.Object.WorldPivot=target*entry.Local end
end
return Service
