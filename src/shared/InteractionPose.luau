local IK=require(script.Parent.CharacterPose)
local Pose={ReachContact=.3,ReachDuration=.65,DownDuration=.9,UpDuration=1.15}
local function smooth(t) t=math.clamp(t,0,1);return t*t*(3-2*t) end
function Pose.State(mode,t,riseFrom,layFrom)
 if mode=="Reach" then return 0,0,t<Pose.ReachContact and smooth(t/Pose.ReachContact) or 1-smooth((t-Pose.ReachContact)/(Pose.ReachDuration-Pose.ReachContact)) end
 if mode=="LootDown" then return smooth(t/.65),smooth((t-.25)/.5),1 end
 if mode=="Loot" then return 1,1,1 end
 if mode=="LootUp" then return (riseFrom or 1)*(1-smooth((t-.5)/.65)),(layFrom or 1)*(1-smooth((t-.18)/.4)),1 end
 return 0,0,0
end
function Pose.Apply(c,root,m,now)
 local mode=c:GetAttribute("InteractionMode")
 if not mode then return false end
 local t=math.max(0,now-(c:GetAttribute("InteractionStartedAt") or now))
 local crouch,laid,reach=Pose.State(mode,t,c:GetAttribute("InteractionRiseFrom"),c:GetAttribute("InteractionLayFrom"))
 local held=c:FindFirstChild("HeldItem")
 local motor=held and held:FindFirstChild("WeaponGrip")
 local legLength=0
 for _,side in ipairs({"Left","Right"}) do
  local j=m[side.."Hip"]
  legLength=math.max(legLength,(j:GetAttribute("UpperVector") or Vector3.zero).Magnitude+(j:GetAttribute("LowerVector") or Vector3.zero).Magnitude)
 end
 local drop=legLength*.48*crouch
 m.RootJoint.Transform=CFrame.new(0,-drop,0)
 m.Waist.Transform=CFrame.Angles(math.rad(-23)*crouch,0,0)
 m.Neck.Transform=CFrame.Angles(math.rad(10)*crouch,0,0)
 local lower=root.CFrame*m.RootJoint.C0*m.RootJoint.Transform*m.RootJoint.C1:Inverse()
 local upper=lower*m.Waist.C0*m.Waist.Transform*m.Waist.C1:Inverse()
 for _,side in ipairs({"Left","Right"}) do
  local hip,knee=m[side.."Hip"],m[side.."Knee"]
  local a,b=hip:GetAttribute("UpperVector"),hip:GetAttribute("LowerVector")
  local foot=hip:GetAttribute("FootPosition")
  if a and b and foot then
   local anchor=lower*hip.C0
   local delta=anchor:VectorToObjectSpace(root.CFrame:PointToWorldSpace(foot)-anchor.Position)
   local s,e=IK.Arm(a,b,delta,Vector3.new(0,0,-1))
   hip.Transform=s;knee.Transform=e
  end
 end
 local target=c:GetAttribute("InteractionPoint") or (root.Position+root.CFrame.LookVector)
 local gripWorld
 if motor and motor.Part1 then
  local rest=motor:GetAttribute("RestC0") or motor.C0
  local localFrame=rest
  if mode=="Reach" then
   local down=CFrame.new(root.Size.X*.9,-legLength*.55,-.05)*CFrame.Angles(math.rad(-65),0,0)*(CFrame.new(-rest.Position)*rest)
   localFrame=rest:Lerp(down,reach)
  else
   local ground=-(root.Size.Y/2+(c:GetAttribute("RigHipHeight") or legLength))
   local onGround=CFrame.new(root.Size.X/2+.5,ground+.12,-.15)*CFrame.Angles(0,0,math.pi/2)*(CFrame.new(-rest.Position)*rest)
   localFrame=(rest+CFrame.new(0,-drop,0).Position):Lerp(onGround,laid)
  end
  motor.Transform=motor.C0:Inverse()*localFrame
  local frame=root.CFrame*localFrame*(motor.C1 or CFrame.identity):Inverse()
  local grip=held:FindFirstChild("_HandGrip",true)
  gripWorld=grip and frame*grip.CFrame or frame
 end
 for _,side in ipairs({"Left","Right"}) do
  local shoulder,elbow=m[side.."Shoulder"],m[side.."Elbow"]
  local rest=shoulder:GetAttribute("AuthoredC0")
  local standing=shoulder:GetAttribute("StandingRotation") or CFrame.identity
  local a,b=shoulder:GetAttribute("UpperVector"),shoulder:GetAttribute("LowerVector")
  if not rest or not a or not b then continue end
  local frame=upper*rest*CFrame.new(shoulder:GetAttribute("StandingOffset") or Vector3.zero)
  local hanging=frame.Position+frame:VectorToWorldSpace(standing:VectorToWorldSpace(a+b))
  local aim=hanging
  local sign=side=="Left" and -1 or 1
  local search=target+root.CFrame.RightVector*sign*.12+Vector3.new(0,.18+.06*math.sin(t*5+sign),0)
  if mode=="Reach" then
   if side==(c:GetAttribute("InteractionHand") or "Right") then
    local base=gripWorld and (gripWorld.Position+gripWorld.LookVector*.2) or hanging
    aim=base+(target-base)*reach
   elseif side=="Right" and gripWorld then aim=gripWorld.Position end
  elseif mode=="LootUp" then
   local destination=gripWorld and (gripWorld.Position+(side=="Left" and gripWorld.LookVector*.2 or Vector3.zero)) or hanging
   local weight=side=="Right" and smooth(t/.18) or smooth((t-.3)/.3)
   aim=search+(destination-search)*weight
  elseif side=="Right" and gripWorld and mode=="LootDown" then
   local release=smooth((t-.65)/.25)
   aim=gripWorld.Position+(search-gripWorld.Position)*release
  else
   local base=gripWorld and mode=="LootDown" and (gripWorld.Position+gripWorld.LookVector*.2) or hanging
   aim=base+(search-base)*crouch
  end
  local s,e=IK.Arm(a,b,frame:VectorToObjectSpace(aim-frame.Position),Vector3.new(side=="Left" and -1 or 1,-1,.2))
  shoulder.Transform=standing:Inverse()*s;elbow.Transform=e
 end
 return true
end
return Pose
