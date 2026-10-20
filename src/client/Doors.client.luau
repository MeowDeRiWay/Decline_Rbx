local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local Input=game:GetService("UserInputService")
local player=Players.LocalPlayer
local action=ReplicatedStorage:WaitForChild("DoorRemotes"):WaitForChild("Action")
local Access=require(ReplicatedStorage.Shared.DoorRules)
local Rules=require(ReplicatedStorage.Shared.TownRules)
local Interaction=require(ReplicatedStorage.Shared.Interaction)
local Config=require(ReplicatedStorage.Shared.TownConfig)
local doors,flags={},{}
local hovered
local highlight=Instance.new("Highlight")
highlight.Name="DoorHover";highlight.DepthMode=Enum.HighlightDepthMode.Occluded
highlight.FillTransparency=.7;highlight.Enabled=false;highlight.Parent=workspace
local function register(object)
 if object.Name=="Flag" then flags[object]=true end
 if object:GetAttribute("Door")==true and (object:IsA("Model") or object:IsA("BasePart")) then doors[object]=true end
end
for _,object in ipairs(workspace:GetDescendants()) do register(object) end
workspace.DescendantAdded:Connect(function(object) task.defer(function() register(object) end) end)
local function attr(object,key)
 while object and object~=workspace do
  local value=object:GetAttribute(key)
  if value~=nil then return value end
  object=object.Parent
 end
end
-- Open doors have CanQuery disabled. Intersect their saved physical bounds for closing.
local function rayDistance(object,ray)
 local frame,size
 if object:IsA("Model") then frame,size=object:GetBoundingBox() else frame,size=object.CFrame,object.Size end
 local origin=frame:PointToObjectSpace(ray.Origin)
 local direction=frame:VectorToObjectSpace(ray.Direction)
 local low,high=0,1000
 for _,axis in ipairs({"X","Y","Z"}) do
  local half=size[axis]/2
  if math.abs(direction[axis])<1e-6 then if math.abs(origin[axis])>half then return end
  else
   local a,b=(-half-origin[axis])/direction[axis],(half-origin[axis])/direction[axis]
   if a>b then a,b=b,a end
   low,high=math.max(low,a),math.min(high,b)
   if low>high then return end
  end
 end
 return low
end
RunService.RenderStepped:Connect(function()
 hovered=nil;highlight.Enabled=false
 local character=player.Character
 local root=character and character:FindFirstChild("HumanoidRootPart")
 local camera=workspace.CurrentCamera
 if not root or not camera or character:GetAttribute("Knockout") or character:GetAttribute("IsDead") then return end
 local mouse=Input:GetMouseLocation()
 local ray=camera:ViewportPointToRay(mouse.X,mouse.Y)
 local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances={character}
 local hit=workspace:Raycast(ray.Origin,ray.Direction*1000,params)
 local limit=hit and (hit.Position-ray.Origin).Magnitude or 1000
 local target=hit and hit.Instance
 while target and target~=workspace and not doors[target] do target=target.Parent end
 if target==workspace then target=nil end
 for door in pairs(doors) do
  if not door:IsDescendantOf(workspace) then doors[door]=nil
  elseif door:GetAttribute("DoorOpen")==true and Interaction.Distance(door,root.Position)<=Config.InteractionDistance then
   local distance=rayDistance(door,ray)
   if distance and distance<=limit then target=door;limit=distance end
  end
 end
 if not target then return end
 local id=attr(target,"TownID")
 local leader=0
 for flag in pairs(flags) do
  if not flag:IsDescendantOf(workspace) then flags[flag]=nil
  elseif flag:GetAttribute("TownID")==id then leader=flag:GetAttribute("LeaderID");break end
 end
 local allowed=Access.Allowed(player.UserId,player:GetAttribute("TownID"),id,attr(target,"OwnerID"),
  Rules.ParseOwners(attr(target,"Co-OwnerID")),leader,attr(target,"TownGate")==true)
 local color=allowed and Color3.fromRGB(65,220,110) or Color3.fromRGB(235,65,65)
 highlight.Adornee=target;highlight.FillColor=color;highlight.OutlineColor=color;highlight.Enabled=true
 if Interaction.Distance(target,root.Position)<=Config.InteractionDistance then hovered=target end
end)
Input.InputBegan:Connect(function(input,processed)
 if processed or Input:GetFocusedTextBox() then return end
 if input.KeyCode==Enum.KeyCode.E and hovered then action:FireServer(hovered) end
end)
