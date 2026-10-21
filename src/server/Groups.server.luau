local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Rules=require(ReplicatedStorage.Shared.GroupRules)
local Sight=require(ReplicatedStorage.Shared.Sight)
local Journal=require(script.Parent.Services.JournalService)
local Affiliation=require(ReplicatedStorage.Shared.AffiliationRules)
local state=Rules.New()
local folder=Instance.new("Folder");folder.Name="GroupRemotes";folder.Parent=ReplicatedStorage
local action=Instance.new("RemoteEvent");action.Name="Action";action.Parent=folder
local remote=Instance.new("RemoteEvent");remote.Name="State";remote.Parent=folder
local function alive(player)
 local character=player and player.Character
 local hp=character and character:FindFirstChildOfClass("Humanoid")
 return character and hp and hp.Health>0 and not character:GetAttribute("Knockout") and character:FindFirstChild("HumanoidRootPart")
end
local function publish()
 for _,player in ipairs(Players:GetPlayers()) do
  local id=state.Membership[player.UserId];local group=id and state.Groups[id]
  player:SetAttribute("GroupID",id or 0);player:SetAttribute("GroupLeaderID",group and group.Leader or 0)
  local members={}
  if group then
   for user in pairs(group.Members) do
    local member=Players:GetPlayerByUserId(user)
    if member then table.insert(members,{ID=user,Name=member.DisplayName or member.Name}) end
   end
   table.sort(members,function(a,b) return a.ID<b.ID end)
  end
  local invite=state.Invites[player.UserId]
  if invite and invite.Expires<=os.clock() then state.Invites[player.UserId]=nil;invite=nil end
  local sender=invite and Players:GetPlayerByUserId(invite.From)
  remote:FireClient(player,{ID=id or 0,Leader=group and group.Leader or 0,Members=members,Maximum=Rules.Maximum,
   Invite=sender and {Token=invite.Token,From=sender.UserId,Name=sender.DisplayName or sender.Name,Expires=workspace:GetServerTimeNow()+math.max(0,invite.Expires-os.clock())} or nil})
 end
end
local recent={}
action.OnServerEvent:Connect(function(player,command,value)
 if player:GetAttribute("AttributesConfirmed")~=true then return end
 local now=os.clock()
 if now-(recent[player] or -math.huge)<.2 then return end
 recent[player]=now
 if command=="Request" then publish();return end
 if not alive(player) then return end
 local user=player.UserId
 if command=="Invite" then
  if typeof(value)~="number" or value~=math.floor(value) then return end
  local target=Players:GetPlayerByUserId(value)
  local a,b=alive(player),alive(target)
  if not a or not b or not Affiliation.SameFaction(player,target) or (a.Position-b.Position).Magnitude>40 then return end
  local hit=Sight.Cast(a.Position,b.Position-a.Position,player.Character)
  if hit and not hit.Instance:IsDescendantOf(target.Character) then return end
  if Rules.Invite(state,user,value,now) then
   Journal.Send(target,(player.DisplayName or player.Name).." invited you to a group. Press G to respond.")
   Journal.Send(player,"Group invitation sent.")
  else Journal.Send(player,"Cannot invite this player right now.") end
 elseif command=="Reply" then
  if typeof(value)~="boolean" then return end
  Rules.Reply(state,user,value,now,function(from) local sender=Players:GetPlayerByUserId(from);return alive(sender) and Affiliation.SameFaction(player,sender) end)
 elseif command=="Leave" then Rules.Leave(state,user)
 elseif command=="Kick" then if typeof(value)=="number" then Rules.Kick(state,user,value) end
 else return end
 publish()
end)
local function register(player)
 player:SetAttribute("GroupID",0);player:SetAttribute("GroupLeaderID",0)
 player:GetAttributeChangedSignal("TeamID"):Connect(function() Rules.Leave(state,player.UserId);publish() end)
 player:GetAttributeChangedSignal("TownID"):Connect(function() Rules.Leave(state,player.UserId);publish() end)
end
Players.PlayerAdded:Connect(register)
for _,player in ipairs(Players:GetPlayers()) do register(player) end
Players.PlayerRemoving:Connect(function(player) recent[player]=nil;Rules.Leave(state,player.UserId);publish() end)
