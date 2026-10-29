-- Humanoid deceleration can leave a small horizontal drift after releasing input.
-- Stop only grounded, voluntary locomotion; preserve gravity, falling and KO.
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
RunService.PreSimulation:Connect(function()
 local c=Players.LocalPlayer.Character
 local root=c and c:FindFirstChild("HumanoidRootPart")
 local hp=c and c:FindFirstChildOfClass("Humanoid")
 if not root or not hp or root.Anchored or hp.Health<=0 or hp.Sit or hp.PlatformStand or c:GetAttribute("Knockout") or c:GetAttribute("IsDead") or hp.FloorMaterial==Enum.Material.Air then return end
 if hp.MoveDirection.Magnitude<.001 then
  local v=root.AssemblyLinearVelocity
  if math.abs(v.X)+math.abs(v.Z)>.001 then root.AssemblyLinearVelocity=Vector3.new(0,v.Y,0) end
 end
end)
