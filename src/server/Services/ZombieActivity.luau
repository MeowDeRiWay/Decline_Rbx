-- One movement dispatcher; sleeping zombies have no individual Heartbeat callback.
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local Config=require(ReplicatedStorage.Shared.GameConfig)
local Progression=require(ReplicatedStorage.Shared.ProgressionRules)
local Rules=require(ReplicatedStorage.Shared.ZombieActivityRules)
local Service={}
local records,active,views,reportTimes={},{},{},{}
local footprints={}
local random=Random.new()
local viewRemote=Instance.new("RemoteEvent")
viewRemote.Name="ZombieActivityView";viewRemote.Parent=ReplicatedStorage
local function finite(number)
 return typeof(number)=="number" and number==number and math.abs(number)<math.huge
end
viewRemote.OnServerEvent:Connect(function(player,height,aspect)
 local now=os.clock()
 if now-(reportTimes[player] or -math.huge)<.4 then return end
 reportTimes[player]=now
 if not finite(height) or not finite(aspect) then return end
 local _,maximum=Progression.ZoomBounds(player:GetAttribute("ViewRange") or 25,Config.CameraHeight,Config.CameraFieldOfView)
 views[player]={Height=math.clamp(height,18,maximum),Aspect=math.clamp(aspect,.5,4)}
end)
Players.PlayerRemoving:Connect(function(player) views[player]=nil;reportTimes[player]=nil end)
local function playerFootprints()
 local result={}
 for _,player in ipairs(Players:GetPlayers()) do
  local character=player.Character
  local root=character and character:FindFirstChild("HumanoidRootPart")
  local hp=character and character:FindFirstChildOfClass("Humanoid")
  if not root or not hp or hp.Health<=0 or character:GetAttribute("IsDead") then continue end
  local _,maximum=Progression.ZoomBounds(player:GetAttribute("ViewRange") or 25,Config.CameraHeight,Config.CameraFieldOfView)
  local view=views[player]
  -- Before the first report, keep a conservative maximum screen active.
  local height=view and math.clamp(view.Height,18,maximum) or maximum
  local aspect=view and view.Aspect or 4
  local corners={}
  for _,offset in ipairs(Rules.ScreenOffsets(height,Config.CameraBack*height/Config.CameraHeight,Config.CameraFieldOfView,aspect)) do
   table.insert(corners,{X=root.Position.X+offset.X,Z=root.Position.Z+offset.Z})
  end
  corners.Center=root.Position;corners.Range=player:GetAttribute("ViewRange") or 5*(player:GetAttribute("Attention") or 5)
  table.insert(result,corners)
 end
 return result
end
local function gapAt(position)
 local gap=math.huge
 for _,corners in ipairs(footprints) do
  local radial=math.max(0,math.sqrt((position.X-corners.Center.X)^2+(position.Z-corners.Center.Z)^2)-corners.Range)
  gap=math.min(gap,math.max(radial,Rules.EdgeDistance(position.X,position.Z,corners)))
  if gap==0 then break end
 end
 return gap
end
local function teleport(record)
 local model,root=record.Model,record.Root
 local angle=random:NextNumber(-math.pi,math.pi)
 local radius=random:NextNumber(1,10)
 local raw=root.Position+Vector3.new(math.cos(angle)*radius,0,math.sin(angle)*radius)
 -- Never teleport into the active screen buffer or into the AFK band.
 if Rules.Mode(gapAt(raw))~="Minimal" then return end
 local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude
 params.FilterDescendantsInstances={model};params.RespectCanCollide=true
 local step=math.max(.15,root.Size.Y*.5)
 local origin=raw+Vector3.new(0,step,0)
 local delta=Vector3.new(0,-step-root.Size.Y/2-.3,0)
 local floor=workspace:Raycast(origin,delta,params)
 local reference=model:FindFirstChild("ZombieHome")
 local home=reference and reference.Value
 if home and home:IsDescendantOf(workspace) then
  local homeParams=RaycastParams.new();homeParams.FilterType=Enum.RaycastFilterType.Include
  homeParams.FilterDescendantsInstances={home}
  local hit=workspace:Raycast(origin,delta,homeParams)
  if hit and (not floor or hit.Position.Y>floor.Position.Y) then floor=hit end
 end
 if not floor or floor.Normal.Y<.85 then return end
 local position=Vector3.new(raw.X,floor.Position.Y+root.Size.Y/2+.02,raw.Z)
 if math.abs(position.Y-root.Position.Y)>step then return end
 local desired=CFrame.lookAt(position,position+Vector3.new(math.cos(angle),0,math.sin(angle)))
 local transform=desired*root.CFrame:Inverse()
 local box,size=model:GetBoundingBox()
 local overlap=OverlapParams.new();overlap.FilterType=Enum.RaycastFilterType.Exclude
 overlap.FilterDescendantsInstances={model};overlap.RespectCanCollide=true
 -- Endpoint only: no pathfinding, Blockcast or collision tests along the journey.
 if #workspace:GetPartBoundsInBox(transform*box,Vector3.new(math.max(.01,size.X-.02),math.max(.01,size.Y-.02),math.max(.01,size.Z-.02)),overlap)>0 then return end
 model:PivotTo(transform*model:GetPivot())
end
function Service.Register(model,root,step,onMode)
 local record={Model=model,Root=root,Step=step,OnMode=onMode,Mode=nil,NextTeleport=os.clock()+random:NextNumber(0,Rules.TeleportInterval)}
 records[model]=record
 return {Disconnect=function() records[model]=nil;active[model]=nil end}
end
local function change(record,mode)
 if record.Mode==mode then return end
 record.Mode=mode
 if mode=="Active" then active[record.Model]=record else active[record.Model]=nil end
 record.Model:SetAttribute("ActivityMode",mode)
 if record.OnMode then record.OnMode(mode) end
end
RunService.Heartbeat:Connect(function(dt)
 for model,record in pairs(active) do
  if not model:IsDescendantOf(workspace) then records[model]=nil;active[model]=nil
  else record.Step(dt) end
 end
end)
task.spawn(function()
 while true do
  footprints=playerFootprints()
  local budget=0
  for model,record in pairs(records) do
   local hp=model:FindFirstChildOfClass("Humanoid")
   if not model:IsDescendantOf(workspace) or not hp or hp.Health<=0 then records[model]=nil;active[model]=nil;continue end
   local mode=Rules.Mode(gapAt(record.Root.Position))
   change(record,mode)
   local now=os.clock()
   if mode=="Minimal" and now>=record.NextTeleport then
    record.NextTeleport=now+Rules.TeleportInterval
    teleport(record)
   elseif mode=="AFK" and now>=record.NextTeleport then
    -- No endpoint or movement work while AFK, and no synchronized wake-up burst.
    record.NextTeleport=now+random:NextNumber(1,Rules.TeleportInterval)
   end
   budget+=1
   if budget>=32 then budget=0;task.wait() end
  end
  task.wait(.5)
 end
end)
return Service
