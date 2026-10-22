local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Rules=require(ReplicatedStorage.Shared.ProgressionRules)
local Config=require(ReplicatedStorage.Shared.ProgressionConfig)
local Journal=require(script.Parent.JournalService)
local Service={}
local states={}
local disconnected={}
local remote
local locked=setmetatable({},{__mode="k"})
local function creationLock(player,character,confirmed)
 local root=character:FindFirstChild("HumanoidRootPart")
 local hp=character:FindFirstChildOfClass("Humanoid")
 if not confirmed then
  character:SetAttribute("CreatingCharacter",true)
  if root and not locked[character] then locked[character]={Root=root,Anchored=root.Anchored} end
  if root then root.Anchored=true;root.AssemblyLinearVelocity=Vector3.zero;root.AssemblyAngularVelocity=Vector3.zero end
  if hp then hp.WalkSpeed=0;hp.Jump=false end
  if not character:FindFirstChild("CreationProtection") then
   local field=Instance.new("ForceField");field.Name="CreationProtection";field.Visible=false;field.Parent=character
  end
 else
  local record=locked[character]
  if record then
   if record.Root.Parent then record.Root.Anchored=record.Anchored end
   locked[character]=nil
   if hp and hp.Health>0 then hp.Health=hp.MaxHealth;character:SetAttribute("Health",hp.Health) end
  end
  local field=character:FindFirstChild("CreationProtection");if field then field:Destroy() end
  character:SetAttribute("CreatingCharacter",false)
 end
end
local function stateFor(player)
 if not states[player] then states[player]=disconnected[player.UserId] or Rules.New();disconnected[player.UserId]=nil end
 return states[player]
end
function Service.Snapshot(player)
 local s=stateFor(player)
 local practice={};for id,data in pairs(s.Practice) do practice[id]=table.clone(data) end
 return {Level=s.Level,XP=s.XP,NextXP=1000*(s.Level+1),Points=s.Points,SkillPoints=s.SkillPoints,
 TaggedSkills=table.clone(s.TaggedSkills or {}),TagsConfirmed=s.TagsConfirmed==true,Confirmed=s.Confirmed,Stats=table.clone(s.Stats),Skills=Rules.TotalSkills(s),Practice=practice,Perks=table.clone(s.Perks),PerkPoints=s.PerkPoints}
end
function Service.Sync(player)
 local state=stateFor(player);if state.Level>=30 then state.Perks.Observant=1 end;local bonus=Rules.Bonuses(state.Stats,state.Perks,state.Level);local totals=Rules.TotalSkills(state)
 player:SetAttribute("CharacterLevel",state.Level);player:SetAttribute("CharacterXP",state.XP)
 player:SetAttribute("AttributePoints",state.Points);player:SetAttribute("SkillPoints",state.SkillPoints)
 player:SetAttribute("AttributesConfirmed",state.Confirmed)
 player:SetAttribute("PerkPoints",state.PerkPoints)
 player:SetAttribute("Profession",nil);player:SetAttribute("TalentPoints",nil)
 for id,value in pairs(state.Stats) do player:SetAttribute(id,value) end
 for id,value in pairs(totals) do player:SetAttribute("Skill"..id,value) end
 -- Clear retired talent effects for all consumers during transition.
 for id,value in pairs({KnifeMultiplier=1,MeleeAbsorption=0,CriticalNegation=0,PreserveDurabilityChance=0,AmmoWeightMultiplier=1}) do bonus[id]=value end
 for _,category in ipairs({"Automatic","Pistol","Rifle","MachineGun"}) do bonus[category.."AccuracyBonus"]=0;bonus[category.."CritChance"]=0 end
 bonus.Accuracy=totals.Unarmed
 for id,value in pairs(bonus) do player:SetAttribute(id,value) end
 local character=player.Character
 if character then
  for id,value in pairs(bonus) do character:SetAttribute(id,value) end
  local hp=character:FindFirstChildOfClass("Humanoid")
  if hp then hp.MaxHealth=bonus.MaxHealth;hp.Health=math.min(hp.Health,hp.MaxHealth);character:SetAttribute("MaxHealth",hp.MaxHealth);character:SetAttribute("Health",hp.Health) end
  creationLock(player,character,state.Confirmed)
 end
 if remote and player.Parent==Players then remote:FireClient(player,Service.Snapshot(player)) end
end
function Service.Award(player,amount)
 if not player or player.Parent~=Players then return end
 if Rules.AddXP(stateFor(player),amount) then Journal.Send(player,string.format("You gained %g XP.",amount*(1+(stateFor(player).Perks.GoodStudent or 0))));Service.Sync(player) end
end
function Service.Meets(player,requirements) return Rules.Meets(stateFor(player),requirements) end
function Service.CanStation(player,name) return Service.Meets(player,Config.StationRequirements[name]) end
function Service.CanBuild(player,kind) return Service.Meets(player,Config.BuildingRequirements[kind]) end
function Service.CraftEffects() return Rules.CraftEffects() end
function Service.CraftXP(player,recipe,count) Service.Award(player,Rules.CraftExperience(recipe,count)) end
function Service.Loot(_,items) return items end
function Service.Harvest(player,kind,count)
 if not player or player.Parent~=Players then return end
 local id=({Tree="Lumberjack",StoneVein="Miner",ScrapPile="Scavenger"})[kind]
 if id then Rules.Practice(stateFor(player),id,count) end
 Service.Award(player,count)
end
function Service.ZombieDied(model,items)
 Service.Award(Players:GetPlayerByUserId(model:GetAttribute("LastDamagerID") or 0),Rules.KillExperience((model:FindFirstChildOfClass("Humanoid") or {}).MaxHealth))
 return items
end
function Service.Start()
 if Service.Started then return end;Service.Started=true
 local folder=Instance.new("Folder");folder.Name="ProgressionRemotes";folder.Parent=ReplicatedStorage
 remote=Instance.new("RemoteEvent");remote.Name="State";remote.Parent=folder
 local action=Instance.new("RemoteEvent");action.Name="Action";action.Parent=folder
 local last={}
 action.OnServerEvent:Connect(function(player,command,value)
  local now=os.clock();if now-(last[player] or -math.huge)<.1 then return end;last[player]=now
  local state=stateFor(player)
  if command=="Confirm" then
   if typeof(value)=="table" and typeof(value.TaggedSkills)=="table" and not state.TagsConfirmed then Rules.Confirm(state,value.Stats,value.TaggedSkills) end
  elseif command=="ConfirmTags" and state.Confirmed then Rules.SelectTags(state,value)
  elseif command=="Perk" and typeof(value)=="string" then Rules.SpendPerk(state,value)
  elseif command=="Skill" and typeof(value)=="string" then Rules.SpendSkill(state,value)
  elseif command~="Request" then return end
  Service.Sync(player)
 end)
 local function added(player)
  stateFor(player);Service.Sync(player)
  player.CharacterAdded:Connect(function(character) character:WaitForChild("Humanoid",10);character:WaitForChild("HumanoidRootPart",10);if player.Character==character then Service.Sync(player) end end)
 end
 Players.PlayerAdded:Connect(added)
 Players.PlayerRemoving:Connect(function(player) disconnected[player.UserId]=states[player];states[player]=nil;last[player]=nil end)
 for _,player in ipairs(Players:GetPlayers()) do added(player) end
 task.spawn(function()
  while true do
   task.wait(60)
   for player,state in pairs(states) do
    local character=player.Character;local hp=character and character:FindFirstChildOfClass("Humanoid")
    if state.Confirmed and hp and hp.Health>0 and not character:GetAttribute("Knockout") and not character:GetAttribute("IsDead") then
     hp.Health=math.min(hp.MaxHealth,hp.Health+Rules.Bonuses(state.Stats,state.Perks,state.Level).Regeneration)
     character:SetAttribute("Health",hp.Health)
    end
   end
  end
 end)
end
return Service
