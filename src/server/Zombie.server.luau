local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Sight = require(ReplicatedStorage.Shared.Sight)
local IdleRules = require(ReplicatedStorage.Shared.ZombieIdleRules)
local Sector = require(ReplicatedStorage.Shared.VisibilityRules)
local Items = require(ReplicatedStorage.Shared.ItemConfig).Items
local Motion = require(ReplicatedStorage.Shared.WeaponMotion)
local Visuals = require(script.Parent.Services.EquipmentVisuals)
local Damage = require(script.Parent.Services.DamageService)
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
 local weapon = Items.ZombieHand.Weapon
 model:SetAttribute("WeaponCondition",weapon.MaxUses)
 Visuals.Apply(model,"ZombieHand")
 local ready = 0
 local dead=false
 local function sync()
  model:SetAttribute("Health",humanoid.Health)
  model:SetAttribute("MaxHealth",humanoid.MaxHealth)
 end
 local function die()
  if dead then return end
  dead=true
  local held = model:FindFirstChild("HeldItem")
  local motor = held and held:FindFirstChild("WeaponGrip")
  if motor then Motion.Cancel(motor) end
  model:SetAttribute("AIState","Dead")
  model:SetAttribute("TargetName","")
  model:SetAttribute("IsDead",true)
  model:SetAttribute("Knockout",false)
  model:SetAttribute("BlocksVision",false)
  for _,part in ipairs(model:GetDescendants()) do
   if part:IsA("BasePart") then part.Anchored=true; part.CanCollide=false end
  end
  -- Loot and terminal state are set before the fall animation. Rig state events
  -- and animation failures must not prevent looting or leave the AI running.
  Chests.CreateCorpse(model,{Potato=math.random(0,10)})
  local direction=model:GetAttribute("LastHitDirection")
  if typeof(direction)~="Vector3" then direction=root.CFrame.LookVector end
  direction=Vector3.new(direction.X,0,direction.Z)
  direction=direction.Magnitude>.001 and direction.Unit or Vector3.new(0,0,-1)
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
 end
 humanoid.HealthChanged:Connect(function()
  sync()
  if humanoid.Health<=0 then die() end
 end)
 humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(sync)
 humanoid.Died:Connect(die)
 sync()
 local function moveToward(destination,speed,dt,stoppingDistance,ignored)
  local delta=destination-root.Position
  delta=Vector3.new(delta.X,0,delta.Z)
  if delta.Magnitude<=stoppingDistance then return true end
  local direction=delta.Unit
  local distance=math.min(speed*math.min(dt,.1),delta.Magnitude-stoppingDistance)
  if distance<=0 then return true end
  local params=RaycastParams.new()
  params.FilterType=Enum.RaycastFilterType.Exclude
  params.FilterDescendantsInstances=ignored and {model,ignored} or {model}
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
  -- The home floor may be non-collidable. It still supports our server-driven
  -- zombie movement; otherwise the first step would drop it to the terrain below.
  local homeReference=model:FindFirstChild("ZombieHome")
  local home=homeReference and homeReference:IsA("ObjectValue") and homeReference.Value
  if home and home:IsDescendantOf(workspace) then
   local homeParams=RaycastParams.new()
   homeParams.FilterType=Enum.RaycastFilterType.Include
   homeParams.FilterDescendantsInstances={home}
   homeParams.RespectCanCollide=false
   local homeGround=workspace:Raycast(position+Vector3.new(0,stepHeight,0),Vector3.new(0,-stepHeight-root.Size.Y/2-2,0),homeParams)
   if homeGround and homeGround.Normal.Y>=.95 and (not ground or homeGround.Position.Y>ground.Position.Y) then ground=homeGround end
  end
  if not ground then model:SetAttribute("AIState","Blocked"); return true end
  position=Vector3.new(position.X,ground.Position.Y+root.Size.Y/2,position.Z)
  local turned=root.CFrame:Lerp(CFrame.lookAt(root.Position,root.Position+direction),math.clamp(dt*3,0,1))
  local desiredRoot=CFrame.new(position)*turned.Rotation
  model:PivotTo(desiredRoot*root.CFrame:Inverse()*model:GetPivot())
  return obstruction ~= nil
 end
 local idle = IdleRules.New()
 local idlePhase
 local lookStart
 local wanderTarget
 local random = Random.new()
 local function idleStep(dt)
  local phase,progress = IdleRules.Step(idle,dt)
  if phase ~= idlePhase then
   idlePhase = phase
   if phase == "Looking" then lookStart = root.CFrame end
   if phase == "Wandering" then
    local direction = CFrame.Angles(0,random:NextNumber(-math.pi,math.pi),0).LookVector
    wanderTarget = root.Position+direction*random:NextNumber(1,10)
   end
  end
  model:SetAttribute("AIState","Idle"..phase)
  if phase == "Looking" then
   -- One smooth right-left sweep, finishing in the original direction.
   local desiredRoot = lookStart*CFrame.Angles(0,math.sin(progress*2*math.pi)*math.rad(60),0)
   model:PivotTo(desiredRoot*root.CFrame:Inverse()*model:GetPivot())
  elseif phase == "Wandering" then
   if moveToward(wanderTarget,humanoid.WalkSpeed*.5,dt,.1,nil) then IdleRules.FinishWalk(idle) end
  end
 end
 local nearest
 local elapsed=0
 local movement
 movement=RunService.Heartbeat:Connect(function(dt)
  if not model:IsDescendantOf(workspace) then movement:Disconnect(); return end
  -- Custom anchored rigs may not enter Humanoid's Dead state. HP is authoritative.
  if humanoid.Health<=0 and not dead then die() end
  if dead then movement:Disconnect(); return end
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
   if nearest then model:SetAttribute("AIState","Chasing") end
  end
  if not nearest or not nearest.Parent then idleStep(dt); return end
  -- Detection interrupts all idle actions; after losing sight start a fresh rest.
  idle = IdleRules.New()
  idlePhase = nil
  local delta=nearest.Position-root.Position
  delta=Vector3.new(delta.X,0,delta.Z)
  local stoppingDistance=(root.Size.Z+nearest.Size.Z)/2+.15
  local attackDistance = root.Size.Z/2+nearest.Size.Z/2+weapon.Range
  if delta.Magnitude<=attackDistance and os.clock()>=ready and (model:GetAttribute("WeaponCondition") or 0)>0 then
   if not model:FindFirstChild("HeldItem") then Visuals.Apply(model,"ZombieHand") end
   local held=model:FindFirstChild("HeldItem")
   local motor=held and held:FindFirstChild("WeaponGrip")
   if motor then
    ready=os.clock()+60/weapon.AttacksPerMinute
    model:SetAttribute("AIState","Attacking")
    local victimRoot=nearest
    Motion.Play(motor,weapon)
    task.delay(Motion.HitDelay(weapon),function()
     if dead or humanoid.Health<=0 or not model.Parent or not victimRoot.Parent then return end
     local victim=victimRoot.Parent:FindFirstChildOfClass("Humanoid")
     if not victim or victim.Health<=0 then return end
     local offset=victimRoot.Position-root.Position
     if offset.Magnitude>attackDistance then return end
     local facing=root.CFrame.LookVector
     if not Sector.InSector(facing.X,facing.Z,offset.X,offset.Z,160) then return end
     local hit=Sight.Cast(head.Position,victimRoot.Position-head.Position,model)
     if hit and not hit.Instance:IsDescendantOf(victimRoot.Parent) then return end
     if Damage.Apply(victim,weapon.Damage,weapon.DamageType,root.Position)>0 then
      model:SetAttribute("WeaponCondition",math.max(0,(model:GetAttribute("WeaponCondition") or 0)-1))
     end
    end)
   end
  end
  if delta.Magnitude<=stoppingDistance then return end
  moveToward(nearest.Position,humanoid.WalkSpeed,dt,stoppingDistance,nearest.Parent)
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
