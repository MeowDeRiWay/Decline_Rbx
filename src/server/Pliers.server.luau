-- A small placeholder until an authored Pliers Model is supplied in Items.
local Storage=game:GetService("ServerStorage")
local Visuals=require(script.Parent.Services.EquipmentVisuals)
if Visuals.Template("Pliers") then return end
local folder=Storage:FindFirstChild("Items")
if not folder then folder=Instance.new("Folder");folder.Name="Items";folder.Parent=Storage end
local model=Instance.new("Model");model.Name="Pliers"
for _,side in ipairs({-1,1}) do
 for _,jaw in ipairs({false,true}) do
  local part=Instance.new("Part");part.Name=jaw and "Jaw" or "Handle"
  part.Size=Vector3.new(.055,.055,jaw and .2 or .3)
  part.CFrame=CFrame.new(side*.065,0,jaw and -.17 or .08)*CFrame.Angles(0,side*(jaw and -.2 or .15),0)
  part.Color=jaw and Color3.fromRGB(150,150,155) or Color3.fromRGB(145,45,35)
  part.Material=Enum.Material.Metal;part.Anchored=true;part.CanCollide=false;part.Parent=model
  if not model.PrimaryPart then model.PrimaryPart=part end
 end
end
model.Parent=folder
