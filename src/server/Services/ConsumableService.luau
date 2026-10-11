local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Items = require(ReplicatedStorage.Shared.ItemConfig)
local Rules = require(ReplicatedStorage.Shared.ConsumableRules)
local Inventory = require(script.Parent.InventoryService)
local Service = {}
function Service.Eat(player, id)
 local definition = typeof(id) == "string" and Items.Items[id]
 if not definition or not definition.Consume then return false end
 local character = player.Character
 local humanoid = character and character:FindFirstChildOfClass("Humanoid")
 if not humanoid or humanoid.Health <= 0 or character:GetAttribute("Knockout") then return false end
 local food, sick = character:GetAttribute("Food"), character:GetAttribute("Sick")
 if typeof(food) ~= "number" or typeof(sick) ~= "number" then return false end
 if not Inventory.Remove(player, id, 1) then return false end
 local newFood, newSick = Rules.Apply(food, sick, definition.Consume)
 character:SetAttribute("Food", newFood)
 character:SetAttribute("Sick", newSick)
 return true
end
return Service
