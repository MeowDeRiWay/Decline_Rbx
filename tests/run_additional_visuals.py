"""Verify the actual uploaded backpack pivot fit, future variants and safe welds."""
from pathlib import Path
import subprocess,sys,tempfile
root=Path(__file__).resolve().parents[1]
def module(p):return '(function()\n'+(root/p).read_text()+'\nend)()'
helpers=(root/'tests/run_character_rig.py').read_text().split("source+=r'''")[1].split('local function test(frame)')[0]
s=(root/'tests/rig_math.fixture.luau').read_text()+helpers
s+='\nlocal Back='+module('src/server/Services/AdditionalVisuals.luau')
s+='\nlocal geometry='+module('tests/backpack_geometry.fixture.luau')
s+=r'''
function methods:GetPivot() return self.CFrame end
function methods:GetBoundingBox() return self.PrimaryPart.CFrame,self.PrimaryPart.Size end
function methods:Clone()
 local copy=Instance.new(self.ClassName);copy.Name=self.Name;copy.CFrame=self.CFrame;copy.Size=self.Size
 return copy
end
for _,pose in ipairs({CFrame.identity,CFrame.Angles(.5,.8,-.2),CFrame.Angles(0,1.7,math.pi/2)}) do
 local character=Instance.new("Model")
 local torso=Instance.new("Part",character);torso.Name="LowerTorso";torso.Size=Vector3.new(2,1,1);torso.CFrame=CFrame.new(5,8,10)*pose
 local template=Instance.new("Model");template.CFrame=CFrame.new(40,3,7)*CFrame.Angles(0,.8,0)
 local part=Instance.new("Part",template);part.Name="Kit";part.Size=Vector3.new(.5,.6,.3);part.CFrame=template.CFrame*CFrame.new(2,0,0);template.PrimaryPart=part
 assert(Back.Apply(character,"SurgicalKit",template))
 local worn=character:FindFirstChild("EquippedAdditional");local fitted=worn:FindFirstChild("Kit")
 near(torso.CFrame:ToObjectSpace(fitted.CFrame).Position,Vector3.new(-1.3,.2,0))
 near(fitted.CFrame.RightVector,torso.CFrame.RightVector)
 local weld=fitted:FindFirstChild("BeltWeld");assert(weld.Part0==torso and weld.Part1==fitted)
 assert(fitted.Massless and not fitted.Anchored and not fitted.CanCollide and not fitted.CanQuery)
 assert(Back.Apply(character,"SurgicalKit",template) and character:FindFirstChild("EquippedAdditional")==worn)
 assert(Back.Apply(character,nil) and not character:FindFirstChild("EquippedAdditional"))
 assert(Back.Apply(character,"OtherAdditional",template) and not character:FindFirstChild("EquippedAdditional"))
end
print("PASS: kit left-belt fit, pivot independence, rotated torso, safe welds, cache/removal and kit-only visual")
'''
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'backpack.luau';p.write_text(s);subprocess.run([sys.argv[1],str(p)],check=True)
