local Interaction = {}
function Interaction.NearestPoint(object, position)
 local frame,size
 if object:IsA("Model") then frame,size = object:GetBoundingBox()
 else frame,size = object.CFrame,object.Size end
 local point,half = frame:PointToObjectSpace(position),size/2
 return frame:PointToWorldSpace(Vector3.new(math.clamp(point.X,-half.X,half.X),math.clamp(point.Y,-half.Y,half.Y),math.clamp(point.Z,-half.Z,half.Z)))
end
function Interaction.Distance(object, position)
 return (Interaction.NearestPoint(object,position)-position).Magnitude
end
return Interaction
