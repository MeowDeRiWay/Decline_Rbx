local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Motion = require(ReplicatedStorage.Shared.WeaponMotion)
local Damage = require(script.Parent.Services.DamageService)
local Inventory = require(script.Parent.Services.InventoryService)
local Resources = require(script.Parent.Services.ResourceService)
local Items = require(ReplicatedStorage.Shared.ItemConfig).Items
local attack = Instance.new("RemoteEvent")
attack.Name = "WeaponAttack"
attack.Parent = ReplicatedStorage
local random = Random.new()
local ready = {}
attack.OnServerEvent:Connect(function(player)
 local character = player.Character
 local humanoid = character and character:FindFirstChildOfClass("Humanoid")
 local root = character and character:FindFirstChild("HumanoidRootPart")
 local held = character and character:FindFirstChild("HeldItem")
 local motor = held and held:FindFirstChild("WeaponGrip")
 if not root or not humanoid or humanoid.Health <= 0 or character:GetAttribute("Knockout") or not motor then return end
 local now = os.clock()
 if now < (ready[player] or 0) then return end
 local weapon = Inventory.GetWeapon(player)
 if not weapon then return end
 local definition=Items[character:GetAttribute("HandsItem")]
 if definition and definition.Firearm then return end
 local knifeMultiplier=definition and definition.CraftTool=="Knife" and (player:GetAttribute("KnifeMultiplier") or 1) or 1
 local motionWeapon=weapon
 if knifeMultiplier~=1 then motionWeapon=table.clone(weapon); motionWeapon.AttacksPerMinute*=knifeMultiplier end
 local cooldown = 60 / motionWeapon.AttacksPerMinute
 ready[player] = now + cooldown
 Motion.Play(motor,motionWeapon)
 task.delay(Motion.HitDelay(motionWeapon),function()
 if player.Character ~= character or humanoid.Health <= 0 or character:GetAttribute("Knockout") or motor.Parent ~= held or held.Parent ~= character or Inventory.GetWeapon(player) ~= weapon then return end
 local params = OverlapParams.new()
 params.FilterType = Enum.RaycastFilterType.Exclude
 params.FilterDescendantsInstances = {character}
 local parts = workspace:GetPartBoundsInBox(root.CFrame * CFrame.new(0,0,-(root.Size.Z/2 + weapon.Range/2)),Vector3.new(weapon.Width,root.Size.Y+1,weapon.Range),params)
 local seen, nearest, distance, resourceTarget = {},nil,math.huge,false
 for _,part in ipairs(parts) do
  local resource = Resources.Find(part)
  local target = resource or part:FindFirstAncestorOfClass("Model")
  while target and not resource and not target:FindFirstChildOfClass("Humanoid") do
   target = target.Parent and target.Parent:FindFirstAncestorOfClass("Model")
  end
  local victim = target and target:FindFirstChildOfClass("Humanoid")
  if resource or (victim and not seen[victim]) then
   if victim then seen[victim] = true end
   local blocked = false
   local ancestor = target
   while ancestor and ancestor ~= workspace do
    if ancestor.Name == "Chest" or ancestor:GetAttribute("Structure") or ancestor:GetAttribute("Building") then blocked = true end
    ancestor = ancestor.Parent
   end
   if not blocked and (resource or victim.Health > 0) then
    local point
    if resource then
     -- Hit the reachable surface of a large tree, not its high model pivot.
     local localPoint,half = part.CFrame:PointToObjectSpace(root.Position),part.Size/2
     point = part.CFrame:PointToWorldSpace(Vector3.new(math.clamp(localPoint.X,-half.X,half.X),math.clamp(localPoint.Y,-half.Y,half.Y),math.clamp(localPoint.Z,-half.Z,half.Z)))
     if (point-root.Position).Magnitude < .001 then point = part.Position end
    else
     local targetRoot = victim.RootPart or target:FindFirstChild("HumanoidRootPart") or part
     point = targetRoot.Position
    end
    local delta = point-root.Position
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.FilterDescendantsInstances = {character}
    local obstruction = workspace:Raycast(root.Position,delta,rayParams)
    if delta.Magnitude < distance and (not obstruction or obstruction.Instance:IsDescendantOf(target)) then
     nearest,distance,resourceTarget = resource or victim,delta.Magnitude,resource ~= nil
    end
   end
  end
 end
 if nearest then
  if resourceTarget then Resources.Hit(player,nearest,weapon)
  else
   if not Damage.RollHit(player,nearest) then
    Damage.Miss(nearest.Parent,player)
    Inventory.UseWeapon(player)
    return
   end
   nearest.Parent:SetAttribute("LastDamagerID",player.UserId)
   nearest.Parent:SetAttribute("LastHitItem",character:GetAttribute("HandsItem"))
   local dealt = Damage.Apply(nearest,weapon.Damage*knifeMultiplier+(player:GetAttribute("MeleeBonus") or 0),weapon.DamageType,root.Position,"Melee",{HitChecked=true,Attacker=player})
   if dealt > 0 then Inventory.UseWeapon(player) end
  end
 end
 end)
end)
Players.PlayerRemoving:Connect(function(player) ready[player] = nil end)
