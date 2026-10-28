local WorldActivity=require(script.Parent.WorldActivityService)
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local Players=game:GetService("Players")
local Rules=require(ReplicatedStorage.Shared.FirearmRules)
local Damage=require(script.Parent.DamageService)
local Accuracy=require(ReplicatedStorage.Shared.AccuracyRules)
local Service={}
local bullets,fx={},{}
local count,sequence=0,0
local random=Random.new()
local remote=Instance.new("RemoteEvent");remote.Name="FirearmEffects";remote.Parent=ReplicatedStorage
local function emit(kind,point,data)
 data=data or {};data.Kind=kind;data.Point=point;table.insert(fx,data)
end
local function material(part)
 local ancestor=part
 while ancestor and ancestor~=workspace do
  local value=ancestor:GetAttribute("Material")
  if typeof(value)=="string" then return value,ancestor end
  ancestor=ancestor.Parent
 end
 local name=part:IsA("BasePart") and part.Material.Name
 local map={Wood="Wood",WoodPlanks="Wood",Glass="Glass",Brick="Brick",Concrete="Concrete",Metal="Metal",DiamondPlate="Metal",CorrodedMetal="Metal"}
 return map[name],part
end
local function victimOf(part)
 local ancestor=part
 while ancestor and ancestor~=workspace do
  if ancestor:IsA("Model") then
   local hp=ancestor:FindFirstChildOfClass("Humanoid")
   if hp then return hp end
  end
  ancestor=ancestor.Parent
 end
end
local function block(part)
 return part:IsA("Part") and part.Shape==Enum.PartType.Block
end
local function barrier(hit,direction)
 local kind,group=material(hit.Instance)
 if not kind or not block(hit.Instance) then return nil end
 local parts=group==hit.Instance and {group} or group:GetDescendants()
 local intervals,entries={},{}
 for _,part in ipairs(parts) do
  if not block(part) or not part.CanQuery then continue end
  local value=material(part)
  if value~=kind then continue end
  local a,b=Rules.Interval(hit.Position,direction,part.CFrame,part.Size)
  if a and b>.000001 then table.insert(intervals,{a,b});table.insert(entries,{part,a,b}) end
  if #entries>=128 then break end
 end
 local merged=Rules.Merge(intervals)
 local span=merged[1]
 if not span or span[1]>.001 then return nil end
 local consumed={}
 for _,entry in ipairs(entries) do if entry[2]<=span[2] and entry[3]>=span[1] then table.insert(consumed,entry[1]) end end
 return kind,span[2],consumed
end
function Service.Fire(player,character,origin,direction,definition,ammoType,itemID)
 if count>=256 then return false end
 local sniperBonus=0
 if definition.Category=="Rifle" and definition.SingleOnly and definition.BoltAction~=false and (player:GetAttribute("SniperCriticalBonus") or 0)>0 then
  if workspace:GetServerTimeNow()-(player:GetAttribute("StationarySince") or workspace:GetServerTimeNow())>=2 then sniperBonus=player:GetAttribute("SniperCriticalBonus") end
 end
 sequence+=1;count+=1
 bullets[sequence]={ID=sequence,Player=player,Character=character,Position=origin,Direction=direction,
  Skill=Accuracy.ForWeapon(player,{Firearm=definition}),SightBonus=Accuracy.SightBonus(character:FindFirstChild("HeldItem")),Remaining=definition.Range,Initial=definition.Range,Speed=definition.Speed,Damage=random:NextInteger(definition.DamageMin or definition.Damage,definition.DamageMax or definition.Damage)*(definition.Category=="Pistol" and (player:GetAttribute("CowboyMultiplier") or 1) or 1),PostDefenseDamage=player:GetAttribute("RangedDamageBonus") or 0,
  SniperBonus=sniperBonus,Caliber=definition.Caliber,AmmoType=ammoType,ItemID=itemID,Category=definition.Category or "Rifle",IgnoredDormant={},BoltAction=definition.Category=="Rifle" and definition.SingleOnly==true and definition.BoltAction~=false,Ignored={character},Impacts=0}
 emit("Muzzle",origin)
 return true
end
local function damageVictim(bullet,victim)
 if not victim.Parent or victim.Health<=0 then return end
if Damage.RollHit(bullet.Player,victim,bullet.SightBonus,bullet.Skill) then
 victim.Parent:SetAttribute("LastDamagerID",bullet.Player.UserId)
 victim.Parent:SetAttribute("LastHitItem",bullet.ItemID)
 local sniper=bullet.SniperBonus or 0
 local critical=random:NextNumber()<((sniper)+(bullet.Player:GetAttribute("CriticalChance") or 0)+(bullet.Category=="Pistol" and (bullet.Player:GetAttribute("PistolCriticalBonus") or 0) or 0))
 local multiplier=critical and random:NextNumber(bullet.Player:GetAttribute("CriticalMin") or 1.5,bullet.Player:GetAttribute("CriticalMax") or 2) or 1
 local ignoreAbsorption,ignoreResistance=Rules.ArmorIgnore(bullet.Caliber,bullet.AmmoType)
 local dealt=Damage.Apply(victim,bullet.Damage*math.max(.1,bullet.Remaining/bullet.Initial),"Bullet",bullet.Position-bullet.Direction,"Ranged",{HitChecked=true,CriticalMultiplier=multiplier,Attacker=bullet.Player,PostDefenseDamage=bullet.PostDefenseDamage,ArmorIgnoreAbsorption=ignoreAbsorption,ArmorIgnoreResistance=ignoreResistance})
 if dealt>0 and bullet.BoltAction and random:NextNumber()<(bullet.Player:GetAttribute("DisarmChance") or 0) then
  local targetPlayer=Players:GetPlayerFromCharacter(victim.Parent)
  if targetPlayer then require(script.Parent.WorldItemService).Disarm(targetPlayer)
  else require(script.Parent.WorldItemService).DisarmCreature(victim.Parent) end
 end
else Damage.Miss(victim.Parent,bullet.Player,"Ranged") end
end
RunService.Heartbeat:Connect(function(dt)
 for id,bullet in pairs(bullets) do
  local distance=math.min(bullet.Speed*math.min(dt,.1),bullet.Remaining)
  local stopped=false
  for _=1,16 do
   if distance<=.00001 or bullet.Remaining<=.00001 then break end
   local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances=bullet.Ignored
   local hit=workspace:Raycast(bullet.Position,bullet.Direction*distance,params)
   local dormant=WorldActivity.Raycast(bullet.Position,bullet.Direction*distance,bullet.Ignored,bullet.IgnoredDormant)
   if dormant and (not hit or dormant.Distance<(hit.Position-bullet.Position).Magnitude) then hit=dormant else dormant=nil end
   if not hit then bullet.Position+=bullet.Direction*distance;bullet.Remaining-=distance;break end
   local traveled=(hit.Position-bullet.Position).Magnitude
   bullet.Remaining-=traveled;distance-=traveled;bullet.Position=hit.Position
   bullet.Impacts+=1
   if bullet.Impacts>64 then stopped=true;break end
   local victim=victimOf(hit.Instance)
   if victim and victim.Health>0 then
    if dormant then
     local savedHit=dormant
     task.spawn(function() WorldActivity.ResolveHit(savedHit);damageVictim(bullet,victim) end)
    else damageVictim(bullet,victim) end
    emit("Impact",hit.Position,{Direction=hit.Normal,Material="Flesh"});stopped=true;break
   end
   local kind,thickness,parts
   if dormant then kind,thickness,parts=WorldActivity.Barrier(dormant,bullet.Direction)
   else kind,thickness,parts=barrier(hit,bullet.Direction) end
   emit("Impact",hit.Position,{Direction=hit.Normal,Material=kind or "Concrete"})
   if not kind then stopped=true;break end
   local cost=Rules.Cost(kind,thickness,bullet.Caliber)
   if cost>=bullet.Remaining then
    bullet.Position+=bullet.Direction*(thickness*bullet.Remaining/cost);stopped=true;break
   end
   bullet.Remaining-=cost
   -- Traverse the material without another collision against its visual layers.
   bullet.Position+=bullet.Direction*(thickness+.0001)
   distance=math.max(0,distance-thickness)
   for _,part in ipairs(parts) do
    if dormant then
     bullet.IgnoredDormant[part]=true
     if part.Part then table.insert(bullet.Ignored,part.Part) end
    else table.insert(bullet.Ignored,part) end
   end
   bullet.Speed*=math.sqrt(math.max(.1,bullet.Remaining/(bullet.Remaining+cost)))
   emit("Impact",bullet.Position,{Direction=bullet.Direction,Material=kind,Exit=true})
  end
  emit("Trace",bullet.Position,{ID=id,Direction=bullet.Direction})
  if stopped or bullet.Remaining<=.00001 then emit("Stop",bullet.Position,{ID=id});bullets[id]=nil;count-=1 end
 end
 if #fx==0 then return end
 for _,player in ipairs(Players:GetPlayers()) do
  local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
  if not root then continue end
  local nearby={}
  for _,event in ipairs(fx) do if (event.Point-root.Position).Magnitude<=200 then table.insert(nearby,event) end end
  if #nearby>0 then remote:FireClient(player,nearby) end
 end
 table.clear(fx)
end)
return Service
