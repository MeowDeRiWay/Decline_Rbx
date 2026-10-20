local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local remote=Instance.new("RemoteEvent")
remote.Name="PersonalNotice";remote.Parent=ReplicatedStorage
local Journal={}
function Journal.Send(player,message)
 if player and player.Parent==Players then remote:FireClient(player,message) end
end
return Journal
