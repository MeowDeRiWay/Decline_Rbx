local R=require("../src/shared/MapRules")
local x,z=R.Cell(19.99,-.01,0,0);assert(x==0 and z==-1)
x,z=R.Cell(10,10,0,0);assert(x==0 and z==0)
local seen={};assert(#R.Reveal(0,0,seen)==9);assert(#R.Reveal(0,0,seen)==0)
assert(#R.Reveal(1,0,seen)==3 and seen["-1:-1"] and not seen["3:0"])
local regions={
 {X=10,Z=10,W=200,H=200,Cos=1,Sin=0,Kind="Forest"},
 {X=10,Z=10,W=100,H=20,Cos=1,Sin=0,Kind="RoadX"},
 {X=10,Z=10,W=20,H=100,Cos=1,Sin=0,Kind="RoadZ"},
 {X=30,Z=30,W=20,H=20,Cos=1,Sin=0,Kind="House"},
 {X=70,Z=30,W=40,H=40,Cos=1,Sin=0,Kind="Infrastructure"},
 {X=-30,Z=30,W=20,H=40,Cos=0,Sin=1,Kind="ScrapYard"},
}
local index=R.Index(regions,0,0)
assert(R.Kind(index,0,0,0,0)=="RoadCross")
assert(R.Kind(index,1,0,0,0)=="RoadX" and R.Kind(index,0,1,0,0)=="RoadZ")
assert(R.Kind(index,1,1,0,0)=="House")
assert(R.Kind(index,3,1,0,0)=="Infrastructure")
assert(R.Kind(index,-2,1,0,0)=="ScrapYard")
assert(R.Kind(index,20,20,0,0)=="Ground")
assert(R.RoadKind(20,100,1,0)=="RoadZ" and R.RoadKind(20,100,0,1)=="RoadX")
-- A 20x20 footprint centered on a plot maps to one cell, not four.
local house={{X=0,Z=0,W=20,H=20,Cos=1,Sin=0,Kind="House"}}
local aligned=R.Index(house,10,10)
assert(R.Kind(aligned,-1,-1,10,10)=="House" and R.Kind(aligned,0,-1,10,10)=="Ground")
print("PASS: 20-stud cells, negative/aligned coordinates, personal reveal, rotated footprints, road intersections and classification priority")
