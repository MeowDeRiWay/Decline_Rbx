local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Damage = require(script.Parent.Services.DamageService)
local Inventory = require(script.Parent.Services.InventoryService)
local attack = Instance.new("RemoteEvent")
attack.Name = "WeaponAttack"
attack.Parent = ReplicatedStorage
local ready = {}
attack.OnServerEvent:Connect(function(player)
 local character = player.Character
 local humanoid = character and character:FindFirstChildOfClass("Humanoid")
 local root = character and character:FindFirstChild("HumanoidRootPart")
 local held = character and character:FindFirstChild("HeldItem")
 local motor = held and held:FindFirstChild("WeaponGrip")
 if not root or not humanoid or humanoid.Health <= 0 or not motor then return end
 local now = os.clock()
 if now < (ready[player] or 0) then return end
 local weapon = Inventory.GetWeapon(player)
 if not weapon then return end
 local cooldown = 60 / weapon.AttacksPerMinute
 ready[player] = now + cooldown
 local base = motor:GetAttribute("RestC0")
 motor.C0 = CFrame.new(0,0,-weapon.Thrust) * base
 TweenService:Create(motor,TweenInfo.new(cooldown,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{C0=base}):Play()
 local params = OverlapParams.new()
 params.FilterType = Enum.RaycastFilterType.Exclude
 params.FilterDescendantsInstances = {character}
 local parts = workspace:GetPartBoundsInBox(root.CFrame * CFrame.new(0,0,-(root.Size.Z/2 + weapon.Range/2)),Vector3.new(weapon.Width,root.Size.Y+1,weapon.Range),params)
 local seen, nearest, distance = {},nil,math.huge
 for _,part in ipairs(parts) do
  local target = part:FindFirstAncestorOfClass("Model")
  while target and not target:FindFirstChildOfClass("Humanoid") do target = target.Parent:FindFirstAncestorOfClass("Model") end
  local victim = target and target:FindFirstChildOfClass("Humanoid")
  if victim and not seen[victim] then
   seen[victim] = true
   local blocked = false
   local ancestor = target
   while ancestor and ancestor ~= workspace do
    if ancestor.Name == "Chest" or ancestor:GetAttribute("Structure") or ancestor:GetAttribute("Building") then blocked = true end
    ancestor = ancestor.Parent
   end
   if not blocked and victim.Health > 0 then
    local targetRoot = victim.RootPart or target:FindFirstChild("HumanoidRootPart") or part
    local delta = targetRoot.Position-root.Position
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.FilterDescendantsInstances = {character}
    local obstruction = workspace:Raycast(root.Position,delta,rayParams)
    if delta.Magnitude < distance and (not obstruction or obstruction.Instance:IsDescendantOf(target)) then
     nearest,distance = victim,delta.Magnitude
    end
   end
  end
 end
 if nearest then
  local dealt = Damage.Apply(nearest,weapon.Damage,weapon.DamageType,root.Position)
  if dealt > 0 then Inventory.UseWeapon(player) end
 end
end)
Players.PlayerRemoving:Connect(function(player) ready[player] = nil end)
