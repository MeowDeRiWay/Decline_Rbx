local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Service = require(script.Parent.Services.InventoryService)
local folder = Instance.new("Folder")
folder.Name, folder.Parent = "InventoryRemotes", ReplicatedStorage
local action = Instance.new("RemoteEvent")
action.Name, action.Parent = "Action", folder
local state = Instance.new("RemoteEvent")
state.Name, state.Parent = "State", folder
Service.Changed:Connect(function(player) state:FireClient(player, Service.Snapshot(player)) end)
Service.Start()
local lastAction = {}
Players.PlayerRemoving:Connect(function(player) lastAction[player] = nil end)
action.OnServerEvent:Connect(function(player, command, value)
 local now = os.clock()
 if now - (lastAction[player] or -math.huge) < 0.1 then return end
 lastAction[player] = now
 if command == "Request" then state:FireClient(player, Service.Snapshot(player)); return end
 local character = player.Character
 local humanoid = character and character:FindFirstChildOfClass("Humanoid")
 if not humanoid or humanoid.Health <= 0 or character:GetAttribute("Knockout") then return end
 if command == "Equip" then Service.Equip(player, value)
 elseif command == "Unequip" then Service.Unequip(player, value) end
end)
