local Rules = {}
function Rules.InSector(forwardX,forwardZ,offsetX,offsetZ,angle)
 local distance = math.sqrt(offsetX*offsetX+offsetZ*offsetZ)
 local forwardLength = math.sqrt(forwardX*forwardX+forwardZ*forwardZ)
 if distance < .0001 then return true end
 if forwardLength < .0001 then return false end
 local dot = (forwardX*offsetX+forwardZ*offsetZ)/(distance*forwardLength)
 return dot >= math.cos(math.rad(angle/2)) - 1e-7
end
function Rules.OnScreen(x,y,depth,width,height)
 return depth > 0 and x >= 0 and y >= 0 and x <= width and y <= height
end
-- Limit a horizontal ray to the first edge of the viewport projected on the ground.
function Rules.ScreenRayDistance(x,z,dx,dz,corners,maximum)
 local result = maximum
 for index,a in ipairs(corners) do
  local b = corners[index % #corners+1]
  local ex,ez = b.X-a.X,b.Z-a.Z
  local cross = dx*ez-dz*ex
  if math.abs(cross)>1e-7 then
   local ax,az=a.X-x,a.Z-z
   local distance=(ax*ez-az*ex)/cross
   local along=(ax*dz-az*dx)/cross
   if distance>=0 and along>=0 and along<=1 then result=math.min(result,distance) end
  end
 end
 return result
end
return Rules
