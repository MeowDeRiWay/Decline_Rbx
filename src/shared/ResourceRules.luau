local Rules = {}
function Rules.CanDamage(resource, definition)
 return definition ~= nil and definition.HarvestTool == resource.Tool
end
function Rules.Damage(health, damage)
 return math.max(0, health - damage)
end
function Rules.Spaced(points, x, z, spacing)
 for _,point in ipairs(points) do
  if (point.X-x)^2 + (point.Z-z)^2 < spacing^2 then return false end
 end
 return true
end
local function cross(a,b,c)
 return (b.X-a.X)*(c.Z-a.Z)-(b.Z-a.Z)*(c.X-a.X)
end
function Rules.Footprint(frame,size)
 local points = {}
 for _,x in ipairs({-1,1}) do for _,y in ipairs({-1,1}) do for _,z in ipairs({-1,1}) do
  local p = frame:PointToWorldSpace(Vector3.new(x*size.X/2,y*size.Y/2,z*size.Z/2))
  table.insert(points,{X=p.X,Z=p.Z})
 end end end
 table.sort(points,function(a,b) return a.X==b.X and a.Z<b.Z or a.X<b.X end)
 local lower,upper = {},{}
 for _,p in ipairs(points) do
  while #lower>=2 and cross(lower[#lower-1],lower[#lower],p)<=0 do table.remove(lower) end
  table.insert(lower,p)
 end
 for i=#points,1,-1 do
  local p=points[i]
  while #upper>=2 and cross(upper[#upper-1],upper[#upper],p)<=0 do table.remove(upper) end
  table.insert(upper,p)
 end
 table.remove(lower); table.remove(upper)
 for _,p in ipairs(upper) do table.insert(lower,p) end
 return lower
end
local function separated(a,b)
 for i,p in ipairs(a) do
  local q=a[i%#a+1]
  local nx,nz=-(q.Z-p.Z),q.X-p.X
  local amin,amax,bmin,bmax=math.huge,-math.huge,math.huge,-math.huge
  for _,v in ipairs(a) do local n=v.X*nx+v.Z*nz;amin=math.min(amin,n);amax=math.max(amax,n) end
  for _,v in ipairs(b) do local n=v.X*nx+v.Z*nz;bmin=math.min(bmin,n);bmax=math.max(bmax,n) end
  if amax<=bmin or bmax<=amin then return true end
 end
 return false
end
local function segmentDistanceSquared(p,a,b)
 local dx,dz=b.X-a.X,b.Z-a.Z
 local length=dx*dx+dz*dz
 local t=length>0 and math.clamp(((p.X-a.X)*dx+(p.Z-a.Z)*dz)/length,0,1) or 0
 return (p.X-a.X-t*dx)^2+(p.Z-a.Z-t*dz)^2
end
function Rules.GapSquared(a,b)
 if not separated(a,b) and not separated(b,a) then return 0 end
 local distance=math.huge
 for _,p in ipairs(a) do for i,q in ipairs(b) do distance=math.min(distance,segmentDistanceSquared(p,q,b[i%#b+1])) end end
 for _,p in ipairs(b) do for i,q in ipairs(a) do distance=math.min(distance,segmentDistanceSquared(p,q,a[i%#a+1])) end end
 return distance
end
function Rules.Clearance(footprints,candidate,gap)
 for _,other in ipairs(footprints) do
  if gap == 0 then
   if not separated(candidate,other) and not separated(other,candidate) then return false end
  elseif Rules.GapSquared(candidate,other)<gap*gap-1e-8 then return false end
 end
 return true
end
-- One Bernoulli trial per square stud. Partial edge cells scale by their area.
function Rules.RollCells(width, depth, chance, random, visit)
 for x=0,math.ceil(width)-1 do
  local cellWidth=math.min(1,width-x)
  for z=0,math.ceil(depth)-1 do
   local cellDepth=math.min(1,depth-z)
   if random:NextNumber() < chance*cellWidth*cellDepth then
    visit(-width/2+x+random:NextNumber()*cellWidth, -depth/2+z+random:NextNumber()*cellDepth)
   end
  end
 end
end
-- Broad phase for dense resource regions; exact footprint overlap remains authoritative.
function Rules.FootprintIndex(cellSize)
 local buckets={}
 local function keys(footprint,visit)
  local xmin,xmax,zmin,zmax=math.huge,-math.huge,math.huge,-math.huge
  for _,p in ipairs(footprint) do
   xmin=math.min(xmin,p.X); xmax=math.max(xmax,p.X)
   zmin=math.min(zmin,p.Z); zmax=math.max(zmax,p.Z)
  end
  for x=math.floor(xmin/cellSize),math.floor(xmax/cellSize) do
   for z=math.floor(zmin/cellSize),math.floor(zmax/cellSize) do
    if visit(x..":"..z)==false then return false end
   end
  end
  return true
 end
 return {
  Insert=function(_,footprint)
   keys(footprint,function(key)
    buckets[key]=buckets[key] or {}; table.insert(buckets[key],footprint)
   end)
  end,
  Clear=function(_,footprint)
   local seen={}
   return keys(footprint,function(key)
    for _,other in ipairs(buckets[key] or {}) do
     if not seen[other] then
      seen[other]=true
      if not Rules.Clearance({other},footprint,0) then return false end
     end
    end
   end)
  end,
 }
end
-- The last occupant leaving starts a fresh delay; re-entry resets it.
function Rules.Occupancy(state, occupied, now, delay)
 if occupied then state.Occupied = true; state.AllowedAt = now + delay
 elseif state.Occupied then state.Occupied = false; state.AllowedAt = now + delay end
 return not occupied and now >= (state.AllowedAt or 0)
end
return Rules
