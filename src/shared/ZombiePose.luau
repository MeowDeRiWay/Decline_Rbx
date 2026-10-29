-- One body, three persistent cosmetic archetypes. No dependency on a held hand.
local Z={Tag="DeclineAnimatedZombie",Weapon={DamageType="Blunt",Range=1,AttacksPerMinute=10}}
function Z.Assign(model,random)
 local kind=model:GetAttribute("ZombieAnimationType")
 if kind~=1 and kind~=2 and kind~=3 then kind=random:NextInteger(1,3);model:SetAttribute("ZombieAnimationType",kind) end
 local side=model:GetAttribute("ZombieAttackSide")
 if side~="Left" and side~="Right" then model:SetAttribute("ZombieAttackSide",random:NextInteger(1,2)==1 and "Left" or "Right") end
 if model:GetAttribute("ZombieAnimationPhase")==nil then model:SetAttribute("ZombieAnimationPhase",random:NextNumber(0,2*math.pi)) end
 return kind
end
function Z.Contact(kind) return kind==1 and .35 or (kind==2 and .4 or .25) end
local function pulse(t,contact)
 if t<0 or t>contact+.45 then return 0 end
 if t<=contact then return t/contact end
 return 1-(t-contact)/.45
end
function Z.Sample(size,kind,side,phase,elapsed)
 local hit=pulse(elapsed,Z.Contact(kind))
 local waist=math.rad(-(kind==1 and (30+28*hit) or (kind==2 and (28+8*hit) or (32+6*hit))))
 local result={Waist=CFrame.Angles(waist,0,0),Neck=CFrame.Angles(math.rad(12-(kind==1 and 22*hit or 0)),0,0)}
 for _,name in ipairs({"Left","Right"}) do
  local sign=name=="Left" and -1 or 1
  local target
  -- Directions, not nearby hand targets: both limb sections stay straight.
  if kind==1 then
   target=Vector3.new(sign*.03,-1,-.08)
  elseif kind==2 then
   local lift=-.12+.22*hit
   if elapsed>.4 and elapsed<.8 then lift=.10-.60*((elapsed-.4)/.4)
   elseif elapsed>=.8 and elapsed<1.1 then lift=-.50+.38*((elapsed-.8)/.3) end
   target=Vector3.new(sign*.05,lift,-1)
  elseif name==side then
   target=Vector3.new(sign*.04,-.10+.12*hit,-1)
  else
   -- A straight hanging arm sways as one limb; no bent-elbow combat guard.
   target=Vector3.new(sign*.03,-1,.08*math.sin(phase*.8))
  end
  result[name]=target
 end
 return result
end
return Z
