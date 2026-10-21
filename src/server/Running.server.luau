local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage.Shared.GameConfig)
local Rules = require(ReplicatedStorage.Shared.MovementRules)
local remote = Instance.new("RemoteEvent")
remote.Name = "SetRunning"
remote.Parent = ReplicatedStorage
local Sprint=require(ReplicatedStorage.Shared.SprintRules)
local sneak=Instance.new("RemoteEvent");sneak.Name="SetSneaking";sneak.Parent=ReplicatedStorage
local lastSneak={}
sneak.OnServerEvent:Connect(function(player,value)
 if typeof(value)~="boolean" or player:GetAttribute("AttributesConfirmed")~=true or os.clock()-(lastSneak[player] or -math.huge)<.15 then return end
 local c=player.Character;local hp=c and c:FindFirstChildOfClass("Humanoid")
 if not hp or hp.Health<=0 or c:GetAttribute("Knockout") or c:GetAttribute("CraftingLocked") then return end
 lastSneak[player]=os.clock();c:SetAttribute("Sneaking",value)
end)
local requested = {}
local reserves = {}
remote.OnServerEvent:Connect(function(player,value)
 if typeof(value) ~= "boolean" then return end
 requested[player] = value
end)
local function added(player)
 player.CharacterAdded:Connect(function() requested[player] = false; reserves[player]=nil;player.Character:SetAttribute("Sneaking",false) end)
 requested[player] = false
end
Players.PlayerAdded:Connect(added)
Players.PlayerRemoving:Connect(function(player) requested[player] = nil;reserves[player]=nil;lastSneak[player]=nil end)
for _,player in ipairs(Players:GetPlayers()) do added(player) end
RunService.Heartbeat:Connect(function(dt)
 for player,wantsRun in pairs(requested) do
  local character = player.Character
  local humanoid = character and character:FindFirstChildOfClass("Humanoid")
  if not humanoid then continue end
  local allowed = player:GetAttribute("AttributesConfirmed")==true and humanoid.Health > 0 and not humanoid.Sit and not humanoid.PlatformStand and not character:GetAttribute("Knockout") and not character:GetAttribute("CraftingLocked")
  local maximum=Sprint.Maximum()
  local reserve=reserves[player]
  if not reserve or reserve.Character~=character then reserve={Character=character,Value=maximum,Exhausted=false};reserves[player]=reserve end
  local moving=humanoid.MoveDirection.Magnitude>.01
  local running
  reserve.Value,reserve.Exhausted,running=Sprint.Step(reserve.Value,maximum,reserve.Exhausted,wantsRun and not character:GetAttribute("Sneaking"),moving,allowed,dt)
  local value=math.floor(reserve.Value*10)/10
  if character:GetAttribute("SprintRemaining")~=value then character:SetAttribute("SprintRemaining",value) end
  if character:GetAttribute("SprintMaximum")~=maximum then character:SetAttribute("SprintMaximum",maximum) end
  local multiplier = Rules.LoadMultiplier(character:GetAttribute("LoadKg"),Config,player:GetAttribute("CarryLimitKg"))
  local speed = (player:GetAttribute("AttributesConfirmed")~=true or character:GetAttribute("Knockout") or character:GetAttribute("CraftingLocked")) and 0 or (running and (player:GetAttribute("RunBonus") or 1) or (player:GetAttribute("WalkBonus") or .3))*(character:GetAttribute("Sneaking") and .5 or 1)*multiplier
  if humanoid.WalkSpeed ~= speed then humanoid.WalkSpeed = speed end
  if character:GetAttribute("Running") ~= running then character:SetAttribute("Running",running) end
 end
end)
