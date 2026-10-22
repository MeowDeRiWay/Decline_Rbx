"""Exercise real wall assembly against rotated references and arbitrary model pivots."""
from pathlib import Path
import subprocess,sys,tempfile
root=Path(__file__).resolve().parents[1]
source=(root/'src/server/Services/WallReplacementService.luau').read_text()
cases='''
local originalClone=methods.Clone
function methods:Clone()
 local clone=originalClone(self)
 clone.CanCollide=self.CanCollide;clone.Anchored=self.Anchored
 return clone
end
local library=make("Folder","CityGeneration",ServerStorage)
local walls=make("Folder","Walls",library)
local source=make("Model","Wall (brick)",walls,{BlocksVision=true})
source.CFrame=cf(Vector3.new(31,5,21),.3)
local anchor=make("Model","WallYard",source)
anchor.CFrame=cf(Vector3.new(33,3,24),.7)
local base=make("Part","Part",anchor);base.CFrame=anchor.CFrame;base.CanCollide=false
local outside=make("Part","Outside",source);outside.CFrame=cf(Vector3.new(34,4,24),.7);outside.CanCollide=true
local house=make("Model","House",workspace)
local marker=make("Model","WallPlacer",house,{Replace="Wall (brick)",BlocksVision=false})
marker.CFrame=cf(Vector3.new(10,1,10),-.6)
local target=make("Model","YardPlacer",marker)
target.CFrame=cf(Vector3.new(-4,2,8),math.pi/2)
make("Part","Part",target)
local targetFrame=target.CFrame
Service.Fill(house)
assert(marker.destroyed and #house:GetChildren()==1,"placeholder completely replaced, not left colliding")
local built=house:FindFirstChild("Wall (brick)")
assert(built and built.Parent==house and built:GetAttribute("BlocksVision")==true,"marker's false vision flag cannot override wall")
assert((built.WallYard.CFrame.Position-targetFrame.Position).Magnitude<1e-8 and math.abs(built.WallYard.CFrame.yaw-targetFrame.yaw)<1e-8,"reference position and yaw align despite offset pivots")
assert(built.Outside.Anchored and built.WallYard.Part.Anchored and built.Outside.CanCollide and not built.WallYard.Part.CanCollide,"anchor all parts without changing authored collisions")
assert(built.WallYard.Part.Transparency==1 and not built.WallYard.Part.CanQuery and not built.WallYard.Part.CanTouch and not built.WallYard.Part.CastShadow,"WallYard is an invisible inert marker")
assert(built.Outside.Transparency~=1,"wall geometry outside WallYard remains visible")
assert(source.Parent==walls and not source.Outside.Anchored,"source template untouched")
Service.Fill(house);assert(#house:GetChildren()==1,"repeated fill cannot duplicate pieces")
local missing=make("Model","WindowPlacer",house,{Replace="Window (brick)"});make("Part","Part",missing)
Service.Fill(house);assert(not missing.destroyed,"missing template keeps marker for retry")
local window=source:Clone();window.Name="Window (brick)";window:SetAttribute("BlocksVision",false);window.Parent=walls
Service.Fill(house);assert(missing.destroyed and house:FindFirstChild("Window (brick)"):GetAttribute("BlocksVision")==false,"late template retry preserves window attributes")
local part=make("Part","Any name",house,{Replace="Wall (brick)"});part.CFrame=cf(Vector3.new(20,0,20),-.4)
Service.Fill(house);assert(part.destroyed,"Part placeholders also supported with own CFrame")
local preplaced=source:Clone();preplaced.Parent=workspace
Service.Fill(workspace);assert(preplaced.WallYard.Part.Transparency==1 and preplaced.Outside.Transparency~=1,"preplaced walls hide placement markers too")
print("PASS: exact Replace names, nested pieces, pivot/reference alignment and yaw, anchoring/collisions/vision, source preservation, no duplicates and missing-template retry")
'''
parts=[(root/'tests/fixtures/town_mock.luau').read_text(),(root/'tests/city_geometry.fixture.luau').read_text(),(root/'tests/city_service.fixture.luau').read_text(),'local Service=(function()\n'+source+'\nend)()',cases]
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'test.luau';p.write_text('\n'.join(parts));subprocess.run([sys.argv[1],str(p)],check=True)
