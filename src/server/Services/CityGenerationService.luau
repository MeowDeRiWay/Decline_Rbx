local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.CityGenerationConfig)
local Rules = require(ReplicatedStorage.Shared.CityGenerationRules)
local Furniture=require(script.Parent.StoreFurnitureService)
local Walls=require(script.Parent.WallReplacementService)
local Placement=require(script.Parent.StaticPlacement)
local Service = {}
local started = false
local configuredSeed = Config.Seed
local seed = if typeof(configuredSeed)=="number" and configuredSeed==configuredSeed and math.abs(configuredSeed)<math.huge
 then math.floor(configuredSeed) else Random.new():NextInteger(0,2147483647)
local generated, busy, warnings = {}, {}, {}
local categories=setmetatable({},{__mode="k"})
local folder
local hiddenPlots,boundsCache,retryAt={},{},{}
local hidePlot
local deadline=0
local generating=false
local function budget()
 if os.clock()>=deadline then task.wait();deadline=os.clock()+.002 end
end
local function generatedContent(object)
 local ancestor=object
 while ancestor and ancestor~=workspace do
  if ancestor==folder or ancestor.Name=="GeneratedFurniture" or ancestor:GetAttribute("GeneratedCityHouse")==true or ancestor:GetAttribute("GeneratedWallPiece")==true then return true end
  ancestor=ancestor.Parent
 end
 return false
end
local function box(object)
 if object:IsA("Model") and object:FindFirstChildWhichIsA("BasePart",true) then return object:GetBoundingBox() end
 if object:IsA("BasePart") then return object.CFrame,object.Size end
 return nil
end
-- Only authored workspace bounds are cached. Template geometry remains live.
local function authoredBox(object)
 local cached=boundsCache[object]
 if cached then return cached.Frame,cached.Size end
 local frame,size=box(object)
 if frame then boundsCache[object]={Frame=frame,Size=size} end
 return frame,size
end
local function invalidateBounds(object)
 local current=object
 while current and current~=workspace do boundsCache[current]=nil;current=current.Parent end
end
local function positions()
 local result={}
 for _,player in ipairs(Players:GetPlayers()) do
  local character=player.Character
  local root=character and character:FindFirstChild("HumanoidRootPart")
  local hp=character and character:FindFirstChildOfClass("Humanoid")
  if root and hp and hp.Health>0 then table.insert(result,root.Position) end
 end
 return result
end
local function distance(object,points)
 local frame,size=authoredBox(object)
 if not frame then return math.huge end
 local best=math.huge
 for _,point in ipairs(points) do best=math.min(best,Rules.DistanceSquared(frame,size,point)) end
 return best
end
local function nearby(object,points)
 return distance(object,points or positions())<=Config.GenerationRadius*Config.GenerationRadius
end
local function plotSeed(plot,frame)
 local hash=seed
 local key=string.format("%.4f:%.4f:%.4f:%s",frame.Position.X,frame.Position.Y,frame.Position.Z,plot:GetFullName())
 for i=1,#key do hash=(hash*31+string.byte(key,i))%2147483647 end
 return hash
end
local function warnOnce(plot, message)
 if warnings[plot] ~= message then warnings[plot] = message; warn("[Decline City] " .. message) end
end
local function templates(category)
 local root = ServerStorage:FindFirstChild("CityGeneration")
 local houses = root and root:FindFirstChild(category)
 local result = {}
 if houses then
  for _, house in ipairs(houses:GetChildren()) do
   local yard = house:FindFirstChild("Yard")
   if house:IsA("Model") and (category~="Houses" or house:GetAttribute("ZHouse") == true) and yard and box(yard) then table.insert(result,house) end
  end
 end
 table.sort(result,function(a,b) return a.Name < b.Name end)
 return result
end
-- Comparators must never query model geometry: sorting a town previously made
-- tens of thousands of GetBoundingBox/FindFirstChildWhichIsA calls per retry.
local function sortPlots(list)
 local keys={}
 for index,object in ipairs(list) do
  local frame=authoredBox(object)
  keys[object]={Position=frame and frame.Position,Name=object:GetFullName()}
  if index%32==0 then budget() end
 end
 table.sort(list,function(a,b)
  local ak,bk=keys[a],keys[b]
  local ap,bp=ak.Position,bk.Position
  if (ap==nil)~=(bp==nil) then return ap~=nil end
  if ap and bp then
   for _,key in ipairs({"X","Z","Y"}) do
    if ap[key]~=bp[key] then return ap[key]<bp[key] end
   end
  end
  return ak.Name<bk.Name
 end)
end
-- Keep authored candidates indexed; retry ticks never allocate a full world descendant list.
local plotIndex,roadIndex,markerIndex={},{},{}
local watchers={}
local function untrack(object)
 if not watchers[object] and not boundsCache[object] then return end
 invalidateBounds(object)
 hiddenPlots[object],retryAt[object]=nil,nil
 plotIndex[object],roadIndex[object],markerIndex[object]=nil,nil,nil
 local connections=watchers[object]
 if connections then for _,connection in ipairs(connections) do connection:Disconnect() end end
 watchers[object]=nil
end
local function classify(object)
 retryAt[object]=nil
 if not object:IsDescendantOf(workspace) or generatedContent(object) then
  plotIndex[object],roadIndex[object],markerIndex[object]=nil,nil,nil;return
 end
 plotIndex[object]=object:IsA("Model") and ((object.Name=="YardPlace" and object:GetAttribute("ForZHouse")==true) or object:GetAttribute("ForInfrastructure")==true) or nil
 if plotIndex[object] and not hiddenPlots[object] then hidePlot(object);hiddenPlots[object]=true end
 roadIndex[object]=object:GetAttribute("Road")==true or nil
 markerIndex[object]=(object.Name=="WallYard" or Furniture.IsMarker(object) or typeof(object:GetAttribute("Replace"))=="string") or nil
end
local function track(object)
 if not (object:IsA("Model") or object:IsA("BasePart")) or generatedContent(object) then return end
 invalidateBounds(object)
 classify(object)
 if not started or watchers[object] then return end
 local connections={};watchers[object]=connections
 for _,key in ipairs({"ForZHouse","ForInfrastructure","Road","Replace","AutoPlacer"}) do
  table.insert(connections,object:GetAttributeChangedSignal(key):Connect(function() classify(object) end))
 end
 table.insert(connections,object:GetPropertyChangedSignal("Name"):Connect(function() classify(object) end))
 if object:IsA("BasePart") then
  for _,property in ipairs({"CFrame","Size"}) do
   table.insert(connections,object:GetPropertyChangedSignal(property):Connect(function() invalidateBounds(object) end))
  end
  local ancestor=object.Parent
  while ancestor and ancestor~=workspace do
   if plotIndex[ancestor] then hidePlot(object);break end
   ancestor=ancestor.Parent
  end
 end
end
local function roads()
 local result={}
 for object in pairs(roadIndex) do
  if object:IsDescendantOf(workspace) and authoredBox(object) then table.insert(result,object) end
 end
 sortPlots(result);return result
end
local function nearestRoad(plotFrame, list)
 local point, distance
 for index, road in ipairs(list) do
  if index%64==0 then budget() end
  local frame,size = authoredBox(road)
  if not frame then continue end
  local candidate = Rules.RoadPoint(frame,size,plotFrame.Position)
  local delta = candidate - plotFrame.Position
  local d = Vector3.new(delta.X,0,delta.Z).Magnitude
  if d > .001 and (not distance or d < distance) then point,distance = candidate,d end
 end
 return point
end
hidePlot=function(plot)
 local parts=plot:IsA("BasePart") and {plot} or plot:GetDescendants()
 for _, part in ipairs(parts) do
  if part:IsA("BasePart") then
   part.Transparency,part.CanCollide,part.CanTouch,part.CanQuery = 1,false,false,false
   part.Anchored,part.CastShadow = true,false
   part:SetAttribute("BlocksVision",false)
  end
 end
 plot:SetAttribute("BlocksVision",false)
end
local function place(plot, sources, roadList)
 if busy[plot] or generatedContent(plot) or not plot:IsDescendantOf(workspace) or (plot:GetAttribute("ForZHouse") ~= true and plot:GetAttribute("ForInfrastructure") ~= true) then return end
 local explicit=plot:GetAttribute("GenerationCategory") or (plot:GetAttribute("ForInfrastructure")==true and "Factories" or nil)
 if explicit and not sources[explicit] then warnOnce(plot,"Unknown GenerationCategory: "..tostring(explicit));return end
 if generated[plot] and generated[plot]:IsDescendantOf(workspace) then return end
 local existing = plot:FindFirstChild("GeneratedHouse")
 if existing and existing:IsA("ObjectValue") and existing.Value and existing.Value:IsDescendantOf(workspace) then
  generated[plot] = existing.Value; hidePlot(plot); return
 end
 if #sources.Houses==0 and #sources.Stores==0 and #sources.Factories==0 then warnOnce(plot,"Add building Models with an inner Yard in ServerStorage/CityGeneration/Houses, Stores or Factories"); return end
 local plotFrame,plotSize = authoredBox(plot)
 if not plotFrame then warnOnce(plot,"YardPlace needs a physical marker Part"); return end
 if math.abs(plotFrame.UpVector.Y-1) > .001 then warnOnce(plot,"YardPlace must be horizontal; yaw rotation is supported"); return end
 local roadPoint = nearestRoad(plotFrame,roadList)
 if not plot:IsDescendantOf(workspace) or not nearby(plot) then return end
 if not roadPoint then warnOnce(plot,"No usable road with Road=true near YardPlace"); return end
 busy[plot] = true
 local random=Random.new(plotSeed(plot,plotFrame))
 local function candidatesFor(category)
  local result={}
  for _,house in ipairs(sources[category]) do
   local yardFrame,yardSize=box(house:FindFirstChild("Yard"))
   local localYard=house:GetPivot():ToObjectSpace(yardFrame)
   local frame=Rules.Frame(plotFrame,localYard,roadPoint)
   if Rules.Fits(frame,localYard,yardSize,plotFrame,plotSize,Config.FitTolerance) then table.insert(result,{house=house,frame=frame}) end
  end
  return result
 end
 if not categories[plot] then categories[plot]=explicit or Rules.Category(random:NextNumber(),Config.StoreChance) end
 local category=categories[plot]
 local candidates=candidatesFor(category)
 if #candidates==0 and not explicit then
  category=category=="Stores" and "Houses" or "Stores"
  candidates=candidatesFor(category)
 end
 if #candidates==0 then busy[plot]=nil; warnOnce(plot,"No building Yard fits this YardPlace; match the building Yard to the plot footprint (20x20 or 40x40) and aligned yard axes"); return end
 local chosen = candidates[random:NextInteger(1,#candidates)]
 local clone = chosen.house:Clone()
 clone:SetAttribute("GeneratedCityHouse",true)
 clone:SetAttribute("ForInfrastructure",nil)
 clone:SetAttribute("GenerationCategory",category)
 clone:SetAttribute("GenerationSeed",seed)
 local yard = clone:FindFirstChild("Yard")
 local yardParts=yard:IsA("BasePart") and {yard} or yard:GetDescendants()
 for _, part in ipairs(yardParts) do
  if part:IsA("BasePart") then
   part.Transparency,part.CanCollide,part.CanTouch,part.CanQuery = 1,false,false,false
   part:SetAttribute("BlocksVision",false)
  end
 end
 yard:SetAttribute("BlocksVision",false)
 for _, part in ipairs(clone:GetDescendants()) do if part:IsA("BasePart") then part.Anchored = true end end
 Placement.Move(clone,chosen.frame)
 Walls.Fill(clone)
 Furniture.Fill(clone)
 local placedYard=box(yard)
 local anchorError=placedYard and (placedYard.Position-plotFrame.Position).Magnitude or math.huge
 clone:SetAttribute("GenerationPlacementVersion","RigidParts1")
 clone:SetAttribute("GenerationAnchorError",anchorError)
 clone:SetAttribute("GenerationTarget",plotFrame.Position)
 if anchorError>Config.FitTolerance then warnOnce(plot,string.format("Building Yard missed plot by %.3f studs",anchorError)) end
 local reference = Instance.new("ObjectValue")
 reference.Name,reference.Value,reference.Parent = "GenerationSource",plot,clone
 generated[plot] = clone
 clone.Parent = folder
 if existing then existing:Destroy() end
 reference = Instance.new("ObjectValue")
 reference.Name,reference.Value,reference.Parent = "GeneratedHouse",clone,plot
 plot:SetAttribute("Generated",true)
 hidePlot(plot)
 warnings[plot],busy[plot] = nil,nil
end
local function generate(incremental)
 deadline=os.clock()+.002
 if not incremental then
  plotIndex,roadIndex,markerIndex={},{},{}
  for _,object in ipairs(workspace:GetDescendants()) do track(object) end
 end
 if not incremental then table.clear(retryAt) end
 local points=positions()
 local plots,distances={},{}
 if #points>0 then
  for object in pairs(plotIndex) do
   budget()
   local house=generated[object]
   if not object:IsDescendantOf(workspace) or (house and house:IsDescendantOf(workspace)) or os.clock()<(retryAt[object] or 0) then continue end
   local gap=distance(object,points)
   if gap<=Config.GenerationRadius*Config.GenerationRadius then table.insert(plots,object);distances[object]=gap end
  end
 end
 -- Only pending nearby plots need road/template discovery. Closest plots go
 -- first; coordinate ordering resolves ties, independent plot RNG keeps the seed
 -- reproducible when players visit towns in a different order.
 if #plots>0 then
  local sources={Houses=templates("Houses"),Stores=templates("Stores"),Factories=templates("Factories")}
  local roadList=roads()
  sortPlots(plots)
  local rank={};for i,plot in ipairs(plots) do rank[plot]=i end
  table.sort(plots,function(a,b) return distances[a]==distances[b] and rank[a]<rank[b] or distances[a]<distances[b] end)
  for i,plot in ipairs(plots) do
   if i>Config.PlotsPerStep then break end
   if nearby(plot) then
    place(plot,sources,roadList)
    if generated[plot] and generated[plot]:IsDescendantOf(workspace) then retryAt[plot]=nil
    else retryAt[plot]=os.clock()+Config.RetryInterval end
   end
   budget()
  end
 end
 if #points>0 then
  local markers={}
  for object in pairs(markerIndex) do table.insert(markers,object) end
  local processed=0
  for _,object in ipairs(markers) do
   budget()
   if processed>=Config.PlotsPerStep then break end
   if object:IsDescendantOf(workspace) and not generatedContent(object) and os.clock()>=(retryAt[object] or 0) and nearby(object) then
    if Furniture.IsMarker(object) then Furniture.Fill(object) else Walls.Fill(object) end
    retryAt[object]=os.clock()+Config.RetryInterval
    processed+=1
   end
  end
 end
 -- Release markers that have been removed; do not leave their generated houses behind.
 for plot, house in pairs(generated) do
  if not plot:IsDescendantOf(workspace) then house:Destroy(); generated[plot],warnings[plot],busy[plot],categories[plot] = nil,nil,nil,nil end
 end
end
function Service.Generate(incremental)
 if generating then return end
 generating=true
 local ok,message=pcall(generate,incremental)
 generating=false
 if not ok then error(message,0) end
end
function Service.Start()
 if started then return end
 started = true
 folder = workspace:FindFirstChild("GeneratedCityHouses")
 if not folder then folder = Instance.new("Folder"); folder.Name = "GeneratedCityHouses"; folder.Parent = workspace end
 folder:SetAttribute("GenerationSeed",seed)
 folder:SetAttribute("GenerationMode","NearbyPlots")
 folder:SetAttribute("GenerationRadius",Config.GenerationRadius)
 workspace.DescendantAdded:Connect(track)
 workspace.DescendantRemoving:Connect(untrack)
 Service.Generate()
 task.spawn(function()
  while true do task.wait(Config.CheckInterval); Service.Generate(true) end
 end)
end
return Service
