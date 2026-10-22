Service.Start()
local action=ReplicatedStorage.TownRemotes.Action
local function call(player,command,value,extra) clock+=.2; action.OnServerEvent:Fire(player,command,value,extra) end
call(a,"Join",1); call(b,"Join",1); call(c,"Join",2)
assert(a:GetAttribute("TownID")==1 and a.Character.Humanoid.Health==100)
call(d,"Join",3)
assert(d:GetAttribute("TeamID")==1 and d.Character:GetPivot().Position.X==33 and d.Character.Humanoid.Health==100,
 "TownSpawn.TeamID=1 must match Flag.Team=1 rather than TownID=3, after engine placement")
d.Character.Humanoid.Health=41
Service.PlaceCharacter(d,d.Character)
assert(d.Character.Humanoid.Health==41,"repeated placement must not heal or reduce current health")
Service.LoadCharacter(d)
assert(d.Character:GetPivot().Position.X==33 and d.Character.Humanoid.Health==2,"respawn must also use final town placement")
assert(flagA:GetAttribute("LeaderID")==101 and flagB:GetAttribute("LeaderID")==103)
local guestGate={}
d:SetAttribute("TownID",nil)
Doors.request(d,guestGate,1)
local gatePrompt=Service.Snapshot(a).Prompts[1]
assert(gatePrompt,"mayor receives passage request")
call(c,"Reply",gatePrompt,true);assert(not Doors.admitted,"another mayor cannot authorize gate")
call(a,"Reply",gatePrompt,true)
assert(Doors.admitted[1]==d and Doors.admitted[2]==guestGate and Doors.admitted[3]==1,"approval preserves exact requested gate and town")
assert(d:GetAttribute("TownID")==nil,"passage must not grant town membership")
d:SetAttribute("TownID",3)

call(c,"Open",plot); call(c,"Build","Kitchen")
assert(not plot:GetAttribute("BuildingID"),"foreign town must not build")
blockedBuilding="Kitchen"
call(b,"Open",plot)
local lockedKitchen
for _,option in ipairs(Service.Snapshot(b).Session.Plot.Options) do
 if option.ID=="Kitchen" then lockedKitchen=option end
end
assert(lockedKitchen and lockedKitchen.CanBuild==false,"unmet building remains visible and marked locked")
call(b,"Build","Kitchen")
assert(not Service.Snapshot(b).Session.Plot.Pending and logs[102]==30,"server rejects locked construction without spending or requesting approval")
blockedBuilding=nil
call(b,"Open",plot); call(b,"Build","Kitchen")
local notices=ReplicatedStorage.TownRemotes.Notice.sent
local approval
for _,item in ipairs(notices) do if item.data.Kind=="Approval" and item.player==a then approval=item.data.ID end end
assert(approval and not plot:GetAttribute("BuildingID"))
call(c,"Reply",approval,true); assert(not plot:GetAttribute("BuildingID"),"only actual mayor may approve")
call(a,"Reply",approval,true)
assert(logs[102]==25 and scrap[102]==85 and menu.Parent==nil and plot:FindFirstChild("Kitchen (T1)").BuildingMenu,"consume5logs/15scrap and use kitchen sign")
assert(plot:GetAttribute("BuildingID")=="Kitchen" and plot:GetAttribute("OwnerID")==102 and space.Parent==nil)
call(a,"Open",flagA); call(a,"OwnAll")
assert(plot:GetAttribute("OwnerID")==102,"removed bulk ownership action must have no effect")
call(a,"Vote"); assert(not Service.Snapshot(a).Towns[1].VoteEndsAt,"mayor cannot start self-removal vote")
call(a,"Open",plot); call(a,"Owner",101)
call(a,"CoOwner",102,true); assert(plot:GetAttribute("Co-OwnerID")=="102")
call(b,"Open",plot); call(b,"CoOwner",102,false)
assert(plot:GetAttribute("Co-OwnerID")=="102","co-owners cannot manage the access list")
call(a,"Open",flagA); call(a,"Relation",2,"Ally")
local alliance
for _,item in ipairs(notices) do if item.data.Kind=="Approval" and item.player==c then alliance=item.data.ID end end
assert(alliance)
call(b,"Reply",alliance,true); assert(Service.Snapshot(a).Towns[1].Relations[1].Relation=="Neutral")
call(c,"Reply",alliance,true); assert(Service.Snapshot(a).Towns[1].Relations[1].Relation=="Ally")
call(a,"Relation",2,"War"); assert(Service.Snapshot(c).Towns[2].Relations[1].Relation=="War")
call(b,"Open",flagA); call(b,"Vote")
local vote=Service.Snapshot(b).Prompts[1]; assert(vote)
call(c,"Reply",vote,false); call(a,"Reply",vote,true)
assert(Service.Snapshot(b).Towns[1].VoteEndsAt,"vote continues while an eligible member has not voted")
call(b,"Reply",vote,false)
assert(not Service.Snapshot(b).Towns[1].VoteEndsAt,"vote ends immediately after every eligible member votes")
call(b,"Reply",vote,true)
tick(61)
assert(flagA:GetAttribute("LeaderID")==101,"tie and duplicate vote preserve mayor")
call(b,"Vote"); assert(not Service.Snapshot(b).Towns[1].VoteEndsAt,"cooldown enforced")
tick(601); call(b,"Vote"); vote=Service.Snapshot(b).Prompts[1]
call(b,"Reply",vote,true); tick(31)
assert(flagA:GetAttribute("LeaderID")==0,"Y means remove, and removal starts election")
local election=Service.Snapshot(b).Election
assert(election and #election.Candidates==2 and election.ID~=vote)
call(b,"ClaimMayor"); assert(flagA:GetAttribute("LeaderID")==0,"vacant office cannot bypass election")
call(c,"Reply",election.ID,true); call(c,"VoteCandidate",election.ID,103)
assert(not Service.Snapshot(c).Election,"foreign town cannot participate")
call(a,"Reply",election.ID,true); call(b,"Reply",election.ID,true)
assert(Service.Snapshot(a).Election.Participating and not Service.Snapshot(a).Election.Answered)
call(a,"VoteCandidate",election.ID,103)
assert(not Service.Snapshot(a).Election.Answered,"foreign candidates rejected")
call(a,"VoteCandidate",election.ID,102)
call(a,"VoteCandidate",election.ID,101)
call(b,"VoteCandidate",election.ID,102)
assert(flagA:GetAttribute("LeaderID")==102 and not Service.Snapshot(b).Election,"most votes wins; self-vote allowed; no duplicate ballot")
call(b,"Resign")
election=Service.Snapshot(b).Election
assert(flagA:GetAttribute("LeaderID")==0 and election,"resignation immediately vacates office and opens election")
call(a,"Reply",election.ID,false); call(b,"Reply",election.ID,true); call(b,"VoteCandidate",election.ID,102)
assert(flagA:GetAttribute("LeaderID")==102 and not Service.Snapshot(b).Election,"skipping counts as final response; election completes early")
call(b,"Resign"); election=Service.Snapshot(b).Election
call(a,"Reply",election.ID,true); call(b,"Reply",election.ID,true)
call(a,"VoteCandidate",election.ID,101); call(b,"VoteCandidate",election.ID,102)
local runoff=Service.Snapshot(b).Election
assert(runoff and runoff.ID~=election.ID and flagA:GetAttribute("LeaderID")==0,"tie starts runoff")
call(a,"Reply",runoff.ID,true); call(b,"Reply",runoff.ID,true)
call(a,"VoteCandidate",runoff.ID,102); call(b,"VoteCandidate",runoff.ID,102)
assert(flagA:GetAttribute("LeaderID")==102,"runoff elects winning candidate")
call(a,"Open",plot); call(a,"Owner",0); assert(plot:GetAttribute("OwnerID")==101,"former mayor cannot revoke ownership")
call(b,"Open",plot); call(b,"Destroy"); assert(space.Parent==plot and not plot:GetAttribute("BuildingID"))
call(a,"Open",plot); call(a,"Build","Kitchen")
local expired
for _,item in ipairs(notices) do if item.data.Kind=="Approval" and item.player==b then expired=item.data.ID end end
assert(expired); tick(61); call(b,"Reply",expired,true); assert(not plot:GetAttribute("BuildingID"))
-- The mayor must receive and answer the same request, even for their own building.
call(b,"Open",plot); call(b,"Build","Kitchen")
local selfRequest
for _,item in ipairs(notices) do if item.player==b and item.data.Kind=="Approval" then selfRequest=item.data.ID end end
assert(selfRequest and not plot:GetAttribute("BuildingID") and logs[102]==25,"self-build waits for Y/N without spending")
call(b,"Reply",selfRequest,false)
assert(not plot:GetAttribute("BuildingID") and logs[102]==25,"decline does not consume logs")
call(b,"Build","Kitchen")
for _,item in ipairs(notices) do if item.player==b and item.data.Kind=="Approval" then selfRequest=item.data.ID end end
call(b,"Reply",selfRequest,true)
assert(plot:GetAttribute("BuildingID")=="Kitchen" and logs[102]==20 and scrap[102]==70,"self-approval consumes5logs/15scrap")
call(b,"Reply",selfRequest,true); assert(logs[102]==20,"repeated approval cannot charge twice")
call(b,"Open",plot); call(b,"Destroy")
assert(menu.Parent==plot,"demolition restores empty plot sign")
logs[101]=5
call(a,"Open",plot); call(a,"Build","Kitchen")
local missing
for _,item in ipairs(notices) do if item.player==b and item.data.Kind=="Approval" then missing=item.data.ID end end
logs[101]=0
call(b,"Reply",missing,true)
assert(not plot:GetAttribute("BuildingID") and logs[101]==0,"materials checked again on approval")
call(a,"Open",plot); call(a,"Build","Kitchen")
assert(not Service.Snapshot(a).Session.Plot.Pending,"no materials cannot reserve construction")
call(b,"Open",flagA); call(b,"Leave"); assert(not b:GetAttribute("TownID") and flagA:GetAttribute("LeaderID")==0)
print("PASS: removal-to-election, immediate resignation, candidate validation, self-vote, plurality, skip, runoff, duplicate rejection;  city join/spawn 2 HP, foreign building rejection, mayor approval authorization, replacement/restoration of Space, ownership, bilateral alliance, unilateral war, vote anonymity/duplicates/ties/removal/cooldown, approval expiry, mayor departure")
