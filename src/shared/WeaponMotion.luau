local TweenService = game:GetService("TweenService")
local Motion = {}
local active = setmetatable({},{__mode="k"})
function Motion.Cancel(motor)
 if not motor then return end
 local state = active[motor]
 if motor:GetAttribute("ChopStartedAt")~=nil or state and state.Chop then
  motor:SetAttribute("ChopStartedAt",nil);motor.Transform=CFrame.identity
 end
 if state then
  state.cancelled = true
  if state.tween then state.tween:Cancel() end
  active[motor] = nil
 end
end
function Motion.ChopTiming(weapon)
 -- Match the attack gate used by both Combat scripts: no idle tail after a chop.
 local duration=60/weapon.AttacksPerMinute
 local windup=duration*.6
 return windup,duration-windup
end
function Motion.HitDelay(weapon)
 if weapon.Animation=="Chop" then
  local windup,strike=Motion.ChopTiming(weapon)
  return windup+strike
 end
 if weapon.Animation=="Thrust" then return .15 end
 return (weapon.Animation == "SwingLeft" or weapon.DamageType == "Blunt") and .25 or 0
end
-- Axes use a clocked local Transform, never competing client/server C0 tweens.
-- The attacker predicts the accepted request; its matching acknowledgement keeps
-- the original phase, while other viewers sample the server timestamp directly.
function Motion.PredictChop(motor,weapon,now,sequence)
 if not motor or not motor.Parent then return end
 active[motor]={Chop=true,StartedAt=now,Duration=60/weapon.AttacksPerMinute,Sequence=sequence}
end
function Motion.StepChop(motor,now)
 if not motor or not motor.Parent then return nil,false end
 local base=motor:GetAttribute("RestC0")
 if not base then return nil,false end
 local start,duration= motor:GetAttribute("ChopStartedAt"),motor:GetAttribute("ChopDuration")
 local prediction=active[motor]
 if prediction and prediction.Chop and (motor:GetAttribute("ChopSequence")==prediction.Sequence or typeof(start)~="number" or start<=prediction.StartedAt) then
  start,duration=prediction.StartedAt,prediction.Duration
 end
 if typeof(start)~="number" or typeof(duration)~="number" or duration<=0 then return nil,false end
 local elapsed=now-start
 local windup=duration*.6
 local angle=0
 if elapsed>=0 and elapsed<windup then
  local t=elapsed/windup;angle=(1-(1-t)^2)*math.pi/2
 elseif elapsed>=windup and elapsed<duration then
  local t=(elapsed-windup)/(duration-windup);angle=(1-t)^2*math.pi/2
 end
 local target=CFrame.new(base.Position)*CFrame.Angles(angle,0,0)*CFrame.new(-base.Position)*base
 motor.Transform=base:Inverse()*target
 -- Return the actual grip-part frame for same-step hand IK. Reading the held
 -- model's previous physics pose here causes one-frame hand/weapon feedback.
 local frame=motor.Part0 and motor.Part0.CFrame*base*motor.Transform*(motor.C1 or CFrame.identity):Inverse()
 return frame,elapsed>=0 and elapsed<duration
end
function Motion.GripFrame(motor,attachment,frame)
 if not frame or not motor.Part1 or not attachment or not attachment:IsA("Attachment") then return frame end
 local offset=attachment.Parent==motor.Part1 and attachment.CFrame or motor.Part1.CFrame:ToObjectSpace(attachment.WorldCFrame)
 return frame*offset
end
function Motion.Play(motor,weapon,startedAt,sequence)
 if not motor or not motor.Parent then return end
 local base=motor:GetAttribute("RestC0")
 if not base then return end
 if weapon.Animation=="Chop" then
  -- Only the server calls Play for axes. Attributes announce one accepted swing
  -- to every viewer; rendering never streams C0 changes over replication.
  Motion.Cancel(motor)
  motor.C0=base
  motor:SetAttribute("ChopDuration",60/weapon.AttacksPerMinute)
  motor:SetAttribute("ChopSequence",sequence or 0)
  motor:SetAttribute("ChopStartedAt",startedAt or workspace:GetServerTimeNow())
  return
 end
 Motion.Cancel(motor)
 local state = {}
 active[motor] = state
 local function tween(target,duration)
  state.tween = TweenService:Create(motor,TweenInfo.new(duration,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{C0=target})
  state.tween:Play()
 end
 if weapon.Animation=="Thrust" then
  motor.C0=CFrame.new(0,0,.08)*base
  tween(CFrame.new(0,0,-(weapon.Thrust or .4))*base,.15)
  task.delay(.15,function() if not state.cancelled and motor.Parent then tween(base,.3) end end)
 elseif (weapon.Animation == "SwingLeft" or weapon.DamageType == "Blunt") then
  motor.C0 = CFrame.Angles(0,math.rad(-25),0)*base
  tween(CFrame.Angles(0,math.rad(110),0)*base,.25)
  task.delay(.25,function()
   if not state.cancelled and motor.Parent then tween(base,.35) end
  end)
 else
  motor.C0 = CFrame.new(0,0,-(weapon.Thrust or .5))*base
  tween(base,60/weapon.AttacksPerMinute)
 end
end
return Motion
