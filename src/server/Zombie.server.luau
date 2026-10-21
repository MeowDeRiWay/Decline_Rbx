local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Sight = require(ReplicatedStorage.Shared.Sight)
local Navigation = require(script.Parent.Services.ZombieNavigation)
game:GetService("RunService").Heartbeat:Connect(function() Navigation.Update() end)
local Activity = require(script.Parent.Services.ZombieActivity)
local Crowd = require(ReplicatedStorage.Shared.CrowdRules)
local IdleRules = require(ReplicatedStorage.Shared.ZombieIdleRules)
local Sector = require(ReplicatedStorage.Shared.VisibilityRules)
local LootConfig = require(ReplicatedStorage.Shared.ZombieLootConfig)
local LootRules = require(ReplicatedStorage.Shared.LootRules)
local Items = require(ReplicatedStorage.Shared.ItemConfig).Items
local Motion = require(ReplicatedStorage.Shared.WeaponMotion)
local Visuals = require(script.Parent.Services.EquipmentVisuals)
local Noise=require(script.Parent.Services.NoiseService)
local Damage = require(script.Parent.Services.DamageService)
local Chests = require(script.Parent.Services.ChestService)
local Progression=require(ReplicatedStorage.Shared.ProgressionRules)
local ZombieStats=require(ReplicatedStorage.Shared.ZombieStats)
local statRandom=Random.new()
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
 local stats=ZombieStats.Roll(statRandom)
 local derived=Progression.Bonuses(stats)
 local skills=Progression.SkillValues(stats)
 for id,value in pairs(stats) do model:SetAttribute(id,value) end
 for id,value in pairs(derived) do model:SetAttribute(id,value) end
 model:SetAttribute("SkillUnarmed",skills.Unarmed)
 model:SetAttribute("Accuracy",skills.Unarmed)
 model:SetAttribute("SightRange",derived.ViewRange)
 model:SetAttribute("MoveSpeed",derived.RunBonus)
 humanoid.MaxHealth=derived.MaxHealth;humanoid.Health=derived.MaxHealth
 humanoid.WalkSpeed=derived.RunBonus
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
  Chests.CreateCorpse(model,require(script.Parent.Services.ProgressionService).ZombieDied(model,LootRules.Roll(LootConfig,Items)))
  local direction=model:GetAttribute("LastHitDirection")
  if typeof(direction)~="Vector3" then direction=root.CFrame.LookVector end
  direction=Vector3.new(direction.X,0,direction.Z)
  direction=direction.Magnitude>.001 and direction.Unit or Vector3.new(0,0,-1)
  local start=model:GetPivot()
  local standingPosition=root.Position
  local fallRoot=CFrame.lookAt(standingPosition,standingPosition+direction)*CFrame.Angles(-math.pi/2,0,0)
  local destination=fallRoot*root.CFrame:Inverse()*start
  model:PivotTo(destination)
  -- Ground the actual body, not the equipped hand or a custom model pivot.
  local bottom=math.huge
  for _,part in ipairs(model:GetDescendants()) do
   if part:IsA("BasePart") and part.Transparency<1 and not (held and part:IsDescendantOf(held)) then
    local cf,size=part.CFrame,part.Size
    local radius=math.abs(cf.RightVector.Y)*size.X/2+math.abs(cf.UpVector.Y)*size.Y/2+math.abs(cf.LookVector.Y)*size.Z/2
    bottom=math.min(bottom,cf.Position.Y-radius)
   end
  end
  if bottom==math.huge then bottom=root.Position.Y-root.Size.Z/2 end
  local params=RaycastParams.new()
  params.FilterType=Enum.RaycastFilterType.Exclude
  local excluded={model}
  for _,player in ipairs(Players:GetPlayers()) do if player.Character then table.insert(excluded,player.Character) end end
  local creatures=workspace:FindFirstChild("Creatures")
  if creatures then table.insert(excluded,creatures) end
  params.FilterDescendantsInstances=excluded
  params.RespectCanCollide=true
  local floor=workspace:Raycast(standingPosition+Vector3.new(0,2,0),Vector3.new(0,-100,0),params)
  local reference=model:FindFirstChild("ZombieHome")
  local home=reference and reference:IsA("ObjectValue") and reference.Value
  if home and home:IsDescendantOf(workspace) then
   local homeParams=RaycastParams.new()
   homeParams.FilterType=Enum.RaycastFilterType.Include
   homeParams.FilterDescendantsInstances={home}
   local homeFloor=workspace:Raycast(standingPosition+Vector3.new(0,2,0),Vector3.new(0,-100,0),homeParams)
   if homeFloor and (not floor or homeFloor.Position.Y>floor.Position.Y) then floor=homeFloor end
  end
  if floor then destination += Vector3.new(0,floor.Position.Y-bottom+.02,0) end
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
  if distance<=0 then return false,true end
  local params=RaycastParams.new()
  params.FilterType=Enum.RaycastFilterType.Exclude
  params.FilterDescendantsInstances=ignored and {model,ignored} or {model}
  params.RespectCanCollide=true
  local movementVector=direction*distance
  -- Match navigation's travel-aligned footprint when entering narrow doorways.
  local travelFrame=CFrame.lookAt(root.Position,root.Position+direction)
  local bodySize=Vector3.new(math.max(.01,root.Size.X-.02),root.Size.Y*.9,math.max(.01,root.Size.Z-.02))
  local obstruction=workspace:Blockcast(travelFrame,bodySize,movementVector,params)
  if obstruction then
   distance=math.max(0,obstruction.Distance-.02)
   model:SetAttribute("AIState","Blocked")
  end
  local position=root.Position+direction*distance
  local groundExcluded={model}
  for other in pairs(registered) do
   if other~=model and other:IsDescendantOf(workspace) then
    table.insert(groundExcluded,other)
    local otherRoot=other:FindFirstChild("HumanoidRootPart")
    local hp=other:FindFirstChildOfClass("Humanoid")
    if otherRoot and hp and hp.Health>0 and math.abs(root.Position.Y-otherRoot.Position.Y)<(root.Size.Y+otherRoot.Size.Y)/2+.2 then
     local radius=(math.sqrt(root.Size.X^2+root.Size.Z^2)+math.sqrt(otherRoot.Size.X^2+otherRoot.Size.Z^2))/2+.05
     if not Crowd.CanStep(root.Position.X,root.Position.Z,position.X,position.Z,otherRoot.Position.X,otherRoot.Position.Z,radius) then
      model:SetAttribute("AIState","CrowdBlocked")
      return false,true
     end
    end
   end
  end
  for _,player in ipairs(Players:GetPlayers()) do if player.Character then table.insert(groundExcluded,player.Character) end end
  local groundParams=RaycastParams.new()
  groundParams.FilterType=Enum.RaycastFilterType.Exclude
  groundParams.FilterDescendantsInstances=groundExcluded
  groundParams.RespectCanCollide=true
  local stepHeight=math.max(.15,root.Size.Y*.5)
  local ground=workspace:Raycast(position+Vector3.new(0,stepHeight,0),Vector3.new(0,-stepHeight-root.Size.Y/2-2,0),groundParams)
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
  if not ground or ground.Normal.Y < .85 or math.abs(ground.Position.Y+root.Size.Y/2+.02-root.Position.Y)>stepHeight then
   model:SetAttribute("AIState","Blocked"); return false,true
  end
  position=Vector3.new(position.X,ground.Position.Y+root.Size.Y/2+.02,position.Z)
  local turned=travelFrame
  local desiredRoot=CFrame.new(position)*turned.Rotation
  model:PivotTo(desiredRoot*root.CFrame:Inverse()*model:GetPivot())
  return false,obstruction ~= nil
 end
 local navigation=Navigation.New(model,root)
 navigation.CachedWorld=true
 local function navigate(destination,speed,dt,stoppingDistance,ignored)
  local delta=destination-root.Position
  if Vector3.new(delta.X,0,delta.Z).Magnitude<=stoppingDistance then
   local ray=navigation:Parameters(ignored)
   if navigation:Clear(root.Position,destination,ray) then return true,false end
  end
  local waypoint=navigation:Waypoint(destination,ignored)
  if not waypoint then
   model:SetAttribute("NavigationStatus",navigation.Pending and "Planning" or "NoRoute")
   return false,not navigation.Pending
  end
  model:SetAttribute("NavigationStatus","FollowingRoute")
  local arrived,blocked=moveToward(waypoint,speed,dt,.08,ignored)
  if blocked then navigation:Blocked() end
  return false,blocked
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
   local arrived,blocked=navigate(wanderTarget,model:GetAttribute("WalkBonus"),dt,.1,nil)
   if arrived or blocked then IdleRules.FinishWalk(idle) end
  end
 end
 local nearest
 local lastSeenPosition,lastSeenCharacter
 local searchStart,searchElapsed,searchBlocked
 local elapsed=0
 local heardPosition,heardUntil,heardBlocked,noiseCursor=nil,0,0,0
 local regenAt=os.clock()+60
 local movement
 movement=Activity.Register(model,root,function(dt)
  if not model:IsDescendantOf(workspace) then navigation:Cancel(); movement:Disconnect(); return end
  -- Custom anchored rigs may not enter Humanoid's Dead state. HP is authoritative.
  if humanoid.Health<=0 and not dead then die() end
  if dead then navigation:Cancel(); movement:Disconnect(); return end
  if os.clock()>=regenAt then regenAt=os.clock()+60;humanoid.Health=math.min(humanoid.MaxHealth,humanoid.Health+(model:GetAttribute("Regeneration") or 0)) end
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
   local heard,cursor=Noise.Listen(root.Position,model:GetAttribute("Attention"),noiseCursor)
   noiseCursor=cursor
   if not nearest and heard then
    heardPosition=heard.Position;heardUntil=os.clock()+60;heardBlocked=0
    model:SetAttribute("LastHeardPosition",heardPosition);model:SetAttribute("LastHeardKind",heard.Kind)
   end
   if nearest then
    heardPosition=nil
    lastSeenPosition,lastSeenCharacter=nearest.Position,nearest.Parent
    model:SetAttribute("LastSeenPosition",lastSeenPosition)
    searchStart,searchElapsed,searchBlocked=nil,0,0
   end
   model:SetAttribute("DetectionReason",nearest and "Visible target" or reason)
   model:SetAttribute("TargetName",nearest and nearest.Parent.Name or "")
   if nearest then model:SetAttribute("AIState","Chasing") end
  end
  if not nearest or not nearest.Parent then
   local targetHumanoid=lastSeenCharacter and lastSeenCharacter:FindFirstChildOfClass("Humanoid")
   if not targetHumanoid or targetHumanoid.Health<=0 or lastSeenCharacter:GetAttribute("Knockout") then lastSeenPosition=nil end
   if not lastSeenPosition and heardPosition then
    model:SetAttribute("AIState","InvestigatingSound")
    local arrived,blocked=navigate(heardPosition,humanoid.WalkSpeed,dt,.4,nil)
    heardBlocked=blocked and heardBlocked+dt or 0
    if arrived or heardBlocked>=3 or os.clock()>=heardUntil then heardPosition=nil;idle=IdleRules.New();idlePhase=nil end
    return
   end
   if lastSeenPosition then
    if not searchStart then
     model:SetAttribute("AIState","SearchingLastPosition")
     local arrived,blocked=navigate(lastSeenPosition,humanoid.WalkSpeed,dt,.15,nil)
     searchBlocked=blocked and (searchBlocked or 0)+dt or 0
     if arrived or searchBlocked>=3 then searchStart=root.CFrame; searchElapsed=0 end
    else
     model:SetAttribute("AIState","SearchingLook")
     searchElapsed+=dt
     local progress=math.min(searchElapsed/8,1)
     local desired=searchStart*CFrame.Angles(0,math.sin(progress*2*math.pi)*math.rad(60),0)
     model:PivotTo(desired*root.CFrame:Inverse()*model:GetPivot())
     if progress>=1 then
      lastSeenPosition,lastSeenCharacter,searchStart=nil,nil,nil
      idle=IdleRules.New(); idlePhase=nil
     end
    end
   else idleStep(dt) end
   return
  end
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
     if dead or humanoid.Health<=0 or model:GetAttribute("ActivityMode")~="Active" or not model.Parent or not victimRoot.Parent then return end
     local victim=victimRoot.Parent:FindFirstChildOfClass("Humanoid")
     if not victim or victim.Health<=0 or victimRoot.Parent:GetAttribute("Knockout") then return end
     local offset=victimRoot.Position-root.Position
     if offset.Magnitude>attackDistance then return end
     local facing=root.CFrame.LookVector
     if not Sector.InSector(facing.X,facing.Z,offset.X,offset.Z,160) then return end
     local hit=Sight.Cast(head.Position,victimRoot.Position-head.Position,model)
     if hit and not hit.Instance:IsDescendantOf(victimRoot.Parent) then return end
     if not Damage.RollHit(model,victim,0,model:GetAttribute("SkillUnarmed")) then Damage.Miss(victim.Parent,model);return end
     local critical=statRandom:NextNumber()<(model:GetAttribute("CriticalChance") or 0)
     if Damage.Apply(victim,model:GetAttribute("MeleeBonus"),weapon.DamageType,root.Position,"Melee",{Attacker=model,HitChecked=true,CriticalMultiplier=critical and statRandom:NextInteger(2,4) or 1})>0 then
      model:SetAttribute("WeaponCondition",math.max(0,(model:GetAttribute("WeaponCondition") or 0)-1))
     end
    end)
   end
  end
  -- Being close across a wall/window is not the same as arriving.
  navigate(nearest.Position,humanoid.WalkSpeed,dt,stoppingDistance,nearest.Parent)
 end,function(mode)
  -- Drop stale paths and targets when sleeping; wake starts with fresh detection.
  nearest=nil
  lastSeenPosition,lastSeenCharacter,searchStart=nil,nil,nil
  searchElapsed,searchBlocked=0,0
  navigation:Cancel()
  navigation=Navigation.New(model,root)
  navigation.CachedWorld=true
  idle=IdleRules.New();idlePhase=nil
  elapsed=random:NextNumber(0,.1)
  if mode~="Active" then
   model:SetAttribute("AIState",mode)
   model:SetAttribute("TargetName","")
   model:SetAttribute("DetectionReason","Outside active screen buffer")
   model:SetAttribute("NavigationStatus","Sleeping")
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
