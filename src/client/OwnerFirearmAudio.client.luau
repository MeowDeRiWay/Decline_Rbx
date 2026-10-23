-- Attackers and players receiving a hit hear one centered local copy.
-- Other clients keep the server-approved spatial sound and hearing range.
local Players=game:GetService("Players")
local SoundService=game:GetService("SoundService")
local Debris=game:GetService("Debris")
local player=Players.LocalPlayer
local active={}
local connections={}
local function stop(source,copyDestroying)
 local record=active[source]
 if not record then return end
 active[source]=nil
 for _,connection in ipairs(record.Connections) do connection:Disconnect() end
 if not copyDestroying then record.Copy:Stop();record.Copy:Destroy() end
end
local function combatSound(source)
 return source.Name=="CombatPunch" or source.Name=="CombatMiss" or source.Name=="CombatShotEvade"
end
local function center(source)
 if not source:IsA("Sound") or active[source] then return end
 if combatSound(source) then
  local own=source:GetAttribute("CombatOwnerUserId")==player.UserId
  local received=player.Character and source:IsDescendantOf(player.Character)
  if not own and not received then return end
 elseif source.Name~="PlayingShotSound" and source.Name~="PlayingReloadSound" then return end
 local copy=source:Clone()
 copy.Name="Owner"..source.Name
 copy.Looped=false;copy.PlayOnRemove=false
 copy.Parent=SoundService -- A non-positional source: camera/facing cannot pan it.
 local record={Copy=copy,Connections={}}
 active[source]=record
 -- Volume is local to this client; the original stays audible for everyone else.
 source.Volume=0
 table.insert(record.Connections,source:GetPropertyChangedSignal("Volume"):Connect(function()
  if source.Volume~=0 then source.Volume=0 end
 end))
 table.insert(record.Connections,source.Destroying:Connect(function() stop(source) end))
 table.insert(record.Connections,source.Ended:Connect(function() stop(source) end))
 table.insert(record.Connections,copy.Destroying:Connect(function() stop(source,true) end))
 table.insert(record.Connections,copy.Ended:Connect(function() stop(source) end))
 copy:Play()
 Debris:AddItem(copy,15)
end
local function clear()
 for _,connection in ipairs(connections) do connection:Disconnect() end
 table.clear(connections)
 local sources={};for source in pairs(active) do table.insert(sources,source) end
 for _,source in ipairs(sources) do stop(source) end
end
local function bind(character)
 clear()
 table.insert(connections,character.DescendantAdded:Connect(center))
 table.insert(connections,character.DescendantRemoving:Connect(stop))
 for _,source in ipairs(character:GetDescendants()) do center(source) end
end
player.CharacterAdded:Connect(bind)
player.CharacterRemoving:Connect(clear)
if player.Character then bind(player.Character) end

-- Punches are emitted at the victim, which can be outside the attacker's rig.
workspace.DescendantAdded:Connect(function(source)
 if source:IsA("Sound") and combatSound(source) then center(source) end
end)
for _,source in ipairs(workspace:GetDescendants()) do
 if source:IsA("Sound") and combatSound(source) then center(source) end
end
