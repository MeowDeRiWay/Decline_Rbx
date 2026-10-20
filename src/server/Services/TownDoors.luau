local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")
local Interaction = require(ReplicatedStorage.Shared.Interaction)
local Rules = require(ReplicatedStorage.Shared.TownRules)
local Access = require(ReplicatedStorage.Shared.DoorRules)
local Config = require(ReplicatedStorage.Shared.TownConfig)
local Service = {}
local doors, lastAction = {}, {}
local function physical(object)
 local parts = {}
 if object:IsA("BasePart") then table.insert(parts, object) end
 for _, child in ipairs(object:GetDescendants()) do if child:IsA("BasePart") then table.insert(parts, child) end end
 return parts
end
local function ancestorAttribute(object, name)
 while object and object ~= workspace do
  local value = object:GetAttribute(name)
  if value ~= nil then return value end
  object = object.Parent
 end
end
local function flagFor(id)
 for _, object in ipairs(workspace:GetDescendants()) do
  if object.Name == "Flag" and object:GetAttribute("TownID") == id then return object end
 end
end
local function identity(door)
 local id = ancestorAttribute(door, "TownID")
 local flag = id and flagFor(id)
 return id, flag and flag:GetAttribute("LeaderID") or 0
end
function Service.Allowed(player, door)
 local id, leader = identity(door)
 return Access.Allowed(player.UserId, player:GetAttribute("TownID"), id,
  ancestorAttribute(door,"OwnerID"), Rules.ParseOwners(ancestorAttribute(door,"Co-OwnerID")), leader,
  ancestorAttribute(door,"TownGate") == true)
end
local function setOpen(door, record, open)
 door:SetAttribute("DoorOpen", open)
 for part, original in pairs(record.parts) do
  if part.Parent then
   part.Transparency = open and 1 or original.Transparency
   part.CanCollide = not open and original.CanCollide
   part.CanQuery = not open and original.CanQuery
   part.CanTouch = not open and original.CanTouch
   if open then part:SetAttribute("BlocksVision",false) else part:SetAttribute("BlocksVision",original.BlocksVision) end
  end
 end
end
local function near(player, door)
 local character = player.Character
 local root = character and character:FindFirstChild("HumanoidRootPart")
 local hp = character and character:FindFirstChildOfClass("Humanoid")
 if not root or not hp or hp.Health <= 0 or character:GetAttribute("Knockout") or character:GetAttribute("IsDead") then return false end
 if Interaction.Distance(door,root.Position) > Config.InteractionDistance then return false end
 local params = RaycastParams.new(); params.FilterType = Enum.RaycastFilterType.Exclude
 params.FilterDescendantsInstances = {character}
 local point = Interaction.NearestPoint(door,root.Position)
 local hit = workspace:Raycast(root.Position,point-root.Position,params)
 return not hit or hit.Instance == door or hit.Instance:IsDescendantOf(door)
end
function Service.Admit(player, door, townID)
 local record = doors[door]
 if not record or not door:IsDescendantOf(workspace) or ancestorAttribute(door,"TownGate") ~= true
  or ancestorAttribute(door,"TownID") ~= townID or player:GetAttribute("TownID") ~= nil or not near(player,door) then return false end
 record.untilTime = workspace:GetServerTimeNow()+20
 setOpen(door,record,true)
 return true
end
local function register(door)
 if doors[door] or door:GetAttribute("Door") ~= true or not (door:IsA("Model") or door:IsA("BasePart")) then return end
 -- One Door attribute on the outer moving assembly; child parts move together.
 local parent = door.Parent
 while parent and parent ~= workspace do if parent:GetAttribute("Door") == true then return end; parent=parent.Parent end
 local record = {parts={}}
 for _, part in ipairs(physical(door)) do
  record.parts[part] = {Transparency=part.Transparency,CanCollide=part.CanCollide,CanQuery=part.CanQuery,
   CanTouch=part.CanTouch,BlocksVision=part:GetAttribute("BlocksVision")}
 end
 doors[door] = record
 door:SetAttribute("DoorOpen",false)
end
local function generateWalls()
 local buildings = ServerStorage:FindFirstChild("Buildings")
 local library = buildings and buildings:FindFirstChild("Wall")
 for _, plot in ipairs(workspace:GetDescendants()) do
  if plot.Name ~= "WallPlace" or not (plot:IsA("Model") or plot:IsA("BasePart")) or plot:FindFirstChild("GeneratedWall") then continue end
  local name = plot:GetAttribute("WallTemplate")
  local template = typeof(name)=="string" and library and library:FindFirstChild(name)
  local yard = template and template:FindFirstChild("WallYard")
  local id = ancestorAttribute(plot,"TownID")
  if not template or not template:IsA("Model") or not yard or not id then
   warn("[Decline] WallPlace needs TownID, WallTemplate and a matching Buildings/Wall template with WallYard"); continue
  end
  local clone = template:Clone()
  local anchor = clone:FindFirstChild("WallYard")
  clone:PivotTo(plot:GetPivot() * anchor:GetPivot():ToObjectSpace(clone:GetPivot()))
  clone:SetAttribute("TownID",id)
  clone:SetAttribute("TownGate",clone:FindFirstChild("GateDoor",true) ~= nil)
  for _, part in ipairs(physical(clone)) do part.Anchored=true end
  for _, part in ipairs(physical(anchor)) do part.Transparency=1;part.CanCollide=false;part.CanQuery=false;part.CanTouch=false;part:SetAttribute("BlocksVision",false) end
  for _, part in ipairs(physical(plot)) do part.Transparency=1;part.CanCollide=false;part.CanQuery=false;part.CanTouch=false;part:SetAttribute("BlocksVision",false) end
  local group=Instance.new("Folder");group.Name="GeneratedWall";group.Parent=plot
  clone.Parent=group
 end
end
function Service.Start(requestPassage, tell)
 generateWalls()
 for _, object in ipairs(workspace:GetDescendants()) do register(object) end
 workspace.DescendantAdded:Connect(function(object) task.defer(function() if object:IsDescendantOf(workspace) then register(object) end end) end)
 local folder=Instance.new("Folder");folder.Name="DoorRemotes";folder.Parent=ReplicatedStorage
 local action=Instance.new("RemoteEvent");action.Name="Action";action.Parent=folder
 action.OnServerEvent:Connect(function(player,door)
  if typeof(door)~="Instance" or not doors[door] or not door:IsDescendantOf(workspace) then return end
  local time=workspace:GetServerTimeNow()
  if time-(lastAction[player] or -math.huge)<.5 then return end
  lastAction[player]=time
  if not near(player,door) then return end
  local record=doors[door]
  if Service.Allowed(player,door) then
   record.untilTime=workspace:GetServerTimeNow()+5
   setOpen(door,record,true)
  elseif player:GetAttribute("TownID")==nil and ancestorAttribute(door,"TownGate")==true and not door:GetAttribute("DoorOpen") then
   requestPassage(player,door,ancestorAttribute(door,"TownID"))
  else tell(player,"This door is locked. You do not have access.") end
 end)
 Players.PlayerRemoving:Connect(function(player) lastAction[player]=nil end)
 task.spawn(function()
  while true do
   task.wait(.25)
   for door,record in pairs(doors) do
    if not door:IsDescendantOf(workspace) then doors[door]=nil
    elseif record.untilTime and workspace:GetServerTimeNow()>=record.untilTime then record.untilTime=nil;setOpen(door,record,false) end
   end
  end
 end)
end
return Service
