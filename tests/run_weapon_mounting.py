"""Verify rifle clearance, backpack markers and equipment-change remounting."""
from pathlib import Path
import subprocess
import sys
import tempfile

root = Path(__file__).resolve().parents[1]
def module(path):
    text = (root / path).read_text()
    text = text.replace("local IK=require(script.Parent.CharacterPose)", "local IK={}")
    text = text.replace('local Pose=require(game:GetService("ReplicatedStorage").Shared.HandActionPose)', "")
    return "(function()\n" + text + "\nend)()"

helpers = (root / "tests/run_character_rig.py").read_text().split("source+=r'''")[1].split("local function test(frame)")[0]
source = (root / "tests/rig_math.fixture.luau").read_text() + helpers
source += "\nlocal Pose=" + module("src/shared/HandActionPose.luau")
source += "\nlocal Holsters=" + module("src/server/Services/HolsterVisuals.luau")
source += "\nlocal Armor=" + module("src/server/Services/ArmorVisuals.luau")
source += "\nlocal measured=" + module("tests/measured_weapon_mount.fixture.luau")
source += r'''
local find=methods.FindFirstChild
function methods:FindFirstChild(name,recurse)
 if not recurse then return find(self,name) end
 for _,child in ipairs(self:GetDescendants()) do if child.Name==name then return child end end
end
function methods:FindFirstChildWhichIsA(kind,recurse)
 for _,child in ipairs(self:GetDescendants()) do if child:IsA(kind) then return child end end
end
function methods:GetPivot() return self.PrimaryPart and self.PrimaryPart.CFrame or self.CFrame or CFrame.identity end
function methods:Clone()
 local copy=Instance.new(self.ClassName)
 copy.Name=self.Name;copy.CFrame=self.CFrame;copy.Size=self.Size
 copy.Transparency=self.Transparency
 copy.Attributes=table.clone(self.Attributes)
 return copy
end
local function part(parent,name,frame,size)
 local p=Instance.new("Part",parent);p.Name=name;p.CFrame=frame;p.Size=size;return p
end
local function extents(model,reference)
 local low=Vector3.new(math.huge,math.huge,math.huge)
 local high=-low
 for _,p in ipairs(model:GetDescendants()) do
  if p:IsA("BasePart") and (p.Transparency or 0)<.95 then
   for _,x in ipairs({-1,1}) do for _,y in ipairs({-1,1}) do for _,z in ipairs({-1,1}) do
    local point=reference:PointToObjectSpace(p.CFrame:PointToWorldSpace(Vector3.new(x*p.Size.X/2,y*p.Size.Y/2,z*p.Size.Z/2)))
    low=Vector3.new(math.min(low.X,point.X),math.min(low.Y,point.Y),math.min(low.Z,point.Z))
    high=Vector3.new(math.max(high.X,point.X),math.max(high.Y,point.Y),math.max(high.Z,point.Z))
   end end end
  end
 end
 return low,high
end
for _,rotation in ipairs({CFrame.identity,CFrame.Angles(.2,1.3,-.1)}) do
 objects={}
 local c=Instance.new("Model")
 local frame=CFrame.new(10,5,-7)*rotation
 local root=part(c,"HumanoidRootPart",frame,Vector3.new(.4,.7,.315))
 local torso=part(c,"UpperTorso",frame,Vector3.new(.4,.4,.315))
 local weapon=Instance.new("Model");weapon.CFrame=CFrame.new(8,1,5)*CFrame.Angles(.3,.7,0)
 part(weapon,"Receiver",weapon.CFrame*CFrame.new(.05,0,0),Vector3.new(.11,.12,.8))
 part(weapon,"Magazine",weapon.CFrame*CFrame.new(.05,-.15,.1),Vector3.new(.09,.2,.14))
 local function template() return weapon end
 assert(Holsters.Apply(c,"PrimaryWeapon","Rifle",template))
 local worn=c:FindFirstChild("HolsteredPrimaryWeapon")
 local mount=frame:ToObjectSpace(Pose.StorageFrame(c,root,"PrimaryWeapon",weapon))
 assert(math.abs(mount.Position.Y+torso.Size.Y*.45)<.0001,"rifle sits lower along the back")
 assert(mount:VectorToWorldSpace(Vector3.new(0,-1,0)).X>.95,"magazine faces the character's right")
 local low=extents(worn,frame)
 assert(math.abs(low.Z-(torso.Size.Z/2+.003))<.0001,"rifle rests against the bare back with only a small clearance")
 near(Pose.StorageFrame(c,root,"PrimaryWeapon").Position,(frame*worn:GetAttribute("StorageOffset")).Position)
 assert(Holsters.Apply(c,"PrimaryWeapon","Rifle",template) and c:FindFirstChild("HolsteredPrimaryWeapon")==worn,"unchanged mounts stay cached")
 local backpack=Instance.new("Model",c);backpack.Name="EquippedBack"
 part(backpack,"Bag",frame*CFrame.new(0,0,.4)*CFrame.Angles(0,.2,0),Vector3.new(.55,.65,.3))
 local _,packHigh=extents(backpack,frame)
 assert(Holsters.Apply(c,"PrimaryWeapon","Rifle",template))
 local side=c:FindFirstChild("HolsteredPrimaryWeapon")
 low=extents(side,frame)
 assert(side~=worn and math.abs(low.X-packHigh.X-.003)<.0001,"wearing a backpack remounts the same rifle at its right side")
 local packMount=frame:ToObjectSpace(Pose.StorageFrame(c,root,"PrimaryWeapon",weapon))
 assert(packMount:VectorToWorldSpace(Vector3.new(0,-1,0)).Z>.999,"backpack magazine points aft away from the character")
 assert(math.abs(packMount:VectorToWorldSpace(Vector3.xAxis).X)>.999,"rifle broad side lies flat against the backpack side")
 near(Pose.StorageFrame(c,root,"PrimaryWeapon").Position,(frame*side:GetAttribute("StorageOffset")).Position)
 backpack:Destroy()
 assert(Holsters.Apply(c,"PrimaryWeapon","Rifle",template))
 low=extents(c:FindFirstChild("HolsteredPrimaryWeapon"),frame)
 assert(math.abs(low.Z-(torso.Size.Z/2+.003))<.0001,"removing a backpack brings the rifle back against the torso")
 local jacket=Instance.new("Model",c);jacket.Name="EquippedArmor"
 local jacketTorso=Instance.new("Model",jacket);jacketTorso.Name="UpperTorso"
 part(jacketTorso,"JacketBack",frame*CFrame.new(0,0,.19),Vector3.new(.45,.45,.08))
 assert(Holsters.Apply(c,"PrimaryWeapon","Rifle",template))
 low=extents(c:FindFirstChild("HolsteredPrimaryWeapon"),frame)
 assert(math.abs(low.Z-.233)<.0001,"rifle clears the actual jacket surface")
 local armorTemplate=Instance.new("Model");armorTemplate.CFrame=CFrame.identity
 local upper=Instance.new("Model",armorTemplate);upper.Name="UpperTorso";upper.CFrame=CFrame.identity
 part(upper,"Chest",CFrame.new(0,0,-.2),Vector3.new(.5,.5,.08))
 local marker=Instance.new("Model",upper);marker:SetAttribute("Backpack",true)
 part(marker,"NestedBag",CFrame.new(0,0,.4),Vector3.new(.6,.7,.3))
 local loose=Instance.new("Model",armorTemplate);loose:SetAttribute("Backpack",true)
 part(loose,"OuterPocket",CFrame.new(.36,0,.4),Vector3.new(.12,.3,.2))
 assert(Armor.Apply(c,"MiliArmor1",armorTemplate))
 local armor=c:FindFirstChild("EquippedArmor")
 local marked=0
 for _,p in ipairs(armor:GetDescendants()) do
  if p:IsA("BasePart") and p:GetAttribute("Backpack")==true then marked+=1 end
 end
 assert(marked==2,"nested and armor-root Backpack models retain their marker on the fitted geometry")
 assert(Holsters.Apply(c,"PrimaryWeapon","Rifle",template))
 low=extents(c:FindFirstChild("HolsteredPrimaryWeapon"),frame)
 local pocket=armor:FindFirstChild("OuterPocket",true)
 local pocketRight=frame:PointToObjectSpace(pocket.Position).X+pocket.Size.X/2
 assert(math.abs(low.X-pocketRight-.003)<.0001,"integrated armor backpack sets rifle clearance")
 local pistol=Pose.StorageFrame(c,root,"SecondaryWeapon")
 local expected=root.CFrame*CFrame.new(root.Size.X/2+.13,-root.Size.Y*.5,.02)*CFrame.Angles(math.rad(-90),0,0)
 near(pistol.Position,expected.Position)
end
for name,parts in pairs(measured.Weapons) do
 objects={}
 local c=Instance.new("Model")
 local root=part(c,"HumanoidRootPart",CFrame.identity,measured.BodySize)
 local torso=part(c,"UpperTorso",CFrame.identity,measured.UpperTorsoSize)
 local template=Instance.new("Model");template.CFrame=CFrame.identity
 for _,entry in ipairs(parts) do
  local p=part(template,entry.Name,entry.Frame,entry.Size)
  p.Transparency=entry.Transparency
 end
 local marker=part(template,"InvisibleMount",CFrame.new(0,0,-2),Vector3.new(3,3,3))
 marker.Transparency=1
 assert(Holsters.Apply(c,"PrimaryWeapon",name,function() return template end))
 local rifle=c:FindFirstChild("HolsteredPrimaryWeapon")
 local low=extents(rifle,CFrame.identity)
 assert(math.abs(low.Z-torso.Size.Z/2-.003)<.0001,"measured weapon touches back without invisible markers affecting fit: "..name)
 local mount=rifle:GetAttribute("StorageOffset")
 assert(math.abs(mount.LookVector.Z)<.0001,"barrel stays parallel to the plane of the back")
 if name=="Rifle223" then
  local receiver=rifle:FindFirstChild("Receiver")
  local group=Instance.new("Model")
  local copy=part(group,"Receiver",receiver.CFrame,receiver.Size)
  local receiverLow=extents(group,CFrame.identity)
  assert(receiverLow.Z-torso.Size.Z/2<.012,"actual Rifle223 receiver hugs the back rather than floating behind the stock")
 end
 for armorName,shell in pairs(measured.Armor) do
  local armor=Instance.new("Model",c);armor.Name="EquippedArmor"
  local upper=Instance.new("Model",armor);upper.Name="UpperTorso"
  local backpack=Instance.new("Model")
  for _,entry in ipairs(shell) do
   local piece=part(upper,"Armor",entry.Frame,entry.Size);piece.Transparency=entry.Transparency
   if entry.Backpack then
    piece:SetAttribute("Backpack",true)
    local copy=part(backpack,"Bag",entry.Frame,entry.Size);copy.Transparency=entry.Transparency
   end
  end
  assert(Holsters.Apply(c,"PrimaryWeapon",name,function() return template end))
  local low=extents(c:FindFirstChild("HolsteredPrimaryWeapon"),CFrame.identity)
  if #backpack:GetDescendants()>0 then
   local _,high=extents(backpack,CFrame.identity)
   assert(math.abs(low.X-high.X-.003)<.0001,"measured armor backpack clearance: "..armorName.." / "..name)
   local packMount=Pose.StorageFrame(c,root,"PrimaryWeapon",template)
   assert(packMount:VectorToWorldSpace(Vector3.new(0,-1,0)).Z>.999,"integrated backpack magazine points away from the character")
   assert(math.abs(packMount:VectorToWorldSpace(Vector3.xAxis).X)>.999,"integrated backpack weapon lies broadside against the bag")
  else
   local _,high=extents(armor,CFrame.identity)
   assert(math.abs(low.Z-math.max(torso.Size.Z/2,high.Z)-.003)<.0001,"measured jacket back clearance: "..armorName.." / "..name)
  end
  armor:Destroy();backpack:Destroy()
 end
end
print("PASS: nine supplied weapons against the actual body and four supplied armor shells, invisible marker exclusion, back/pack clearance, rotated rigs, remounting and draw targets")
'''
with tempfile.TemporaryDirectory() as directory:
    path = Path(directory) / "weapon_mounting.luau"
    path.write_text(source)
    subprocess.run([sys.argv[1] if len(sys.argv) > 1 else "luau", str(path)], check=True)
