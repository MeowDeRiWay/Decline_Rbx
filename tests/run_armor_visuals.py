"""Fit armor groups onto the actual custom rig and verify safe weld ownership."""
from pathlib import Path
import subprocess,sys,tempfile
root=Path(__file__).resolve().parents[1]
def module(path):return '(function()\n'+(root/path).read_text()+'\nend)()'
helpers=(root/'tests/run_character_rig.py').read_text().split("source+=r'''")[1].split('local function test(frame)')[0]
s=(root/'tests/rig_math.fixture.luau').read_text()+helpers
s+='\nlocal Rig='+module('src/shared/CharacterRig.luau')
s+='\nlocal Armor='+module('src/server/Services/ArmorVisuals.luau')
s+='\nlocal Items='+module('src/shared/ItemConfig.luau')
s+='\nlocal Recipes='+module('src/shared/CraftConfig.luau')
s+='\nlocal Craft='+module('src/shared/CraftRules.luau')
s+='\nlocal Defense='+module('src/shared/DefenseRules.luau')
s+='\nlocal geometry='+module('tests/character_geometry.fixture.luau')
s+='\nlocal military='+module('tests/military_armor_geometry.fixture.luau')
s+=r'''
function methods:GetPivot() return self.CFrame or CFrame.identity end
function methods:Clone()
 local p=Instance.new(self.ClassName);p.Name=self.Name;p.Size=self.Size;p.CFrame=self.CFrame;p.Attributes=table.clone(self.Attributes);p.Transparency=self.Transparency
 return p
end
local c=Instance.new("Model")
local originals={}
for _,g in ipairs(geometry) do local p=Instance.new("Part",c);p.Name=g.Name;p.CFrame=g.CFrame;p.Size=g.Size;p.Transparency=0;originals[g.Name]=g end
local root=c:FindFirstChild("Body");root.Name="HumanoidRootPart"
assert(Rig.Prepare(c,root,Instance.new("Humanoid",c)))
local frames={[root]=root.CFrame}
for _=1,12 do for _,j in ipairs(c:GetDescendants()) do if j:IsA("Motor6D") and frames[j.Part0] and not frames[j.Part1] then frames[j.Part1]=frames[j.Part0]*j.C0*j.C1:Inverse() end end end
for p,cf in pairs(frames) do p.CFrame=cf end
local template=Instance.new("Model");template.CFrame=CFrame.new(30,4,20)
for _,name in ipairs({"UpperTorso","LeftUpperArm","LeftLowerArm","RightUpperArm","RightLowerArm"}) do
 local group=Instance.new("Folder",template);group.Name=name
 local p=Instance.new("Part",group);p.Name="Any name";p.CFrame=originals[name].CFrame;p.Size=originals[name].Size*1.1
end
local held=Instance.new("Part",c);held.Name="HeldItem"
assert(Armor.Apply(c,"LeatherArmor",template))
local model=c:FindFirstChild("EquippedArmor");assert(model and held.Parent==c)
local count=0
for _,p in ipairs(model:GetDescendants()) do if p:IsA("Part") then
 count+=1
 local j=p:FindFirstChild("ArmorWeld");assert(j and j.Part1==p and j.Part0.Name==p.Parent.Name)
 assert(not p.Anchored and p.Massless and not p.CanCollide and not p.CanQuery and not p.CanTouch)
 near(p.CFrame.Position,j.Part0.Position)
 near(p.CFrame.UpVector,j.Part0.CFrame.UpVector)
 near(p.CFrame.LookVector,j.Part0.CFrame.LookVector)
end end
assert(count==5,"jacket and all sleeve sections mount separately")
assert(Armor.Apply(c,"LeatherArmor",template) and c:FindFirstChild("EquippedArmor")==model,"inventory updates do not rebuild armor")
Armor.Apply(c,nil);assert(not c:FindFirstChild("EquippedArmor") and held.Parent==c)
local anchored=Instance.new("Model");anchored.CFrame=CFrame.identity
local group=Instance.new("Folder",anchored);group.Name="UpperTorso"
local marker=Instance.new("Part",group);marker.Name="Anchor";marker.CFrame=originals.UpperTorso.CFrame
local plate=Instance.new("Part",group);plate.Name="Front";plate.Size=Vector3.new(.4,.5,.08);plate.CFrame=marker.CFrame*CFrame.new(0,0,-.2)
assert(Armor.Apply(c,"LeatherArmor",anchored))
local fitted=c:FindFirstChild("EquippedArmor"):FindFirstChild("UpperTorso"):FindFirstChild("Front")
near(c:FindFirstChild("UpperTorso").CFrame:ToObjectSpace(fitted.CFrame).Position,Vector3.new(0,0,-.2))
assert(#c:FindFirstChild("EquippedArmor"):GetDescendants()==3,"Anchor is not worn/copied")
local item=Items.Items.LeatherArmor;local recipe=Recipes.MakeLeatherArmor
assert(item.Slot=="Body" and item.Weight==2 and item.Armor.Absorption==2 and item.Armor.Resistance==.1)
assert(Defense.Resolve(20,item.Armor.Resistance,item.Armor.Absorption)==16)
assert(recipe.Station=="Workstation" and recipe.Duration==60 and recipe.Requirements.Skills.Repair==100 and recipe.RequiresPresence)
assert(recipe.Ingredients.Cloth==6 and recipe.Ingredients.SewingKit==nil and recipe.Tool=="SewingKit")
assert(Craft.Speed({},recipe)==nil and Craft.Speed({SewingKit=1},recipe)==1)
assert(not Craft.Plan({Cloth=5},recipe,1))
local plan=assert(Craft.Plan({Cloth=6,SewingKit=1},recipe,1))
assert(plan.Ingredients.Cloth==6 and plan.Ingredients.SewingKit==nil and plan.Outputs.LeatherArmor==1)
local improved=Items.Items.LeatherArmor2;local upgrade=Recipes.MakeLeatherArmor2
assert(improved.Slot=="Body" and improved.Weight==3 and improved.Armor.Absorption==4 and improved.Armor.Resistance==.15)
assert(Defense.Resolve(20,improved.Armor.Resistance,improved.Armor.Absorption)==13)
assert(upgrade.Station=="Workstation" and upgrade.Duration==60 and upgrade.Requirements.Skills.Repair==140 and upgrade.Tool=="SewingKit")
assert(not Craft.Plan({LeatherArmor=1,Scrap=4},upgrade,1) and not Craft.Plan({Scrap=5},upgrade,1))
local upgraded=assert(Craft.Plan({LeatherArmor=1,Scrap=5,SewingKit=1},upgrade,1))
assert(upgraded.Ingredients.LeatherArmor==1 and upgraded.Ingredients.Scrap==5 and upgraded.Ingredients.SewingKit==nil and upgraded.Outputs.LeatherArmor2==1)
local previous=c:FindFirstChild("EquippedArmor")
assert(Armor.Apply(c,"LeatherArmor2",anchored) and c:FindFirstChild("EquippedArmor")~=previous,"upgrading replaces the previous armor visuals")
-- Reproduce both uploaded helmets on the supplied character, including turning
-- the whole scene and posing the head independently before equipping armor.
for _,armor in ipairs(military.Armor) do
 for _,yaw in ipairs({0,.8,-1.5}) do
  local characterFrame=CFrame.new(-580,20,14)*CFrame.Angles(0,yaw,0)
  local armorFrame=CFrame.new(-575,7,-12)*CFrame.Angles(0,-yaw,0)
  local character=Instance.new("Model")
  for _,g in ipairs(military.Character) do
   local p=Instance.new("Part",character);p.Name=g.Name;p.Size=g.Size;p.CFrame=characterFrame*g.CFrame;p.Transparency=0
  end
  local root=character:FindFirstChild("Body");root.Name="HumanoidRootPart"
  assert(Rig.Prepare(character,root,Instance.new("Humanoid",character)))
  local head=character:FindFirstChild("Head")
  head.CFrame=head.CFrame*CFrame.Angles(.25,.4,-.1)
  local template=Instance.new("Model");template.CFrame=armorFrame
  for _,g in ipairs(armor.Groups) do
   local folder=Instance.new("Folder",template);folder.Name=g.Name
   for _,part in ipairs(g.Parts) do
    local p=Instance.new("Part",folder);p.Name=part.Name;p.Size=part.Size;p.CFrame=armorFrame*part.CFrame
   end
  end
  assert(Armor.Apply(character,armor.ID,template))
  local worn=character:FindFirstChild("EquippedArmor"):FindFirstChild("Head")
  local parts={}
  for _,p in ipairs(worn:GetDescendants()) do if p:IsA("BasePart") then table.insert(parts,p) end end
  local cap=parts[1];local localCap=head.CFrame:ToObjectSpace(cap.CFrame)
  assert(math.abs(localCap.Position.Y-.0819730759)<.0001,"helmet cap retains modeled height above head center: "..armor.ID)
  assert(localCap.Position.Y+cap.Size.Y/2>head.Size.Y/2,"cap covers the top of the head")
  for i,p in ipairs(parts) do
   local weld=p:FindFirstChild("ArmorWeld");assert(weld.Part0==head)
   local source=armor.Groups[#armor.Groups].Parts
   local expected=source[1].CFrame:ToObjectSpace(source[i].CFrame)
   local actual=cap.CFrame:ToObjectSpace(p.CFrame)
   near(actual.Position,expected.Position);near(actual.UpVector,expected.UpVector)
  end
  -- An explicit Head/Anchor overrides the automatic torso reference.
  local group=template:FindFirstChild("Head")
  local anchor=Instance.new("Part",group);anchor.Name="Anchor";anchor.CFrame=armorFrame*CFrame.new(585.9874877929688,-5.799969673156738,-.3990880846977234)
  Armor.Apply(character,nil);assert(Armor.Apply(character,armor.ID,template))
  local anchored=character:FindFirstChild("EquippedArmor"):FindFirstChild("Head")
  local copies={}
  for _,p in ipairs(anchored:GetDescendants()) do if p:IsA("BasePart") then table.insert(copies,p) end end
  assert(#copies==#parts,"Head Anchor is not worn")
  local sourceCap=armor.Groups[#armor.Groups].Parts[1]
  near(head.CFrame:ToObjectSpace(copies[1].CFrame).Position,anchor.CFrame:ToObjectSpace(armorFrame*sourceCap.CFrame).Position)
 end
end
print("PASS: both actual military helmet meshes retain cap height, visor spacing and head welds under scene rotations/head poses; explicit Anchor wins")
print("PASS: actual torso/sleeve fit, section welds, no armor physics/hitboxes, caching/removal, exact Anchor offsets, Body defense/weight and cloth/kit recipe")
'''
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'armor.luau';p.write_text(s);subprocess.run([sys.argv[1],str(p)],check=True)
