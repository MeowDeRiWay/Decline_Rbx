local Players = game:GetService("Players")
local Life = require(script.Parent.PlayerLifeService)
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local report=Instance.new("RemoteEvent");report.Name="CombatReport";report.Parent=ReplicatedStorage
local Defense=require(ReplicatedStorage.Shared.DefenseRules)
local Affiliation=require(ReplicatedStorage.Shared.AffiliationRules)
local Accuracy=require(ReplicatedStorage.Shared.AccuracyRules)
local Items=require(ReplicatedStorage.Shared.ItemConfig).Items
local Audio=require(script.Parent.CombatAudio)
local Service = {}
local function friendly(attacker,target)
 if not attacker then return false end
 local source=attacker:IsA("Player") and attacker or Players:GetPlayerFromCharacter(attacker)
 return Affiliation.Friendly(source,Players:GetPlayerFromCharacter(target) or (target:GetAttribute("OfflineUserId") and target))
end
local function announce(target,kind,amount,attacker,attackKind,critical,knockout)
 local victim=Players:GetPlayerFromCharacter(target)
 local attackerPlayer=attacker and attacker:IsA("Player")
 local actor=attackerPlayer and attacker.Character or attacker
 local actorName=attacker and (attackerPlayer and (attacker.DisplayName or attacker.Name) or (attacker:GetAttribute("DisplayName") or attacker.Name)) or "Unknown attacker"
 local humanoid=target:FindFirstChildOfClass("Humanoid")
 local payload={Target=target,Actor=actor,ActorName=actorName,
  TargetName=victim and (victim.DisplayName or victim.Name) or (target:GetAttribute("DisplayName") or target.Name),
  ActorUserId=attackerPlayer and attacker.UserId or nil,TargetUserId=victim and victim.UserId or nil,TargetIsCreature=victim==nil,ActorIsCreature=not attackerPlayer,Kind=kind,Damage=amount,AttackKind=attackKind,Critical=critical==true,
  Killed=humanoid and humanoid.Health<=0 or false,Knockout=knockout==true}
 local offlineID=target:GetAttribute("OfflineUserId")
 if offlineID then payload.TargetUserId=offlineID;payload.TargetIsCreature=false end
 local position=target:GetPivot().Position
 -- Bound network traffic; exact camera/sector/wall visibility is checked locally.
 for _,observer in ipairs(Players:GetPlayers()) do
  local root=observer.Character and observer.Character:FindFirstChild("HumanoidRootPart")
  if root and (root.Position-position).Magnitude<=250+(observer:GetAttribute("ViewBonus") or 0)*10 then report:FireClient(observer,payload) end
 end
end
function Service.Miss(target,attacker,attackKind)
 local victim=Players:GetPlayerFromCharacter(target)
 if victim and victim:GetAttribute("AttributesConfirmed")==false then return end
 if friendly(attacker,target) then return end
 local actor=attacker and (attacker:IsA("Player") and attacker.Character or attacker)
 local owner=attacker and attacker:IsA("Player") and attacker.UserId or nil
 if attackKind=="Ranged" then Audio.Play(target,"ShotEvade",owner) else Audio.Play(actor,"Miss",owner) end
 announce(target,"Miss",0,attacker,attackKind)
end
local function armorClass(actor,model)
 local value=actor:GetAttribute("DodgeChance") or 0
 local hands=model and model:GetAttribute("HandsItem")
 if not hands or hands=="" then value+=actor:GetAttribute("UnarmedArmorClass") or 0 end
 return value
end
function Service.RollHit(attacker,humanoid,bonus,skill)
 if attacker:IsA("Player") and attacker:GetAttribute("AttributesConfirmed")==false then return false end
 if friendly(attacker,humanoid.Parent) then return false end
 local defender=Players:GetPlayerFromCharacter(humanoid.Parent)
 if defender and defender:GetAttribute("AttributesConfirmed")==false then return false end
 local dodge=armorClass(defender or humanoid.Parent,humanoid.Parent)
 local character=attacker:IsA("Player") and attacker.Character or attacker
 local root=character and character:FindFirstChild("HumanoidRootPart")
 local target=humanoid.Parent:FindFirstChild("HumanoidRootPart",true) or humanoid.Parent:FindFirstChildWhichIsA("BasePart",true)
 if not root or not target then return false end
 local chance=Accuracy.Chance(skill or Accuracy.ForWeapon(attacker,Items[character:GetAttribute("HandsItem")]),bonus,(target.Position-root.Position).Magnitude,dodge,Accuracy.NightMultiplier(attacker))/100
 return math.random()<chance
end
function Service.Apply(humanoid,amount,damageType,sourcePosition,attackKind,options)
 local target = humanoid.Parent
 if not target or humanoid.Health <= 0 or target:GetAttribute("Knockout") then return 0 end
 options=options or {}
 if friendly(options.Attacker,target) then return 0 end
 local victim=Players:GetPlayerFromCharacter(target)
 if victim and victim:GetAttribute("AttributesConfirmed")==false then return 0 end
 if options.Attacker and options.Attacker:IsA("Player") and options.Attacker:GetAttribute("AttributesConfirmed")==false then return 0 end
 if sourcePosition then
  local delta = target:GetPivot().Position-sourcePosition
  delta = Vector3.new(delta.X,0,delta.Z)
  if delta.Magnitude > .001 then target:SetAttribute("LastHitDirection",delta.Unit) end
 end
 local before = humanoid.Health
 local wasKnockedOut=target:GetAttribute("Knockout")==true
 local player=Players:GetPlayerFromCharacter(target)
 options=options or {}
 local dodge=player and armorClass(player,target) or 0
 if not options.HitChecked and dodge>0 and math.random()<math.clamp(dodge/100,0,1) then
  target:SetAttribute("LastDamage",0);target:SetAttribute("LastDamageDodged",true);announce(target,"Dodge",0,options.Attacker,attackKind);return 0
 end
 target:SetAttribute("LastDamageDodged",false)
 local attacker=options.Attacker
 local attackerPlayer=attacker and attacker:IsA("Player") and attacker or nil
 local bypass=attackerPlayer and math.random()<(attackerPlayer:GetAttribute("ArmorBypassChance") or 0) or false
 local multiplier=options.CriticalMultiplier or 1
 if attackKind=="Melee" and attackerPlayer and attackerPlayer:GetAttribute("BackstabCritical") then
  local source=attackerPlayer.Character and attackerPlayer.Character:FindFirstChild("HumanoidRootPart")
  local body=target:FindFirstChild("HumanoidRootPart")
  if source and body then
   local offset=source.Position-body.Position
   local facing=body.CFrame.LookVector
   if offset.X*facing.X+offset.Z*facing.Z<0 then multiplier=2.5 end
  end
 end
 target:SetAttribute("LastArmorBypass",bypass)
 local negation=player and (player:GetAttribute("CriticalNegation") or 0) or 0
 if not bypass and multiplier>1 and negation>0 and math.random()<negation then multiplier=1 end
 local ignoreAbsorption=attackKind=="Melee" and attackerPlayer and (attackerPlayer:GetAttribute("MeleeIgnoreAbsorption") or 0) or 0
 local ignoreResistance=attackKind=="Melee" and attackerPlayer and (attackerPlayer:GetAttribute("MeleeIgnoreResistance") or 0) or 0
 local function resolve(value,resistance,absorption)
  return Defense.Resolve(value,math.max(0,math.clamp(resistance,0,.9)-ignoreResistance),math.max(0,absorption-ignoreAbsorption))
 end
 local postDefense=attackKind=="Ranged" and math.max(0,options.PostDefenseDamage or 0) or 0
 amount*=multiplier
 target:SetAttribute("LastDamageCritical",multiplier>1)
 if player then
  if target:FindFirstChildOfClass("ForceField") then amount=0
  else
   local absorption=(player:GetAttribute("ArmorAbsorption") or 0)+(player:GetAttribute("DamageAbsorption") or 0)+(attackKind=="Melee" and (player:GetAttribute("MeleeAbsorption") or 0) or 0)
   amount=(bypass and amount or resolve(amount,(player:GetAttribute("ArmorResistance") or 0)+(player:GetAttribute("DamageResistance") or 0)+(humanoid.Health<humanoid.MaxHealth*.25 and (player:GetAttribute("LowHealthResistance") or 0) or 0),absorption))+postDefense
   amount=amount>0 and Life.Damage(player,humanoid,amount,true,true) or 0
  end
 elseif target.Name == "Mannikin" then
  -- Training targets reset on the lethal hit without entering the Dead state.
  if not target:FindFirstChildOfClass("ForceField") then
   amount=(bypass and amount or resolve(amount,(target:GetAttribute("DamageResistance") or 0)+(target:GetAttribute("ArmorResistance") or 0),(target:GetAttribute("DamageAbsorption") or 0)+(target:GetAttribute("ArmorAbsorption") or 0)))+postDefense
   local remaining = math.max(0,before-amount)
   humanoid.Health = remaining > 0 and remaining or humanoid.MaxHealth
   amount = math.min(before,amount)
  else amount = 0 end
 else
  amount=(bypass and amount or resolve(amount,(target:GetAttribute("DamageResistance") or 0)+(target:GetAttribute("ArmorResistance") or 0),(target:GetAttribute("DamageAbsorption") or 0)+(target:GetAttribute("ArmorAbsorption") or 0)))+postDefense
  humanoid:TakeDamage(amount)
  amount = math.max(0,before-humanoid.Health)
 end
 if amount>0 and attackKind=="Melee" and options.Attacker then
  local actor=options.Attacker:IsA("Player") and options.Attacker.Character or options.Attacker
  local hands=actor and actor:GetAttribute("HandsItem")
  if not hands or hands=="" or hands=="ZombieHand" then Audio.Play(target,"Punch",options.Attacker:IsA("Player") and options.Attacker.UserId or nil) end
 end
 target:SetAttribute("LastDamage",amount)
 target:SetAttribute("LastDamageType",damageType)
 target:SetAttribute("Health",humanoid.Health)
 target:SetAttribute("MaxHealth",humanoid.MaxHealth)
 announce(target,"Hit",amount,options.Attacker,attackKind,multiplier>1 and amount>0,not wasKnockedOut and target:GetAttribute("Knockout")==true)
 return amount
end
return Service
