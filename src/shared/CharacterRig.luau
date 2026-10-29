-- Custom two-section limbs. Joint frames use the root's axes, independent of
-- authored Part rotations. No part is moved or resized while building the rig.
local Rig={}
local names={"LowerTorso","UpperTorso","Head","LeftUpperArm","LeftLowerArm","RightUpperArm","RightLowerArm","LeftUpperLeg","LeftLowerLeg","RightUpperLeg","RightLowerLeg"}
Rig.Names=names
local function bounds(root,part)
 local cf=root.CFrame:ToObjectSpace(part.CFrame)
 local r,u,l=cf.RightVector,cf.UpVector,cf.LookVector
 local s=part.Size/2
 local half=Vector3.new(math.abs(r.X)*s.X+math.abs(u.X)*s.Y+math.abs(l.X)*s.Z,math.abs(r.Y)*s.X+math.abs(u.Y)*s.Y+math.abs(l.Y)*s.Z,math.abs(r.Z)*s.X+math.abs(u.Z)*s.Y+math.abs(l.Z)*s.Z)
 return cf.Position,half
end
function Rig.Prepare(character,root,humanoid)
 local parts={}
 for _,name in ipairs(names) do
  local part=character:FindFirstChild(name)
  if not part or not part:IsA("BasePart") then return false end
  parts[name]=part
 end
 if character:GetAttribute("DeclineRigVersion")==1 then
  humanoid.HipHeight=character:GetAttribute("RigHipHeight") or humanoid.HipHeight
  return true
 end
 -- Snapshot before parenting any motors: joint creation may already move an assembly.
 local frames={[root]=root.CFrame}
 for _,part in pairs(parts) do frames[part]=part.CFrame end
 local pending={}
 local members={[root]=true}
 for _,part in pairs(parts) do members[part]=true end
 -- Only replace joints internal to this body. Equipment and accessory joints survive.
 for _,object in ipairs(character:GetDescendants()) do
  if (object:IsA("JointInstance") or object:IsA("WeldConstraint")) and members[object.Part0] and members[object.Part1] then object:Destroy() end
 end
 local function point(part,axis,sign)
  local p,h=bounds(root,part)
  if axis=="X" then return p+Vector3.new(h.X*sign,0,0) end
  return p+Vector3.new(0,h.Y*sign,0)
 end
 local function joint(name,a,b,p,standing,offset)
  local frame=frames[root]*CFrame.new(p)
  local motor=Instance.new("Motor6D")
  motor.Name=name;motor.Part0=a;motor.Part1=b
  local rest=frames[a]:ToObjectSpace(frame)
  motor.C0=rest
  motor.C1=frames[b]:ToObjectSpace(frame)
  motor:SetAttribute("AuthoredC0",rest)
  motor:SetAttribute("StandingRotation",standing or CFrame.identity)
  motor:SetAttribute("StandingOffset",offset or Vector3.zero)
  table.insert(pending,{Motor=motor,Parent=a,Rest=rest,Rotation=standing or CFrame.identity,Offset=offset or Vector3.zero})
  return motor
 end
 local lower,upper=parts.LowerTorso,parts.UpperTorso
 joint("RootJoint",root,lower,(bounds(root,lower)))
 joint("Waist",lower,upper,(point(lower,"Y",1)+point(upper,"Y",-1))/2)
 joint("Neck",upper,parts.Head,(point(upper,"Y",1)+point(parts.Head,"Y",-1))/2)
 for _,side in ipairs({"Left","Right"}) do
  local arm,forearm=parts[side.."UpperArm"],parts[side.."LowerArm"]
  local thigh,shin=parts[side.."UpperLeg"],parts[side.."LowerLeg"]
  local center,half=bounds(root,arm)
  local sign=center.X>=0 and 1 or -1
  local shoulder=point(arm,"X",-sign)
  local elbow=(point(arm,"X",sign)+point(forearm,"X",-sign))/2
  local hand=point(forearm,"X",sign)
  local motor=joint(side.."Shoulder",upper,arm,shoulder,CFrame.Angles(0,0,-sign*math.pi/2),Vector3.new(sign*(half.Y+.015),half.Y,0))
  motor:SetAttribute("UpperVector",elbow-shoulder)
  motor:SetAttribute("LowerVector",hand-elbow)
  joint(side.."Elbow",arm,forearm,elbow)
  joint(side.."Hip",lower,thigh,point(thigh,"Y",1))
  joint(side.."Knee",thigh,shin,(point(thigh,"Y",-1)+point(shin,"Y",1))/2)
 end
 -- First finish every joint frame in the authored T-pose, then lower the arms.
 for _,entry in ipairs(pending) do
  entry.Motor.C0=entry.Rest*CFrame.new(entry.Offset)*entry.Rotation
  entry.Motor.Parent=entry.Parent
 end
 local bottom=math.huge
 for _,name in ipairs({"LeftLowerLeg","RightLowerLeg"}) do
  local p,h=bounds(root,parts[name]);bottom=math.min(bottom,p.Y-h.Y)
 end
 humanoid.HipHeight=math.max(0,-bottom-root.Size.Y/2)
 character:SetAttribute("RigHipHeight",humanoid.HipHeight)
 humanoid.AutomaticScalingEnabled=false
 root.Transparency=1;root.RootPriority=127;root.Massless=false
 for _,part in pairs(parts) do
  part.Anchored=false;part.Massless=true
  part.CanCollide=false;part.CanTouch=false
  -- Retain the existing broad root/head hitboxes; decorative limbs are not extra hits.
  part.CanQuery=part==parts.Head
 end
 if not humanoid:FindFirstChildOfClass("Animator") then Instance.new("Animator",humanoid) end
 character:SetAttribute("DeclineRigVersion",1)
 return true
end
return Rig
