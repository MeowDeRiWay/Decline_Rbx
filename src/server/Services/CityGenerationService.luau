local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.CityGenerationConfig)
local Rules = require(ReplicatedStorage.Shared.CityGenerationRules)
local Furniture=require(script.Parent.StoreFurnitureService)
local Walls=require(script.Parent.WallReplacementService)
local Service = {}
local started = false
local configuredSeed = Config.Seed
local seed = if typeof(configuredSeed)=="number" and configuredSeed==configuredSeed and math.abs(configuredSeed)<math.huge
 then math.floor(configuredSeed) else Random.new():NextInteger(0,2147483647)
local random = Random.new(seed)
local generated, busy, warnings = {}, {}, {}
local categories=setmetatable({},{__mode="k"})
local folder
local function box(object)
 if object:IsA("Model") and object:FindFirstChildWhichIsA("BasePart",true) then return object:GetBoundingBox() end
 if object:IsA("BasePart") then return object.CFrame,object.Size end
 return nil
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
   if house:IsA("Model") and (category=="Stores" or house:GetAttribute("ZHouse") == true) and yard and box(yard) then table.insert(result,house) end
  end
 end
 table.sort(result,function(a,b) return a.Name < b.Name end)
 return result
end
local function plotOrder(a,b)
 local af,bf = box(a),box(b)
 if not af or not bf then return a:GetFullName() < b:GetFullName() end
 for _, key in ipairs({"X","Z","Y"}) do if af.Position[key] ~= bf.Position[key] then return af.Position[key] < bf.Position[key] end end
 return a:GetFullName() < b:GetFullName()
end
local function roads()
 local result = {}
 for _, object in ipairs(workspace:GetDescendants()) do
  if object:GetAttribute("Road") == true and box(object) then table.insert(result,object) end
 end
 table.sort(result,plotOrder)
 return result
end
local function nearestRoad(plotFrame, list)
 local point, distance
 for _, road in ipairs(list) do
  local frame,size = box(road)
  local candidate = Rules.RoadPoint(frame,size,plotFrame.Position)
  local delta = candidate - plotFrame.Position
  local d = Vector3.new(delta.X,0,delta.Z).Magnitude
  if d > .001 and (not distance or d < distance) then point,distance = candidate,d end
 end
 return point
end
local function hidePlot(plot)
 for _, part in ipairs(plot:GetDescendants()) do
  if part:IsA("BasePart") then
   part.Transparency,part.CanCollide,part.CanTouch,part.CanQuery = 1,false,false,false
   part.Anchored,part.CastShadow = true,false
   part:SetAttribute("BlocksVision",false)
  end
 end
 plot:SetAttribute("BlocksVision",false)
end
local function place(plot, sources, roadList)
 if busy[plot] or not plot:IsDescendantOf(workspace) or plot:GetAttribute("ForZHouse") ~= true then return end
 local existing = plot:FindFirstChild("GeneratedHouse")
 if existing and existing:IsA("ObjectValue") and existing.Value and existing.Value:IsDescendantOf(workspace) then
  generated[plot] = existing.Value; hidePlot(plot); return
 end
 if generated[plot] and generated[plot]:IsDescendantOf(workspace) then return end
 if #sources.Houses==0 and #sources.Stores==0 then warnOnce(plot,"Add building Models with an inner Yard in ServerStorage/CityGeneration/Houses or Stores"); return end
 local plotFrame,plotSize = box(plot)
 if not plotFrame then warnOnce(plot,"YardPlace needs a physical marker Part"); return end
 if math.abs(plotFrame.UpVector.Y-1) > .001 then warnOnce(plot,"YardPlace must be horizontal; yaw rotation is supported"); return end
 local roadPoint = nearestRoad(plotFrame,roadList)
 if not roadPoint then warnOnce(plot,"No usable road with Road=true near YardPlace"); return end
 busy[plot] = true
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
 if not categories[plot] then categories[plot]=Rules.Category(random:NextNumber(),Config.StoreChance) end
 local category=categories[plot]
 local candidates=candidatesFor(category)
 if #candidates==0 then
  category=category=="Stores" and "Houses" or "Stores"
  candidates=candidatesFor(category)
 end
 if #candidates==0 then busy[plot]=nil; warnOnce(plot,"No building Yard fits this YardPlace; expected matching 20x20 markers and aligned yard axes"); return end
 local chosen = candidates[random:NextInteger(1,#candidates)]
 local clone = chosen.house:Clone()
 clone:SetAttribute("GeneratedCityHouse",true)
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
 clone:PivotTo(chosen.frame)
 Walls.Fill(clone)
 Furniture.Fill(clone)
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
function Service.Generate()
 local sources,roadList,plots = {Houses=templates("Houses"),Stores=templates("Stores")},roads(),{}
 for _, object in ipairs(workspace:GetDescendants()) do
  if object:IsA("Model") and object.Name == "YardPlace" and object:GetAttribute("ForZHouse") == true then table.insert(plots,object) end
 end
 table.sort(plots,plotOrder)
 for _, plot in ipairs(plots) do place(plot,sources,roadList) end
 Walls.Fill(workspace)
 Furniture.Fill(workspace)
 -- Release markers that have been removed; do not leave their generated houses behind.
 for plot, house in pairs(generated) do
  if not plot:IsDescendantOf(workspace) then house:Destroy(); generated[plot],warnings[plot],busy[plot],categories[plot] = nil,nil,nil,nil end
 end
end
function Service.Start()
 if started then return end
 started = true
 folder = workspace:FindFirstChild("GeneratedCityHouses")
 if not folder then folder = Instance.new("Folder"); folder.Name = "GeneratedCityHouses"; folder.Parent = workspace end
 folder:SetAttribute("GenerationSeed",seed)
 Service.Generate()
 task.spawn(function()
  while true do task.wait(Config.RetryInterval); Service.Generate() end
 end)
end
return Service
