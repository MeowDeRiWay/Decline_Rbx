local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Life=require(script.Parent.Services.PlayerLifeService)
local remote=Instance.new("RemoteEvent")
remote.Name="OutcastRestart";remote.Parent=ReplicatedStorage
remote.OnServerEvent:Connect(function(player)
 Life.RestartOutcast(player)
end)
