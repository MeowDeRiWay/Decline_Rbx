-- Replicated C0 poses: terminal bodies must survive cloning and have identical
-- geometry on the server and clients, independently of cosmetic Transform poses.
local Pose=require(script.Parent.CharacterPose)
local Fall={}
function Fall.Rest(joint)
 return (joint:GetAttribute("AuthoredC0") or joint.C0)*CFrame.new(joint:GetAttribute("StandingOffset") or Vector3.zero)*(joint:GetAttribute("StandingRotation") or CFrame.identity)
end
function Fall.Targets(joints,kind,prone)
 local result={}
 for _,j in ipairs(joints) do result[j]=Fall.Rest(j) end
 local function bend(name,x,y,z)
  for _,j in ipairs(joints) do if j.Name==name then result[j]=Fall.Rest(j)*CFrame.Angles(math.rad(x),math.rad(y or 0),math.rad(z or 0)) end end
 end
 local curled=kind=="Knockout"
 local carried=kind=="Carried"
 bend("Waist",carried and -12 or (curled and -28 or -4))
 bend("Neck",carried and -22 or (curled and -32 or 8),0,(curled or carried) and 0 or 7)
 for _,side in ipairs({"Left","Right"}) do
  local sign=side=="Left" and -1 or 1
  bend(side.."Hip",carried and 78 or (curled and 72 or (side=="Left" and 8 or -4)),0,(curled or carried) and 0 or sign*9)
  bend(side.."Knee",carried and -20 or (curled and -132 or (side=="Left" and -14 or -8)))
  local shoulder,elbow
  for _,j in ipairs(joints) do if j.Name==side.."Shoulder" then shoulder=j elseif j.Name==side.."Elbow" then elbow=j end end
  if shoulder and elbow then
   local a,b=shoulder:GetAttribute("UpperVector"),shoulder:GetAttribute("LowerVector")
   if a and b then
    local upper,lower
    if carried then upper=Vector3.new(sign*.12,-.15,-1);lower=Vector3.new(sign*.1,.1,-1)
    elseif curled then upper=Vector3.new(sign*.12,-.45,-1);lower=Vector3.new(-sign*.1,.9,-.35)
    elseif kind=="Zombie" then
     -- Facing down: reach towards the head. Facing up: towards the feet.
     upper=Vector3.new(sign*.12,prone and 1 or -1,-.12)
     lower=Vector3.new(sign*.08,prone and 1 or -1,-.05)
    else upper=Vector3.new(sign*.26,-1,-.08);lower=Vector3.new(sign*.35,-1,-.02) end
    local rotation=Pose.Between(a,upper)
    result[shoulder]=(shoulder:GetAttribute("AuthoredC0") or shoulder.C0)*CFrame.new(shoulder:GetAttribute("StandingOffset") or Vector3.zero)*rotation
    result[elbow]=Fall.Rest(elbow)*rotation:Inverse()*Pose.Between(b,lower)
   end
  end
 end
 return result
end
function Fall.Solve(root,frame,joints,targets)
 local frames={[root]=frame}
 -- Topological traversal; no dependence on GetDescendants order or stale parts.
 for _=1,#joints do
  local changed=false
  for _,j in ipairs(joints) do
   if frames[j.Part0] and not frames[j.Part1] then
    frames[j.Part1]=frames[j.Part0]*targets[j]*j.C1:Inverse();changed=true
   end
  end
  if not changed then break end
 end
 return frames
end
function Fall.RadiusY(cf,size)
 return (math.abs(cf.RightVector.Y)*size.X+math.abs(cf.UpVector.Y)*size.Y+math.abs(cf.LookVector.Y)*size.Z)/2
end
return Fall
