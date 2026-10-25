local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Items = require(ReplicatedStorage.Shared.ItemConfig)
local Rules = require(ReplicatedStorage.Shared.ConsumableRules)
local Inventory = require(script.Parent.InventoryService)
local Service = {}
function Service.Consume(player, id)
 local definition = typeof(id) == "string" and Items.Items[id]
 if not definition or not definition.Consume then return false end
 if definition.Requirements and not require(script.Parent.ProgressionService).Meets(player,definition.Requirements) then return false end
 local character = player.Character
 local humanoid = character and character:FindFirstChildOfClass("Humanoid")
 if not humanoid or humanoid.Health <= 0 or character:GetAttribute("Knockout") then return false end
 local water=character:GetAttribute("Water")
 if typeof(water)~="number" then return false end
 for returned in pairs(definition.ReturnItems or {}) do if not Items.Items[returned] then return false end end
 local food, sick = character:GetAttribute("Food"), character:GetAttribute("Sick")
 if typeof(food) ~= "number" or typeof(sick) ~= "number" then return false end
 if not Inventory.Remove(player, id, 1) then return false end
 local newFood, newSick, newWater = Rules.Apply(food, sick, definition.Consume, water)
 character:SetAttribute("Food", newFood)
 character:SetAttribute("Sick", newSick)
 character:SetAttribute("Water",newWater)
 humanoid.Health=math.min(humanoid.MaxHealth,humanoid.Health+(definition.Consume.Health or 0));character:SetAttribute("Health",humanoid.Health)
 for returned,count in pairs(definition.ReturnItems or {}) do Inventory.Add(player,returned,count) end
 return true
end
-- Keep compatibility with existing callers while using a neutral action name.
Service.Eat=Service.Consume
function Service.PourOut(player,id)
 local definition=typeof(id)=="string" and Items.Items[id]
 local empty=definition and definition.EmptyContainer
 if not empty or not Items.Items[empty] then return false end
 local character=player.Character
 local humanoid=character and character:FindFirstChildOfClass("Humanoid")
 if not humanoid or humanoid.Health<=0 or character:GetAttribute("Knockout") or character:GetAttribute("CraftingLocked") then return false end
 -- Replaces one pocket container, or the held container while keeping it equipped.
 return Inventory.ReplaceOne(player,id,empty)
end
return Service
