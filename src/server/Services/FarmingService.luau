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
  beds[model]={};model:SetAttribute("Crop","");model:SetAttribute("Watered",false);model:SetAttribute("CropReady",false)
 end
end
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
local function visualize(bed,state,progress)
 local folder=Storage:FindFirstChild("Farming")
 folder=folder and folder:FindFirstChild(Config.StageFolder)
 local templates={}
 for _,model in ipairs(folder and folder:GetChildren() or {}) do
  local number=tonumber(model.Name:match("^"..Config.StagePrefix.."(%d+)$"))
  if number and model:IsA("Model") then table.insert(templates,{Model=model,Number=number}) end
 end
 table.sort(templates,function(a,b) return a.Number<b.Number end)
 local stage=Rules.Stage(progress,#templates)
 if not stage or state.Stage==stage then return end
 if state.Visual then state.Visual:Destroy() end
 local visual=templates[stage].Model:Clone()
 local anchor=bed:FindFirstChild("CropAnchor",true)
 visual:PivotTo(anchor and anchor:GetPivot() or bed:GetPivot())
 for _,part in ipairs(visual:GetDescendants()) do
  if part:IsA("BasePart") then part.Anchored=true;part.CanCollide=false;part.CanTouch=false;part.CanQuery=false end
 end
 visual.Name="GrowingPotato";visual:SetAttribute("BlocksVision",false);visual.Parent=bed
 state.Visual=visual;state.Stage=stage
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
 register(model);local state=beds[model]
 local progress=Rules.Progress(state.Started,workspace:GetServerTimeNow(),Config.GrowthSeconds)
 if state.Crop and progress>=1 then
  if inventory.Equipment.Hands then Journal.Send(player,"Empty your hands to harvest.");return false end
  local amount=Rules.Yield(random:NextInteger(Config.MinYield,Config.MaxYield),yieldMultiplier(model),random:NextNumber())
  if not Inventory.Add(player,Config.Crop,amount) then return false end
  if state.Visual then state.Visual:Destroy() end
  beds[model]={};model:SetAttribute("Crop","");model:SetAttribute("Watered",false);model:SetAttribute("CropReady",false);model:SetAttribute("CropProgress",0)
  Progression.FarmXP(player,amount);Journal.Send(player,"You harvested "..amount.." potatoes.");return true
 elseif not state.Crop then
  if inventory.Equipment.Hands then Journal.Send(player,"Empty your hands to plant.");return false end
  if not Inventory.Remove(player,Config.Crop,Config.SeedCount) then Journal.Send(player,"You need a potato to plant.");return false end
  yieldMultiplier(model)
  state.Crop=Config.Crop;model:SetAttribute("Crop",Config.Crop);model:SetAttribute("PlanterID",player.UserId)
  visualize(model,state,0);Journal.Send(player,"Potato planted. Water the bed with a bucket.");return true
 elseif not state.Started then
  if not Inventory.ReplaceOne(player,"DirtyWaterBucket","EmptyBucket") then Journal.Send(player,"Bring a bucket of water to water this bed.");return false end
  state.Started=workspace:GetServerTimeNow();model:SetAttribute("Watered",true);model:SetAttribute("CropReadyAt",state.Started+Config.GrowthSeconds)
  Journal.Send(player,"You watered the garden bed.");return true
 end
 Journal.Send(player,"The potatoes are still growing.");return false
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
    elseif state.Crop then
     yieldMultiplier(bed)
     local progress=Rules.Progress(state.Started,workspace:GetServerTimeNow(),Config.GrowthSeconds)
     bed:SetAttribute("CropProgress",progress);bed:SetAttribute("CropReady",progress>=1);visualize(bed,state,progress)
    end
   end
  end
 end)
end
return Service
