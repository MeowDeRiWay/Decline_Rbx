-- Screen-space shading on the character's horizontal plane; never blocks input.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.GameConfig)
local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "VisionShade"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = -10
gui.Parent = player:WaitForChild("PlayerGui")
local rows = {}
local rowHeight = 4
local function mask()
 local frame = Instance.new("Frame")
 frame.BorderSizePixel = 0
 frame.BackgroundColor3 = Color3.fromRGB(8,12,20)
 frame.BackgroundTransparency = Config.UnseenShadeTransparency
 frame.Active = false
 frame.Parent = gui
 return frame
end
local function intersect(origin,direction,height)
 if math.abs(direction.Y) < 1e-6 then return nil end
 local distance = (height-origin.Y)/direction.Y
 if distance <= 0 then return nil end
 return origin+direction*distance
end
local function clip(a,b,lo,hi)
 if a < 0 and b < 0 then return nil,nil end
 if a >= 0 and b >= 0 then return lo,hi end
 local crossing = a/(a-b)
 if a < 0 then lo = math.max(lo,crossing) else hi = math.min(hi,crossing) end
 if lo > hi then return nil,nil end
 return lo,hi
end
RunService:BindToRenderStep("DeclineVisionShade",Enum.RenderPriority.Camera.Value+4,function()
 local character = player.Character
 local root = character and character:FindFirstChild("HumanoidRootPart")
 local camera = workspace.CurrentCamera
 gui.Enabled = root ~= nil and camera ~= nil
 if not gui.Enabled then return end
 local width,height = camera.ViewportSize.X,camera.ViewportSize.Y
 local count = math.ceil(height/rowHeight)
 while #rows < count do table.insert(rows,{mask(),mask()}) end
 local forward = root.CFrame.LookVector
 local right = Vector3.new(-forward.Z,0,forward.X)
 local tangent = math.tan(math.rad(Config.CreatureViewAngle/2))
 for i,pair in ipairs(rows) do
  local y = (i-1)*rowHeight
  if i > count then pair[1].Visible=false; pair[2].Visible=false; continue end
  local leftRay = camera:ViewportPointToRay(0,y+rowHeight/2)
  local rightRay = camera:ViewportPointToRay(width,y+rowHeight/2)
  local left = intersect(leftRay.Origin,leftRay.Direction,root.Position.Y)
  local rightPoint = intersect(rightRay.Origin,rightRay.Direction,root.Position.Y)
  local lo,hi = 0,1
  if left and rightPoint then
   local a,b = left-root.Position,rightPoint-root.Position
   lo,hi = clip(a:Dot(forward)*tangent+a:Dot(right),b:Dot(forward)*tangent+b:Dot(right),lo,hi)
   if lo then lo,hi = clip(a:Dot(forward)*tangent-a:Dot(right),b:Dot(forward)*tangent-b:Dot(right),lo,hi) end
  else lo=nil end
  local start,finish = lo and lo*width or width,hi and hi*width or width
  pair[1].Position = UDim2.fromOffset(0,y)
  pair[1].Size = UDim2.fromOffset(start,math.min(rowHeight,height-y))
  pair[1].Visible = start > 0
  pair[2].Position = UDim2.fromOffset(finish,y)
  pair[2].Size = UDim2.fromOffset(width-finish,math.min(rowHeight,height-y))
  pair[2].Visible = finish < width
 end
end)
