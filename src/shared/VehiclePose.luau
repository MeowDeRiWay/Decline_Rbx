local IK=require(script.Parent.CharacterPose)
local Pose={}
function Pose.Apply(character,root,motors,humanoid)
 local seat=humanoid.SeatPart
 if not seat or character:GetAttribute("VehicleSeated")~=true then return false end
 local vehicle=seat.Parent
 while vehicle and vehicle~=workspace and vehicle:GetAttribute("Vehicle")~=true do vehicle=vehicle.Parent end
 if not vehicle or vehicle==workspace then return false end
 local rootMotor=motors.RootJoint
 rootMotor.Transform=CFrame.identity
 motors.Waist.Transform=CFrame.Angles(math.rad(12),0,0)
 motors.Neck.Transform=CFrame.Angles(math.rad(-8),0,0)
 for _,side in ipairs({"Left","Right"}) do
  motors[side.."Hip"].Transform=CFrame.Angles(math.rad(95),0,0)
  motors[side.."Knee"].Transform=CFrame.Angles(math.rad(-55),0,0)
 end
 local lower=root.CFrame*rootMotor.C0*rootMotor.Transform*rootMotor.C1:Inverse()
 local waist=motors.Waist
 local chest=lower*waist.C0*waist.Transform*waist.C1:Inverse()
 local folder=vehicle:FindFirstChild("Components")
 local wheel=folder and folder:FindFirstChild("SteeringWheel_1")
 for _,side in ipairs({"Left","Right"}) do
  local shoulder,elbow=motors[side.."Shoulder"],motors[side.."Elbow"]
  local upper,forearm=shoulder:GetAttribute("UpperVector"),shoulder:GetAttribute("LowerVector")
  local rest=shoulder:GetAttribute("AuthoredC0")
  if not upper or not forearm or not rest then continue end
  local standing=shoulder:GetAttribute("StandingRotation") or CFrame.identity
  local anchor=(chest*rest*CFrame.new(shoulder:GetAttribute("StandingOffset") or Vector3.zero)).Position
  local target
  if seat:IsA("VehicleSeat") and wheel then
   for _,part in ipairs(wheel:GetDescendants()) do
    if part:IsA("BasePart") and part:GetAttribute("HandTarget")==side then
     local motor=wheel:FindFirstChild("VehicleJoint",true)
     local offset=part:GetAttribute("VehicleMountOffset")
     if motor and motor.Part0 and offset then
      local rotation=CFrame.Angles(0,0,-(vehicle:GetAttribute("Steering") or 0)*math.rad(120))
      target=(motor.Part0.CFrame*motor.C0*rotation*motor.C1:Inverse()*offset).Position
     else target=part.Position end
     break
    end
   end
  end
  target=target or root.CFrame:PointToWorldSpace(Vector3.new((side=="Left" and -1 or 1)*root.Size.X*.4,-root.Size.Y*.25,-.3))
  local a,b=IK.Arm(upper,forearm,chest:VectorToObjectSpace(target-anchor),Vector3.new(side=="Left" and -1 or 1,-1,.15),1)
  shoulder.Transform=standing:Inverse()*a;elbow.Transform=b
 end
 return true
end
return Pose
