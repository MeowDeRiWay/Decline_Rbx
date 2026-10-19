-- Minimal horizontal CFrame/Vector3 mock for placement geometry, not a Studio playtest.
local Vector3, CFrame = {}, {}
local vm,cm = {},{}
function Vector3.new(x,y,z) return setmetatable({X=x,Y=y,Z=z},vm) end
Vector3.zero=Vector3.new(0,0,0)
function vm.__add(a,b) return Vector3.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
function vm.__sub(a,b) return Vector3.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
function vm.__unm(a) return Vector3.new(-a.X,-a.Y,-a.Z) end
function vm.__index(a,k)
 local length=math.sqrt(a.X*a.X+a.Y*a.Y+a.Z*a.Z)
 if k=="Magnitude" then return length end
 if k=="Unit" then return Vector3.new(a.X/length,a.Y/length,a.Z/length) end
end
local function cf(position,yaw) return setmetatable({Position=position,yaw=yaw or 0},cm) end
function CFrame.new(p) return cf(p or Vector3.zero) end
function CFrame.lookAt(position,target)
 local look=target-position
 return cf(position,math.atan2(-look.X,-look.Z))
end
function cm.__index(a,k)
 if k=="UpVector" then return Vector3.new(0,1,0) end
 if k=="RightVector" then return Vector3.new(math.cos(a.yaw),0,-math.sin(a.yaw)) end
 if k=="LookVector" then return Vector3.new(-math.sin(a.yaw),0,-math.cos(a.yaw)) end
 return cm[k]
end
function cm:ToObjectSpace(other) return cf(self:PointToObjectSpace(other.Position),other.yaw-self.yaw) end
function cm:VectorToWorldSpace(v)
 local c,s=math.cos(self.yaw),math.sin(self.yaw)
 return Vector3.new(c*v.X+s*v.Z,v.Y,-s*v.X+c*v.Z)
end
function cm:VectorToObjectSpace(v) return cf(Vector3.zero,-self.yaw):VectorToWorldSpace(v) end
function cm:PointToWorldSpace(v) return self.Position+self:VectorToWorldSpace(v) end
function cm:PointToObjectSpace(v) return self:VectorToObjectSpace(v-self.Position) end
function cm.__mul(a,b) return cf(a:PointToWorldSpace(b.Position),a.yaw+b.yaw) end
