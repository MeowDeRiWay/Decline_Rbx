-- Cosmetic model attributes never change damage, ammunition or gameplay timing.
local Presentation={}
local sets={Pistol=true,Rifle=true,Launcher=true,Knife=true,Axe=true,Shovel=true,Mine=true}
local reloads={Pistol=true,AR=true,Bullpup=true,SingleRound=true,Rocket=true,None=true}
local function attribute(model,name,allowed,fallback)
 local value=model and model:GetAttribute(name)
 return allowed[value] and value or fallback
end
function Presentation.AnimationSet(model,definition)
 definition=definition or {}
 local gun=definition.Firearm
 local fallback=definition.Trap and "Mine" or gun and (gun.Projectile=="Rocket" and "Launcher" or gun.Category=="Pistol" and "Pistol" or "Rifle")
  or definition.HarvestTool=="Axe" and "Axe" or definition.HarvestTool=="Shovel" and "Shovel" or (definition.Weapon or definition.CraftTool=="Knife") and "Knife" or nil
 return attribute(model,"AnimationSet",sets,fallback)
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
return Presentation
