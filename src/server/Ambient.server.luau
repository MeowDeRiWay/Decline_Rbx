-- PvP music is server-authoritative. NPCs, misses and absorbed hits never signal it.
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Damage=require(script.Parent.Services.DamageService)
local Towns=require(script.Parent.Services.TownService)
local Affiliation=require(ReplicatedStorage.Shared.AffiliationRules)
local Config=require(ReplicatedStorage.Shared.AmbientConfig)
local function active(player)
 local character=player.Character
 local hp=character and character:FindFirstChildOfClass("Humanoid")
 return player.Parent==Players and hp and hp.Health>0 and not character:GetAttribute("Knockout") and not character:GetAttribute("IsDead")
end
Damage.OnPlayerDamage(function(attacker,victim,amount)
 if amount<=0 or attacker==victim or Affiliation.Friendly(attacker,victim) or Towns.RelationBetween(attacker,victim)=="Ally" then return end
 local deadline=workspace:GetServerTimeNow()+Config.CombatSeconds
 for _,player in ipairs({attacker,victim}) do
  if active(player) then player:SetAttribute("BattleAmbientUntil",deadline) end
 end
end)
local function bind(player)
 local connections={}
 local function characterAdded(character)
  for _,connection in ipairs(connections) do connection:Disconnect() end
  table.clear(connections)
  player:SetAttribute("BattleAmbientUntil",nil)
  player:SetAttribute("TerritoryResolved",false)
  local function update()
   if not active(player) then player:SetAttribute("BattleAmbientUntil",nil) end
  end
  table.insert(connections,character:GetAttributeChangedSignal("Knockout"):Connect(update))
  table.insert(connections,character:GetAttributeChangedSignal("IsDead"):Connect(update))
  local hp=character:FindFirstChildOfClass("Humanoid")
  if hp then table.insert(connections,hp.HealthChanged:Connect(update)) end
 end
 player.CharacterAdded:Connect(characterAdded)
 player.CharacterRemoving:Connect(function()
  for _,connection in ipairs(connections) do connection:Disconnect() end
  table.clear(connections)
  player:SetAttribute("BattleAmbientUntil",nil)
  player:SetAttribute("TerritoryResolved",false)
 end)
 if player.Character then characterAdded(player.Character) end
end
Players.PlayerAdded:Connect(bind)
for _,player in ipairs(Players:GetPlayers()) do bind(player) end
