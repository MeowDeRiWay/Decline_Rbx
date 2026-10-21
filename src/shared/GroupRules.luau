local Rules={Maximum=8,InviteLifetime=30}
function Rules.New() return {Groups={},Membership={},Invites={},NextID=0,InviteSerial=0} end
local function size(group) local n=0;for _ in pairs(group.Members) do n+=1 end;return n end
function Rules.Invite(state,from,target,now)
 if from==target or state.Membership[target] then return false end
 local id=state.Membership[from];local group=id and state.Groups[id]
 if group and (group.Leader~=from or size(group)>=Rules.Maximum) then return false end
 local pending=state.Invites[target]
 if pending and pending.Expires>now then return false end
 state.InviteSerial+=1
 state.Invites[target]={From=from,Group=id,Expires=now+Rules.InviteLifetime,Token=state.InviteSerial}
 return true
end
function Rules.Reply(state,target,accept,now,connected)
 local invite=state.Invites[target];state.Invites[target]=nil
 if not invite or invite.Expires<=now or not accept or state.Membership[target] or not connected(invite.From) then return false end
 if state.Membership[invite.From]~=invite.Group then return false end
 local id=invite.Group
 if id then
  local group=state.Groups[id]
  if not group or group.Leader~=invite.From or size(group)>=Rules.Maximum then return false end
  group.Members[target]=true
 else
  state.NextID+=1;id=state.NextID
  state.Groups[id]={Leader=invite.From,Members={[invite.From]=true,[target]=true}}
  state.Membership[invite.From]=id
 end
 state.Membership[target]=id
 return true
end
function Rules.Leave(state,user)
 state.Invites[user]=nil
 for target,invite in pairs(state.Invites) do if invite.From==user then state.Invites[target]=nil end end
 local id=state.Membership[user];state.Membership[user]=nil
 local group=id and state.Groups[id]
 if not group then return end
 group.Members[user]=nil
 if size(group)<2 then
  for member in pairs(group.Members) do state.Membership[member]=nil end
  state.Groups[id]=nil
 elseif group.Leader==user then
  local leader=math.huge;for member in pairs(group.Members) do leader=math.min(leader,member) end
  group.Leader=leader
 end
end
function Rules.Kick(state,leader,target)
 local id=state.Membership[leader];local group=id and state.Groups[id]
 if not group or group.Leader~=leader or target==leader or not group.Members[target] then return false end
 Rules.Leave(state,target);return true
end
return Rules
