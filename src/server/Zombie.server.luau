local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
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
   part.Anchored=true
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
 -- Move the authored model on the server; no R6/R15 rig is required.
 humanoid.AutoRotate=false
 model:SetAttribute("AIState","Idle")
 model:SetAttribute("TargetName","")
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
 local nearest
 local elapsed=0
 local movement
 movement=RunService.Heartbeat:Connect(function(dt)
  if not model:IsDescendantOf(workspace) or dead then movement:Disconnect(); return end
  elapsed+=dt
  if elapsed>=.1 then
   elapsed%=.1
   nearest=nil
   local range=model:GetAttribute("SightRange")
   local forward=root.CFrame.LookVector
   local reason="No player"
   for _,player in ipairs(Players:GetPlayers()) do
    local character=player.Character
    local target=character and character:FindFirstChild("HumanoidRootPart")
    local hp=character and character:FindFirstChildOfClass("Humanoid")
    if target and hp and hp.Health>0 and not character:GetAttribute("Knockout") then
     local delta=target.Position-root.Position
     if delta.Magnitude>=range then reason="Out of range"
     elseif not Sector.InSector(forward.X,forward.Z,delta.X,delta.Z,model:GetAttribute("ViewAngle")) then reason="Outside view"
     else
      local targetHead=character:FindFirstChild("Head")
      local seen=false
      for _,point in ipairs({targetHead and targetHead.Position or target.Position,target.Position}) do
       local hit=Sight.Cast(head.Position+Vector3.new(0,.05,0),point-head.Position-Vector3.new(0,.05,0),model)
       if not hit or hit.Instance:IsDescendantOf(character) then seen=true; break end
      end
      if seen then nearest,range=target,delta.Magnitude else reason="Sight blocked" end
     end
    end
   end
   model:SetAttribute("DetectionReason",nearest and "Visible target" or reason)
   model:SetAttribute("TargetName",nearest and nearest.Parent.Name or "")
   model:SetAttribute("AIState",nearest and "Chasing" or "Idle")
  end
  if not nearest or not nearest.Parent then return end
  local delta=nearest.Position-root.Position
  delta=Vector3.new(delta.X,0,delta.Z)
  local stoppingDistance=(root.Size.Z+nearest.Size.Z)/2+.15
  if delta.Magnitude<=stoppingDistance then return end
  local direction=delta.Unit
  local distance=math.min(humanoid.WalkSpeed*math.min(dt,.1),delta.Magnitude-stoppingDistance)
  if distance<=0 then return end
  local params=RaycastParams.new()
  params.FilterType=Enum.RaycastFilterType.Exclude
  params.FilterDescendantsInstances={model,nearest.Parent}
  params.RespectCanCollide=true
  local movementVector=direction*distance
  local obstruction=workspace:Blockcast(root.CFrame,root.Size*.9,movementVector,params)
  if obstruction then
   distance=math.max(0,obstruction.Distance-.02)
   model:SetAttribute("AIState","Blocked")
  end
  local position=root.Position+direction*distance
  local stepHeight=math.max(root.Size.Y,.2)
  local ground=workspace:Raycast(position+Vector3.new(0,stepHeight,0),Vector3.new(0,-stepHeight-root.Size.Y/2-2,0),params)
  if not ground then model:SetAttribute("AIState","Blocked"); return end
  position=Vector3.new(position.X,ground.Position.Y+root.Size.Y/2,position.Z)
  local desiredRoot=CFrame.lookAt(position,position+direction)
  model:PivotTo(desiredRoot*root.CFrame:Inverse()*model:GetPivot())
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
