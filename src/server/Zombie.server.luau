local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Sight = require(ReplicatedStorage.Shared.Sight)
local Sector = require(ReplicatedStorage.Shared.VisibilityRules)
local Chests = require(script.Parent.Services.ChestService)
local registered = setmetatable({},{__mode="k"})
local function positive(value)
 return typeof(value)=="number" and value==value and value>0 and value<math.huge
end
local function prepare(model)
 if not model:IsA("Model") or registered[model] then return end
 if model.Name~="Zombie" and model:GetAttribute("CreatureType")~="Zombie" then return end
 local root = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Body")
 local head = model:FindFirstChild("Head")
 if not root or not root:IsA("BasePart") or not head or not head:IsA("BasePart") then return end
 registered[model]=true
 local humanoid=model:FindFirstChildOfClass("Humanoid") or Instance.new("Humanoid")
 humanoid.RequiresNeck=false
 humanoid.BreakJointsOnDeath=false
 humanoid.HipHeight=0
 humanoid.AutoRotate=true
 humanoid.AutoJumpEnabled=false
 humanoid.JumpPower=0
 humanoid.JumpHeight=0
 humanoid.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None
 local maximum=model:GetAttribute("MaxHealth")
 if not positive(maximum) then maximum=humanoid.MaxHealth~=100 and humanoid.MaxHealth or 20 end
 humanoid.MaxHealth=maximum
 humanoid.Health=maximum
 local speed=model:GetAttribute("MoveSpeed")
 humanoid.WalkSpeed=positive(speed) and speed or (humanoid.WalkSpeed>0 and humanoid.WalkSpeed~=16 and humanoid.WalkSpeed or 3)
 humanoid.Parent=model
 root.Name="HumanoidRootPart"
 model.PrimaryPart=root
 model:SetAttribute("CreatureType","Zombie")
 if model:GetAttribute("DisplayName")==nil then model:SetAttribute("DisplayName","Zombie") end
 if model:GetAttribute("BlocksVision")==nil then model:SetAttribute("BlocksVision",true) end
 if not positive(model:GetAttribute("SightRange")) then model:SetAttribute("SightRange",20) end
 if not positive(model:GetAttribute("ViewAngle")) then model:SetAttribute("ViewAngle",160) end
 for _,part in ipairs(model:GetDescendants()) do
  if part:IsA("BasePart") then
   part.Anchored=false
   part.CanQuery=true
   part.CanCollide=part==root
   if part~=root then
    part.Massless=true
    local weld=Instance.new("WeldConstraint")
    weld.Name="ZombieBodyWeld"
    weld.Part0,weld.Part1,weld.Parent=root,part,root
   end
  end
 end
 root:SetNetworkOwner(nil)
 local dead=false
 local function sync()
  model:SetAttribute("Health",humanoid.Health)
  model:SetAttribute("MaxHealth",humanoid.MaxHealth)
 end
 humanoid.HealthChanged:Connect(sync)
 humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(sync)
 local function die()
  if dead then return end
  dead=true
  model:SetAttribute("IsDead",true)
  model:SetAttribute("Knockout",false)
  model:SetAttribute("BlocksVision",false)
  for _,part in ipairs(model:GetDescendants()) do
   if part:IsA("BasePart") then part.Anchored=true; part.CanCollide=false end
  end
  local direction=model:GetAttribute("LastHitDirection") or root.CFrame.LookVector
  local start=model:GetPivot()
  local destination=CFrame.lookAt(start.Position,start.Position+direction)*CFrame.Angles(-math.pi/2,0,0)
  model:PivotTo(destination)
  local box,size=model:GetBoundingBox()
  local radius=math.abs(box.RightVector.Y)*size.X/2+math.abs(box.UpVector.Y)*size.Y/2+math.abs(box.LookVector.Y)*size.Z/2
  local params=RaycastParams.new()
  params.FilterType=Enum.RaycastFilterType.Exclude
  params.FilterDescendantsInstances={model}
  local floor=workspace:Raycast(start.Position+Vector3.new(0,2,0),Vector3.new(0,-100,0),params)
  if floor then destination += Vector3.new(0,floor.Position.Y-(box.Position.Y-radius)+.02,0) end
  model:PivotTo(start)
  local value=Instance.new("CFrameValue")
  value.Value=start
  local connection=value.Changed:Connect(function(cf) if model.Parent then model:PivotTo(cf) end end)
  local tween=TweenService:Create(value,TweenInfo.new(.35,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Value=destination})
  tween.Completed:Once(function() connection:Disconnect(); value:Destroy() end)
  tween:Play()
  Chests.CreateCorpse(model,{Potato=math.random(0,10)})
 end
 humanoid.Died:Connect(die)
 sync()
 task.spawn(function()
  while model:IsDescendantOf(workspace) and not dead do
   local nearest,range=nil,model:GetAttribute("SightRange")
   local forward=root.CFrame.LookVector
   for _,player in ipairs(Players:GetPlayers()) do
    local character=player.Character
    local target=character and character:FindFirstChild("HumanoidRootPart")
    local hp=character and character:FindFirstChildOfClass("Humanoid")
    if target and hp and hp.Health>0 and not character:GetAttribute("Knockout") then
     local delta=target.Position-root.Position
     if delta.Magnitude<range and Sector.InSector(forward.X,forward.Z,delta.X,delta.Z,model:GetAttribute("ViewAngle")) then
      local hit=Sight.Cast(head.Position,target.Position-head.Position,model)
      if not hit or hit.Instance:IsDescendantOf(character) then nearest,range=target,delta.Magnitude end
     end
    end
   end
   humanoid:MoveTo(nearest and nearest.Position or root.Position)
   task.wait(.2)
  end
 end)
end
local function consider(object)
 if object:IsA("Model") then prepare(object) end
 local ancestor=object.Parent
 while ancestor and ancestor~=workspace do
  if ancestor:IsA("Model") then prepare(ancestor) end
  ancestor=ancestor.Parent
 end
end
for _,object in ipairs(workspace:GetDescendants()) do consider(object) end
workspace.DescendantAdded:Connect(function(object) task.defer(consider,object) end)
