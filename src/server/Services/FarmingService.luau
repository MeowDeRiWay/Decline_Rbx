local Storage=game:GetService("ServerStorage")
local Replicated=game:GetService("ReplicatedStorage")
local Players=game:GetService("Players")
local Config=require(Replicated.Shared.FarmingConfig)
local Rules=require(Replicated.Shared.FarmingRules)
local Interaction=require(Replicated.Shared.Interaction)
local ItemConfig=require(Replicated.Shared.ItemConfig)
local Inventory=require(script.Parent.InventoryService)
local Progression=require(script.Parent.ProgressionService)
local Journal=require(script.Parent.JournalService)
local Service={}
local beds=setmetatable({},{__mode="k"})
local random=Random.new()
local function register(model)
 if model:IsA("Model") and model.Name==Config.Bed and not beds[model] then
  local _,size=model:GetBoundingBox()
  beds[model]={Plants={},Size=size,LastUpdate=workspace:GetServerTimeNow()}
  model:SetAttribute("Watering",0);model:SetAttribute("PlantCount",0);model:SetAttribute("Crop","")
  model:SetAttribute("CropReady",false);model:SetAttribute("RottenPlants",0)
 end
end
local function capacity(bed) return math.max(1,tonumber(bed:GetAttribute("MaxWatering")) or 100) end
local function plantLimit(bed) return math.clamp(math.floor(tonumber(bed:GetAttribute("MaxPlants")) or 5),1,100) end
local function yieldMultiplier(bed)
 local ancestor=bed.Parent
 while ancestor and ancestor~=workspace do
  if ancestor.Name==Config.Greenhouse then
   local plot=ancestor.Parent
   local ownerID=ancestor:GetAttribute("OwnerID") or 0
   if ownerID<=0 then ownerID=(plot and plot:GetAttribute("OwnerID")) or 0 end
   if ancestor:GetAttribute("YieldOwnerID")~=ownerID then
    ancestor:SetAttribute("YieldOwnerID",ownerID);ancestor:SetAttribute("GreenhouseYieldMultiplier",1)
   end
   local owner=Players:GetPlayerByUserId(ownerID)
   if owner then
    local multiplier=owner:GetAttribute("GreenhouseYieldMultiplier") or 1
    if ancestor:GetAttribute("GreenhouseYieldMultiplier")~=multiplier then ancestor:SetAttribute("GreenhouseYieldMultiplier",multiplier) end
    return multiplier
   end
   return ancestor:GetAttribute("GreenhouseYieldMultiplier") or 1
  end
  ancestor=ancestor.Parent
 end
 return 1
end
local function visualize(bed,plant,index,count)
 local stage=Rules.Stage(plant.Progress,plant.Rotten)
 if plant.Stage==stage then return end
 if plant.Visual then plant.Visual:Destroy();plant.Visual=nil end
 plant.Stage=stage
 local folder=Storage:FindFirstChild("Farming")
 folder=folder and folder:FindFirstChild(Config.StageFolder)
 local template=folder and folder:FindFirstChild(Config.StagePrefix..stage)
 if not template or not template:IsA("Model") then return end
 local anchor=bed:FindFirstChild("CropAnchor",true)
 local frame=anchor and anchor:GetPivot() or bed:GetPivot()
 local size=beds[bed].Size
 local length=math.max(size.X,size.Z)
 local offset=((index-.5)/count-.5)*length
 local position=size.X>size.Z and CFrame.new(offset,0,0) or CFrame.new(0,0,offset)
 local visual=template:Clone();visual:PivotTo(frame*position)
 for _,part in ipairs(visual:GetDescendants()) do
  if part:IsA("BasePart") then part.Anchored=true;part.CanCollide=false;part.CanTouch=false;part.CanQuery=false end
 end
 visual.Name="GrowingPotato";visual:SetAttribute("BlocksVision",false);visual.Parent=bed
 plant.Visual=visual
end
local function publish(bed,state)
 local ready,rotten,progress=0,0,0
 for index,plant in ipairs(state.Plants) do
  if plant.Rotten then rotten+=1 elseif plant.Progress>=1 then ready+=1 end
  progress+=plant.Progress;visualize(bed,plant,index,#state.Plants)
 end
 bed:SetAttribute("PlantCount",#state.Plants);bed:SetAttribute("ReadyPlants",ready);bed:SetAttribute("RottenPlants",rotten)
 bed:SetAttribute("CropReady",ready>0);bed:SetAttribute("CropProgress",#state.Plants>0 and progress/#state.Plants or 0)
 bed:SetAttribute("Crop",#state.Plants>0 and Config.Crop or "")
end
function Service.Step(bed,now)
 local state=beds[bed];if not state then return end
 local elapsed=math.max(0,now-state.LastUpdate);state.LastUpdate=now
 local water=math.clamp(tonumber(bed:GetAttribute("Watering")) or 0,0,capacity(bed))
 -- One-second slices keep catch-up and ordinary heartbeat simulation identical.
 local remaining=elapsed;local cursor=now-elapsed
 while remaining>0 do
  local dt=math.min(1,remaining);remaining-=dt;cursor+=dt
  local factor,chance=Rules.Water(water/capacity(bed)*100)
  local growing=0
  for _,plant in ipairs(state.Plants) do if not plant.Rotten and plant.Progress<1 then growing+=1 end end
  local delta=Rules.Growth(dt,Config.GrowthSeconds,factor,water,growing,Config.WaterPerPlant)
  water=math.max(0,water-delta*growing*Config.WaterPerPlant)
  for _,plant in ipairs(state.Plants) do
   if not plant.Rotten then
    if plant.Progress>=1 then
     if cursor-(plant.ReadyAt or cursor)>=Config.HarvestSeconds then plant.Rotten=true end
    else
     plant.Progress=math.min(1,plant.Progress+delta)
     if plant.Progress>=1-1e-9 then plant.Progress=1 end
     if plant.Progress>=1 then plant.ReadyAt=cursor
     elseif cursor-plant.LastRotCheck>=60 then
      plant.LastRotCheck=cursor
      if random:NextNumber()<chance then plant.Rotten=true end
     end
    end
   end
  end
 end
 bed:SetAttribute("Watering",water);publish(bed,state)
end
local function reachable(player,model)
 if typeof(model)~="Instance" or not model:IsA("Model") or not model:IsDescendantOf(workspace) or (model.Name~=Config.Bed and model.Name~=Config.Well) then return false end
 local character=player.Character;local root=character and character:FindFirstChild("HumanoidRootPart")
 local hp=character and character:FindFirstChildOfClass("Humanoid")
 if not root or not hp or hp.Health<=0 or player:GetAttribute("AttributesConfirmed")~=true or character:GetAttribute("Knockout") or character:GetAttribute("CraftingLocked") then return false end
 local point=Interaction.NearestPoint(model,root.Position)
 if (point-root.Position).Magnitude>ItemConfig.PickupDistance then return false end
 local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances={character};params.RespectCanCollide=true
 local hit=workspace:Raycast(root.Position,point-root.Position,params)
 return not hit or hit.Instance:IsDescendantOf(model)
end
function Service.Use(player,model)
 if not reachable(player,model) then return false end
 local inventory=Inventory.Snapshot(player)
 if model.Name==Config.Well then
  local bucket=inventory.Equipment.Hands=="EmptyBucket" or (inventory.Items.EmptyBucket or 0)>0
  if Inventory.ReplaceOne(player,bucket and "EmptyBucket" or "EmptyBottle",bucket and "DirtyWaterBucket" or "DirtyWater") then
   Journal.Send(player,"You filled a container with dirty water.");return true
  end
  Journal.Send(player,"Bring an empty bottle or bucket.");return false
 end
 register(model);Service.Step(model,workspace:GetServerTimeNow());local state=beds[model]
 -- A held bucket always waters; a pocket bucket is used while plants are growing.
 local hasBucket=inventory.Equipment.Hands=="DirtyWaterBucket" or (inventory.Items.DirtyWaterBucket or 0)>0
 local ready=false
 for _,plant in ipairs(state.Plants) do if plant.Rotten or plant.Progress>=1 then ready=true end end
 if hasBucket and (inventory.Equipment.Hands=="DirtyWaterBucket" or (#state.Plants>0 and not ready)) then
  local water=model:GetAttribute("Watering") or 0
  if water>=capacity(model) then Journal.Send(player,"The garden bed is already full of water.");return false end
  if not Inventory.ReplaceOne(player,"DirtyWaterBucket","EmptyBucket") then return false end
  model:SetAttribute("Watering",math.min(capacity(model),water+Config.BucketWater))
  Journal.Send(player,"You watered the garden bed.");return true
 end
 if inventory.Equipment.Hands then Journal.Send(player,"Empty your hands to plant, harvest or clear rotten plants.");return false end
 if ready then
  local amount=0;local kept={}
  for _,plant in ipairs(state.Plants) do
   if not plant.Rotten and plant.Progress>=1 then
    amount+=Rules.Yield(random:NextInteger(Config.MinYield,Config.MaxYield),yieldMultiplier(model),random:NextNumber())
   end
  end
  if amount>0 and not Inventory.Add(player,Config.Crop,amount) then return false end
  for _,plant in ipairs(state.Plants) do
   if plant.Rotten or plant.Progress>=1 then if plant.Visual then plant.Visual:Destroy() end
   else table.insert(kept,plant);plant.Stage=nil end
  end
  state.Plants=kept;publish(model,state)
  if amount>0 then Progression.FarmXP(player,amount) end
  Journal.Send(player,"You harvested "..amount.." potatoes and cleared finished plants.");return true
 end
 local count=plantLimit(model)-#state.Plants
 if count>0 then
  local now=workspace:GetServerTimeNow()
  for _=1,count do table.insert(state.Plants,{Progress=0,LastRotCheck=now}) end
  for _,plant in ipairs(state.Plants) do plant.Stage=nil end
  model:SetAttribute("PlanterID",player.UserId);publish(model,state)
  Journal.Send(player,"You planted "..count.." potato plants. Each needs 20 units of water to grow.");return true
 end
 Journal.Send(player,"The potatoes are still growing. Water: "..math.floor(model:GetAttribute("Watering") or 0)..".");return false
end
function Service.Start()
 if Service.Started then return end;Service.Started=true
 for _,model in ipairs(workspace:GetDescendants()) do register(model) end
 workspace.DescendantAdded:Connect(register)
 task.spawn(function()
  while true do
   task.wait(1)
   for bed,state in pairs(beds) do
    if not bed:IsDescendantOf(workspace) then beds[bed]=nil
    else
     yieldMultiplier(bed);Service.Step(bed,workspace:GetServerTimeNow())
    end
   end
  end
 end)
end
return Service
