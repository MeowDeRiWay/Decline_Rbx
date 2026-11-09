local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HomeRules = require(ReplicatedStorage.Shared.ZombieHomeRules)
local Service = {}
local reservations = {}

function Service.Find(character, humanoid)
 local root = character:FindFirstChild("HumanoidRootPart")
 if not root then return nil end
 local params = RaycastParams.new()
 params.FilterType = Enum.RaycastFilterType.Exclude
 params.FilterDescendantsInstances = {character}
 params.RespectCanCollide = true
 local distance = root.Size.Y / 2 + humanoid.HipHeight + .5
 local hit = workspace:Raycast(root.Position, Vector3.new(0, -distance, 0), params)
 if not hit then return nil end
 local floor, ancestor = nil, hit.Instance
 while ancestor and ancestor ~= workspace do
  if ancestor:GetAttribute("LogoutSpawnExempt") or ancestor:GetAttribute("ForInfrastructure") then return nil end
  if ancestor:IsA("Model") and ancestor:GetAttribute("Zombie_home") == true then floor = ancestor end
  ancestor = ancestor.Parent
 end
 return floor and HomeRules.House(floor)
end

function Service.Reserve(house)
 if house then reservations[house] = (reservations[house] or 0) + 1 end
end

function Service.Release(house)
 if not house or not reservations[house] then return end
 local remaining = reservations[house] - 1
 reservations[house] = remaining > 0 and remaining or nil
end

function Service.Blocked(object)
 while object and object ~= workspace do
  if reservations[object] then return true end
  object = object.Parent
 end
 return false
end

return Service
