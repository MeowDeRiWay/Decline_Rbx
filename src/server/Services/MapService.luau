local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Run=game:GetService("RunService")
local Rules=require(ReplicatedStorage.Shared.MapRules)
local Service={}
local candidates={}
local records={} -- Per-user exploration belongs only to this generated server world.
local index={}
local originX,originZ=0,0
local revision=0
local remote
local dirty=true
local lastBuild=-math.huge
local function box(object)
 if object:IsA("BasePart") then return object.CFrame,object.Size end
 if object:IsA("Model") and object:FindFirstChildWhichIsA("BasePart",true) then return object:GetBoundingBox() end
end
local function category(object)
 if object:IsA("Model") then
  if object:GetAttribute("GeneratedCityHouse")==true then
   return object:GetAttribute("GenerationCategory")=="Houses" and "House" or "Infrastructure"
  end
  if object.Name=="Forest" or object.Name=="ScrapYard" or object.Name=="StoneYard" then return object.Name end
  if object.Name=="BuildingSpace" and type(object:GetAttribute("BuildingID"))=="string" and object:GetAttribute("BuildingID")~="" then return "Infrastructure" end
  if object:GetAttribute("ZHouse")==true and object:FindFirstChild("Yard") then return "House" end
 end
 if object:GetAttribute("Road")==true then return "Road" end
 -- Support the existing authored Workspace/roads folder as well as Road=true.
 local parent=object.Parent
 if parent and string.lower(parent.Name)=="roads" and (object:IsA("BasePart") or object:IsA("Model")) then return "Road" end
end
local function track(object)
 if not (object:IsA("Model") or object:IsA("BasePart")) then return end
 if category(object) or (object:IsA("Model") and (object.Name=="YardPlace" or object.Name=="BuildingSpace")) then
  candidates[object]=true;dirty=true
 end
end
local function build()
 local regions={}
 local anchor
 for object in pairs(candidates) do
  if not object:IsDescendantOf(workspace) then candidates[object]=nil;continue end
  if not anchor and object.Name=="YardPlace" then local cf=box(object);if cf then anchor=cf.Position end end
 end
 if revision==0 and anchor then originX=(anchor.X-10)%20;originZ=(anchor.Z-10)%20 end
 local function add(object,kind)
  local cf,size=box(object)
  if not cf or size.X<=0 or size.Z<=0 then return end
  local c,s=cf.RightVector.X,cf.RightVector.Z
  -- Resource marker slabs are horizontal. Ignore pitch/roll in the 2D map.
  local length=math.sqrt(c*c+s*s);if length<.001 then return end
  c,s=c/length,s/length
  table.insert(regions,{X=cf.Position.X,Z=cf.Position.Z,W=size.X,H=size.Z,Cos=c,Sin=s,Kind=kind})
 end
 for object in pairs(candidates) do
  local kind=category(object)
  if not kind then continue end
  if kind=="Forest" or kind=="ScrapYard" or kind=="StoneYard" then
   for _,part in ipairs(object:GetDescendants()) do if part:IsA("BasePart") then add(part,kind) end end
  elseif kind=="House" or kind=="Infrastructure" then
   local source=object:FindFirstChild("GenerationSource")
   local footprint=(source and source.Value) or object:FindFirstChild("Yard") or object
   add(footprint,kind)
  else add(object,kind) end
 end
 index=Rules.Index(regions,originX,originZ)
 revision+=1;dirty=false;lastBuild=os.clock()
end
local function recordFor(player)
 local r=records[player.UserId]
 if not r then r={Seen={},Sent={},Version=player:GetAttribute("MapExplorationVersion") or 0};records[player.UserId]=r end
 return r
end
local function send(player,r,reset)
 local batch={}
 local function flush(clear)
  if #batch==0 and not clear then return end
  remote:FireClient(player,{Reset=clear==true,OriginX=originX,OriginZ=originZ,Cells=batch})
  batch={}
 end
 if reset then r.Sent={};flush(true) end
 for key,cell in pairs(r.Seen) do
  local data,signature=Rules.CellData(index,cell.X,cell.Z,originX,originZ)
  if r.Sent[key]~=signature then
   r.Sent[key]=signature;table.insert(batch,data)
   if #batch==256 then flush(false) end
  end
 end
 flush(false)
end
function Service.Step(player)
 if dirty and os.clock()-lastBuild>=2 then build() end
 local r=recordFor(player)
 local character=player.Character
 local root=character and character:FindFirstChild("HumanoidRootPart")
 local hp=character and character:FindFirstChildOfClass("Humanoid")
 if not root or not hp or hp.Health<=0 or player:GetAttribute("CharacterLoading") or player:GetAttribute("Reconnecting") or player:GetAttribute("AttributesConfirmed")~=true or character:GetAttribute("Knockout") or character:GetAttribute("IsDead") or player:GetAttribute("OutcastEnd") then return end
 local x,z=Rules.Cell(root.Position.X,root.Position.Z,originX,originZ)
 if r.X==x and r.Z==z and r.Revision==revision then return end
 r.X,r.Z,r.Revision=x,z,revision
 Rules.Reveal(x,z,r.Seen)
 -- Only newly revealed / nearby refreshed cells need a delta on movement.
 local nearby={}
 for dx=-1,1 do for dz=-1,1 do local key=Rules.Key(x+dx,z+dz);nearby[key]=r.Seen[key] end end
 local batch={}
 for key,cell in pairs(nearby) do
  local data,signature=Rules.CellData(index,cell.X,cell.Z,originX,originZ)
  if r.Sent[key]~=signature then r.Sent[key]=signature;table.insert(batch,data) end
 end
 if #batch>0 then remote:FireClient(player,{OriginX=originX,OriginZ=originZ,Cells=batch}) end
end
function Service.Start()
 if Service.Started then return end;Service.Started=true
 remote=Instance.new("RemoteEvent");remote.Name="MapState";remote.Parent=ReplicatedStorage
 local request=Instance.new("RemoteEvent");request.Name="MapRequest";request.Parent=ReplicatedStorage
 for _,object in ipairs(workspace:GetDescendants()) do track(object) end
 build()
 workspace.DescendantAdded:Connect(function(object)
  track(object)
  -- An authored model may be parented before its Yard/marker parts are added.
  if object.Parent then track(object.Parent) end
 end)
 workspace.DescendantRemoving:Connect(function(object) if candidates[object] then candidates[object]=nil;dirty=true end end)
 local function added(player)
  local r=recordFor(player)
  player:GetAttributeChangedSignal("MapExplorationVersion"):Connect(function()
   local version=player:GetAttribute("MapExplorationVersion") or 0
   if version~=r.Version then r.Version=version;r.Seen={};r.Sent={};r.X=nil;send(player,r,true) end
  end)
 end
 Players.PlayerAdded:Connect(added)
 for _,player in ipairs(Players:GetPlayers()) do added(player) end
 request.OnServerEvent:Connect(function(player)
  local r=recordFor(player)
  if r.RequestAt and os.clock()-r.RequestAt<1 then return end
  r.RequestAt=os.clock()
  if dirty then build() end
  Service.Step(player);send(player,r,true)
 end)
 Players.PlayerRemoving:Connect(function(player) local r=records[player.UserId];if r then r.RequestAt=nil end end)
 local elapsed=0
 Run.Heartbeat:Connect(function(dt)
  elapsed+=dt;if elapsed<.5 then return end;elapsed=0
  -- Re-read live footprints/categories without scanning world descendants again.
  if os.clock()-lastBuild>=15 then dirty=true end
  for _,player in ipairs(Players:GetPlayers()) do Service.Step(player) end
 end)
end
return Service
