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
 label.Text = string.format("-%g",amount)
 label.Parent = gui
 local info = TweenInfo.new(.85,Enum.EasingStyle.Quad,Enum.EasingDirection.Out)
 TweenService:Create(gui,info,{StudsOffsetWorldSpace=gui.StudsOffsetWorldSpace+Vector3.new(0,.7,0)}):Play()
 TweenService:Create(label,info,{TextTransparency=1,TextStrokeTransparency=1}):Play()
 Debris:AddItem(gui,1)
end
function Service.Apply(humanoid,amount,damageType)
 local target = humanoid.Parent
 if not target or humanoid.Health <= 0 then return 0 end
 local before = humanoid.Health
 if target.Name == "Mannikin" then
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
 popup(target,amount)
 return amount
end
return Service
