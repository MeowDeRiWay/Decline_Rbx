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
function Service.Detonate(point,settings,attacker,character,itemID,baseDamage,options)
 options=options or {}
 task.spawn(function()
  WorldActivity.Ensure(point,settings.BlastRadius+2)
  local victims={}
  for _,part in ipairs(workspace:GetPartBoundsInRadius(point,settings.BlastRadius+3)) do
   local hp=victimOf(part)
   if hp then victims[hp]=true end
  end
  local shooter=character and character:FindFirstChildOfClass("Humanoid")
  if shooter then victims[shooter]=true end
  local trigger=options.TriggerCharacter and options.TriggerCharacter:FindFirstChildOfClass("Humanoid")
  if trigger then victims[trigger]=true end
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
   if attacker or options.OwnerUserId then model:SetAttribute("LastDamagerID",options.OwnerUserId or attacker.UserId) end
   model:SetAttribute("LastHitItem",itemID)
   local victim=options.OnDamage and game:GetService("Players"):GetPlayerFromCharacter(model)
   local dealt=Damage.Apply(hp,amount,"Explosive",point,"Explosion",{HitChecked=true,Attacker=attacker,FriendlyFire=options.FriendlyFire or model==character,InstantKill=lethal})
   if options.OnDamage and dealt>0 then
    local ok,err=pcall(options.OnDamage,hp,dealt,victim)
    if not ok then warn("[Decline explosion notice] "..tostring(err)) end
   end
  end
 end)
end
return Service
