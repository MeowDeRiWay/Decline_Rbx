local TweenService = game:GetService("TweenService")
local Motion = {}
local active = setmetatable({},{__mode="k"})
function Motion.Cancel(motor)
 local state = active[motor]
 if state then
  state.cancelled = true
  if state.tween then state.tween:Cancel() end
  active[motor] = nil
 end
end
function Motion.HitDelay(weapon)
 return (weapon.Animation == "SwingLeft" or weapon.DamageType == "Blunt") and .25 or 0
end
function Motion.Play(motor,weapon)
 if not motor or not motor.Parent then return end
 Motion.Cancel(motor)
 local base = motor:GetAttribute("RestC0")
 if not base then return end
 local state = {}
 active[motor] = state
 local function tween(target,duration)
  state.tween = TweenService:Create(motor,TweenInfo.new(duration,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{C0=target})
  state.tween:Play()
 end
 if (weapon.Animation == "SwingLeft" or weapon.DamageType == "Blunt") then
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
