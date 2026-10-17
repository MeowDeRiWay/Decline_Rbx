"""Test real placement rules with horizontal Roblox geometry mocks."""
from pathlib import Path
import subprocess
import sys
import tempfile
root = Path(__file__).resolve().parents[1]
mock = (root/'tests/city_geometry.fixture.luau').read_text()
rules = (root/'src/shared/CityGenerationRules.luau').read_text()
cases = '''
local plot=CFrame.new(Vector3.new(50,7,70))
local yard=cf(Vector3.new(13,2,-8),0)
local size=Vector3.new(20,.2,20)
for _,direction in ipairs({Vector3.new(1,0,0),Vector3.new(-1,0,0),Vector3.new(0,0,1),Vector3.new(0,0,-1)}) do
 local road=plot.Position+direction
 local placed=Rules.Frame(plot,yard,road)
 local center=(placed*yard).Position
 assert((center-plot.Position).Magnitude<.00001,"offset Yard must align with plot, including height")
 assert((placed:VectorToWorldSpace(Vector3.new(0,0,1))-direction).Magnitude<.00001,"+Z must face road")
 assert(Rules.Fits(placed,yard,size,plot,size,.05))
end
local turnedPlot=cf(plot.Position,math.pi/2)
local frame=Rules.Frame(turnedPlot,yard,Vector3.new(80,7,73))
assert(Rules.Fits(frame,yard,size,turnedPlot,size,.05),"rotated plot accepts snapped 20x20 yard")
assert(not Rules.Fits(frame,yard,Vector3.new(22,1,20),turnedPlot,size,.05),"oversized yard rejected")
local diagonalYard=cf(yard.Position,math.pi/4)
local diagonalFrame=Rules.Frame(plot,diagonalYard,Vector3.new(90,7,70))
assert(not Rules.Fits(diagonalFrame,diagonalYard,size,plot,size,.05),"diagonal yard cannot spill into neighboring plots")
local road=Rules.RoadPoint(CFrame.new(Vector3.new(0,0,0)),Vector3.new(20,1,20),Vector3.new(30,7,3))
assert((road-Vector3.new(10,0,3)).Magnitude<.00001,"road orientation uses closest edge rather than tile center")
print("PASS: all four road directions, positive-Z front, offset Yard alignment, marker height, rotated plots, oversized/diagonal yard rejection, nearest road edge")
'''
with tempfile.TemporaryDirectory(prefix='decline-city-') as directory:
    path = Path(directory)/'city_geometry.luau'
    path.write_text(mock+'\nlocal Rules=(function()\n'+rules+'\nend)()\n'+cases)
    subprocess.run([sys.argv[1] if len(sys.argv)>1 else 'luau', str(path)],check=True)
