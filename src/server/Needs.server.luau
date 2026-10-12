local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local Life = require(script.Parent.Services.PlayerLifeService)
local Rules = require(ReplicatedStorage.Shared:WaitForChild("NeedsRules"))
local active = {}
local function numberAttribute(character, name, fallback)
 local value = character:GetAttribute(name)
 if typeof(value) ~= "number" or value ~= value or math.abs(value) == math.huge then return fallback end
 return value
end
local function attach(player, character)
 local humanoid = character:WaitForChild("Humanoid", 10)
 local root = character:WaitForChild("HumanoidRootPart", 10)
 if not humanoid or not root or player.Character ~= character or player.Parent ~= Players then return end
 for key, value in pairs({Food = 100, Water = 100, Sick = 0, Working = false, Knockout = false}) do
  character:SetAttribute(key, value)
 end
 if character:GetAttribute("LoadKg") == nil then character:SetAttribute("LoadKg", 0) end
 local function healthChanged()
  character:SetAttribute("Health", humanoid.Health)
  character:SetAttribute("MaxHealth", humanoid.MaxHealth)
 end
 healthChanged()
 local healthConnection = humanoid.HealthChanged:Connect(healthChanged)
 local maxConnection = humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(healthChanged)
 local old = active[player]
 if old then old.healthConnection:Disconnect(); old.maxConnection:Disconnect() end
 active[player] = {character = character, humanoid = humanoid, root = root, healthConnection = healthConnection, maxConnection = maxConnection}
end
local function added(player)
 player.CharacterAdded:Connect(function(character) task.spawn(attach, player, character) end)
 if player.Character then task.spawn(attach, player, player.Character) end
end
Players.PlayerAdded:Connect(added)
Players.PlayerRemoving:Connect(function(player)
 local state = active[player]
 if state then state.healthConnection:Disconnect(); state.maxConnection:Disconnect() end
 active[player] = nil
end)
for _, player in ipairs(Players:GetPlayers()) do added(player) end
local elapsed = 0
RunService.Heartbeat:Connect(function(dt)
 elapsed += dt
 if elapsed < Config.NeedsInterval then return end
 local step = elapsed
 elapsed = 0
 for player, state in pairs(active) do
  local character, humanoid, root = state.character, state.humanoid, state.root
  if player.Character ~= character or not character.Parent or humanoid.Health <= 0 then continue end
  local velocity = root.AssemblyLinearVelocity
  local moving = Vector3.new(velocity.X, 0, velocity.Z).Magnitude > 0.1
  local rate = Config.IdleConsumption
  if moving then
   rate = character:GetAttribute("Running") == true and Config.RunConsumption or Config.WalkConsumption
  end
  if character:GetAttribute("Working") == true then rate += Config.WorkConsumption end
  local weight = math.max(0, numberAttribute(character, "LoadKg", 0))
  rate += weight * Config.WeightConsumption
  local food, water, sick, damage = Rules.Step(numberAttribute(character, "Food", 100), numberAttribute(character, "Water", 100), numberAttribute(character, "Sick", 0), rate, step, Config)
  character:SetAttribute("Food", food)
  character:SetAttribute("Water", water)
  character:SetAttribute("Sick", sick)
  character:SetAttribute("LoadKg", weight)
  -- Direct health subtraction ensures survival damage is not blocked by spawn ForceField.
  if damage > 0 then Life.Damage(player,humanoid,damage) end
 end
end)
