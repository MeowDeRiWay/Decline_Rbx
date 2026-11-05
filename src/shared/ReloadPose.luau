-- Sample one server-announced reload on every viewer; no per-frame remotes.
local Reload={}
local function smooth(t) t=math.clamp(t,0,1);return t*t*(3-2*t) end
function Reload.Sample(kind,t,rounds)
 t=math.clamp(t,0,1)
 local weight=smooth(t/.2)*(1-smooth((t-.8)/.2))
 local cycle=math.clamp((t-.2)/.6,0,1)*math.max(1,rounds or 1)
 local insertion=kind=="SingleRound" and (.5-.5*math.cos(cycle*2*math.pi)) or math.clamp((t-.3)/.4,0,1)
 return weight,smooth(insertion)
end
function Reload.Frame(kind,rest,t)
 local weight=Reload.Sample(kind,t)
 local shift=kind=="Rocket" and Vector3.new(0,-.5,-.15) or Vector3.new(0,-.15,.08)
 local rotation=rest-rest.Position
 if kind=="Rocket" then
  -- Tip the muzzle forward/down; the rear opening faces up for top loading.
  return CFrame.new(rest.Position+shift*weight)*CFrame.Angles(-math.pi/2*weight,0,0)*rotation
 end
 return CFrame.new(rest.Position+shift*weight)*rotation*CFrame.Angles(math.rad(12)*weight,0,0)
end
function Reload.Apply(c,root,held,motor,now)
 if not held or not motor or not motor.Part1 or not c:GetAttribute("Reloading") then return end
 if c:GetAttribute("ReloadItemID")~=held:GetAttribute("Item_ID") then return end
 local start,duration=c:GetAttribute("ReloadStartedAt"),c:GetAttribute("ReloadDuration")
 if typeof(start)~="number" or typeof(duration)~="number" or duration<=0 then return end
 local t=(now-start)/duration
 if t<0 or t>=1 then return end
 local kind=c:GetAttribute("ReloadVisualType") or "None"
 if kind=="None" then return end
 local rest=motor:GetAttribute("RestC0") or motor.C0
 local desired=Reload.Frame(kind,rest,t)
 motor.Transform=motor.C0:Inverse()*desired
 local world=root.CFrame*desired*(motor.C1 or CFrame.identity):Inverse()
 local function anchor(name,fallback)
  local attachment=held:FindFirstChild(name,true)
  if attachment and attachment:IsA("Attachment") then
   local offset=motor.Part1.CFrame:ToObjectSpace(attachment.WorldCFrame)
   return (world*offset).Position
  end
  return (world*CFrame.new(fallback)).Position
 end
 local right=anchor("RightHandGrip",Vector3.zero)
 if not held:FindFirstChild("RightHandGrip",true) then right=anchor("_HandGrip",Vector3.zero) end
 local support=anchor("LeftHandGrip",Vector3.new(0,0,-.25))
 local weight,insertion=Reload.Sample(kind,t,c:GetAttribute("ReloadRoundCount"))
 -- Optional authored targets keep the same animation usable across model sizes.
 local load
 if kind=="Rocket" then
  load=anchor("ReloadGrip",Vector3.new(0,0,.65))
  if not held:FindFirstChild("ReloadGrip",true) then load=anchor("_BackblastOrigin",Vector3.new(0,0,.65)) end
  local tubeDirection=root.CFrame:VectorToWorldSpace(CFrame.Angles(-math.pi/2*weight,0,0).LookVector)
  load-=tubeDirection*(.4*(1-insertion))
 elseif kind=="SingleRound" then
  load=anchor("ReloadGrip",Vector3.new(0,.12,.05))+root.CFrame.UpVector*(.2*(1-insertion))
 else
  local position=kind=="Bullpup" and Vector3.new(0,-.22,.35) or kind=="Pistol" and Vector3.new(0,-.22,0) or Vector3.new(0,-.22,-.15)
  load=anchor("ReloadGrip",position)-root.CFrame.UpVector*(.35*(1-insertion))
 end
 -- Bullpups keep the front support hand planted while the right hand loads.
 if kind=="Bullpup" then return world,right+(load-right)*weight,support end
 return world,right,support+(load-support)*weight
end
return Reload
