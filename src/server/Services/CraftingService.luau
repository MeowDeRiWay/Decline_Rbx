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
local Service={}
local states=setmetatable({},{__mode="k"})
local sessions={}
local changed=Instance.new("BindableEvent")
Service.Changed=changed.Event
local function reachable(player,stove)
 if typeof(stove)~="Instance" or not stove:IsA("Model") or (stove.Name~="Stove" and stove.Name~="CuttingBoard" and stove.Name~="Workstation") or not stove:IsDescendantOf(workspace) or not stove:FindFirstChildWhichIsA("BasePart",true) then return false end
 local character=player.Character
 local root=character and character:FindFirstChild("HumanoidRootPart")
 local hp=character and character:FindFirstChildOfClass("Humanoid")
 if not root or not hp or hp.Health<=0 or character:GetAttribute("Knockout") then return false end
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
  if job.Root and job.Root.Parent and hp and hp.Health>0 and not character:GetAttribute("Knockout") then job.Root.Anchored=job.WasAnchored end
 end
end
local function cancel(stove,job)
 local state=states[stove]
 if not state or state.Job~=job then return end
 state.Job=nil
 unlock(job)
 for id,count in pairs(job.Ingredients) do Inventory.Add(job.Player,id,count) end
 notify(stove)
end
function Service.Open(player,stove)
 if not reachable(player,stove) or not Progression.CanStation(player,stove.Name) then return false end
 if sessions[player] and sessions[player]~=stove then Service.Close(player) end
 states[stove]=states[stove] or {Ready={}}
 sessions[player]=stove
 changed:Fire(player)
 return true
end
function Service.Close(player)
 local stove=sessions[player]
 if not stove then return end
 sessions[player]=nil
 local job=states[stove] and states[stove].Job
 if job and job.RequiresPresence and job.Player==player then cancel(stove,job) end
 changed:Fire(player)
end
function Service.Snapshot(player)
 local stove=sessions[player]
 local state=stove and states[stove]
 local job=state and state.Job
 return {CookingOpen=stove~=nil,CookingStation=stove and stove.Name,CookingReady=state and table.clone(state.Ready) or {},CookingEndsAt=job and job.EndsAt or 0,CookingRecipe=job and job.Recipe or nil,CookingRequiresPresence=job and job.RequiresPresence or false,CookingCount=job and job.Count or 0}
end
function Service.Cook(player,id,requested)
 local stove=sessions[player]
 if not reachable(player,stove) then Service.Close(player); return false end
 local recipe=typeof(id)=="string" and Recipes[id]
 local state=states[stove]
 if recipe and recipe.Requirements and not Progression.Meets(player,recipe.Requirements) then return false end
 if not recipe or recipe.Station~=stove.Name or state.Job or not Progression.CanStation(player,stove.Name) then return false end
 recipe=Rules.Discount(recipe,player:GetAttribute("CraftCostMultiplier"))
 local own=Inventory.Snapshot(player)
 local speed=Rules.Speed(own.CraftTools or {},recipe)
 if not speed or speed<=0 then return false end
 local available=Rules.Available(own.Items,recipe)
 local count=Rules.Batch(available,requested,recipe.MaxBatch)
 if not count then return false end
 local plan=Rules.Plan(own.Items,recipe,count)
 if not plan then return false end
 local effects=Progression.CraftEffects(player,stove.Name,count)
 local duration=recipe.Duration/speed*effects.DurationMultiplier
 local character=player.Character
 local root=character:FindFirstChild("HumanoidRootPart")
 local job={Recipe=id,Count=count,EndsAt=workspace:GetServerTimeNow()+duration,Player=player,Character=character,Root=root,WasAnchored=root.Anchored,RequiresPresence=recipe.RequiresPresence==true,Ingredients=plan.Ingredients}
 state.Job=job
 if not Inventory.ConsumeIngredients(player,{Ingredients=plan.Ingredients},1) then state.Job=nil; return false end
 if job.RequiresPresence then
  character:SetAttribute("CraftingLocked",true)
  root.Anchored=true
 end
 notify(stove)
 task.delay(duration,function()
  if not stove:IsDescendantOf(workspace) or state.Job~=job then return end
  if job.RequiresPresence and (sessions[player]~=stove or player.Character~=character or not reachable(player,stove)) then cancel(stove,job); return end
  unlock(job)
  local outputs=Progression.Loot(player,ProgressionRules.CraftOutputs(plan.Outputs,recipe,effects))
  for output,amount in pairs(outputs) do state.Ready[output]=(state.Ready[output] or 0)+amount end
  local completed={}
  for id,amount in pairs(outputs) do table.insert(completed,string.format("%d × %s",amount,Items.Items[id].Name or id)) end
  table.sort(completed)
  Journal.Send(player,"You crafted "..table.concat(completed,", ")..".")
  state.Job=nil
  Progression.CraftXP(player,recipe,count)
  notify(stove)
 end)
 return true
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
function Service.CollectRecipe(player,id,requested)
 local stove=sessions[player]
 if not reachable(player,stove) then Service.Close(player); return false end
 local recipe=typeof(id)=="string" and Recipes[id]
 if not recipe or recipe.Station~=stove.Name then return false end
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
end
Players.PlayerRemoving:Connect(function(player) Service.Close(player) end)
return Service
