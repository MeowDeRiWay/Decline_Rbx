-- One authored 20-stud world cell is 20 pixels at zoom 1. North is -Z.
local R={CellSize=20,RevealRadius=1,BucketSize=8}
local priorities={Ground=0,Forest=1,ScrapYard=2,StoneYard=2,RoadX=3,RoadZ=3,RoadCross=3,House=4,Infrastructure=5}
function R.Key(x,z) return x..":"..z end
function R.Cell(x,z,ox,oz) return math.floor((x-ox)/20),math.floor((z-oz)/20) end
function R.Reveal(x,z,seen)
 local result={}
 for dx=-R.RevealRadius,R.RevealRadius do for dz=-R.RevealRadius,R.RevealRadius do
  local a,b=x+dx,z+dz;local key=R.Key(a,b)
  if not seen[key] then seen[key]={X=a,Z=b};table.insert(result,seen[key]) end
 end end
 return result
end
function R.Contains(region,x,z)
 local dx,dz=x-region.X,z-region.Z
 return math.abs(dx*region.Cos+dz*region.Sin)<=region.W/2+.01 and math.abs(-dx*region.Sin+dz*region.Cos)<=region.H/2+.01
end
function R.Index(regions,ox,oz)
 local index={}
 for _,r in ipairs(regions) do
  local ex=math.abs(r.Cos)*r.W/2+math.abs(r.Sin)*r.H/2
  local ez=math.abs(r.Sin)*r.W/2+math.abs(r.Cos)*r.H/2
  local x1,z1=R.Cell(r.X-ex,r.Z-ez,ox,oz);local x2,z2=R.Cell(r.X+ex,r.Z+ez,ox,oz)
  for x=math.floor(x1/8),math.floor(x2/8) do for z=math.floor(z1/8),math.floor(z2/8) do
   local key=R.Key(x,z);index[key]=index[key] or {};table.insert(index[key],r)
  end end
 end
 return index
end
function R.Kind(index,x,z,ox,oz)
 local kind="Ground"
 local pointX,pointZ=ox+(x+.5)*20,oz+(z+.5)*20
 for _,r in ipairs(index[R.Key(math.floor(x/8),math.floor(z/8))] or {}) do
  if R.Contains(r,pointX,pointZ) then
   local candidate=r.Kind
   if (kind=="RoadX" and candidate=="RoadZ") or (kind=="RoadZ" and candidate=="RoadX") then kind="RoadCross"
   elseif (priorities[candidate] or 0)>(priorities[kind] or 0) then kind=candidate end
  end
 end
 return kind
end
function R.RoadKind(w,h,cos,sin)
 local alongX=(w>=h and math.abs(cos)>=math.abs(sin)) or (w<h and math.abs(sin)>math.abs(cos))
 return alongX and "RoadX" or "RoadZ"
end
return R
