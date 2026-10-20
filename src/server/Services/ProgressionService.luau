local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Rules=require(ReplicatedStorage.Shared.ProgressionRules)
local Config=require(ReplicatedStorage.Shared.ProgressionConfig)
local Items=require(ReplicatedStorage.Shared.ItemConfig).Items
local Journal=require(script.Parent.JournalService)
local Service={}
local states={}
local remote
local random=Random.new()
local function stateFor(player)
 if not states[player] then states[player]=Rules.New(Config.StartingPoints) end
 return states[player]
end
function Service.Sync(player)
 local state=stateFor(player)
 local bonus=Rules.Bonuses(state.Stats)
 for id,value in pairs(Rules.CombatBonuses(state)) do bonus[id]=value end
 player:SetAttribute("Profession",state.Profession)
 player:SetAttribute("ProfessionLevel",state.Level)
 player:SetAttribute("ProfessionXP",state.XP)
 player:SetAttribute("AttributePoints",state.Points)
 player:SetAttribute("TalentPoints",state.TalentPoints)
 for id,value in pairs(state.Stats) do player:SetAttribute(id,value) end
 for id,value in pairs(bonus) do player:SetAttribute(id,value) end
 local character=player.Character
 if character then
  for id,value in pairs(bonus) do character:SetAttribute(id,value) end
  local hp=character:FindFirstChildOfClass("Humanoid")
  if hp then hp.MaxHealth=bonus.MaxHealth; character:SetAttribute("MaxHealth",hp.MaxHealth) end
 end
 if remote and player.Parent==Players then remote:FireClient(player,Service.Snapshot(player)) end
end
function Service.Snapshot(player)
 local s=stateFor(player)
 return {Level=s.Level,XP=s.XP,NextXP=100*(s.Level+1),Points=s.Points,Profession=s.Profession,
  TalentPoints=s.TalentPoints,Stats=table.clone(s.Stats),Bonuses=Rules.Bonuses(s.Stats),Talents=table.clone(s.Talents)}
end
function Service.Award(player,amount)
 if not player or player.Parent~=Players then return end
 if typeof(amount)=="number" and amount>0 then Journal.Send(player,string.format("You gained %d XP.",math.floor(amount+.5))) end
 if Rules.AddXP(stateFor(player),amount) then Service.Sync(player) end
end
function Service.CanStation(player,name)
 if name=="Workstation" then return true end
 local profession=Config.Professions[stateFor(player).Profession]
 return profession and profession.Stations[name]==true or false
end
function Service.CanBuild(player,kind)
 local profession=Config.Professions[stateFor(player).Profession]
 -- Before selecting a profession existing buildings remain available.
 return stateFor(player).Profession=="" or (profession and profession.Buildings[kind]==true) or false
end
function Service.CraftEffects(player,station,count)
 return Rules.CraftEffects(stateFor(player),station,count)
end
function Service.CraftXP(player,station)
 local profession=Config.Professions[stateFor(player).Profession]
 if profession and profession.Stations[station] then Service.Award(player,Config.CraftXP) end
end
function Service.Loot(player,items)
 if not player or player.Parent~=Players then return items end
 return Rules.BonusLoot(items,stateFor(player).Stats,function() return random:NextNumber() end)
end
function Service.ZombieDied(model,items)
 local player=Players:GetPlayerByUserId(model:GetAttribute("LastDamagerID") or 0)
 Service.Award(player,Config.ZombieXP)
 if player and player.Parent==Players then
  local definition=Items[model:GetAttribute("LastHitItem")]
  local extra=Rules.ShovelLoot(stateFor(player),definition and definition.HarvestTool=="Shovel",function() return random:NextNumber() end)
  if extra>0 then items=table.clone(items); items.Rags=(items.Rags or 0)+extra end
 end
 return Service.Loot(player,items)
end
function Service.Start()
 if Service.Started then return end
 Service.Started=true
 local folder=Instance.new("Folder"); folder.Name="ProgressionRemotes"; folder.Parent=ReplicatedStorage
 remote=Instance.new("RemoteEvent"); remote.Name="State"; remote.Parent=folder
 local action=Instance.new("RemoteEvent"); action.Name="Action"; action.Parent=folder
 local last={}
 action.OnServerEvent:Connect(function(player,command,value)
  if typeof(command)~="string" then return end
  local now=os.clock()
  if now-(last[player] or -math.huge)<.1 then return end
  last[player]=now
  local state=stateFor(player)
  if command=="Request" then Service.Sync(player); return end
  if typeof(value)~="string" then return end
  if command=="Choose" and state.Profession=="" and Config.Professions[value] then state.Profession=value
  elseif command=="Spend" then Rules.Spend(state,value)
  elseif command=="Talent" then
   local profession=Config.Professions[state.Profession]
   if profession then Rules.Learn(state,value,profession.Talents[value]) end
  end
  Service.Sync(player)
 end)
 local function added(player)
  stateFor(player); Service.Sync(player)
  player.CharacterAdded:Connect(function(character)
   character:WaitForChild("Humanoid",10)
   if player.Character==character then Service.Sync(player) end
  end)
 end
 Players.PlayerAdded:Connect(added)
 Players.PlayerRemoving:Connect(function(player) states[player]=nil; last[player]=nil end)
 for _,player in ipairs(Players:GetPlayers()) do added(player) end
end
return Service
