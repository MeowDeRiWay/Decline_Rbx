local Players=game:GetService("Players")
local Run=game:GetService("RunService")
local records={};local elapsed=0
Players.PlayerRemoving:Connect(function(player) records[player]=nil end)
Run.Heartbeat:Connect(function(dt)
 elapsed+=dt;if elapsed<.1 then return end;elapsed=0
 for _,player in ipairs(Players:GetPlayers()) do
  local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
  local r=records[player]
  if root and (not r or r.Root~=root or (root.Position-r.Position).Magnitude>.03) then
   records[player]={Root=root,Position=root.Position};player:SetAttribute("StationarySince",workspace:GetServerTimeNow())
  elseif not root then records[player]=nil;player:SetAttribute("StationarySince",nil) end
 end
end)
