local Shared=game:GetService("ReplicatedStorage").Shared
local Rules=require(Shared.VehicleRules)
local Assembly={}
local function parts(model)
 local result={}
 for _,part in ipairs(model:GetDescendants()) do if part:IsA("BasePart") then table.insert(result,part) end end
 return result
end
local function hide(part)
 part.Transparency=1;part.CanCollide=false;part.CanTouch=false;part.CanQuery=false;part.CastShadow=false
end
local function weld(first,second)
 local joint=Instance.new("WeldConstraint")
 joint.Name="VehicleWeld";joint.Part0=first;joint.Part1=second;joint.Parent=second
end
local function kindOf(name)
 return name:match("^Door") and "Door" or name
end
local function setupHealth(model,kind)
 local maximum=Rules.MaxHealth(model)
 model:SetAttribute("HP",maximum)
 if kind=="Battery" then
  local capacity=Rules.Number(model:GetAttribute("MaxCharge"),14,.001,10000)
  model:SetAttribute("MaxCharge",capacity);model:SetAttribute("Charge",capacity)
 elseif kind=="FuelTank" then
  local capacity=Rules.Number(model:GetAttribute("FuelCapacity"),72,.001,1000000)
  model:SetAttribute("FuelCapacity",capacity);model:SetAttribute("Fuel",capacity);model:SetAttribute("Burning",false)
 end
end
function Assembly.Build(template,library)
 local vehicle=template:Clone()
 local body=vehicle:FindFirstChild("Body")
 local root=body and body:FindFirstChild("Chassis",true)
 if not body or not root or not root:IsA("BasePart") then vehicle:Destroy();return nil,"Vehicle needs Body/Chassis." end
 local markers={}
 for _,object in ipairs(vehicle:GetDescendants()) do
  if object:IsA("BasePart") and typeof(object:GetAttribute("Detail"))=="string" then table.insert(markers,object) end
 end
 -- Validate everything before producing a partially assembled live vehicle.
 for _,marker in ipairs(markers) do
  local source=library:FindFirstChild(marker:GetAttribute("Detail"))
  local mount=source and source:FindFirstChild("Mount",true)
  if not source or not source:IsA("Model") or not mount or not mount:IsA("BasePart") then
   local message="Missing component model/Mount: "..marker:GetAttribute("Detail")
   vehicle:Destroy();return nil,message
  end
 end
 for _,object in ipairs(vehicle:GetDescendants()) do
  if object:IsA("JointInstance") or object:IsA("WeldConstraint") or object:IsA("LuaSourceContainer") then object:Destroy() end
 end
 vehicle.PrimaryPart=root
 vehicle:SetAttribute("Vehicle",true);vehicle:SetAttribute("VehicleTemplate",template.Name)
 vehicle:SetAttribute("DisplayName",template:GetAttribute("DisplayName") or (template.Name=="Car_1" and "Interceptor" or template.Name))
 vehicle:SetAttribute("EngineOn",false);vehicle:SetAttribute("EngineStarting",false)
 vehicle:SetAttribute("Speed",0);vehicle:SetAttribute("Steering",0);vehicle:SetAttribute("LightsOn",false)
 body:SetAttribute("VehicleComponent","Body");setupHealth(body,"Body")
 for _,part in ipairs(parts(body)) do
  part.Anchored=part==root;part.Massless=part~=root
  if part.Transparency<.95 then part.CanQuery=true end
  if part~=root then weld(root,part) end
 end
 root.RootPriority=127;root.Anchored=true
 local folder=Instance.new("Folder");folder.Name="Components";folder.Parent=vehicle
 local records={};local counts={}
 local bottom=math.huge
 local front,rear
 for _,marker in ipairs(markers) do
  local detail=marker:GetAttribute("Detail")
  local kind=kindOf(detail)
  counts[detail]=(counts[detail] or 0)+1
  local model=library:FindFirstChild(detail):Clone()
  model.Name=detail.."_"..counts[detail]
  local mount=model:FindFirstChild("Mount",true)
  -- CFrame is the physical correction frame. PivotOffset must not be applied twice.
  local delta=marker.CFrame*mount.CFrame:Inverse()
  model:PivotTo(delta*model:GetPivot())
  for _,object in ipairs(model:GetDescendants()) do
   if object:IsA("JointInstance") or object:IsA("WeldConstraint") or object:IsA("LuaSourceContainer") then object:Destroy() end
  end
  model.PrimaryPart=mount;model:SetAttribute("VehicleComponent",kind)
  model:SetAttribute("Detail",detail);setupHealth(model,kind)
  model:SetAttribute("Steerable",kind=="Wheel" and marker:GetAttribute("Steerable")==true)
  model:SetAttribute("Open",false)
  local partList=parts(model)
  if kind=="Wheel" and root.CFrame:PointToObjectSpace(marker.Position).X<0 then
   -- Keep Mount aligned to Detail; turn the geometry so the outer face points left.
   local flip=CFrame.new(mount.Position)*CFrame.fromAxisAngle(root.CFrame.UpVector,math.pi)*CFrame.new(-mount.Position)
   for _,part in ipairs(partList) do if part~=mount then part.CFrame=flip*part.CFrame end end
   model:SetAttribute("WheelFlipped",true)
  end
  local seat
  local minY,maxY=math.huge,-math.huge
  for _,part in ipairs(partList) do
   part.Anchored=false;part.Massless=true;part.CanTouch=false
   part.CanCollide=(kind=="Door" or kind=="Hood" or kind=="Trunk") and part.Transparency<.95
   part.CanQuery=part.Transparency<.95
   if part:GetAttribute("HandTarget") then part:SetAttribute("VehicleMountOffset",mount.CFrame:ToObjectSpace(part.CFrame)) end
   if part==mount or part:GetAttribute("HandTarget") or part.Name=="SmokeOrigin" then hide(part)
   else
    local half=math.abs(part.CFrame.RightVector.Y)*part.Size.X/2+math.abs(part.CFrame.UpVector.Y)*part.Size.Y/2+math.abs(part.CFrame.LookVector.Y)*part.Size.Z/2
    minY=math.min(minY,part.Position.Y-half);maxY=math.max(maxY,part.Position.Y+half)
   end
   if part~=mount then weld(mount,part) end
   if part:IsA("Seat") or part:IsA("VehicleSeat") then
    seat=part;seat.Disabled=false;seat.CanCollide=false;seat.CanTouch=false
    if seat:IsA("VehicleSeat") then seat.MaxSpeed=0;seat.Torque=0;seat.TurnSpeed=0;seat.HeadsUpDisplay=false end
   end
  end
  hide(mount)
  local joint=Instance.new("Motor6D")
  joint.Name="VehicleJoint";joint.Part0=root;joint.Part1=mount
  joint.C0=root.CFrame:ToObjectSpace(marker.CFrame);joint.C1=CFrame.identity
  joint:SetAttribute("VehicleRestC0",joint.C0);joint.Parent=mount
  local record={Model=model,Kind=kind,Mount=mount,Joint=joint,Rest=joint.C0,Seat=seat,Parts=partList,Angle=0}
  if kind=="Wheel" then
   record.Radius=math.max(.05,(maxY-minY)/2)
   model:SetAttribute("WheelRadius",record.Radius)
   bottom=math.min(bottom,minY)
   local z=joint.C0.Position.Z
   if model:GetAttribute("Steerable") then front=front and math.min(front,z) or z
   else rear=rear and math.max(rear,z) or z end
  end
  model.Parent=folder;table.insert(records,record)
  marker:Destroy()
 end
 local bodyFrame,bodySize=body:GetBoundingBox()
 if bottom==math.huge then bottom=bodyFrame.Position.Y-bodySize.Y/2 end
 local data={Model=vehicle,Root=root,Body=body,Components=records,Folder=folder,
  GroundOffset=root.Position.Y-bottom,CollisionOffset=root.CFrame:ToObjectSpace(bodyFrame),
  CollisionSize=Vector3.new(math.max(.1,bodySize.X-.08),math.max(.1,bodySize.Y-.1),math.max(.1,bodySize.Z-.08)),
  Wheelbase=front and rear and math.max(.5,rear-front) or 3}
 for _,record in ipairs(records) do
  if record.Seat then
   local best,distance
   for _,door in ipairs(records) do
    if door.Kind=="Door" then
     local d=(door.Mount.Position-record.Seat.Position).Magnitude
     if not distance or d<distance then best=door;distance=d end
    end
   end
   record.Door=best
   if best then
    local link=Instance.new("ObjectValue");link.Name="EntryDoor";link.Value=best.Model;link.Parent=record.Model
   end
  end
 end
 return data
end
return Assembly
