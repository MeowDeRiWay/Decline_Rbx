-- Keep the mine's authored horizontal orientation, regardless of pivot rotation.
local Geometry={}
function Geometry.Measure(source)
 local pivot=source:GetPivot()
 local low=Vector3.new(math.huge,math.huge,math.huge)
 local high=Vector3.new(-math.huge,-math.huge,-math.huge)
 local parts=source:GetDescendants()
 if source:IsA("BasePart") then table.insert(parts,source) end
 for _,part in ipairs(parts) do if part:IsA("BasePart") then
  local half=part.Size*.5
  for _,x in ipairs({-half.X,half.X}) do for _,y in ipairs({-half.Y,half.Y}) do for _,z in ipairs({-half.Z,half.Z}) do
   local p=part.CFrame:PointToWorldSpace(Vector3.new(x,y,z))
   low=Vector3.new(math.min(low.X,p.X),math.min(low.Y,p.Y),math.min(low.Z,p.Z))
   high=Vector3.new(math.max(high.X,p.X),math.max(high.Y,p.Y),math.max(high.Z,p.Z))
  end end end
 end end
 return {Rotation=pivot-pivot.Position,Center=(low+high)*.5-pivot.Position,Size=high-low,Bottom=low.Y-pivot.Position.Y}
end
function Geometry.Held(root,source)
 local shape=Geometry.Measure(source)
 local center=Vector3.new(0,-root.Size.Y*.1,-root.Size.Z/2-.35)
 return root.CFrame*CFrame.new(center-shape.Center)*shape.Rotation,center,shape.Size
end
function Geometry.Placed(point,yaw,source)
 local shape=Geometry.Measure(source)
 return CFrame.new(point)*CFrame.Angles(0,yaw,0)*CFrame.new(0,-shape.Bottom,0)*shape.Rotation
end
return Geometry
