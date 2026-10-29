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
local Motion=require(Shared:WaitForChild("WeaponMotion"))
local Driver={}
function Driver.Start(localPlayer,serverPreview)
local records={}
local watched={}
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
  records[player]={Character=character,Root=root,HP=hp,Motors=motors,Phase=0,Amount=0,Last=root.Position,Elapsed=0}
 end
 local queued=false
 local function queue()
  if queued then return end;queued=true
  task.defer(function() queued=false;if watched[player]==links then rebuild() end end)
 end
 table.insert(links,character:GetAttributeChangedSignal("InteractionMode"):Connect(function()
  if not character:GetAttribute("InteractionMode") then return end
  local held=character:FindFirstChild("HeldItem");local motor=held and held:FindFirstChild("WeaponGrip")
  if motor then Motion.Cancel(motor);motor.C0=motor:GetAttribute("RestC0") or motor.C0 end
 end))
 table.insert(links,character:GetAttributeChangedSignal("BodyPoseKind"):Connect(function()
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
  if not serverPreview and (not viewer or (root.Position-viewer.Position).Magnitude>180) then r.Last=root.Position;r.Feet=nil;continue end
  -- Frozen bodies keep the existing knockout/death pose.
  if (root.Anchored and not c:GetAttribute("InteractionLocked")) or hp.Health<=0 or c:GetAttribute("Knockout") or c:GetAttribute("IsDead") then r.Last=root.Position;continue end
  r.Elapsed+=dt
  if player~=localPlayer and r.Elapsed<1/30 then continue end
  local elapsed=r.Elapsed;r.Elapsed=0
  if Interact.Apply(c,root,m,workspace:GetServerTimeNow()) then r.Last=root.Position;r.Feet=nil;r.Interacting=true;continue end
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
  local held=c:FindFirstChild("HeldItem")
  local definition=Items[c:GetAttribute("HandsItem")]
  local equipped=held and definition and (definition.Firearm or definition.Weapon)
  local twoHands=definition and (definition.Firearm or definition.HarvestTool=="Axe" or definition.HarvestTool=="Shovel")
  local grip=held and (held:FindFirstChild("RightHandGrip",true) or held:FindFirstChild("_HandGrip",true))
  local targetFrame=equipped and (grip and grip:IsA("Attachment") and grip.WorldCFrame or held:GetPivot())
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
   if equipped and (side=="Right" or twoHands) then
    -- Primary hand at the grip; support hand toward the barrel. Clamp reach in IK.
    local support=held:FindFirstChild("LeftHandGrip",true)
    local pistol=definition.Firearm and definition.Firearm.Category=="Pistol"
    local target=targetFrame.Position
    if side=="Left" then
     target=support and support:IsA("Attachment") and support.WorldPosition or target+(pistol and -root.CFrame.RightVector*.04 or targetFrame.LookVector*.25)
    end
    local anchor=(shoulder.Part0.CFrame*rest*CFrame.new(offset)).Position
    local delta=root.CFrame:VectorToObjectSpace(target-anchor)
    local s,e=Pose.Arm(upper,lower,delta,Vector3.new(side=="Left" and -1 or 1,-1,.2))
    shoulder.Transform=standing:Inverse()*s;elbow.Transform=e
   elseif equipped and definition.CraftTool=="Knife" and side=="Left" then
    -- Free hand stays forward in a defensive guard; it does not swing at the side.
    local target=root.CFrame:PointToWorldSpace(Vector3.new(-root.Size.X*.6,root.Size.Y*.28,-root.Size.Y*.75))
    local anchor=(shoulder.Part0.CFrame*rest*CFrame.new(offset)).Position
    local delta=root.CFrame:VectorToObjectSpace(target-anchor)
    local s,e=Pose.Arm(upper,lower,delta,Vector3.new(-1,-.5,.15))
    shoulder.Transform=standing:Inverse()*s;elbow.Transform=e
   elseif not definition and not held and punchElapsed>=0 and punchElapsed<1.5 then
    local localTarget,weight=Punch.Target(root.Size,side,punchSequence,punchElapsed)
    local anchor=(shoulder.Part0.CFrame*rest*CFrame.new(offset)).Position
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
 end
end)

end
return Driver
