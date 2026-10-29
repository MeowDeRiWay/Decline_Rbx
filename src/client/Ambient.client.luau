local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local Config=require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("AmbientConfig"))
local AmbientPlayer=require(script.Parent.AmbientPlayer)
local player=Players.LocalPlayer
local music=AmbientPlayer.new(Config)
local function update()
 local character=player.Character
 local hp=character and character:FindFirstChildOfClass("Humanoid")
 local active=player:GetAttribute("AttributesConfirmed")~=false and hp and hp.Health>0 and character:FindFirstChild("HumanoidRootPart") and not character:GetAttribute("Knockout") and not character:GetAttribute("IsDead")
 local mode
 if active then
  if (player:GetAttribute("BattleAmbientUntil") or 0)>workspace:GetServerTimeNow() then mode="Battle"
  elseif player:GetAttribute("TerritoryResolved")==true then
   local distance=player:GetAttribute("TownFlagDistance")
   if distance==nil or distance>Config.TownRadius then mode="Outside" end
  end
 end
 music:SetMode(mode)
end
local elapsed=0
local heartbeat=RunService.Heartbeat:Connect(function(dt)
 elapsed+=dt
 if elapsed<.2 then return end
 elapsed=0;update()
end)
local connections={heartbeat}
for _,attribute in ipairs({"BattleAmbientUntil","TownFlagDistance","TerritoryResolved"}) do
 table.insert(connections,player:GetAttributeChangedSignal(attribute):Connect(update))
end
table.insert(connections,player.CharacterAdded:Connect(function() music:SetMode(nil) end))
table.insert(connections,player.CharacterRemoving:Connect(function() music:SetMode(nil) end))
script.Destroying:Connect(function()
 for _,connection in ipairs(connections) do connection:Disconnect() end
 music:Destroy()
end)
update()
