local Rules=require("../src/shared/ZombieActivityRules")
assert(Rules.Mode(0)=="Active" and Rules.Mode(50)=="Active")
assert(Rules.Mode(50.001)=="Minimal" and Rules.Mode(200)=="Minimal")
assert(Rules.Mode(200.001)=="AFK" and Rules.Mode(math.huge)=="AFK")
local square={{X=-10,Z=-5},{X=10,Z=-5},{X=10,Z=5},{X=-10,Z=5}}
assert(Rules.EdgeDistance(0,0,square)==0)
assert(Rules.EdgeDistance(10,0,square)==0)
assert(Rules.EdgeDistance(60,0,square)==50)
assert(Rules.Mode(Rules.EdgeDistance(60.01,0,square))=="Minimal")
assert(Rules.Mode(Rules.EdgeDistance(210,0,square))=="Minimal")
assert(Rules.Mode(Rules.EdgeDistance(211,0,square))=="AFK")
assert(math.abs(Rules.EdgeDistance(13,9,square)-5)<1e-6)
assert(Rules.EdgeDistance(0,0,{})==math.huge)
local a=Rules.ScreenOffsets(30,5,40,16/9)
local b=Rules.ScreenOffsets(60,10,40,16/9)
for i=1,4 do
 assert(math.abs(b[i].X-2*a[i].X)<1e-6 and math.abs(b[i].Z-2*a[i].Z)<1e-6,"zoom scales screen footprint")
end
assert(Rules.EdgeDistance(0,0,a)==0,"player inside screen")
assert(a[1].X<0 and a[2].X>0 and a[1].Z<0 and a[3].Z>0,"fixed camera screen orientation")
local wide=Rules.ScreenOffsets(30,5,40,32/9)
local rotated=Rules.ScreenOffsets(30,5,40,16/9,math.pi/2)
for i=1,4 do
 assert(math.abs(rotated[i].X-a[i].Z)<1e-6 and math.abs(rotated[i].Z+a[i].X)<1e-6,"activity footprint follows camera yaw")
end
assert(math.abs(wide[1].X-2*a[1].X)<1e-6 and wide[1].Z==a[1].Z)
print("PASS: exact 50/200 boundaries, edge/corner distances, no players, zoom/aspect screen footprint")
