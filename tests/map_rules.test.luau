local R=require("../src/shared/MapRules")
local x,z=R.Cell(19.99,-.01,0,0);assert(x==0 and z==-1)
local seen={};assert(#R.Reveal(0,0,seen)==9);assert(#R.Reveal(0,0,seen)==0)
assert(#R.Reveal(1,0,seen)==3 and seen["-1:-1"] and not seen["3:0"])
local regions={
 {X=10,Z=10,W=200,H=200,Cos=1,Sin=0,Kind="Forest"},
 {X=10,Z=10,W=100,H=20,Cos=1,Sin=0,Kind="Road"},
 {X=10,Z=10,W=20,H=100,Cos=1,Sin=0,Kind="Road"},
 {X=30,Z=30,W=20,H=20,Cos=1,Sin=0,Kind="House"},
 {X=70,Z=30,W=40,H=40,Cos=1,Sin=0,Kind="Infrastructure"},
 {X=-30,Z=30,W=20,H=40,Cos=0,Sin=1,Kind="ScrapYard"},
}
local index=R.Index(regions,0,0)
assert(R.Kind(index,1,1,0,0)=="House" and R.Kind(index,3,1,0,0)=="Infrastructure")
assert(R.Kind(index,-2,1,0,0)=="ScrapYard" and R.Kind(index,20,20,0,0)=="Ground")
assert(R.RoadMask(index,0,0,0,0)==65535 and R.RoadMask(index,1,0,0,0)==65535)
local road={}
-- Regression: the game's roads are SQUARE 20x20 slabs, not long narrow parts.
-- Consecutive slabs must fill their cells continuously, independent of local yaw.
for row=-2,2 do table.insert(road,{X=10,Z=10+row*20,W=20,H=20,Cos=1,Sin=0,Kind="Road"}) end
local tiles=R.Index(road,0,0)
for row=-2,2 do
 local mask=R.RoadMask(tiles,0,row,0,0);assert(mask==65535,"no railway-like gaps between square road tiles")
 local rects=R.RoadRects(mask);assert(#rects==1 and rects[1].W==1 and rects[1].H==1)
end
assert(R.RoadMask(tiles,1,0,0,0)==0,"do not spill roads into grass or fog")
local half=R.RoadRects(255);assert(#half==1 and half[1].X==0 and half[1].Z==0 and half[1].W==1 and half[1].H==.5)
assert(#R.RoadRects(0)==0)
local rotated={{X=10,Z=10,W=100,H=5,Cos=0,Sin=1,Kind="Road"}}
local rotatedIndex=R.Index(rotated,0,0)
assert(R.RoadMask(rotatedIndex,0,1,0,0)~=0 and R.RoadMask(rotatedIndex,1,0,0,0)==0)
local house=R.Index({{X=0,Z=0,W=20,H=20,Cos=1,Sin=0,Kind="House"}},10,10)
assert(R.Kind(house,-1,-1,10,10)=="House" and R.Kind(house,0,-1,10,10)=="Ground")
local _,first=R.CellData(tiles,0,0,0,0);local _,second=R.CellData({},0,0,0,0)
assert(first~=second,"road-only changes trigger map deltas")
print("PASS: actual road footprint masks, contiguous 20x20 slabs, rotated roads, no spill, merged rectangles, fog alignment and terrain priority")
