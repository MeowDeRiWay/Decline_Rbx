local ServerStorage=game:GetService("ServerStorage")
local Assembly=require(script.Parent.VehicleAssembly)
local Vehicles=require(script.Parent.VehicleService)
local Garage={}
local function building(station)
 local ancestor=station
 while ancestor and ancestor~=workspace do
  if ancestor:GetAttribute("BuildingID")=="Garage" or ancestor.Name=="Garage (T1)" then return ancestor end
  ancestor=ancestor.Parent
 end
end
local function placement(station,id)
 local garage=building(station)
 if not garage or not garage:IsDescendantOf(workspace) then return nil,"Garage is unavailable." end
 local marker=garage:FindFirstChild("CarSpawn",true)
 local surface=marker and (marker:IsA("BasePart") and marker or marker.PrimaryPart or marker:FindFirstChildWhichIsA("BasePart",true))
 if not surface then return nil,"Garage needs a CarSpawn marker." end
 local library=ServerStorage:FindFirstChild("Vehicles")
 local template=library and library:FindFirstChild(id)
 local details=library and library:FindFirstChild(id.." details")
 if not template or not details then return nil,"Vehicle template or details folder is missing." end
 local data,message=Assembly.Build(template,details)
 if not data then return nil,message end
 -- CarSpawn's authored pivot controls facing, including its correction rotation.
 local desired=marker:GetPivot()*CFrame.new(0,surface.Size.Y/2+data.GroundOffset,0)
 local frame=desired*data.Root.CFrame:ToObjectSpace(data.Model:GetPivot())
 data.Model:PivotTo(frame)
 local params=OverlapParams.new();params.FilterType=Enum.RaycastFilterType.Exclude
 params.FilterDescendantsInstances={data.Model,marker};params.RespectCanCollide=false
 local box=data.Root.CFrame*data.CollisionOffset
 local obstacles=workspace:GetPartBoundsInBox(box,data.CollisionSize+Vector3.new(.1,.1,.1),params)
 data.Model:Destroy()
 for _,part in ipairs(obstacles) do
  local blocked=part.CanCollide
  local ancestor=part.Parent
  while not blocked and ancestor and ancestor~=workspace do
   blocked=ancestor:GetAttribute("Vehicle")==true or ancestor:FindFirstChildOfClass("Humanoid")~=nil
   ancestor=ancestor.Parent
  end
  if blocked then return nil,"Clear the garage vehicle bay first." end
 end
 return {Frame=frame,Garage=garage,Marker=marker}
end
function Garage.CanCraft(station,id)
 local data,message=placement(station,id)
 return data~=nil,message
end
function Garage.Craft(station,id,player)
 local data,message=placement(station,id)
 if not data then return nil,message end
 local model,errorText=Vehicles.Spawn(id,data.Frame)
 if not model then return nil,errorText end
 model:SetAttribute("OwnerID",player.UserId)
 model:SetAttribute("TownID",data.Garage:GetAttribute("TownID"))
 model:SetAttribute("TeamID",data.Garage:GetAttribute("TeamID"))
 return model
end
function Garage.Start()
 if Garage.Started then return end
 Garage.Started=true
 local function prepare(object)
  local marker=object
  while marker and marker~=workspace and marker.Name~="CarSpawn" do marker=marker.Parent end
  if not marker or marker==workspace or not building(marker) then return end
  local parts=marker:GetDescendants()
  if marker:IsA("BasePart") then table.insert(parts,marker) end
  for _,part in ipairs(parts) do
   if part:IsA("BasePart") then part.Transparency=1;part.CanCollide=false;part.CanTouch=false;part.CanQuery=false end
  end
 end
 for _,object in ipairs(workspace:GetDescendants()) do prepare(object) end
 workspace.DescendantAdded:Connect(function(object) task.defer(function() prepare(object) end) end)
end
return Garage
