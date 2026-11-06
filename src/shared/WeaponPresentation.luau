-- Cosmetic model attributes never change damage, ammunition or gameplay timing.
local Presentation={}
local sets={Pistol=true,Rifle=true,Launcher=true,Knife=true,Axe=true,Shovel=true,Mine=true,Tool=true}
local reloads={Pistol=true,AR=true,Bullpup=true,SingleRound=true,Rocket=true,None=true}
local function attribute(model,name,allowed,fallback)
 local value=model and model:GetAttribute(name)
 return allowed[value] and value or fallback
end
function Presentation.AnimationSet(model,definition)
 definition=definition or {}
 local gun=definition.Firearm
 local fallback=definition.UtilityTool and "Tool" or definition.Trap and "Mine" or gun and (gun.Projectile=="Rocket" and "Launcher" or gun.Category=="Pistol" and "Pistol" or "Rifle")
  or definition.HarvestTool=="Axe" and "Axe" or definition.HarvestTool=="Shovel" and "Shovel" or (definition.Weapon or definition.CraftTool=="Knife") and "Knife" or nil
 return attribute(model,"AnimationSet",sets,fallback)
end
-- Small hand tools rest just ahead of the right hip/chest, within bent-arm reach.
function Presentation.ToolGrip(root)
 return root.CFrame*CFrame.new(root.Size.X*.6,root.Size.Y*.1,-root.Size.Z*.5-root.Size.Y*.55)
end
function Presentation.ReloadType(model,definition,id)
 local gun=definition and definition.Firearm
 local fallback="None"
 if gun then
  fallback=gun.Projectile=="Rocket" and "Rocket"
   or (gun.ManualReload or gun.BoltAction==true) and "SingleRound"
   or gun.Category=="Pistol" and "Pistol"
   or (id=="LSW223" or id=="MarksmanRifle223") and "Bullpup" or "AR"
 end
 return attribute(model,"ReloadType",reloads,fallback)
end
-- Named components use their geometric center, never an authored pivot.
-- Convert through the grip motor's predicted frame to avoid one-frame IK lag.
function Presentation.PartFrame(model,name,motor,world)
 local part=model and model:FindFirstChild(name,true)
 if not part then return nil end
 local frame
 if part:IsA("Model") then
  if not part:FindFirstChildWhichIsA("BasePart",true) then return nil end
  frame=part:GetBoundingBox()
 elseif part:IsA("BasePart") then frame=part.CFrame end
 if frame and world and motor and motor.Part1 then
  frame=world*motor.Part1.CFrame:ToObjectSpace(frame)
 end
 return frame
end
function Presentation.RestFrame(rest,kind,weight)
 local shift=kind=="Pistol" and Vector3.new(.12,-.35,.15) or Vector3.new(0,-.28,.08)
 -- Rotate around the right-hand grip, independent of the authored part axes.
 return CFrame.new(rest.Position+shift*weight)*CFrame.Angles(math.rad(-35)*weight,0,0)*(rest-rest.Position)
end
return Presentation
