"""Execute real bounding-box distance math, including rotated and crossing boxes."""
from pathlib import Path
import subprocess, sys, tempfile
root = Path(__file__).resolve().parents[1]
source = (root / 'tests/rig_math.fixture.luau').read_text()
source += '\nlocal Interaction=(function()\n' + (root / 'src/shared/Interaction.luau').read_text() + '\nend)()\n'
source += '\nlocal function box(frame,size)\n return {CFrame=frame,Size=size,IsA=function() return false end}\nend\nlocal a=box(CFrame.new(),Vector3.new(20,2,2))\nlocal b=box(CFrame.new(16,0,0),Vector3.new(2,2,2))\nlocal p,q,d=Interaction.ClosestPoints(a,b)\nassert(math.abs(d-5)<1e-8)\nb.CFrame=CFrame.new(16.1,0,0)\nassert(select(3,Interaction.ClosestPoints(a,b))>5)\nb.CFrame=CFrame.new(0,0,0)*CFrame.Angles(0,math.pi/2,0);b.Size=Vector3.new(20,2,2)\nassert(select(3,Interaction.ClosestPoints(a,b))==0)\nb.CFrame=CFrame.new(0,0,8)*CFrame.Angles(0,math.pi/4,0);b.Size=Vector3.new(4,2,2)\np,q,d=Interaction.ClosestPoints(a,b)\nassert(math.abs(d-(7-3/math.sqrt(2)))<1e-7)\nprint("PASS: edge distance, 5-stud boundary, rotated boxes and intersecting boxes")\n'
with tempfile.TemporaryDirectory() as directory:
    path = Path(directory) / 'distance.luau'
    path.write_text(source)
    subprocess.run([sys.argv[1], str(path)], check=True)
