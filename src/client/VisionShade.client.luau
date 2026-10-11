-- A projected visibility polygon shades both the rear sector and occluded areas.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.GameConfig)
local Sight = require(ReplicatedStorage.Shared.Sight)
local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "VisionShade"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = -10
gui.Parent = player:WaitForChild("PlayerGui")
local masks = {}
local elapsed = math.huge
local rowHeight = 4
local function mask(index,x,y,width,height)
 local frame = masks[index]
 if not frame then
  frame = Instance.new("Frame")
  frame.BorderSizePixel = 0
  frame.BackgroundColor3 = Color3.fromRGB(8,12,20)
  frame.BackgroundTransparency = Config.UnseenShadeTransparency
  frame.Active = false
  frame.Parent = gui
  masks[index] = frame
 end
 frame.Position = UDim2.fromOffset(x,y)
 frame.Size = UDim2.fromOffset(width,height)
 frame.Visible = true
end
local function planePoint(camera,x,y,height)
 local ray = camera:ViewportPointToRay(x,y)
 if math.abs(ray.Direction.Y) < 1e-6 then return nil end
 local distance = (height-ray.Origin.Y)/ray.Direction.Y
 return distance > 0 and ray.Origin+ray.Direction*distance or nil
end
local function creatureBehindHit(hit,origin,direction)
 local model = hit.Instance:FindFirstAncestorOfClass("Model")
 local creature
 while model do
  if model.Name == "Mannikin" or model:FindFirstChildOfClass("Humanoid") then creature = model end
  model = model.Parent:FindFirstAncestorOfClass("Model")
 end
 if not creature then return hit.Distance end
 -- Start the shadow behind the body so the blocker itself remains readable.
 local box,size = creature:GetBoundingBox()
 local radius = math.abs(direction:Dot(box.RightVector))*size.X/2 + math.abs(direction:Dot(box.UpVector))*size.Y/2 + math.abs(direction:Dot(box.LookVector))*size.Z/2
 return math.max(hit.Distance,(box.Position-origin):Dot(direction)+radius)
end
RunService:BindToRenderStep("DeclineVisionShade",Enum.RenderPriority.Camera.Value+4,function(dt)
 local character = player.Character
 local root = character and character:FindFirstChild("HumanoidRootPart")
 local camera = workspace.CurrentCamera
 gui.Enabled = root ~= nil and camera ~= nil
 if not gui.Enabled then return end
 elapsed += dt
 if elapsed < Config.VisibilityInterval then return end
 elapsed = 0
 local width,height = camera.ViewportSize.X,camera.ViewportSize.Y
 local range = 10
 for _,corner in ipairs({Vector2.new(0,0),Vector2.new(width,0),Vector2.new(width,height),Vector2.new(0,height)}) do
  local point = planePoint(camera,corner.X,corner.Y,root.Position.Y)
  if point then range = math.max(range,(point-root.Position).Magnitude+5) end
 end
 local head = character:FindFirstChild("Head")
 local origin = (head and head:IsA("BasePart") and head.Position or root.Position)+Vector3.new(0,.05,0)
 local forward = Vector3.new(root.CFrame.LookVector.X,0,root.CFrame.LookVector.Z).Unit
 local right = Vector3.new(-forward.Z,0,forward.X)
 local center = camera:WorldToViewportPoint(root.Position)
 local polygon = {Vector2.new(center.X,center.Y)}
 local rays = math.ceil(Config.CreatureViewAngle*2)
 for i=0,rays do
  local angle = math.rad(-Config.CreatureViewAngle/2+Config.CreatureViewAngle*i/rays)
  local direction = forward*math.cos(angle)+right*math.sin(angle)
  local hit = Sight.Cast(origin,direction*range,character)
  local distance = hit and math.min(range,creatureBehindHit(hit,origin,direction)) or range
  local projected = camera:WorldToViewportPoint(root.Position+direction*distance)
  table.insert(polygon,Vector2.new(projected.X,projected.Y))
 end
 local used = 0
 for y=0,height-1,rowHeight do
  local scan = y+math.min(rowHeight,height-y)/2
  local intersections = {}
  for i,a in ipairs(polygon) do
   local b = polygon[i % #polygon+1]
   if (a.Y <= scan and b.Y > scan) or (b.Y <= scan and a.Y > scan) then
    table.insert(intersections,a.X+(scan-a.Y)*(b.X-a.X)/(b.Y-a.Y))
   end
  end
  table.sort(intersections)
  local cursor = 0
  for i=1,#intersections-1,2 do
   local start = math.clamp(intersections[i],0,width)
   local finish = math.clamp(intersections[i+1],0,width)
   if start > cursor then used+=1; mask(used,cursor,y,start-cursor,math.min(rowHeight,height-y)) end
   cursor = math.max(cursor,finish)
  end
  if cursor < width then used+=1; mask(used,cursor,y,width-cursor,math.min(rowHeight,height-y)) end
 end
 for i=used+1,#masks do masks[i].Visible = false end
end)
