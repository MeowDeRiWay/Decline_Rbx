"""Verify the actual uploaded backpack pivot fit, future variants and safe welds."""
from pathlib import Path
import subprocess,sys,tempfile
root=Path(__file__).resolve().parents[1]
def module(p):return '(function()\n'+(root/p).read_text()+'\nend)()'
helpers=(root/'tests/run_character_rig.py').read_text().split("source+=r'''")[1].split('local function test(frame)')[0]
s=(root/'tests/rig_math.fixture.luau').read_text()+helpers
s+='\nlocal Back='+module('src/server/Services/BackVisuals.luau')
s+='\nlocal geometry='+module('tests/backpack_geometry.fixture.luau')
s+=r'''
function methods:GetPivot() return self.PrimaryPart and self.PrimaryPart.CFrame or self.CFrame end
function methods:Clone()
 local copy=Instance.new(self.ClassName);copy.Name=self.Name;copy.CFrame=self.CFrame;copy.Size=self.Size
 return copy
end
for _,pose in ipairs({CFrame.identity,CFrame.Angles(.5,.8,-.2),CFrame.Angles(0,1.7,math.pi/2)}) do
 local character=Instance.new("Model")
 local torso=Instance.new("Part",character);torso.Name="UpperTorso";torso.CFrame=CFrame.new(5,8,10)*pose
 local held=Instance.new("Model",character);held.Name="HeldItem"
 local armor=Instance.new("Model",character);armor.Name="EquippedArmor"
 local sourceWorld=CFrame.new(-580,3,20)*CFrame.Angles(0,.9,0)
 local template=Instance.new("Model")
 local base=Instance.new("Part",template);base.Name="Part";base.Size=geometry.Size;base.CFrame=sourceWorld*geometry.Pivot;template.PrimaryPart=base
 local expected=geometry.Torso:ToObjectSpace(geometry.Pivot)
 assert(Back.Apply(character,"Backpack1",template))
 local worn=character:FindFirstChild("EquippedBack")
 local fitted=worn:FindFirstChild("Part")
 near(torso.CFrame:ToObjectSpace(fitted.CFrame).Position,expected.Position)
 near(fitted.CFrame.RightVector,(torso.CFrame*expected).RightVector)
 local weld=fitted:FindFirstChild("BackWeld");assert(weld.Part0==torso and weld.Part1==fitted)
 assert(fitted.Massless and not fitted.Anchored and not fitted.CanCollide and not fitted.CanTouch and not fitted.CanQuery)
 assert(held.Parent==character and armor.Parent==character,"back items do not replace Hands or Body")
 assert(Back.Apply(character,"Backpack1",template) and character:FindFirstChild("EquippedBack")==worn)
 local pocket=Instance.new("Part",template);pocket.Name="Pocket";pocket.Size=Vector3.new(.3,.2,.15);pocket.CFrame=base.CFrame*CFrame.new(.03,0,.12)
 assert(Back.Apply(character,"Backpack2",template),"future variants retain the common PrimaryPart pivot")
 local larger=character:FindFirstChild("EquippedBack")
 near(torso.CFrame:ToObjectSpace(larger:FindFirstChild("Part").CFrame).Position,expected.Position)
 near(larger:FindFirstChild("Part").CFrame:ToObjectSpace(larger:FindFirstChild("Pocket").CFrame).Position,Vector3.new(.03,0,.12))
 assert(Back.Apply(character,nil) and not character:FindFirstChild("EquippedBack") and armor.Parent==character)
 assert(Back.Apply(character,"Backpack1",nil)==false,"missing template does not leave a false equipped model")
end
print("PASS: measured PrimaryPart-to-torso fit under rotation/bending/KO, shared pivot across larger variants, safe welds, cache/removal and Body/Hands isolation")
'''
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'backpack.luau';p.write_text(s);subprocess.run([sys.argv[1],str(p)],check=True)
