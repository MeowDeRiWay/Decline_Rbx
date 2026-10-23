local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Services=script.Parent.Services
local Rules=require(Services.AdminRules)
local Clock=require(Services.DayClockService)
local Progression=require(Services.ProgressionService)
local Inventory=require(Services.InventoryService)
local Life=require(Services.PlayerLifeService)
local Items=require(ReplicatedStorage.Shared.ItemConfig).Items
local Journal=require(Services.JournalService)
Clock.Start()
local remote=Instance.new("RemoteFunction");remote.Name="AdminAction";remote.Parent=ReplicatedStorage
local last={}
local function ready(player)
 local c=player.Character
 local hp=c and c:FindFirstChildOfClass("Humanoid")
 if player:GetAttribute("AttributesConfirmed")~=true or not c or not hp or hp.Health<=0 or c:GetAttribute("IsDead") then return nil end
 return c,hp
end
local function handle(player,command,data)
 if command=="Request" then return true,"Ready." end
 if typeof(data)~="table" then return false,"Invalid request." end
 if command=="SetHour" and Rules.Number(data.Value,0,23.999,false) then Clock.SetHour(data.Value)
 elseif command=="SetSpeed" and Rules.Number(data.Value,0.01,100,false) then Clock.SetSpeed(data.Value)
 elseif command=="Pause" and typeof(data.Value)=="boolean" then Clock.SetPaused(data.Value)
 elseif command=="GiveItem" then
  if typeof(data.ID)~="string" or not Items[data.ID] or not Rules.Number(data.Count,1,1000,true) then return false,"Choose a valid item and a quantity from 1 to 1000." end
  local c=ready(player)
  if not c or c:GetAttribute("Knockout") then return false,"Spawn a living character first." end
  if not Inventory.Add(player,data.ID,data.Count) then return false,"Could not add the item." end
  Journal.Send(player,string.format("Admin: received %d x %s.",data.Count,Items[data.ID].Name))
  return true,string.format("Received %d x %s.",data.Count,Items[data.ID].Name)
 elseif command=="Levels" or command=="Heal" or command=="Needs" or command=="Revive" then
  if not Rules.Number(data.Target,1,1e15,true) then return false,"Choose an online player." end
  local target=Players:GetPlayerByUserId(data.Target)
  if not target then return false,"Player has left the server." end
  if command=="Levels" then
   if not Rules.Number(data.Count,1,100,true) then return false,"Enter 1 to 100 levels." end
   if not Progression.GrantLevels(target,data.Count) then return false,"Player must finish character creation first." end
  else
   local c,hp=ready(target)
   if not c then return false,"Player needs a living character." end
   if command=="Revive" then
    if not c:GetAttribute("Knockout") then return false,"Player is not knocked out." end
    local old=target:GetAttribute("ReviveLockedUntil")
    target:SetAttribute("ReviveLockedUntil",0)
    if not Life.Revive(target,0) then target:SetAttribute("ReviveLockedUntil",old);return false,"Could not revive this character." end
    hp.Health=hp.MaxHealth;c:SetAttribute("Health",hp.Health)
   elseif command=="Heal" then
    if c:GetAttribute("Knockout") then return false,"Use Revive for a knocked-out player." end
    hp.Health=hp.MaxHealth;c:SetAttribute("Health",hp.Health);c:SetAttribute("Sick",0)
   else c:SetAttribute("Food",100);c:SetAttribute("Water",100);c:SetAttribute("Sick",0) end
  end
  Journal.Send(target,"Admin "..player.Name..": "..command.." applied to your character.")
  return true,command.." applied to "..target.Name.."."
 else return false,"Invalid action or value." end
 return true,"Server time updated."
end
remote.OnServerInvoke=function(player,command,data)
 if not Rules.Allowed(player.UserId) then return {OK=false,Message="Access denied."} end
 local now=os.clock()
 if now-(last[player] or -math.huge)<.2 then return {OK=false,Message="Please wait a moment."} end
 last[player]=now
 local success,ok,message=pcall(handle,player,command,data)
 if not success then warn("[Admin] "..tostring(ok));return {OK=false,Message="Action failed."} end
 if ok and command~="Request" then print(string.format("[Admin] %s (%d): %s",player.Name,player.UserId,command)) end
 return {OK=ok,Message=message}
end
local function added(player) player:SetAttribute("AdminAccess",Rules.Allowed(player.UserId)) end
Players.PlayerAdded:Connect(added)
Players.PlayerRemoving:Connect(function(player) last[player]=nil end)
for _,player in ipairs(Players:GetPlayers()) do added(player) end
