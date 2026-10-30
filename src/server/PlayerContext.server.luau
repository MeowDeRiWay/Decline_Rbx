local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Carry=require(script.Parent.Services.CarryService)
local Chests=require(script.Parent.Services.ChestService)
local Life=require(script.Parent.Services.PlayerLifeService)
local remote=Instance.new("RemoteEvent");remote.Name="PlayerContextAction";remote.Parent=ReplicatedStorage
local last={}
remote.OnServerEvent:Connect(function(player,action,target)
 local now=os.clock();if now-(last[player] or -math.huge)<.2 then return end;last[player]=now
 if action=="Respawn" then Life.RequestRespawn(player);return end
 if player:GetAttribute("AttributesConfirmed")~=true then return end
 if action=="Carry" then Carry.Pickup(player,target)
 elseif action=="Drop" then Carry.Drop(player)
 elseif action=="Bed" then Carry.PlaceOnBed(player,target)
 elseif action=="Loot" then
  if typeof(target)=="Instance" and target:IsA("Player") and target.Parent==Players and target~=player then Chests.OpenKnockout(player,target) end
 end
end)
Players.PlayerRemoving:Connect(function(player) last[player]=nil end)
