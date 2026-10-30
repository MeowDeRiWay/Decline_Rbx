-- Server interest management. Persistent gameplay objects retain their identity;
-- static leaf geometry is reconstructed from shared, non-replicated prototypes.
local Players=game:GetService("Players")
local Storage=game:GetService("ServerStorage")
local Replicated=game:GetService("ReplicatedStorage")
local Config=require(Replicated.Shared.WorldActivityConfig)
local Rules=require(Replicated.Shared.WorldActivityRules)
local Ballistics=require(Replicated.Shared.FirearmRules)
local Stations=require(Replicated.Shared.CraftStations)
local Service={}
local records,prototypes,buckets={},{},{}
local sequence=0
local sleeping,library
local mutations=0
local nextCheck=0
local function checkpoint()
 mutations+=1
 if mutations%Config.GeometryBatch==0 then task.wait() end
end
local function containers()
 if sleeping then return end
 sleeping=Instance.new("Folder");sleeping.Name="DormantWorld";sleeping.Parent=Storage
 library=Instance.new("Folder");library.Name="WorldGeometryPrototypes";library.Parent=Storage
end
function Service.IsDormant(object)
 local current=object
 while current and current~=workspace and current~=game do
  if current:GetAttribute("WorldDormant")==true then return true end
  current=current.Parent
 end
 return false
end
function Service.Contains(object) return records[object]~=nil end
local function parts(model)
 local result=model:IsA("BasePart") and {model} or {}
 for _,object in ipairs(model:GetDescendants()) do if object:IsA("BasePart") then table.insert(result,object) end end
 return result
end
local function bounds(model)
 if model:IsA("BasePart") then return model.CFrame,model.Size end
 if model:FindFirstChildWhichIsA("BasePart",true) then return model:GetBoundingBox() end
end
local function unindex(record)
 for _,key in ipairs(record.Keys or {}) do
  local bucket=buckets[key]
  if bucket then bucket[record]=nil;if not next(bucket) then buckets[key]=nil end end
 end
 record.Keys={}
end
local function index(record)
 unindex(record)
 -- Conservative AABB of the full oriented model box.
 local f,s=record.Frame,record.Size
 local x=math.abs(f.RightVector.X)*s.X/2+math.abs(f.UpVector.X)*s.Y/2+math.abs(f.LookVector.X)*s.Z/2
 local z=math.abs(f.RightVector.Z)*s.X/2+math.abs(f.UpVector.Z)*s.Y/2+math.abs(f.LookVector.Z)*s.Z/2
 local cell=Config.BucketSize
 for ix=math.floor((f.Position.X-x)/cell),math.floor((f.Position.X+x)/cell) do
  for iz=math.floor((f.Position.Z-z)/cell),math.floor((f.Position.Z+z)/cell) do
   local key=ix..":"..iz;buckets[key]=buckets[key] or {};buckets[key][record]=true
   table.insert(record.Keys,key)
  end
 end
end
local function material(part)
 local ancestor=part
 while ancestor and ancestor~=workspace and ancestor~=Storage do
  local value=ancestor:GetAttribute("Material")
  if typeof(value)=="string" then return value,ancestor end
  ancestor=ancestor.Parent
 end
 local map={Wood="Wood",WoodPlanks="Wood",Glass="Glass",Brick="Brick",Concrete="Concrete",Metal="Metal",DiamondPlate="Metal",CorrodedMetal="Metal"}
 return map[part.Material.Name],part
end
local function protected(part,root,kind)
 if kind~="Building" and kind~="Resource" then return true end
 -- Keep stateful assemblies and references intact; only independent leaf parts
 -- are eligible for destruction/reconstruction.
 for _,child in ipairs(part:GetDescendants()) do
  if not child:IsA("Decal") and not child:IsA("Texture") and not child:IsA("SurfaceAppearance") and not child:IsA("SpecialMesh") then return true end
 end
 local current=part
 while current and current~=root do
  if current:GetAttribute("Door")==true or current:GetAttribute("Zombie_home")==true or typeof(current:GetAttribute("ItemPool"))=="string" or current.Name=="Chest" or current.Name=="TradePost" or current.Name=="GardenBed" or current.Name=="Well" or current:GetAttribute("TradePost")==true or current:GetAttribute("HospitalBed")==true or current.Name=="HospitalBed" or Stations.Kind(current) then return true end
  current=current.Parent
 end
 return part==root
end
local properties={"Name","CFrame","Size","Color","Material","MaterialVariant","Transparency","Reflectance","Anchored","CanCollide","CanQuery","CanTouch","CastShadow","CollisionGroup","CustomPhysicalProperties","Shape"}
local function snapshot(part)
 local saved={Attributes=part:GetAttributes(),Properties={}}
 for _,key in ipairs(properties) do
  local ok,value=pcall(function() return part[key] end)
  if ok then saved.Properties[key]=value end
 end
 return saved
end
local function restore(part,saved)
 for key in pairs(part:GetAttributes()) do part:SetAttribute(key,nil) end
 for key,value in pairs(saved.Attributes) do part:SetAttribute(key,value) end
 for key,value in pairs(saved.Properties) do pcall(function() part[key]=value end) end
end
local function forget(root,record)
 unindex(record);records[root]=nil
 if record.Connection then record.Connection:Disconnect() end
 local group=prototypes[record.Source]
 if group then
  group.Users-=1
  if group.Users==0 then
   for _,part in pairs(group.Parts) do part:Destroy() end
   prototypes[record.Source]=nil
  end
 end
end
function Service.Register(root,kind,source)
 if records[root] then return end
 if Service.IsDormant(root) or not root:IsDescendantOf(workspace) then return end
 local frame,size=bounds(root);if not frame then return end
 -- Authored runnable scripts have coroutine state that cannot be reconstructed
 -- by moving their owner out of Workspace. Keep those roots active.
 for _,object in ipairs(root:GetDescendants()) do
  if object:IsA("Script") or object:IsA("LocalScript") then return end
 end
 containers();sequence+=1
 local record={ID=sequence,Root=root,Kind=kind,Source=source or (kind..":"..sequence),Parent=root.Parent,Frame=frame,Size=size,State="Active",LastNear=os.clock(),Slots=setmetatable({},{__mode="k"}),NextSlot=0,Keys={}}
 for _,part in ipairs(parts(root)) do record.NextSlot+=1;record.Slots[part]=record.NextSlot end
 local group=prototypes[record.Source]
 if not group then group={Users=0,Parts={}};prototypes[record.Source]=group end
 group.Users+=1
 records[root]=record;nextCheck=0
 root:SetAttribute("WorldActivityState","Active")
 index(record)
 record.Connection=root.Destroying:Connect(function() forget(root,record) end)
end
-- Road identity/bounds remain available to generators and the map even when
-- the physical instance is outside Workspace. Roads retain their cheap parts:
-- cloning a unique slab into a prototype would not save memory.
function Service.IsRoad(root)
 if not root or (not root:IsA("Model") and not root:IsA("BasePart")) then return false end
 local record=records[root]
 if record and record.Kind=="Road" then return true end
 local parent=root.Parent
 return root:GetAttribute("Road")==true or (parent and parent:IsA("Folder") and string.lower(parent.Name)=="roads") or false
end
function Service.Footprint(root)
 local record=records[root]
 if record and record.Kind=="Road" and record.State~="Active" then return record.Frame,record.Size end
end
function Service.Roads()
 local result={}
 for root,record in pairs(records) do if record.Kind=="Road" then table.insert(result,root) end end
 return result
end
function Service.RegisterRoad(root)
 if not Service.IsRoad(root) or not root:IsDescendantOf(workspace) then return end
 local ancestor=root.Parent
 while ancestor and ancestor~=workspace do
  if records[ancestor] then return end
  ancestor=ancestor.Parent
 end
 local list=parts(root)
 if #list==0 then return end
 for _,part in ipairs(list) do if not part.Anchored then return end end
 Service.Register(root,"Road")
end
local function prepare(record)
 local descriptors={}
 local protectedJoints={}
 for _,object in ipairs(record.Root:GetDescendants()) do
  if object:IsA("ObjectValue") and object.Value and object.Value:IsA("BasePart") then protectedJoints[object.Value]=true end
  if object:IsA("JointInstance") or object:IsA("WeldConstraint") then
   if object.Part0 then protectedJoints[object.Part0]=true end
   if object.Part1 then protectedJoints[object.Part1]=true end
  end
 end
 for _,part in ipairs(parts(record.Root)) do
  local kind,group=material(part)
  local slot=record.Slots[part]
  if not slot then record.NextSlot+=1;slot="dynamic:"..record.ID..":"..record.NextSlot;record.Slots[part]=slot end
  table.insert(descriptors,{Part=part,Frame=part.CFrame,Size=part.Size,Query=part.CanQuery,Material=kind,Group=group,
   Block=part:IsA("Part") and part.Shape==Enum.PartType.Block,Slot=slot,Parent=part.Parent,
   Protected=protectedJoints[part] or protected(part,record.Root,record.Kind)})
  checkpoint()
  if records[record.Root]~=record then return nil end
 end
 return descriptors
end
local function sleep(record,now,positions)
 record.Busy=true
 local frame,size=bounds(record.Root)
 if not frame then record.Busy=false;return end
 record.Frame,record.Size=frame,size
 local descriptors=prepare(record)
 if not descriptors or records[record.Root]~=record or not record.Root:IsDescendantOf(workspace) or Rules.Near(frame,size,Service.Positions(),Config.SleepRadius) then record.Busy=false;return end
 record.Descriptors=descriptors;record.State="Sleeping";record.Since=now
 record.Root:SetAttribute("WorldDormant",true)
 record.Root:SetAttribute("WorldActivityState","Sleeping")
 record.Root.Parent=sleeping
 index(record);record.Busy=false
end
local function cold(record)
 record.Busy=true
 local group=prototypes[record.Source]
 for _,d in ipairs(record.Descriptors or {}) do
  if records[record.Root]~=record then record.Busy=false;return end
  local part=d.Part
  if part and part.Parent and not d.Protected then
   if not group.Parts[d.Slot] then
    local ok,prototype=pcall(function() return part:Clone() end)
    if ok and prototype then prototype.Parent=library;group.Parts[d.Slot]=prototype end
   end
   if group.Parts[d.Slot] then
    d.Saved=snapshot(part);part:Destroy();d.Part=nil
    -- A material group may itself have been the destroyed leaf part.
    if d.Group==part then d.Group=d end
   end
  end
  checkpoint()
 end
 record.State="Cold";record.Root:SetAttribute("WorldActivityState","Cold");record.Busy=false
end
local function wake(record)
 if record.Busy or record.State=="Active" then return false end
 if not record.Parent or not record.Parent.Parent then record.Root:Destroy();return false end
 record.Busy=true
 local group=prototypes[record.Source]
 for _,d in ipairs(record.Descriptors or {}) do
  if records[record.Root]~=record then record.Busy=false;return false end
  if not d.Part and d.Saved and d.Parent.Parent then
   local part=group.Parts[d.Slot]:Clone();restore(part,d.Saved)
   part.Parent=d.Parent;record.Slots[part]=d.Slot;d.Part=part
  end
  checkpoint()
 end
 -- Geometry is fully restored before exposing the root to physics/clients.
 record.State="Active";record.LastNear=os.clock()
 record.Root:SetAttribute("WorldDormant",nil)
 record.Root:SetAttribute("WorldActivityState","Active")
 record.Root.Parent=record.Parent
 record.Descriptors=nil;record.Busy=false
 return true
end
function Service.Positions()
 local result={}
 for _,player in ipairs(Players:GetPlayers()) do
  local c=player.Character;local root=c and c:FindFirstChild("HumanoidRootPart");local hp=c and c:FindFirstChildOfClass("Humanoid")
  if root and hp and hp.Health>0 then table.insert(result,root.Position) end
 end
 return result
end
function Service.Ensure(position,radius)
 -- Reconnects can restore an offline player inside a sleeping house. Finish
 -- nearby geometry before the caller unanchors that player.
 for _,record in pairs(records) do
  if record.State~="Active" and Rules.DistanceSquared(record.Frame,record.Size,position)<=(radius or 4)^2 then
   while record.Busy do task.wait() end
   wake(record)
  end
 end
end
function Service.Step(now)
 local points=Service.Positions()
 local transitions=0
 local nearby={}
 local cell=Config.BucketSize
 for _,point in ipairs(points) do
  for x=math.floor((point.X-Config.SleepRadius)/cell),math.floor((point.X+Config.SleepRadius)/cell) do
   for z=math.floor((point.Z-Config.SleepRadius)/cell),math.floor((point.Z+Config.SleepRadius)/cell) do
    for record in pairs(buckets[x..":"..z] or {}) do nearby[record]=true end
   end
  end
 end
 -- Restore the nearest surfaces before spending this pass on distant cleanup.
 -- Otherwise a large backlog of sleeping roads could starve a player's floor.
 local waking,distances={},{}
 for record in pairs(nearby) do
  if record.State=="Active" or record.Busy then continue end
  local best=math.huge
  for _,point in ipairs(points) do best=math.min(best,Rules.DistanceSquared(record.Frame,record.Size,point)) end
  if best<=Config.ActiveRadius^2 then distances[record]=best;table.insert(waking,record) end
 end
 table.sort(waking,function(a,b) return distances[a]<distances[b] end)
 for _,record in ipairs(waking) do
  if transitions>=Config.TransitionsPerStep then break end
  if records[record.Root]~=record or record.Busy then continue end
  if wake(record) then transitions+=1;task.wait() end
 end
 local examined=0
 local quiet=true
 for root,record in pairs(records) do
  examined+=1;if examined%128==0 then task.wait() end
  if not root.Parent then continue end
  if record.Kind=="NPC" then
   local hp=root:FindFirstChildOfClass("Humanoid")
   if not hp or hp.Health<=0 or root:GetAttribute("IsDead") or root:GetAttribute("IsCorpse") then
    if record.State~="Active" then wake(record) end
    forget(root,record);continue
   end
  end
  if record.Kind=="NPC" and record.State=="Active" then
   local frame,size=bounds(root);if frame then record.Frame,record.Size=frame,size;index(record) end
  end
  local near=nearby[record] and Rules.Near(record.Frame,record.Size,points,record.State=="Active" and Config.SleepRadius or Config.ActiveRadius)
  if record.State=="Active" then
   quiet=false
   if near then record.LastNear=now
   elseif now-record.LastNear>=Config.SleepDelay and transitions<Config.TransitionsPerStep and not record.Busy then
    sleep(record,now,points);transitions+=1;task.wait()
   end
  elseif record.State=="Sleeping" or record.State=="Cold" then
   if near and transitions<Config.TransitionsPerStep and not record.Busy then wake(record);transitions+=1;task.wait()
   elseif record.State=="Sleeping" and now-record.Since>=Config.ColdDelay and transitions<Config.TransitionsPerStep and not record.Busy then
    cold(record);transitions+=1;task.wait()
   end
   if record.State~="Cold" then quiet=false end
  end
 end
 return #points==0 and quiet and Config.DormantInterval or Config.CheckInterval
end
local function skipped(root,ignored)
 for _,object in ipairs(ignored or {}) do if root==object or root:IsDescendantOf(object) then return true end end
 return false
end
local function geometry(d)
 local part=d.Part
 if part then
  if part.Parent then return part.CFrame,part.Size,part.CanQuery end
  return d.Frame,d.Size,false
 end
 return d.Frame,d.Size,d.Query
end
function Service.Raycast(origin,delta,ignored,consumed,bulletOnly)
 local length=delta.Magnitude;if length<.00001 then return nil end
 local direction=delta/length;local cell=Config.BucketSize
 local candidates={}
 for x=math.floor(math.min(origin.X,origin.X+delta.X)/cell),math.floor(math.max(origin.X,origin.X+delta.X)/cell) do
  for z=math.floor(math.min(origin.Z,origin.Z+delta.Z)/cell),math.floor(math.max(origin.Z,origin.Z+delta.Z)/cell) do
   for record in pairs(buckets[x..":"..z] or {}) do candidates[record]=true end
  end
 end
 local closest
 for record in pairs(candidates) do
  if record.State=="Active" then continue end
  if bulletOnly and (record.Kind=="Item" or record.Root:GetAttribute("Knockout")) then continue end
  if skipped(record.Root,ignored) then continue end
  local a,b=Ballistics.Interval(origin,direction,record.Frame,record.Size)
  if not a or b<0 or a>length then continue end
  for _,d in ipairs(record.Descriptors or {}) do
   if consumed and consumed[d] then continue end
   local frame,size,query=geometry(d)
   if not query then continue end
   local first,last=Ballistics.Interval(origin,direction,frame,size)
   local at=first and math.max(0,first)
   if at and last>.000001 and at<=length and (not closest or at<closest.Distance) then
    local point=origin+direction*at
    closest={Distance=at,Position=point,Normal=Rules.Normal(frame,size,point,direction),Instance=d.Part or record.Root,Descriptor=d,Record=record}
   end
  end
 end
 return closest
end
function Service.ResolveHit(hit)
 -- Death/loot callbacks expect actors in Workspace. Restore the struck actor
 -- and its immediate floor before applying damage, never the whole ray path.
 if hit.Record.Kind=="NPC" then
  local record=hit.Record
  while record.Busy do task.wait() end
  wake(record)
  Service.Ensure(hit.Position,4)
 end
end
function Service.Barrier(hit,direction)
 local d,record=hit.Descriptor,hit.Record
 if not d.Block or not d.Material then return nil end
 local intervals,entries={},{}
 for _,other in ipairs(record.Descriptors or {}) do
  local frame,size,query=geometry(other)
  if not query or not other.Block or other.Group~=d.Group or other.Material~=d.Material then continue end
  local a,b=Ballistics.Interval(hit.Position,direction,frame,size)
  if a and b>.000001 then table.insert(intervals,{a,b});table.insert(entries,{other,a,b}) end
  if #entries>=128 then break end
 end
 local span=Ballistics.Merge(intervals)[1]
 if not span or span[1]>.001 then return nil end
 local used={}
 for _,entry in ipairs(entries) do if entry[2]<=span[2] and entry[3]>=span[1] then table.insert(used,entry[1]) end end
 return d.Material,span[2],used
end
function Service.DormantNPCs()
 local result={}
 for root,record in pairs(records) do if record.Kind=="NPC" and record.State~="Active" then table.insert(result,root) end end
 return result
end
function Service.Stats()
 local result={Active=0,Sleeping=0,Cold=0,ReleasedParts=0}
 for _,record in pairs(records) do
  result[record.State]+=1
  for _,d in ipairs(record.Descriptors or {}) do if not d.Part then result.ReleasedParts+=1 end end
 end
 return result
end
function Service.Start()
 if Service.Started then return end;Service.Started=true;containers()
 Players.PlayerAdded:Connect(function() nextCheck=0 end)
 for _,object in ipairs(workspace:GetDescendants()) do Service.RegisterRoad(object) end
 workspace.DescendantAdded:Connect(function(object)
  Service.RegisterRoad(object)
  if object.Parent then Service.RegisterRoad(object.Parent) end
 end)
 task.spawn(function()
  local nextStats=0
  while true do
   local now=os.clock()
   if now>=nextCheck then
    nextCheck=math.huge
    local delay=Service.Step(now)
    nextCheck=math.min(nextCheck,now+delay)
    if now>=nextStats then
     nextStats=now+5
     for key,value in pairs(Service.Stats()) do sleeping:SetAttribute(key,value) end
    end
   end
   task.wait(Config.CheckInterval)
  end
 end)
end
return Service
