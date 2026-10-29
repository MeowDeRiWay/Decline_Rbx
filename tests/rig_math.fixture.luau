-- Full 3D rigid transforms, independent of the production joint and pose math.
local Vector3,CFrame={},{}
local vm,cm={},{}
function Vector3.new(x,y,z) return setmetatable({X=x,Y=y,Z=z},vm) end
function vm.__add(a,b) return Vector3.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
function vm.__sub(a,b) return Vector3.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
function vm.__unm(a) return Vector3.new(-a.X,-a.Y,-a.Z) end
function vm.__mul(a,b) if type(a)=="number" then a,b=b,a end;return Vector3.new(a.X*b,a.Y*b,a.Z*b) end
function vm.__div(a,b) return a*(1/b) end
function vm.__index(a,k)
 if k=="Magnitude" then return math.sqrt(a.X*a.X+a.Y*a.Y+a.Z*a.Z) end
 if k=="Unit" then return a/a.Magnitude end
 if k=="Dot" then return function(v,b) return v.X*b.X+v.Y*b.Y+v.Z*b.Z end end
 if k=="Cross" then return function(v,b) return Vector3.new(v.Y*b.Z-v.Z*b.Y,v.Z*b.X-v.X*b.Z,v.X*b.Y-v.Y*b.X) end end
end
Vector3.zero=Vector3.new(0,0,0);Vector3.xAxis=Vector3.new(1,0,0);Vector3.yAxis=Vector3.new(0,1,0);Vector3.zAxis=Vector3.new(0,0,1)
local function cf(p,r) return setmetatable({Position=p,R=r or {1,0,0,0,1,0,0,0,1}},cm) end
function CFrame.new(x,y,z) return cf(type(x)=="table" and x or Vector3.new(x or 0,y or 0,z or 0)) end
function cm:VectorToWorldSpace(v)
 local r=self.R
 return Vector3.new(r[1]*v.X+r[2]*v.Y+r[3]*v.Z,r[4]*v.X+r[5]*v.Y+r[6]*v.Z,r[7]*v.X+r[8]*v.Y+r[9]*v.Z)
end
function cm:PointToWorldSpace(v) return self.Position+self:VectorToWorldSpace(v) end
function cm:Inverse()
 local r=self.R;local t=cf(Vector3.zero,{r[1],r[4],r[7],r[2],r[5],r[8],r[3],r[6],r[9]})
 t.Position=t:VectorToWorldSpace(-self.Position);return t
end
function cm:PointToObjectSpace(v) return self:Inverse():PointToWorldSpace(v) end
function cm:VectorToObjectSpace(v) return self:Inverse():VectorToWorldSpace(v) end
function cm:ToObjectSpace(b) return self:Inverse()*b end
function cm.__mul(a,b)
 local r={}
 for row=0,2 do for col=0,2 do
  local n=0;for k=0,2 do n+=a.R[row*3+k+1]*b.R[k*3+col+1] end
  r[row*3+col+1]=n
 end end
 return cf(a:PointToWorldSpace(b.Position),r)
end
function cm.__index(a,k)
 if k=="RightVector" then return a:VectorToWorldSpace(Vector3.xAxis) end
 if k=="UpVector" then return a:VectorToWorldSpace(Vector3.yAxis) end
 if k=="LookVector" then return a:VectorToWorldSpace(-Vector3.zAxis) end
 return cm[k]
end
function CFrame.fromAxisAngle(v,a)
 local x,y,z=v.X,v.Y,v.Z;local c,s=math.cos(a),math.sin(a);local t=1-c
 return cf(Vector3.zero,{t*x*x+c,t*x*y-s*z,t*x*z+s*y,t*x*y+s*z,t*y*y+c,t*y*z-s*x,t*x*z-s*y,t*y*z+s*x,t*z*z+c})
end
function CFrame.Angles(x,y,z) return CFrame.fromAxisAngle(Vector3.xAxis,x)*CFrame.fromAxisAngle(Vector3.yAxis,y)*CFrame.fromAxisAngle(Vector3.zAxis,z) end
CFrame.identity=CFrame.new()
