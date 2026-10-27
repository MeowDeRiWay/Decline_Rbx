-- Preferences only: independent of character saves, deaths and server sessions.
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local store=game:GetService("DataStoreService"):GetDataStore("DeclineHelpPreferences_v1")
local remote=Instance.new("RemoteEvent")
remote.Name="HelpPreference";remote.Parent=ReplicatedStorage
local records={}
local closing=false
local function status(player,record,state)
 if player.Parent==Players then
  player:SetAttribute("HelpPreferenceStatus",state)
  player:SetAttribute("HelpHidden",record.Hidden)
 end
end
local function save(player,record)
 if record.Saving then return end
 record.Saving=true
 while record.Dirty do
  local revision,value=record.Revision,record.Hidden
  local ok=false
  for attempt=1,3 do
   ok=pcall(function()
    store:UpdateAsync("User_"..player.UserId,function(previous)
     local data=type(previous)=="table" and table.clone(previous) or {}
     data.HideOnLogin=value
     return data
    end)
   end)
   if ok then break end
   if attempt<3 then task.wait(attempt) end
  end
  if not ok then status(player,record,"Failed");break end
  if record.Revision==revision then record.Dirty=false;status(player,record,"Saved") end
 end
 record.Saving=false
end
local function added(player)
 if records[player] then return end
 local record={Hidden=false,Ready=false,Revision=0,Dirty=false,Saving=false}
 records[player]=record
 player:SetAttribute("HelpPreferenceReady",false)
 task.spawn(function()
  local ok,data=pcall(function() return store:GetAsync("User_"..player.UserId) end)
  if records[player]~=record or player.Parent~=Players then return end
  record.Hidden=ok and type(data)=="table" and data.HideOnLogin==true
  record.Ready=true
  status(player,record,ok and "Saved" or "LoadFailed")
  player:SetAttribute("HelpPreferenceReady",true)
 end)
end
remote.OnServerEvent:Connect(function(player,value)
 local record=records[player]
 if closing or not record or not record.Ready or typeof(value)~="boolean" then return end
 if record.LastChange and os.clock()-record.LastChange<.5 then return end
 record.LastChange=os.clock()
 if value==record.Hidden and not record.Dirty then return end
 record.Hidden=value;record.Revision+=1;record.Dirty=true
 status(player,record,"Saving")
 -- Coalesce quick changes and serialize writes for this player's preference.
 task.delay(1,function() save(player,record) end)
end)
Players.PlayerAdded:Connect(added)
Players.PlayerRemoving:Connect(function(player)
 local record=records[player]
 if not record then return end
 if record.Dirty then save(player,record) end
 while record.Saving do task.wait(.1) end
 records[player]=nil
end)
for _,player in ipairs(Players:GetPlayers()) do added(player) end
game:BindToClose(function()
 closing=true
 for player,record in pairs(records) do if record.Dirty then task.spawn(save,player,record) end end
 local deadline=os.clock()+25
 repeat
  local pending=false
  for _,record in pairs(records) do if record.Saving then pending=true;break end end
  if not pending then break end
  task.wait(.1)
 until os.clock()>=deadline
end)
