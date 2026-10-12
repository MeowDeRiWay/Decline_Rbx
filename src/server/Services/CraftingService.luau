local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Inventory=require(script.Parent.InventoryService)
local Items=require(ReplicatedStorage.Shared.ItemConfig)
local Recipes=require(ReplicatedStorage.Shared.CraftConfig)
local Rules=require(ReplicatedStorage.Shared.CraftRules)
local Amounts=require(ReplicatedStorage.Shared.InventoryRules)
local Service={}
local states=setmetatable({},{__mode="k"})
local sessions={}
local changed=Instance.new("BindableEvent")
Service.Changed=changed.Event
local function reachable(player,stove)
 if typeof(stove)~="Instance" or not stove:IsA("Model") or (stove.Name~="Stove" and stove.Name~="CuttingBoard") or not stove:IsDescendantOf(workspace) or not stove:FindFirstChildWhichIsA("BasePart",true) then return false end
 local character=player.Character
 local root=character and character:FindFirstChild("HumanoidRootPart")
 local hp=character and character:FindFirstChildOfClass("Humanoid")
 if not root or not hp or hp.Health<=0 or character:GetAttribute("Knockout") then return false end
 local cf,size=stove:GetBoundingBox()
 local p,half=cf:PointToObjectSpace(root.Position),size/2
 local near=cf:PointToWorldSpace(Vector3.new(math.clamp(p.X,-half.X,half.X),math.clamp(p.Y,-half.Y,half.Y),math.clamp(p.Z,-half.Z,half.Z)))
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
function Service.Open(player,stove)
 if not reachable(player,stove) then return false end
 states[stove]=states[stove] or {Ready={}}
 sessions[player]=stove
 changed:Fire(player)
 return true
end
function Service.Close(player)
 if not sessions[player] then return end
 sessions[player]=nil
 changed:Fire(player)
end
function Service.Snapshot(player)
 local stove=sessions[player]
 local state=stove and states[stove]
 local job=state and state.Job
 return {CookingOpen=stove~=nil,CookingStation=stove and stove.Name,CookingReady=state and table.clone(state.Ready) or {},CookingEndsAt=job and job.EndsAt or 0,CookingRecipe=job and job.Recipe or nil,CookingCount=job and job.Count or 0}
end
function Service.Cook(player,id,requested)
 local stove=sessions[player]
 if not reachable(player,stove) then Service.Close(player); return false end
 local recipe=typeof(id)=="string" and Recipes[id]
 local state=states[stove]
 if not recipe or recipe.Station~=stove.Name or state.Job then return false end
 local own=Inventory.Snapshot(player)
 local speed=Rules.Speed(own.CraftTools or {},recipe)
 if not speed or speed<=0 then return false end
 local available=Rules.Available(own.Items,recipe)
 local count=Rules.Batch(available,requested,recipe.MaxBatch)
 if not count then return false end
 local duration=recipe.Duration/speed
 local job={Recipe=id,Count=count,EndsAt=workspace:GetServerTimeNow()+duration}
 state.Job=job
 if not Inventory.ConsumeIngredients(player,recipe,count) then state.Job=nil; return false end
 notify(stove)
 task.delay(duration,function()
  if not stove:IsDescendantOf(workspace) or state.Job~=job then return end
  state.Ready[recipe.Output]=(state.Ready[recipe.Output] or 0)+count*(recipe.OutputCount or 1)
  state.Job=nil
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
function Service.ValidateSessions()
 for player,stove in pairs(sessions) do if not reachable(player,stove) then Service.Close(player) end end
end
Players.PlayerRemoving:Connect(function(player) sessions[player]=nil end)
return Service
