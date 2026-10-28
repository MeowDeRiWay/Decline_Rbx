local Rules=require("../src/shared/ResourceRules")
local function rectangle(x,z,hx,hz,yaw)
 local out={}
 local c,s=math.cos(yaw or 0),math.sin(yaw or 0)
 for _,p in ipairs({{-hx,-hz},{hx,-hz},{hx,hz},{-hx,hz}}) do table.insert(out,{X=x+p[1]*c+p[2]*s,Z=z-p[1]*s+p[2]*c}) end
 return out
end
local a=rectangle(0,0,1,1)
assert(Rules.GapSquared(a,rectangle(5,0,1,1))==9)
assert(Rules.Clearance({a},rectangle(5,0,1,1),3))
assert(not Rules.Clearance({a},rectangle(4.99,0,1,1),3))
assert(Rules.GapSquared(a,rectangle(.5,.5,1,1))==0)
assert(not Rules.Clearance({a},rectangle(0,0,.1,.1),3))
assert(Rules.GapSquared(a,rectangle(5,5,1,1))==18)
local rotated=rectangle(0,0,2,.2,math.pi/4)
assert(not Rules.Clearance({rotated},rectangle(0,0,.2,2,-math.pi/4),3))
assert(Rules.Clearance({rotated},rectangle(10,0,2,.2,math.pi/4),3))
-- Large models need more space than small ones at identical center distances.
assert(not Rules.Clearance({rectangle(0,0,4,1)},rectangle(9,0,4,1),3))
print("PASS: true model-edge clearance, exact boundary, corners, overlap, containment, rotation and different model sizes")

-- Zero gap still rejects overlap, but permits edge contact and tiny clearances.
assert(not Rules.Clearance({a},rectangle(.5,.5,1,1),0))
assert(not Rules.Clearance({a},rectangle(0,0,.1,.1),0))
assert(Rules.Clearance({a},rectangle(2,0,1,1),0))
assert(Rules.Clearance({a},rectangle(2.001,0,1,1),0))
local index=Rules.FootprintIndex(8)
index:Insert(a)
index:Insert(rectangle(-16,-16,2,2))
assert(not index:Clear(rectangle(.5,.5,1,1)))
assert(not index:Clear(rectangle(-16,-16,.1,.1)))
assert(index:Clear(rectangle(2.001,0,1,1)))
assert(index:Clear(rectangle(40,40,1,1)))
print("PASS: zero-gap overlap rejection and spatial index, including negative buckets")

index:Remove(a)
assert(index:Clear(a),"removing a harvested node releases its footprint")
assert(not index:Clear(rectangle(-16,-16,.1,.1)),"removing one node keeps other buckets")
index:Remove(a)
index:Insert(a)
assert(not index:Clear(a),"reinserted footprints still prevent overlaps")
print("PASS: persistent footprint removal and reinsertion")
