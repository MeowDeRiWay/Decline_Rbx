-- Attributes belong to the explosive projectile/trap, never its launcher.
local Rules={}
local function valid(value)
 return typeof(value)=="number" and value==value and value>=0 and value<math.huge
end
function Rules.Resolve(source,defaults)
 defaults=defaults or {}
 local function read(name,fallback)
  local value=source and source:GetAttribute(name)
  if valid(value) then return value end
  value=defaults[name]
  return valid(value) and value or fallback
 end
 local radius=read("BlastRadius",20)
 return {BlastRadius=radius,KillRadius=math.min(radius,read("KillRadius",5))}
end
function Rules.Sample(distance,settings,baseDamage)
 if distance<0 or distance~=distance or distance>settings.BlastRadius then return 0,false end
 if settings.KillRadius>0 and distance<=settings.KillRadius then return baseDamage,true end
 local span=settings.BlastRadius-settings.KillRadius
 if span<=0 then return 0,false end
 return baseDamage*math.clamp((settings.BlastRadius-distance)/span,0,1),false
end
return Rules
