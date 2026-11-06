-- Transform is cosmetic and not replicated: every viewer poses nearby player
-- rigs locally. No per-frame remotes or Workspace scans. Studio alone can
-- run this same driver on the server for visual inspection.
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Pose=require(Shared:WaitForChild("CharacterPose"))
local Foot=require(Shared:WaitForChild("FootPlant"))
local Punch=require(Shared:WaitForChild("UnarmedPose"))
local Items=require(Shared.ItemConfig).Items
local Interact=require(Shared:WaitForChild("InteractionPose"))
local CarryPose=require(Shared:WaitForChild("CarryPose"))
local HandPose=require(Shared:WaitForChild("HandActionPose"))
local Motion=require(Shared:WaitForChild("WeaponMotion"))
local Presentation=require(Shared:WaitForChild("WeaponPresentation"))
local ReloadPose=require(Shared:WaitForChild("ReloadPose"))
local Driver={}
function Driver.Start(localPlayer,serverPreview)
local records={}
local watched={}
local function capture(r)
 local transforms={}
 for name,motor in pairs(r.Motors) do transforms[name]=motor.Transform end
 r.Transforms=transforms
 local held=r.Character:FindFirstChild("HeldItem")
 local motor=held and held:FindFirstChild("WeaponGrip")
 r.WeaponMotor=motor;r.WeaponTransform=motor and motor.Transform or nil
end
local function replay(r)
 for name,transform in pairs(r.Transforms) do r.Motors[name].Transform=transform end
 local motor=r.WeaponMotor
 if motor and motor.Parent and r.WeaponTransform then motor.Transform=r.WeaponTransform end
end
local function invalidate(player,character)
 local r=records[player]
 if r and r.Character==character then r.Transforms=nil;r.WeaponMotor=nil end
end
local joints={"Waist","Neck","RootJoint","LeftShoulder","RightShoulder","LeftElbow","RightElbow","LeftHip","RightHip","LeftKnee","RightKnee"}
local function clear(player)
 local watch=watched[player]
 if watch then for _,connection in ipairs(watch) do connection:Disconnect() end end
 watched[player]=nil;records[player]=nil
end
local function bind(player,character)
 clear(player)
 local links={};watched[player]=links
 local function rebuild()
  if player.Character~=character or character:GetAttribute("DeclineRigVersion")~=1 then records[player]=nil;return end
  local root=character:FindFirstChild("HumanoidRootPart")
  local hp=character:FindFirstChildOfClass("Humanoid")
  if not root or not hp then records[player]=nil;return end
  local motors={}
  for _,name in ipairs(joints) do
   local motor=character:FindFirstChild(name,true)
   if not motor or not motor:IsA("Motor6D") then records[player]=nil;return end
   motors[name]=motor
  end
  local previous=records[player]
  local same=previous and previous.Character==character and previous.Root==root and previous.HP==hp
  if same then for name,motor in pairs(motors) do if previous.Motors[name]~=motor then same=false;break end end end
  if same then
   -- Sounds, attachments and held-item visuals stream in frequently. They do
   -- not replace the rig and must not restart gait or discard planted feet.
   previous.Transforms=nil;previous.WeaponMotor=nil
  else
   records[player]={Character=character,Root=root,HP=hp,Motors=motors,Phase=0,Amount=0,Last=root.Position,Elapsed=0}
  end
 end
 local queued=false
 local function queue()
  if queued then return end;queued=true
  task.defer(function() queued=false;if watched[player]==links then rebuild() end end)
 end
 table.insert(links,character:GetAttributeChangedSignal("InteractionMode"):Connect(function()
  invalidate(player,character)
  if not character:GetAttribute("InteractionMode") then return end
  local held=character:FindFirstChild("HeldItem");local motor=held and held:FindFirstChild("WeaponGrip")
  if motor then Motion.Cancel(motor);motor.C0=motor:GetAttribute("RestC0") or motor.C0 end
 end))
 table.insert(links,character:GetAttributeChangedSignal("HandAction"):Connect(function()
  invalidate(player,character)
  local held=character:FindFirstChild("HeldItem");local motor=held and held:FindFirstChild("WeaponGrip")
  if motor then
   if character:GetAttribute("HandAction") then Motion.Cancel(motor) end
   motor.Transform=CFrame.identity
  end
 end))
 table.insert(links,character:GetAttributeChangedSignal("Reloading"):Connect(function()
  invalidate(player,character)
  local held=character:FindFirstChild("HeldItem");local motor=held and held:FindFirstChild("WeaponGrip")
  if motor then motor.Transform=CFrame.identity end
 end))
 table.insert(links,character:GetAttributeChangedSignal("BodyPoseKind"):Connect(function()
  invalidate(player,character)
  for _,joint in ipairs(character:GetDescendants()) do if joint:IsA("Motor6D") then joint.Transform=CFrame.identity end end
 end))
 table.insert(links,character.DescendantAdded:Connect(queue))
 table.insert(links,character.DescendantRemoving:Connect(function(object)
  local record=records[player]
  if record and (object==record.Root or object==record.HP or (object:IsA("Motor6D") and record.Motors[object.Name]==object)) then records[player]=nil end
  queue()
 end))
 table.insert(links,character:GetAttributeChangedSignal("DeclineRigVersion"):Connect(queue))
 rebuild()
end
local playerLinks={}
local function added(player)
 playerLinks[player]={player.CharacterAdded:Connect(function(c) bind(player,c) end),player.CharacterRemoving:Connect(function() clear(player) end)}
 if player.Character then bind(player,player.Character) end
end
Players.PlayerAdded:Connect(added)
Players.PlayerRemoving:Connect(function(player)
 clear(player)
 for _,connection in ipairs(playerLinks[player] or {}) do connection:Disconnect() end
 playerLinks[player]=nil
end)
for _,player in ipairs(Players:GetPlayers()) do added(player) end
RunService.PreSimulation:Connect(function(dt)
 local viewer=localPlayer and localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
 for player,r in pairs(records) do
  local c,root,hp,m=r.Character,r.Root,r.HP,r.Motors
  if not root:IsDescendantOf(workspace) then continue end
  if not serverPreview and (not viewer or (root.Position-viewer.Position).Magnitude>180) then r.Last=root.Position;r.Feet=nil;r.Transforms=nil;r.Elapsed=0;continue end
  -- Frozen bodies keep the existing knockout/death pose.
  if (root.Anchored and not c:GetAttribute("InteractionLocked")) or hp.Health<=0 or c:GetAttribute("Knockout") or c:GetAttribute("IsDead") then r.Last=root.Position;r.Feet=nil;r.Transforms=nil;r.Elapsed=0;continue end
  local held=c:FindFirstChild("HeldItem")
  local definition=Items[c:GetAttribute("HandsItem")]
  local motor=held and held:FindFirstChild("WeaponGrip")
  local chopFrame,chopping
  if definition and (definition.HarvestTool=="Axe" or definition.HarvestTool=="Shovel") then chopFrame,chopping=Motion.StepChop(motor,workspace:GetServerTimeNow()) end
  local animateChop=chopping or r.Chopping
  r.Chopping=chopping
  r.Elapsed+=dt
  if player~=localPlayer and not animateChop and r.Elapsed<1/30 and r.Transforms then
   -- Animator/native updates can overwrite Transform each simulation step.
   -- Throttle the IK work, never the presentation of the last valid pose.
   replay(r);continue
  end
  local elapsed=r.Elapsed;r.Elapsed=0
  if Interact.Apply(c,root,m,workspace:GetServerTimeNow()) then r.Last=root.Position;r.Feet=nil;r.Interacting=true;if player~=localPlayer then capture(r) end;continue end
  if r.Interacting then
   r.Interacting=nil
   local held=c:FindFirstChild("HeldItem");local motor=held and held:FindFirstChild("WeaponGrip")
   if motor then motor.Transform=CFrame.identity end
  end
  m.Waist.Transform=CFrame.identity;m.Neck.Transform=CFrame.identity
  local displacement=root.Position-r.Last;r.Last=root.Position
  local velocity=Vector3.new(displacement.X,0,displacement.Z)/math.max(elapsed,.001)
  -- Ignore teleports; measure actual translation so walking into a wall is idle.
  local speed=velocity.Magnitude
  if speed>math.max(30,hp.WalkSpeed*3) or hp.Sit or hp.PlatformStand then speed=0;r.Feet=nil end
  local blend=1-math.exp(-12*elapsed)
  local running=c:GetAttribute("Running")==true
  local amount,frequency=Pose.Gait(speed,running)
  r.Amount+=(amount-r.Amount)*blend
  r.Phase=(r.Phase+frequency*elapsed*2*math.pi)%(2*math.pi)
  local direction=speed>.025 and root.CFrame:VectorToObjectSpace(velocity.Unit) or Vector3.new(0,0,-1)
  local lh,rh,lk,rk=Pose.Legs(r.Phase,r.Amount,-direction.Z,direction.X,running and .8 or .35)
  local neutral={}
  local legLength=0
  for _,side in ipairs({"Left","Right"}) do
   local hip=m[side.."Hip"]
   local foot=hip:GetAttribute("FootPosition")
   local upper,lower=hip:GetAttribute("UpperVector"),hip:GetAttribute("LowerVector")
   if foot and upper and lower then
    neutral[side]=root.CFrame:PointToWorldSpace(foot)
    legLength=math.max(legLength,upper.Magnitude+lower.Magnitude)
   end
  end
  if neutral.Left and neutral.Right then
   local feet
   r.Feet,feet=Foot.Step(r.Feet,neutral,speed>.025 and velocity or Vector3.zero,elapsed,running,legLength)
   local crouch=legLength*.045
   m.RootJoint.Transform=CFrame.new(0,-crouch,0)
   for _,side in ipairs({"Left","Right"}) do
    local hip,knee=m[side.."Hip"],m[side.."Knee"]
    local anchor=hip:GetAttribute("RootAnchor")+Vector3.new(0,-crouch,0)
    local delta=root.CFrame:VectorToObjectSpace(feet[side]-root.CFrame:PointToWorldSpace(anchor))
    local a,b=Pose.Arm(hip:GetAttribute("UpperVector"),hip:GetAttribute("LowerVector"),delta,Vector3.new(0,0,-1))
    hip.Transform=a;knee.Transform=b
   end
  else
  m.LeftHip.Transform=lh;m.RightHip.Transform=rh;m.LeftKnee.Transform=lk;m.RightKnee.Transform=rk
  end
  local animationSet=Presentation.AnimationSet(held,definition)
  local equipped=held and definition and (definition.Firearm or definition.Weapon or definition.Trap or definition.Slot=="Medicine" or animationSet=="Tool")
  local twoHands=animationSet=="Pistol" or animationSet=="Rifle" or animationSet=="Launcher" or animationSet=="Axe" or animationSet=="Shovel" or animationSet=="Mine"
  local reloadFrame,reloadRight,reloadLeft=ReloadPose.Apply(c,root,held,motor,workspace:GetServerTimeNow())
  if not reloadFrame and r.Reloading and motor then motor.Transform=CFrame.identity end
  r.Reloading=reloadFrame~=nil
  local now=workspace:GetServerTimeNow()
  local punchStarted=c:GetAttribute("PunchStartedAt")
  local punching=typeof(punchStarted)=="number" and now>=punchStarted and now-punchStarted<1.5
  local breathBlocked=punching or reloadFrame~=nil or c:GetAttribute("Reloading") or c:GetAttribute("HandAction") or c:GetAttribute("CarryingUserId") or hp.Sit or hp.PlatformStand or (equipped and not definition.Firearm)
  local breath=Pose.Breath(now,(player.UserId or 0)%97,root.Size.Y,speed,breathBlocked)
  m.Waist.Transform=CFrame.new(breath)
  -- Predict the same-step chest position for IK instead of reading its previous
  -- physics frame. Hands and chest must rise together without feedback jitter.
  local waist=m.Waist
  local chestFrame=waist.Part0.CFrame*waist.C0*waist.Transform*(waist.C1 or CFrame.identity):Inverse()
  if equipped and definition.Firearm and motor and not reloadFrame and not c:GetAttribute("HandAction") then
   local untilTime=c:GetAttribute("WeaponCombatUntil") or 0
   local relaxed=now>=untilTime
   r.Relaxed=(r.Relaxed or 0)+((relaxed and 1 or 0)-(r.Relaxed or 0))*(1-math.exp(-10*elapsed))
   local rest=motor:GetAttribute("RestC0") or motor.C0
   local desired=Presentation.RestFrame(rest,animationSet,r.Relaxed,root.Size,definition.Firearm.Category)
   -- Rotate about the component grip even if PrimaryPart is elsewhere.
   local right=Presentation.PartFrame(held,"Grip",motor,root.CFrame*rest)
   if right then
    local point=root.CFrame:PointToObjectSpace(right.Position)
    local delta=desired*rest:Inverse()
    desired=desired+point-delta:PointToWorldSpace(point)+(desired.Position-rest.Position)
   end
   if animationSet=="Pistol" or animationSet=="Rifle" then desired=desired+breath end
   if animationSet=="Pistol" then
    -- Place the grip at the natural hanging hand, using actual limb lengths.
    -- A fixed chest-relative offset leaves the elbow bent across the body.
    local shoulder=m.RightShoulder
    local authored=shoulder:GetAttribute("AuthoredC0")
    local upper,lower=shoulder:GetAttribute("UpperVector"),shoulder:GetAttribute("LowerVector")
    if authored and upper and lower then
     local standing=shoulder:GetAttribute("StandingRotation") or CFrame.identity
     local offset=shoulder:GetAttribute("StandingOffset") or Vector3.zero
     local parent=shoulder.Part0==waist.Part1 and chestFrame or shoulder.Part0.CFrame
     local anchor=(parent*authored*CFrame.new(offset)).Position
     local hand=anchor+root.CFrame:VectorToWorldSpace(standing:VectorToWorldSpace(upper+lower))
     local world=root.CFrame*desired*(motor.C1 or CFrame.identity):Inverse()
     local grip=held:FindFirstChild("RightHandGrip",true) or held:FindFirstChild("_HandGrip",true)
     local current=Presentation.PartFrame(held,"Grip",motor,world) or Motion.GripFrame(motor,grip,world)
     desired=desired+root.CFrame:VectorToObjectSpace(hand-current.Position)*r.Relaxed
    end
   end
   motor.Transform=motor.C0:Inverse()*desired
  elseif reloadFrame then r.Relaxed=0 end
  local supportWeight=Presentation.SupportWeight(animationSet,r.Relaxed,reloadFrame~=nil)
  local posedFrame=motor and motor.Part1 and motor.Part0.CFrame*motor.C0*motor.Transform*(motor.C1 or CFrame.identity):Inverse()
  local componentRight=equipped and Presentation.PartFrame(held,"Grip",motor,posedFrame)
  local componentLeft=equipped and Presentation.PartFrame(held,"Handguard",motor,posedFrame)
  local grip=held and (held:FindFirstChild("RightHandGrip",true) or held:FindFirstChild("_HandGrip",true))
  local targetFrame=equipped and (grip and grip:IsA("Attachment") and grip.WorldCFrame or held:GetPivot())
  if componentRight then targetFrame=componentRight end
  if definition and definition.Firearm and not componentRight and posedFrame then targetFrame=Motion.GripFrame(motor,grip,posedFrame) end
  if chopFrame then targetFrame=Motion.GripFrame(motor,grip,chopFrame) end
  if reloadFrame then targetFrame=Motion.GripFrame(motor,grip,reloadFrame) end
  local punchTime=c:GetAttribute("PunchStartedAt")
  local punchElapsed=typeof(punchTime)=="number" and workspace:GetServerTimeNow()-punchTime or -1
  local punchSequence=c:GetAttribute("PunchSequence") or 0
  for _,side in ipairs({"Left","Right"}) do
   local shoulder,elbow=m[side.."Shoulder"],m[side.."Elbow"]
   local standing=shoulder:GetAttribute("StandingRotation") or CFrame.identity
   local rest=shoulder:GetAttribute("AuthoredC0")
   local offset=shoulder:GetAttribute("StandingOffset") or Vector3.zero
   local upper,lower=shoulder:GetAttribute("UpperVector"),shoulder:GetAttribute("LowerVector")
   if not rest or not upper or not lower or not shoulder.Part0 or not shoulder.Part1 or not elbow.Part0 or not elbow.Part1 then continue end
   if c:GetAttribute("CarryingUserId") and side=="Left" then
    local target=CarryPose.SupportPoint(c,root)
    local anchor=((shoulder.Part0==waist.Part1 and chestFrame or shoulder.Part0.CFrame)*rest*CFrame.new(offset)).Position
    local delta=root.CFrame:VectorToObjectSpace(target-anchor)
    local launcher=animationSet=="Launcher"
    local bend=launcher and Vector3.new(side=="Left" and -.6 or 1,-1,.35) or Vector3.new(side=="Left" and -1 or 1,-1,.2)
    local s,e=Pose.Arm(upper,lower,delta,bend)
    shoulder.Transform=standing:Inverse()*s;elbow.Transform=e
   elseif c:GetAttribute("CarryingUserId") then
    local swing=math.sin(r.Phase)*r.Amount*.6
    shoulder.Transform=standing:Inverse()*CFrame.Angles(swing,0,0)*standing
    elbow.Transform=CFrame.identity
   elseif equipped and (side=="Right" or twoHands and supportWeight>.001) then
    -- Primary hand at the grip; support hand toward the barrel. Clamp reach in IK.
    local support=held:FindFirstChild("LeftHandGrip",true)
    local pistol=animationSet=="Pistol"
    local target=targetFrame.Position
    if side=="Left" then
     local supportPose=chopFrame or definition.Firearm and posedFrame
     local supportFrame=supportPose and support and support:IsA("Attachment") and Motion.GripFrame(motor,support,supportPose)
     target=supportFrame and supportFrame.Position or support and support:IsA("Attachment") and support.WorldPosition or target+(pistol and -root.CFrame.RightVector*.04 or targetFrame.LookVector*.25)
    end
    if componentLeft and side=="Left" then target=componentLeft.Position end
    if reloadFrame then target=side=="Left" and reloadLeft or reloadRight end
    local anchor=((shoulder.Part0==waist.Part1 and chestFrame or shoulder.Part0.CFrame)*rest*CFrame.new(offset)).Position
    if side=="Left" and not reloadFrame and supportWeight<1 then
     local swing=-math.sin(r.Phase)*r.Amount*.6
     local hanging=anchor+root.CFrame:VectorToWorldSpace((CFrame.Angles(swing,0,0)*standing):VectorToWorldSpace(upper+lower))
     target=hanging+(target-hanging)*supportWeight
    end
    local delta=root.CFrame:VectorToObjectSpace(target-anchor)
    local launcher=animationSet=="Launcher"
    local bend=launcher and Vector3.new(side=="Left" and -.6 or 1,-1,.35) or Vector3.new(side=="Left" and -1 or 1,-1,.2)
    local hingeWeight=definition.Firearm and (reloadFrame and 1 or 1-(r.Relaxed or 0)) or 0
    local s,e=Pose.Arm(upper,lower,delta,bend,hingeWeight)
    shoulder.Transform=standing:Inverse()*s;elbow.Transform=e
   elseif equipped and animationSet=="Knife" and side=="Left" then
    -- Free hand stays forward in a defensive guard; it does not swing at the side.
    local target=root.CFrame:PointToWorldSpace(Vector3.new(-root.Size.X*.6,root.Size.Y*.28,-root.Size.Y*.75))
    local anchor=((shoulder.Part0==waist.Part1 and chestFrame or shoulder.Part0.CFrame)*rest*CFrame.new(offset)).Position
    local delta=root.CFrame:VectorToObjectSpace(target-anchor)
    local s,e=Pose.Arm(upper,lower,delta,Vector3.new(-1,-.5,.15))
    shoulder.Transform=standing:Inverse()*s;elbow.Transform=e
   elseif not definition and not held and punchElapsed>=0 and punchElapsed<1.5 then
    local localTarget,weight=Punch.Target(root.Size,side,punchSequence,punchElapsed)
    local anchor=((shoulder.Part0==waist.Part1 and chestFrame or shoulder.Part0.CFrame)*rest*CFrame.new(offset)).Position
    local hanging=anchor+root.CFrame:VectorToWorldSpace(standing:VectorToWorldSpace(upper+lower))
    local target=hanging+(root.CFrame:PointToWorldSpace(localTarget)-hanging)*weight
    local delta=root.CFrame:VectorToObjectSpace(target-anchor)
    local s,e=Pose.Arm(upper,lower,delta,Vector3.new(side=="Left" and -1 or 1,-.5,.15))
    shoulder.Transform=standing:Inverse()*s;elbow.Transform=e
   else
    local swing=math.sin(r.Phase)*(side=="Left" and -1 or 1)*r.Amount*.6
    shoulder.Transform=standing:Inverse()*CFrame.Angles(swing,0,0)*standing
    elbow.Transform=CFrame.identity
   end
  end
  HandPose.Apply(c,root,m,workspace:GetServerTimeNow())
  if player~=localPlayer then capture(r) end
 end
end)

end
return Driver
