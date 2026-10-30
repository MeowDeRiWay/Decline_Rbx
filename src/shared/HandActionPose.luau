-- Shared handoff timing and pivot convention for stored weapons and hand poses.
local IK=require(script.Parent.CharacterPose)
local Pose={StowDuration=.5,StowContact=.36,DrawDuration=.55,DrawContact=.18,TreatDuration=2.2,TreatContact=1.6}
local function smooth(t) t=math.clamp(t,0,1);return t*t*(3-2*t) end
function Pose.StorageFrame(c,root,slot)
 local torso=c:FindFirstChild(slot=="SecondaryWeapon" and "LowerTorso" or "UpperTorso") or root
 local attachment=torso:FindFirstChild(slot.."Holster")
 if attachment and attachment:IsA("Attachment") then return attachment.WorldCFrame end
 if slot=="PrimaryWeapon" then
  return torso.CFrame*CFrame.new(torso.Size.X*.42,torso.Size.Y*.15,torso.Size.Z/2+.16)*CFrame.Angles(0,0,math.rad(-10))*CFrame.Angles(math.rad(95),0,math.pi)
 elseif slot=="SecondaryWeapon" then
  return torso.CFrame*CFrame.new(torso.Size.X/2+.13,-torso.Size.Y*.5,.02)*CFrame.Angles(math.rad(-90),0,0)
 end
 return root.CFrame*CFrame.new(root.Size.X*.5,-root.Size.Y*.2,-root.Size.Z*.3)
end
-- The long weapon travels beside and above the right shoulder. A direct lerp
-- from the firing grip to the back would send it through the chest.
function Pose.WeaponFrame(c,root,slot,heldFrame,weight)
 local stored=Pose.StorageFrame(c,root,slot)
 if slot~="PrimaryWeapon" then return heldFrame:Lerp(stored,weight) end
 local torso=c:FindFirstChild("UpperTorso") or root
 local rotation=torso.CFrame:ToObjectSpace(stored)
 rotation=rotation-rotation.Position
 local x=torso.Size.X/2+.18
 local y=torso.Size.Y/2+.18
 local z=torso.Size.Z/2+.22
 local front=torso.CFrame*CFrame.new(x,y,-z)*rotation
 local back=torso.CFrame*CFrame.new(x,y,z)*rotation
 -- Clear the side before rotating. Rolling 180 degrees during a single
 -- chest-to-back lerp sweeps the stock through the body on real rifle models.
 local side=CFrame.new(front.Position)*(heldFrame-heldFrame.Position)
 local raised=front*CFrame.Angles(0,0,-math.pi)
 if weight<.20 then return heldFrame:Lerp(side,smooth(weight/.20)) end
 if weight<.38 then return side:Lerp(raised,smooth((weight-.20)/.18)) end
 if weight<.78 then
  local progress=smooth((weight-.38)/.40)
  -- Roll gradually while crossing above the shoulder, rather than snapping
  -- through a half-turn in one short frame at the front of the chest.
  return raised:Lerp(back*CFrame.Angles(0,0,-math.pi),progress)*CFrame.Angles(0,0,math.pi*progress)
 end
 return back:Lerp(stored,smooth((weight-.78)/.22))
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
   local gripOffset=grip and grip.CFrame or CFrame.identity
   local heldFrame=root.CFrame*rest*gripOffset
   local desired=Pose.WeaponFrame(c,root,slot,heldFrame,Pose.Weight(mode,t))*gripOffset:Inverse()
   localFrame=root.CFrame:ToObjectSpace(desired)
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
     local progress=smooth(t/Pose.DrawContact)
     if slot=="PrimaryWeapon" then
      aim=Pose.WeaponFrame(c,root,slot,CFrame.new(from),progress).Position
     else aim=from+(storage.Position-from)*progress end
    end
   elseif slot=="PrimaryWeapon" or slot=="SecondaryWeapon" then
    -- Only the right hand draws/stows. Release the support hand early when
    -- stowing and blend it into the firing grip only after the draw is clear.
    local support=mode=="Draw" and smooth((t-(Pose.DrawDuration-.14))/.14) or 1-smooth(t/.12)
    shoulder.Transform=CFrame.identity:Lerp(shoulder.Transform,support)
    elbow.Transform=CFrame.identity:Lerp(elbow.Transform,support)
   end
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
