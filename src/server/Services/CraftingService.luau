local WorldActivity=require(script.Parent.WorldActivityService)
local Journal=require(script.Parent.JournalService)
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Inventory=require(script.Parent.InventoryService)
local Items=require(ReplicatedStorage.Shared.ItemConfig)
local Recipes=require(ReplicatedStorage.Shared.CraftConfig)
local Rules=require(ReplicatedStorage.Shared.CraftRules)
local ProgressionRules=require(ReplicatedStorage.Shared.ProgressionRules)
local Amounts=require(ReplicatedStorage.Shared.InventoryRules)
local Interaction=require(ReplicatedStorage.Shared.Interaction)
local Progression=require(script.Parent.ProgressionService)
local Stations=require(ReplicatedStorage.Shared.CraftStations)
local Chests=require(script.Parent.ChestService)
local Supply=require(ReplicatedStorage.Shared.CraftSupply)
local Service={}
local states=setmetatable({},{__mode="k"})
local sessions={}
local stockSignatures={}
local changed=Instance.new("BindableEvent")
Service.Changed=changed.Event
local function reachable(player,stove)
 if typeof(stove)~="Instance" or not stove:IsA("Model") or not Stations.Kind(stove) or not stove:IsDescendantOf(workspace) or not stove:FindFirstChildWhichIsA("BasePart",true) then return false end
 local character=player.Character
 local root=character and character:FindFirstChild("HumanoidRootPart")
 local hp=character and character:FindFirstChildOfClass("Humanoid")
 if not root or not hp or hp.Health<=0 or (character:GetAttribute("Knockout") or character:GetAttribute("HandsBusy")) then return false end
 local near=Interaction.NearestPoint(stove,root.Position)
 local delta=near-root.Position
 if delta.Magnitude>Items.PickupDistance then return false end
 local params=RaycastParams.new()
 params.FilterType=Enum.RaycastFilterType.Exclude
 params.FilterDescendantsInstances={character}
 local hit=workspace:Raycast(root.Position,delta,params)
 return not hit or hit.Instance:IsDescendantOf(stove)
end
local function notify(stove)
 for player,current in pairs(sessions) do if current==stove then changed:Fire(player) end end
end
local function unlock(job)
 if not job.RequiresPresence then return end
 local character=job.Character
 if character and character.Parent then
  character:SetAttribute("CraftingLocked",false)
  local hp=character:FindFirstChildOfClass("Humanoid")
  if job.Root and job.Root.Parent and hp and hp.Health>0 and not (character:GetAttribute("Knockout") or character:GetAttribute("HandsBusy")) then job.Root.Anchored=job.WasAnchored end
 end
end
local function supplies(player,stove)
 local own=Inventory.Export(player)
 if not own then return {},{},{},nil end
 local sources={{State=own}}
 for _,source in ipairs(Chests.CraftSources(player,stove)) do table.insert(sources,source) end
 local items,tools=Supply.Pool(sources,Items.Items)
 return items,tools,sources,own
end
local function refresh(player,sources)
 Inventory.Refresh(player)
 Chests.CraftChanged(sources)
end
local function cancel(stove,job)
 local state=states[stove]
 if not state or state.Job~=job then return end
 state.Job=nil
 Supply.Refund(job.Cycles,job.Index,Items.Items,function(source) return Chests.CraftRefundTarget(source,job.Inventory) end)
 unlock(job)
 refresh(job.Player,job.Sources)
 notify(stove)
end
function Service.Open(player,stove)
 if not reachable(player,stove) or not Progression.CanStation(player,Stations.Kind(stove)) then return false end
 if sessions[player] and sessions[player]~=stove then Service.Close(player) end
 states[stove]=states[stove] or {Ready={}}
 sessions[player]=stove
 changed:Fire(player)
 return true
end
function Service.Close(player)
 local stove=sessions[player]
 if not stove then return end
 sessions[player]=nil;stockSignatures[player]=nil
 local job=states[stove] and states[stove].Job
 if job and job.RequiresPresence and job.Player==player then cancel(stove,job) end
 changed:Fire(player)
end
local function stockSignature(items,tools,sources)
 local parts={tostring(#sources)}
 for id,count in pairs(items) do table.insert(parts,id..":"..count) end
 for id,speed in pairs(tools) do table.insert(parts,"Tool:"..id..":"..speed) end
 table.sort(parts);return table.concat(parts,"|")
end
function Service.Snapshot(player)
 local stove=sessions[player]
 local state=stove and states[stove]
 local job=state and state.Job
 local items,tools,sources={},{},{}
 if stove then items,tools,sources=supplies(player,stove);stockSignatures[player]=stockSignature(items,tools,sources) end
 return {CookingOpen=stove~=nil,CookingStation=stove and Stations.Kind(stove),CookingWorkshopLevel=stove and Stations.WorkshopLevel(stove) or 0,
  CookingReady=state and table.clone(state.Ready) or {},CookingEndsAt=job and job.EndsAt or 0,CookingRecipe=job and job.Recipe or nil,
  CookingRequiresPresence=job and job.RequiresPresence or false,CookingCount=job and job.Cycles[job.Index].Count or 0,
  CookingQueueTotal=job and #job.Cycles or 0,CookingCompleted=job and job.Index-1 or 0,CookingOwner=job and job.Player.UserId or nil,
  CookingItems=items,CookingTools=tools,CookingNearbyChests=math.max(0,#sources-1),CookingMaxQueue=Rules.MaxQueue}
end
local function valid(player,stove,job)
 local character=player.Character
 local hp=character and character:FindFirstChildOfClass("Humanoid")
 if character~=job.Character or not hp or hp.Health<=0 or character:GetAttribute("Knockout") or character:GetAttribute("IsDead") or Inventory.Export(player)~=job.Inventory then return false end
 if not stove:IsDescendantOf(workspace) and not WorldActivity.IsDormant(stove) then return false end
 if not Stations.Allowed(stove,job.Definition) or not Progression.CanStation(player,Stations.Kind(stove)) then return false end
 if job.Definition.Requirements and not Progression.Meets(player,job.Definition.Requirements) then return false end
 if job.RequiresPresence and (sessions[player]~=stove or not reachable(player,stove)) then return false end
 if job.Definition.Tool then
  local _,tools=supplies(player,stove)
  if not Rules.Speed(tools,job.Definition) then return false end
 end
 return true
end
function Service.Cook(player,id,requested)
 local stove=sessions[player]
 if not reachable(player,stove) then Service.Close(player); return false end
 local recipe=typeof(id)=="string" and Recipes[id]
 local state=states[stove]
 if recipe and (not Stations.Allowed(stove,recipe) or (recipe.Requirements and not Progression.Meets(player,recipe.Requirements))) then return false end
 if not recipe or not Stations.Matches(recipe,Stations.Kind(stove)) or state.Job or not Progression.CanStation(player,Stations.Kind(stove)) then return false end
 if recipe.ManualBatch and next(state.Ready)~=nil then return false end
 recipe=Rules.Discount(recipe,player:GetAttribute("CraftCostMultiplier"))
 local items,tools,sources,own=supplies(player,stove)
 if not own then return false end
 local speed=Rules.Speed(tools,recipe)
 if not speed or speed<=0 then return false end
 local cycles=Rules.QueuePlan(items,recipe,requested)
 if not cycles then return false end
 local duration=0
 for _,cycle in ipairs(cycles) do
  cycle.Effects=Progression.CraftEffects(player,recipe)
  cycle.Duration=recipe.Duration/speed*cycle.Effects.DurationMultiplier
  duration+=cycle.Duration
 end
 local character=player.Character
 local root=character:FindFirstChild("HumanoidRootPart")
 local job={Recipe=id,Definition=recipe,Cycles=cycles,Index=1,Sources=sources,Inventory=own,
  EndsAt=workspace:GetServerTimeNow()+duration,Player=player,Character=character,Root=root,WasAnchored=root.Anchored,RequiresPresence=not recipe.ManualBatch}
 state.Job=job
 if not Supply.Reserve(cycles,sources,Items.Items) then state.Job=nil;return false end
 if job.RequiresPresence then character:SetAttribute("CraftingLocked",true);root.Anchored=true end
 refresh(player,sources)
 local function process(index)
  if state.Job~=job then return end
  notify(stove)
  local cycle=cycles[index]
  task.delay(cycle.Duration,function()
   if state.Job~=job or job.Index~=index then return end
   if not valid(player,stove,job) then cancel(stove,job);return end
   local outputs=Progression.Loot(player,ProgressionRules.CraftOutputs(cycle.Outputs,recipe,cycle.Effects))
   -- Detach spent receipts before publishing inventory changes or granting XP.
   cycle.Receipts=nil
   local completed={}
   for output,amount in pairs(outputs) do
    if recipe.ManualBatch then state.Ready[output]=(state.Ready[output] or 0)+amount
    elseif not Inventory.Add(player,output,amount) then
     assert(Amounts.Add(job.Inventory,Items.Items,output,amount))
    end
    table.insert(completed,string.format("%d × %s",amount,Items.Items[output].Name or output))
   end
   table.sort(completed);Journal.Send(player,"You crafted "..table.concat(completed,", ")..".")
   Progression.CraftXP(player,recipe,cycle.Count)
   if index==#cycles then
    state.Job=nil;unlock(job);refresh(player,sources);notify(stove)
   else job.Index=index+1;process(job.Index) end
  end)
 end
 process(1)
 return true
end
function Service.Cancel(player)
 local stove=sessions[player]
 local job=stove and states[stove] and states[stove].Job
 if not job or job.Player~=player then return false end
 cancel(stove,job);return true
end
function Service.CancelPlayer(player)
 for stove,state in pairs(states) do
  if state.Job and state.Job.Player==player then cancel(stove,state.Job) end
 end
 Service.Close(player)
end
function Service.Collect(player,id,requested)
 local stove=sessions[player]
 if not reachable(player,stove) then Service.Close(player); return false end
 if typeof(id)~="string" or not Items.Items[id] then return false end
 local state=states[stove]
 local count=Amounts.DropAmount(state.Ready[id],requested)
 if not count then return false end
 state.Ready[id]-=count
 if state.Ready[id]==0 then state.Ready[id]=nil end
 if not Inventory.Add(player,id,count) then state.Ready[id]=(state.Ready[id] or 0)+count; return false end
 notify(stove)
 return true
end
function Service.CollectAll(player)
 local stove=sessions[player]
 if not reachable(player,stove) then Service.Close(player);return false end
 local ready=states[stove].Ready
 if next(ready)==nil then return false end
 for id in pairs(table.clone(ready)) do if not Service.Collect(player,id,"All") then return false end end
 return true
end
function Service.CollectRecipe(player,id,requested)
 local stove=sessions[player]
 if not reachable(player,stove) then Service.Close(player); return false end
 local recipe=typeof(id)=="string" and Recipes[id]
 if not recipe or not Stations.Matches(recipe,Stations.Kind(stove)) then return false end
 local outputs=Rules.Outputs(recipe)
 local total=0
 for _,output in ipairs(outputs) do total+=states[stove].Ready[output] or 0 end
 local remaining=Amounts.DropAmount(total,requested)
 if not remaining then return false end
 for _,output in ipairs(outputs) do
  local amount=math.min(remaining,states[stove].Ready[output] or 0)
  if amount>0 and not Service.Collect(player,output,amount) then return false end
  remaining-=amount
 end
 return true
end
function Service.ValidateSessions()
 for player,stove in pairs(sessions) do if not reachable(player,stove) then Service.Close(player) end end
 for stove,state in pairs(states) do if state.Job and not valid(state.Job.Player,stove,state.Job) then cancel(stove,state.Job) end end
 for player,stove in pairs(sessions) do
  local items,tools,sources=supplies(player,stove)
  local signature=stockSignature(items,tools,sources)
  if stockSignatures[player]~=signature then stockSignatures[player]=signature;changed:Fire(player) end
 end
end
Players.PlayerRemoving:Connect(function(player) Service.CancelPlayer(player) end)
return Service
