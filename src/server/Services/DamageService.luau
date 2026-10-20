local Players = game:GetService("Players")
local Life = require(script.Parent.PlayerLifeService)
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local report=Instance.new("RemoteEvent");report.Name="CombatReport";report.Parent=ReplicatedStorage
local Service = {}
local function announce(target,kind,amount,attacker,attackKind,critical,knockout)
 local victim=Players:GetPlayerFromCharacter(target)
 local attackerPlayer=attacker and attacker:IsA("Player")
 local actor=attackerPlayer and attacker.Character or attacker
 local actorName=attacker and (attackerPlayer and (attacker.DisplayName or attacker.Name) or (attacker:GetAttribute("DisplayName") or attacker.Name)) or "Unknown attacker"
 local humanoid=target:FindFirstChildOfClass("Humanoid")
 local payload={Target=target,Actor=actor,ActorName=actorName,
  TargetName=victim and (victim.DisplayName or victim.Name) or (target:GetAttribute("DisplayName") or target.Name),
  Kind=kind,Damage=amount,AttackKind=attackKind,Critical=critical==true,
  Killed=humanoid and humanoid.Health<=0 or false,Knockout=knockout==true}
 local position=target:GetPivot().Position
 -- Bound network traffic; exact camera/sector/wall visibility is checked locally.
 for _,observer in ipairs(Players:GetPlayers()) do
  local root=observer.Character and observer.Character:FindFirstChild("HumanoidRootPart")
  if root and (root.Position-position).Magnitude<=250+(observer:GetAttribute("ViewBonus") or 0)*10 then report:FireClient(observer,payload) end
 end
end
function Service.Miss(target,attacker) announce(target,"Miss",0,attacker) end
function Service.RollHit(attacker,humanoid,bonus)
 local defender=Players:GetPlayerFromCharacter(humanoid.Parent)
 local dodge=defender and defender:GetAttribute("DodgeChance") or 0
 local chance=math.max(0,math.clamp((attacker:GetAttribute("Accuracy") or .25)+(bonus or 0),0,.9)-dodge)
 return math.random()<chance
end
function Service.Apply(humanoid,amount,damageType,sourcePosition,attackKind,options)
 local target = humanoid.Parent
 if not target or humanoid.Health <= 0 then return 0 end
 if sourcePosition then
  local delta = target:GetPivot().Position-sourcePosition
  delta = Vector3.new(delta.X,0,delta.Z)
  if delta.Magnitude > .001 then target:SetAttribute("LastHitDirection",delta.Unit) end
 end
 local before = humanoid.Health
 local wasKnockedOut=target:GetAttribute("Knockout")==true
 local player=Players:GetPlayerFromCharacter(target)
 options=options or {}
 local dodge=player and (player:GetAttribute("DodgeChance") or 0) or 0
 if not options.HitChecked and dodge>0 and math.random()<dodge then
  target:SetAttribute("LastDamage",0);target:SetAttribute("LastDamageDodged",true);announce(target,"Dodge",0,options.Attacker,attackKind);return 0
 end
 target:SetAttribute("LastDamageDodged",false)
 local multiplier=options.CriticalMultiplier or 1
 local negation=player and (player:GetAttribute("CriticalNegation") or 0) or 0
 if multiplier>1 and negation>0 and math.random()<negation then multiplier=1 end
 amount*=multiplier
 target:SetAttribute("LastDamageCritical",multiplier>1)
 if player then
  if target:FindFirstChildOfClass("ForceField") then amount=0
  else
   if attackKind=="Melee" then amount=math.max(0,amount-(player:GetAttribute("MeleeAbsorption") or 0)) end
   amount=amount>0 and Life.Damage(player,humanoid,amount,true) or 0
  end
 elseif target.Name == "Mannikin" then
  -- Training targets reset on the lethal hit without entering the Dead state.
  if not target:FindFirstChildOfClass("ForceField") then
   local remaining = math.max(0,before-amount)
   humanoid.Health = remaining > 0 and remaining or humanoid.MaxHealth
   amount = math.min(before,amount)
  else amount = 0 end
 else
  humanoid:TakeDamage(amount)
  amount = math.max(0,before-humanoid.Health)
 end
 target:SetAttribute("LastDamage",amount)
 target:SetAttribute("LastDamageType",damageType)
 target:SetAttribute("Health",humanoid.Health)
 target:SetAttribute("MaxHealth",humanoid.MaxHealth)
 announce(target,"Hit",amount,options.Attacker,attackKind,multiplier>1 and amount>0,not wasKnockedOut and target:GetAttribute("Knockout")==true)
 return amount
end
return Service
