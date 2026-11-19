-- Fade geometry between this viewer's camera and their own character.
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local Occlusion=require(script.Parent.CameraOcclusionState)
local player=Players.LocalPlayer
local faded={}
local elapsed=0
local interval=1/30
local sampleNames={"Head","UpperTorso","LowerTorso","LeftUpperArm","RightUpperArm","LeftLowerLeg","RightLowerLeg"}

local function restore()
 for part,record in pairs(faded) do
  part.LocalTransparencyModifier=record.Original
  Occlusion.Forget(part)
 end
 table.clear(faded)
 elapsed=interval
end

local function excludedFromFade(part)
 local ancestor=part
 while ancestor and ancestor~=workspace do
  if ancestor:GetAttribute("Road")==true or ancestor:GetAttribute("Vehicle")==true
   or ancestor:GetAttribute("Item_ID")~=nil or ancestor.Name=="Items" then return true end
  if ancestor:IsA("Model") and (ancestor.Name=="Mannikin" or ancestor:FindFirstChildOfClass("Humanoid")) then return true end
  ancestor=ancestor.Parent
 end
 return false
end

local function findObstructions(character,root,camera)
 local points={root.Position}
 for _,name in ipairs(sampleNames) do
  local part=character:FindFirstChild(name)
  if part and part:IsA("BasePart") then table.insert(points,part.Position) end
 end
 -- Cover the silhouette as well as its center, including legacy two-part rigs.
 local margin=camera.CFrame.RightVector*root.Size.X*.65
 table.insert(points,root.Position+margin)
 table.insert(points,root.Position-margin)
 for _,record in pairs(faded) do record.Blocking=false end
 for _,part in ipairs(camera:GetPartsObscuringTarget(points,{character})) do
  if part:IsA("BasePart") and part.Transparency<.95 and not excludedFromFade(part) then
   local record=faded[part]
   if not record then
    record={Original=part.LocalTransparencyModifier,Value=part.LocalTransparencyModifier}
    faded[part]=record
    Occlusion.Track(part,record.Original)
   end
   record.Blocking=true
  end
 end
end

player.CharacterRemoving:Connect(restore)
RunService:BindToRenderStep("DeclineCameraOcclusion",Enum.RenderPriority.Camera.Value+3,function(dt)
 local character=player.Character
 local root=character and character:FindFirstChild("HumanoidRootPart")
 local camera=workspace.CurrentCamera
 if not root or not camera then restore();return end
 elapsed+=dt
 if elapsed>=interval then
  elapsed%=interval
  findObstructions(character,root,camera)
 end
 for part,record in pairs(faded) do
  if not part:IsDescendantOf(workspace) then
   part.LocalTransparencyModifier=record.Original
   faded[part]=nil
   Occlusion.Forget(part)
  else
   local target=record.Blocking and math.max(.85,record.Original) or record.Original
   local rate=record.Blocking and 24 or 12
   record.Value+=(target-record.Value)*(1-math.exp(-rate*dt))
   if math.abs(record.Value-target)<.001 then record.Value=target end
   part.LocalTransparencyModifier=record.Value
   if not record.Blocking and record.Value==record.Original then faded[part]=nil;Occlusion.Forget(part) end
  end
 end
end)

script.Destroying:Connect(function()
 RunService:UnbindFromRenderStep("DeclineCameraOcclusion")
 restore()
end)
