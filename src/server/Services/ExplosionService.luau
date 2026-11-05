-- Shared server blast path for rockets and future explosive traps.
local WorldActivity=require(script.Parent.WorldActivityService)
local Shared=game:GetService("ReplicatedStorage").Shared
local Rules=require(Shared.ExplosionRules)
local BulletCast=require(Shared.BulletCast)
local Damage=require(script.Parent.DamageService)
local Service={}
local function victimOf(part)
 local model=part
 while model and model~=workspace do
  if model:IsA("Model") then
   local hp=model:FindFirstChildOfClass("Humanoid")
   if hp then return hp end
  end
  model=model.Parent
 end
end
-- Resolve attributes when arming a trap, or snapshot rocket settings on launch.
function Service.Detonate(point,settings,attacker,character,itemID,baseDamage)
 task.spawn(function()
  WorldActivity.Ensure(point,settings.BlastRadius+2)
  local victims={}
  for _,part in ipairs(workspace:GetPartBoundsInRadius(point,settings.BlastRadius+3)) do
   local hp=victimOf(part)
   if hp then victims[hp]=true end
  end
  local shooter=character and character:FindFirstChildOfClass("Humanoid")
  if shooter then victims[shooter]=true end
  local ignored={}
  for hp in pairs(victims) do table.insert(ignored,hp.Parent) end
  if character and not shooter then table.insert(ignored,character) end
  for hp in pairs(victims) do
   local model=hp.Parent
   local root=model and (model:FindFirstChild("HumanoidRootPart") or model:FindFirstChildWhichIsA("BasePart",true))
   if not root or hp.Health<=0 then continue end
   local amount,lethal=Rules.Sample((root.Position-point).Magnitude,settings,baseDamage)
   if amount<=0 and not lethal then continue end
   if not lethal and BulletCast.Raycast(point,root.Position-point,ignored) then amount*=.5 end
   if attacker then model:SetAttribute("LastDamagerID",attacker.UserId) end
   model:SetAttribute("LastHitItem",itemID)
   Damage.Apply(hp,amount,"Explosive",point,"Explosion",{HitChecked=true,Attacker=attacker,FriendlyFire=model==character,InstantKill=lethal})
  end
 end)
end
return Service
