local Rules = {}
function Rules.CanStep(x,z,nextX,nextZ,otherX,otherZ,radius)
 local sx,sz=x-otherX,z-otherZ
 local dx,dz=nextX-x,nextZ-z
 local start=sx*sx+sz*sz
 local finish=(nextX-otherX)^2+(nextZ-otherZ)^2
 if start<radius*radius then return finish>start+1e-8 end
 local length=dx*dx+dz*dz
 local t=length>0 and math.clamp(-(sx*dx+sz*dz)/length,0,1) or 0
 return (sx+t*dx)^2+(sz+t*dz)^2>=radius*radius
end
return Rules
