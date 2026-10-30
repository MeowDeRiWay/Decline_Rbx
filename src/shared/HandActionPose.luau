-- Shared handoff timing and pivot convention for stored weapons and hand poses.
local IK=require(script.Parent.CharacterPose)
local Pose={StowDuration=.5,StowContact=.36,DrawDuration=.55,DrawContact=.18,TreatDuration=2.2,TreatContact=1.6}
local function smooth(t) t=math.clamp(t,0,1);return t*t*(3-2*t) end
function Pose.StorageFrame(c,root,slot)
 local torso=c:FindFirstChild(slot=="SecondaryWeapon" and "LowerTorso" or "UpperTorso") or root
 local attachment=torso:FindFirstChild(slot.."Holster")
 if attachment and attachment:IsA("Attachment") then return attachment.WorldCFrame end
 if slot=="PrimaryWeapon" then
  return torso.CFrame*CFrame.new(-torso.Size.X*.42,-torso.Size.Y*.25,torso.Size.Z/2+.16)*CFrame.Angles(math.rad(95),0,math.rad(-18))
 elseif slot=="SecondaryWeapon" then
  return torso.CFrame*CFrame.new(torso.Size.X/2+.13,-torso.Size.Y*.5,.02)*CFrame.Angles(math.rad(-90),0,0)
 end
 return root.CFrame*CFrame.new(root.Size.X*.5,-root.Size.Y*.2,-root.Size.Z*.3)
end
function Pose.Weight(mode,t)
 if mode=="Stow" then return smooth(t/Pose.StowContact) end
 if mode=="Draw" then return 1-smooth((t-Pose.DrawContact)/(Pose.DrawDuration-Pose.DrawContact)) end
 return 0
end
-- Returns hand targets; the ordinary gait continues during weapon switches.
function Pose.Apply(c,root,m,now)
 local mode=c:GetAttribute("HandAction")
 if not mode then return false end
 local t=math.max(0,now-(c:GetAttribute("HandActionStartedAt") or now))
 local slot=c:GetAttribute("HandActionSlot") or "Hands"
 local held=c:FindFirstChild("HeldItem")
 local motor=held and held:FindFirstChild("WeaponGrip")
 local storage=Pose.StorageFrame(c,root,slot)
 local gripWorld
 if motor and motor.Part1 then
  local rest=motor:GetAttribute("RestC0") or motor.C0
  local localFrame=rest
  if mode=="Stow" or mode=="Draw" then
   local grip=held:FindFirstChild("_HandGrip",true)
   local desired=storage*(grip and grip.CFrame or CFrame.identity):Inverse()
   localFrame=rest:Lerp(root.CFrame:ToObjectSpace(desired),Pose.Weight(mode,t))
  elseif mode=="TreatSelf" or mode=="TreatOther" then
   local point=c:GetAttribute("HandTreatmentPoint") or root.CFrame:PointToWorldSpace(Vector3.new(0,0,-.4))
   if mode=="TreatSelf" then point=root.CFrame:PointToWorldSpace(Vector3.new(-root.Size.X*.18,root.Size.Y*.2,-root.Size.Z/2-.12)) end
   point+=root.CFrame.RightVector*(math.sin(t*10)*.045)+Vector3.new(0,math.sin(t*7)*.025,0)
   localFrame=CFrame.new(root.CFrame:PointToObjectSpace(point))*(rest-rest.Position)
   localFrame=rest:Lerp(localFrame,smooth(t/.25))
  end
  motor.Transform=motor.C0:Inverse()*localFrame
  local grip=held:FindFirstChild("_HandGrip",true)
  local world=root.CFrame*localFrame*(motor.C1 or CFrame.identity):Inverse()
  gripWorld=grip and world*grip.CFrame or world
 end
 for _,side in ipairs({"Left","Right"}) do
  local shoulder,elbow=m[side.."Shoulder"],m[side.."Elbow"]
  local rest=shoulder:GetAttribute("AuthoredC0")
  local upper,lower=shoulder:GetAttribute("UpperVector"),shoulder:GetAttribute("LowerVector")
  if not rest or not upper or not lower or not shoulder.Part0 or not shoulder.Part1 or not elbow.Part0 or not elbow.Part1 then continue end
  local standing=shoulder:GetAttribute("StandingRotation") or CFrame.identity
  local anchor=(shoulder.Part0.CFrame*rest*CFrame.new(shoulder:GetAttribute("StandingOffset") or Vector3.zero)).Position
  local aim
  if mode=="Stow" or mode=="Draw" then
   if side=="Right" then
    aim=gripWorld and gripWorld.Position or storage.Position
    if mode=="Draw" and not gripWorld then
     local fromSlot=c:GetAttribute("HandActionFromSlot")
     local from=fromSlot and Pose.StorageFrame(c,root,fromSlot).Position or (anchor+root.CFrame:VectorToWorldSpace(standing:VectorToWorldSpace(upper+lower)))
     aim=from+(storage.Position-from)*smooth(t/Pose.DrawContact)
    end
   elseif slot=="PrimaryWeapon" and gripWorld then aim=gripWorld.Position+gripWorld.LookVector*.18 end
  else
   local point=c:GetAttribute("HandTreatmentPoint") or root.Position
   if mode=="TreatSelf" then point=root.CFrame:PointToWorldSpace(Vector3.new(-root.Size.X*.18,root.Size.Y*.2,-root.Size.Z/2-.12)) end
   aim=point+root.CFrame.RightVector*(side=="Left" and -.08 or .08)+Vector3.new(0,math.sin(t*8+(side=="Left" and math.pi or 0))*.035,0)
   if mode=="TreatOther" then m.Waist.Transform=CFrame.Angles(math.rad(-18),0,0) end
  end
  if aim then
   local s,e=IK.Arm(upper,lower,root.CFrame:VectorToObjectSpace(aim-anchor),Vector3.new(side=="Left" and -1 or 1,-1,.2))
   shoulder.Transform=standing:Inverse()*s;elbow.Transform=e
  end
 end
 return true
end
return Pose
