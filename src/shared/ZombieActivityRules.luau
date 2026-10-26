local Rules = {}
Rules.ActiveMargin = 50
Rules.SleepMargin = 200
Rules.TeleportInterval = 120
function Rules.ScreenOffsets(height,back,fieldOfView,aspect,yaw)
 local length=math.sqrt(height*height+back*back)
 local tangent=math.tan(math.rad(fieldOfView/2))
 local corners={}
 for _,xy in ipairs({{-1,1},{1,1},{1,-1},{-1,-1}}) do
  local dy=(-height+xy[2]*tangent*back)/length
  local dz=(-back-xy[2]*tangent*height)/length
  local distance=-height/dy
  local x,z=xy[1]*tangent*aspect*distance,back+dz*distance
  local sine,cosine=math.sin(yaw or 0),math.cos(yaw or 0)
  table.insert(corners,{X=x*cosine+z*sine,Z=-x*sine+z*cosine})
 end
 return corners
end
function Rules.Mode(gap)
 if gap <= Rules.ActiveMargin then return "Active" end
 if gap <= Rules.SleepMargin then return "Minimal" end
 return "AFK"
end
-- Distance to the whole ground footprint of the screen, independent of facing.
function Rules.EdgeDistance(x,z,corners)
 if #corners < 3 then return math.huge end
 local distance=math.huge
 local positive,negative=false,false
 for index,a in ipairs(corners) do
  local b=corners[index % #corners+1]
  local dx,dz=b.X-a.X,b.Z-a.Z
  local cross=dx*(z-a.Z)-dz*(x-a.X)
  if cross>1e-7 then positive=true elseif cross< -1e-7 then negative=true end
  local length=dx*dx+dz*dz
  local t=length>0 and math.clamp(((x-a.X)*dx+(z-a.Z)*dz)/length,0,1) or 0
  distance=math.min(distance,math.sqrt((x-a.X-t*dx)^2+(z-a.Z-t*dz)^2))
 end
 return not (positive and negative) and 0 or distance
end
return Rules
