-- One authored 20-stud world cell is 20 pixels at zoom 1. North is -Z.
local R={CellSize=20,RevealRadius=1,BucketSize=8}
local priorities={Ground=0,Forest=1,ScrapYard=2,StoneYard=2,House=4,Infrastructure=5}
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
  if r.Kind~="Road" and R.Contains(r,pointX,pointZ) and (priorities[r.Kind] or 0)>(priorities[kind] or 0) then kind=r.Kind end
 end
 return kind
end
-- Roads are actual footprints sampled within a cell, never an inferred direction.
-- A square 20x20 road tile covers the entire cell and joins all adjacent road tiles.
function R.RoadMask(index,x,z,ox,oz)
 local mask=0
 local regions=index[R.Key(math.floor(x/8),math.floor(z/8))] or {}
 for row=0,3 do for column=0,3 do
  local px,pz=ox+x*20+(column+.5)*5,oz+z*20+(row+.5)*5
  for _,r in ipairs(regions) do
   if r.Kind=="Road" and R.Contains(r,px,pz) then mask=bit32.bor(mask,bit32.lshift(1,row*4+column));break end
  end
 end end
 return mask
end
-- Merge neighboring samples into rectangles to keep the GUI small.
function R.RoadRects(mask)
 local result,previous={},{}
 for row=0,3 do
  local current={};local column=0
  while column<4 do
   if bit32.band(mask,bit32.lshift(1,row*4+column))==0 then column+=1;continue end
   local start=column
   repeat column+=1 until column==4 or bit32.band(mask,bit32.lshift(1,row*4+column))==0
   local width=column-start;local key=start..":"..width
   local rectangle=previous[key]
   if rectangle then rectangle.H+=.25
   else rectangle={X=start/4,Z=row/4,W=width/4,H=.25};table.insert(result,rectangle) end
   current[key]=rectangle
  end
  previous=current
 end
 return result
end
function R.CellData(index,x,z,ox,oz)
 local kind=R.Kind(index,x,z,ox,oz);local mask=R.RoadMask(index,x,z,ox,oz)
 return {X=x,Z=z,Kind=kind,RoadMask=mask},kind..":"..mask
end
return R
