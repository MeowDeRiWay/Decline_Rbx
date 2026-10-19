local Rules = {}
function Rules.Category(roll,chance) return roll<chance and "Stores" or "Houses" end
function Rules.FurnitureGrid(zoneSize,sourceSize)
 if sourceSize.X<=0 or sourceSize.Z<=0 then return 0,0 end
 return math.floor((zoneSize.X+.001)/sourceSize.X),math.floor((zoneSize.Z+.001)/sourceSize.Z)
end
function Rules.FurnitureFrame(zoneFrame,zoneSize,sourceSize,columns,rows,x,z)
 return zoneFrame*CFrame.new(Vector3.new((x-.5-columns/2)*sourceSize.X,zoneSize.Y/2+sourceSize.Y/2,(z-.5-rows/2)*sourceSize.Z))
end
-- House forward is +Z, unlike Roblox LookVector (-Z).
function Rules.Frame(plotFrame, localYardFrame, roadPoint)
 local delta = roadPoint - plotFrame.Position
 local localDelta = plotFrame:VectorToObjectSpace(Vector3.new(delta.X,0,delta.Z))
 local axis
 if math.abs(localDelta.X) > math.abs(localDelta.Z) then
  axis = Vector3.new(localDelta.X >= 0 and 1 or -1,0,0)
 else axis = Vector3.new(0,0,localDelta.Z >= 0 and 1 or -1) end
 local forward = plotFrame:VectorToWorldSpace(axis)
 forward = Vector3.new(forward.X,0,forward.Z).Unit
 return CFrame.new(plotFrame.Position) * CFrame.lookAt(Vector3.zero,-forward) * CFrame.new(-localYardFrame.Position)
end
function Rules.Fits(frame, yardFrame, yardSize, plotFrame, plotSize, tolerance)
 local placedYard = frame * yardFrame
 for _, x in ipairs({-1,1}) do
  for _, z in ipairs({-1,1}) do
   local point = plotFrame:PointToObjectSpace(placedYard:PointToWorldSpace(Vector3.new(x*yardSize.X/2,0,z*yardSize.Z/2)))
   if math.abs(point.X) > plotSize.X/2+tolerance or math.abs(point.Z) > plotSize.Z/2+tolerance then return false end
  end
 end
 return true
end
function Rules.RoadPoint(frame, size, position)
 local point = frame:PointToObjectSpace(position)
 return frame:PointToWorldSpace(Vector3.new(math.clamp(point.X,-size.X/2,size.X/2),0,math.clamp(point.Z,-size.Z/2,size.Z/2)))
end
return Rules
