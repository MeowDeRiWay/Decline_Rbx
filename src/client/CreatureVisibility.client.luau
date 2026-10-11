local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local Config = require(ReplicatedStorage.Shared.GameConfig)
local Rules = require(ReplicatedStorage.Shared.VisibilityRules)
local tracked = {}
local function property(object)
 if object:IsA("BasePart") then return "LocalTransparencyModifier",1 end
 if object:IsA("Decal") or object:IsA("Texture") then return "Transparency",1 end
 if object:IsA("BillboardGui") or object:IsA("SurfaceGui") or object:IsA("Highlight") or object:IsA("ParticleEmitter") or object:IsA("Beam") or object:IsA("Trail") or object:IsA("Light") or object:IsA("Smoke") or object:IsA("Fire") or object:IsA("Sparkles") then return "Enabled",false end
 if object:IsA("Humanoid") then return "DisplayDistanceType",Enum.HumanoidDisplayDistanceType.None end
end
local function hideObject(record,object)
 if record.saved[object] then return end
 local key,value = property(object)
 if not key then return end
 record.saved[object] = {key,key == "LocalTransparencyModifier" and 0 or (key == "DisplayDistanceType" and Enum.HumanoidDisplayDistanceType.None or object[key])}
 object[key] = value
 if object:IsA("ParticleEmitter") or object:IsA("Trail") then object:Clear() end
end
local function restore(record)
 for object,saved in pairs(record.saved) do
  if object.Parent then object[saved[1]] = saved[2] end
 end
 table.clear(record.saved)
end
local function applyParts(model,record)
 for part in pairs(record.parts) do
  if part:IsDescendantOf(model) then
   -- Authored Transparency is untouched. Visibility owns only the local modifier.
   part.LocalTransparencyModifier = record.visible and 0 or 1
  else record.parts[part] = nil end
 end
end
local function setVisible(model,record,visible)
 if record.visible == visible then applyParts(model,record); return end
 record.visible = visible
 if visible then restore(record)
 else
  hideObject(record,model)
  for _,object in ipairs(model:GetDescendants()) do hideObject(record,object) end
 end
 applyParts(model,record)
end
local function creatureRoot(model)
 local result = model
 local ancestor = model.Parent
 while ancestor and ancestor ~= workspace do
  if ancestor:IsA("Model") and (ancestor.Name == "Mannikin" or ancestor:FindFirstChildOfClass("Humanoid")) then result = ancestor end
  ancestor = ancestor.Parent
 end
 return result
end
local function unregister(model,record)
 restore(record)
 record.added:Disconnect()
 tracked[model] = nil
end
local function register(model)
 if not model or not model:IsA("Model") then return end
 if model.Name ~= "Mannikin" and not model:FindFirstChildOfClass("Humanoid") then return end
 model = creatureRoot(model)
 if tracked[model] then return end
 -- A Mannikin wrapper and its humanoid rig are ONE creature. Two independent
 -- hiders would save each other's transparency=1 and never reveal the model.
 for child,old in pairs(tracked) do
  if child:IsDescendantOf(model) then unregister(child,old) end
 end
 local record = {visible=true,saved={},parts={}}
 for _,object in ipairs(model:GetDescendants()) do
  if object:IsA("BasePart") then record.parts[object] = true end
  if object:IsA("Humanoid") then object.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end
 end
 tracked[model] = record
 record.added = model.DescendantAdded:Connect(function(object)
  if object:IsA("BasePart") then record.parts[object] = true end
  if object:IsA("Humanoid") then object.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end
  if not record.visible then hideObject(record,object) end
 end)
 -- Hide until the first visibility check, so newly streamed creatures don't flash.
 if model ~= player.Character and not (player.Character and model:IsDescendantOf(player.Character)) then setVisible(model,record,false) end
end
for _,object in ipairs(workspace:GetDescendants()) do
 if object:IsA("Model") then register(object) end
end
workspace.DescendantAdded:Connect(function(object)
 if object:IsA("Humanoid") then register(object.Parent)
 elseif object:IsA("Model") then register(object) end
end)
local function visible(model,root,character)
 local target = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Body",true) or model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart",true)
 if not target or not target:IsA("BasePart") then return false end
 local offset = target.Position-root.Position
 local forward = root.CFrame.LookVector
 if not Rules.InSector(forward.X,forward.Z,offset.X,offset.Z,Config.CreatureViewAngle) then return false end
 local head = character:FindFirstChild("Head")
 local origin = (head and head:IsA("BasePart") and head.Position or root.Position) + Vector3.new(0,.05,0)
 local params = RaycastParams.new()
 params.FilterType = Enum.RaycastFilterType.Exclude
 params.FilterDescendantsInstances = {character}
 params.IgnoreWater = true
 -- Either the body or head must be visible from the character, not the camera.
 local function clear(part)
  local excluded = {character}
  for _=1,16 do
   params.FilterDescendantsInstances = excluded
   local hit = workspace:Raycast(origin,part.Position-origin,params)
   if not hit or hit.Instance:IsDescendantOf(model) then return true end
   local obstacle = hit.Instance
   local ancestor = obstacle
   local blocksVision = nil
   while ancestor and ancestor ~= workspace do
    local setting = ancestor:GetAttribute("BlocksVision")
    if typeof(setting) == "boolean" then blocksVision = setting end
    ancestor = ancestor.Parent
   end
   if blocksVision == true then return false end
   -- Invisible triggers and non-solid decoration do not block creature sight.
   if blocksVision == false or (obstacle:IsA("BasePart") and (obstacle.Transparency >= .95 or not obstacle.CanCollide)) then
    table.insert(excluded,obstacle)
   else return false end
  end
  return false
 end
 if clear(target) then return true end
 local targetHead = model:FindFirstChild("Head",true)
 return targetHead ~= nil and targetHead:IsA("BasePart") and clear(targetHead)
end
local elapsed = Config.VisibilityInterval
RunService:BindToRenderStep("DeclineCreatureVisibility",Enum.RenderPriority.Last.Value+1,function(dt)
 -- Apply every frame after the camera's transparency controller, even if the
 -- sector/line-of-sight decision has not changed.
 for model,record in pairs(tracked) do
  if model ~= player.Character then applyParts(model,record) end
 end
 elapsed += dt
 if elapsed < Config.VisibilityInterval then return end
 elapsed = 0
 local character = player.Character
 local root = character and character:FindFirstChild("HumanoidRootPart")
 for model,record in pairs(tracked) do
  if not model:IsDescendantOf(workspace) then
   unregister(model,record)
  else
   local canSee = model == character or (root ~= nil and visible(model,root,character))
   setVisible(model,record,canSee)
   model:SetAttribute("ClientVisible",canSee == true)
   local total,renderable = 0,0
   for part in pairs(record.parts) do
    total += 1
    if part.Transparency < 1 and part.LocalTransparencyModifier < 1 then renderable += 1 end
   end
   model:SetAttribute("ClientPartCount",total)
   model:SetAttribute("ClientRenderablePartCount",renderable)
  end
 end
end)
