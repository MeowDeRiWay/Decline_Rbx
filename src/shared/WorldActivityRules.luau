local Rules={}
function Rules.DistanceSquared(frame,size,position)
 local p=frame:PointToObjectSpace(position)
 local x,z=math.max(0,math.abs(p.X)-size.X/2),math.max(0,math.abs(p.Z)-size.Z/2)
 return x*x+z*z
end
function Rules.Near(frame,size,positions,radius)
 for _,position in ipairs(positions) do
  if Rules.DistanceSquared(frame,size,position)<=radius*radius then return true end
 end
 return false
end
function Rules.Normal(frame,size,point,direction)
 local p=frame:PointToObjectSpace(point)
 local axes={Vector3.new(1,0,0),Vector3.new(0,1,0),Vector3.new(0,0,1)}
 local values,extent={p.X,p.Y,p.Z},{size.X/2,size.Y/2,size.Z/2}
 local best,normal=math.huge,-direction
 for i=1,3 do
  local gap=math.abs(math.abs(values[i])-extent[i])
  if gap<best then best=gap;normal=frame:VectorToWorldSpace(axes[i]*(values[i]>=0 and 1 or -1)) end
 end
 return normal
end
return Rules
