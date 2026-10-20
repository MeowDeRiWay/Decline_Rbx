local Players = game:GetService("Players")
local Life = require(script.Parent.PlayerLifeService)
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Service = {}
local function popup(target,amount)
 local part = target:FindFirstChild("Head") or target:FindFirstChild("HumanoidRootPart") or target:FindFirstChildWhichIsA("BasePart",true)
 if not part then return end
 local gui = Instance.new("BillboardGui")
 gui.Name = "DamagePopup"
 gui.Adornee = part
 gui.Size = UDim2.fromOffset(140,45)
 gui.StudsOffsetWorldSpace = Vector3.new(math.random(-15,15)/100,part.Size.Y/2+.35,0)
 gui.AlwaysOnTop = true
 gui.MaxDistance = 100
 gui.Parent = part
 local label = Instance.new("TextLabel")
 label.Size = UDim2.fromScale(1,1)
 label.BackgroundTransparency = 1
 label.Font = Enum.Font.GothamBold
 label.TextSize = 24
 label.TextColor3 = Color3.fromRGB(255,85,85)
 label.TextStrokeTransparency = .3
 label.Text = typeof(amount)=="string" and amount or string.format("-%g",amount)
 label.Parent = gui
 local info = TweenInfo.new(.85,Enum.EasingStyle.Quad,Enum.EasingDirection.Out)
 TweenService:Create(gui,info,{StudsOffsetWorldSpace=gui.StudsOffsetWorldSpace+Vector3.new(0,.7,0)}):Play()
 TweenService:Create(label,info,{TextTransparency=1,TextStrokeTransparency=1}):Play()
 Debris:AddItem(gui,1)
end
function Service.Miss(target) popup(target,"Miss") end
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
 local player=Players:GetPlayerFromCharacter(target)
 options=options or {}
 local dodge=player and (player:GetAttribute("DodgeChance") or 0) or 0
 if not options.HitChecked and dodge>0 and math.random()<dodge then
  target:SetAttribute("LastDamage",0);target:SetAttribute("LastDamageDodged",true);popup(target,"Dodge");return 0
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
 popup(target,multiplier>1 and amount>0 and string.format("Critical -%g",amount) or amount)
 return amount
end
return Service
