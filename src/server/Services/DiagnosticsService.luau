local Storage=game:GetService("ServerStorage")
local Players=game:GetService("Players")
local Activity=require(script.Parent.ZombieActivity)
local Service={}
local hidden={}
local controller
local container=Instance.new("Folder")
container.Name="DiagnosticZombies";container.Parent=Storage
local function hide(model)
 if workspace:GetAttribute("DiagnosticsZombiesDisabled")~=true or hidden[model] or not model:IsA("Model")
  or (model.Name~="Zombie" and model:GetAttribute("CreatureType")~="Zombie")
  or not model:IsDescendantOf(workspace) then return end
 local hp=model:FindFirstChildOfClass("Humanoid")
 if not hp or hp.Health<=0 then return end
 hidden[model]=model.Parent
 model.Parent=container
end
function Service.SetZombiesDisabled(player,value)
 if player:GetAttribute("AdminAccess")~=true or typeof(value)~="boolean" then return false end
 controller=value and player or nil
 workspace:SetAttribute("DiagnosticsZombiesDisabled",value)
 if value then
  Activity.SuspendDiagnostics()
  for _,object in ipairs(workspace:GetDescendants()) do hide(object) end
 else
  for model,parent in pairs(hidden) do
   hidden[model]=nil
   if model.Parent==container then model.Parent=parent:IsDescendantOf(workspace) and parent or workspace end
  end
 end
 return true
end
function Service.Start()
 if Service.Started then return end
 Service.Started=true
 workspace:SetAttribute("DiagnosticsZombiesDisabled",false)
 workspace.DescendantAdded:Connect(function(object)
  if workspace:GetAttribute("DiagnosticsZombiesDisabled")==true then task.defer(function()
   local model=object:IsA("Model") and object or object.Parent
   if model then hide(model) end
  end) end
 end)
 Players.PlayerRemoving:Connect(function(player)
  if controller==player then
   workspace:SetAttribute("DiagnosticsZombiesDisabled",false);controller=nil
   for model,parent in pairs(hidden) do
    hidden[model]=nil
    if model.Parent==container then model.Parent=parent:IsDescendantOf(workspace) and parent or workspace end
   end
  end
 end)
 task.spawn(function()
  while true do
   local total,active=Activity.DiagnosticStats()
   workspace:SetAttribute("DiagnosticsZombieTotal",total)
   workspace:SetAttribute("DiagnosticsZombieActive",active)
   task.wait(1)
  end
 end)
end
return Service
