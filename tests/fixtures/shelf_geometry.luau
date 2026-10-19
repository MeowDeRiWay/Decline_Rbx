-- Geometry read from user-supplied Shelf.rbxm: upright shelf, pivot pitched 90 degrees.
local shelfPivot={Position=Vector3.new(-0.400043488,-6.5,-1.39997745),RightVector=Vector3.new(1,0,0),LookVector=Vector3.new(-0,1,-0)}
local shelfCorners={
 Vector3.new(-0.900053024,-7.5,-0.9999454505),
 Vector3.new(-0.900053024,-7.5,-0.8999454495),
 Vector3.new(-0.900053024,-5.5,-0.9999454505),
 Vector3.new(-0.900053024,-5.5,-0.8999454495),
 Vector3.new(0.099946976,-7.5,-0.9999454505),
 Vector3.new(0.099946976,-7.5,-0.8999454495),
 Vector3.new(0.099946976,-5.5,-0.9999454505),
 Vector3.new(0.099946976,-5.5,-0.8999454495),
 Vector3.new(-0.900051117,-6.4000122095,-1.89996052),
 Vector3.new(-0.900051117,-6.5000122105,-1.89996052),
 Vector3.new(-0.900051117,-6.4000122095,-0.89996052),
 Vector3.new(-0.900051117,-6.5000122105,-0.89996052),
 Vector3.new(0.099948883,-6.4000122095,-1.89996052),
 Vector3.new(0.099948883,-6.5000122105,-1.89996052),
 Vector3.new(0.099948883,-6.4000122095,-0.89996052),
 Vector3.new(0.099948883,-6.5000122105,-0.89996052),
 Vector3.new(-0.900032043,-7.4000122095,-1.900009338),
 Vector3.new(-0.900032043,-7.5000122105,-1.900009338),
 Vector3.new(-0.900032043,-7.4000122095,-1.000009362),
 Vector3.new(-0.900032043,-7.5000122105,-1.000009362),
 Vector3.new(0.099967957,-7.4000122095,-1.900009338),
 Vector3.new(0.099967957,-7.5000122105,-1.900009338),
 Vector3.new(0.099967957,-7.4000122095,-1.000009362),
 Vector3.new(0.099967957,-7.5000122105,-1.000009362),
}
local shelfBox,shelfSize=Rules.UprightFurnitureBox(shelfPivot,shelfCorners)
assert(math.abs(shelfSize.X-1)<.001 and math.abs(shelfSize.Y-2)<.001 and math.abs(shelfSize.Z-1)<.001,"tilted pivot must not turn shelf height into footprint")
for _,zone in ipairs({{Width=9.99993324,Count=10},{Width=3.99993324,Count=4},{Width=3.99993324,Count=4}}) do
 local columns,rows=Rules.FurnitureGrid(Vector3.new(zone.Width,.1,1),shelfSize)
 assert(columns*rows==zone.Count,"actual store shelf regions must fill despite editor float noise")
end
print("PASS: actual Shelf.rbxm pitched pivot yields upright 1x1 footprint and 10+4+4 store shelves")
