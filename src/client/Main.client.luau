local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local player = Players.LocalPlayer
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local remotes = ReplicatedStorage:WaitForChild("DeclineRemotes")
local gui = Instance.new("ScreenGui")
gui.Name, gui.ResetOnSpawn, gui.Parent = "DeclineHUD", false, player:WaitForChild("PlayerGui")
local function label(parent, text, position, size)
 local item = Instance.new("TextLabel")
 item.Text, item.Position, item.Size = text, position, size
 item.BackgroundColor3, item.BackgroundTransparency = Color3.fromRGB(22, 26, 25), 0.15
 item.TextColor3, item.TextSize, item.Font = Color3.new(1, 1, 1), 18, Enum.Font.Gotham
 item.Parent = parent
 return item
end
local status = label(gui, "Завантаження…", UDim2.new(0, 16, 1, -115), UDim2.new(0, 460, 0, 95))
status.TextWrapped = true
local message = label(gui, "", UDim2.new(0.5, -220, 0, 20), UDim2.new(0, 440, 0, 64))
message.TextWrapped = true
local menu = Instance.new("Frame")
menu.Size, menu.Position = UDim2.new(0, 440, 0, 390), UDim2.new(0.5, -220, 0.5, -195)
menu.BackgroundColor3, menu.Visible, menu.Parent = Color3.fromRGB(30, 36, 33), false, gui
label(menu, "Обери професію та стартове місто", UDim2.fromOffset(10, 10), UDim2.new(1, -20, 0, 40))
local profession = Config.Professions[1]
local professionButton = Instance.new("TextButton")
professionButton.Size, professionButton.Position = UDim2.new(1, -20, 0, 40), UDim2.fromOffset(10, 60)
professionButton.TextColor3, professionButton.BackgroundColor3 = Color3.new(1, 1, 1), Color3.fromRGB(65, 80, 65)
professionButton.TextSize, professionButton.Parent = 18, menu
local index = 1
local function updateProfession() professionButton.Text = "Професія: " .. Config.ProfessionNames[profession] .. "  ▶" end
updateProfession()
professionButton.Activated:Connect(function()
 index = index % #Config.Professions + 1
 profession = Config.Professions[index]
 updateProfession()
end)
local townFolder = workspace:WaitForChild("DeclineWorld"):WaitForChild("Towns")
local towns = townFolder:GetChildren()
table.sort(towns, function(a, b) return a.Flag:GetAttribute("Town_ID") < b.Flag:GetAttribute("Town_ID") end)
for row, town in ipairs(towns) do
 local flag = town:WaitForChild("Flag")
 local button = Instance.new("TextButton")
 button.Size, button.Position = UDim2.new(1, -20, 0, 42), UDim2.fromOffset(10, 110 + (row - 1) * 48)
 button.Text = flag:GetAttribute("Town_name") or town.Name
 button.BackgroundColor3, button.TextColor3 = flag.Color, Color3.new(1, 1, 1)
 button.TextSize, button.Parent = 18, menu
 button.Activated:Connect(function() remotes.SelectTown:FireServer(flag:GetAttribute("Town_ID"), profession) end)
end
local close = Instance.new("TextButton")
close.Text, close.Size, close.Position, close.Parent = "Закрити", UDim2.fromOffset(100, 30), UDim2.new(0.5, -50, 1, -40), menu
close.Activated:Connect(function() menu.Visible = false end)
remotes.OpenTerminal.OnClientEvent:Connect(function() menu.Visible = true end)
player:GetAttributeChangedSignal("Town_ID"):Connect(function() if player:GetAttribute("Town_ID") ~= 0 then menu.Visible = false end end)
local resetCallback = Instance.new("BindableEvent")
resetCallback.Event:Connect(function() remotes.Reset:FireServer() end)
task.spawn(function()
 for _ = 1, 30 do
  local ok = pcall(function() StarterGui:SetCore("ResetButtonCallback", resetCallback) end)
  if ok then return end
  task.wait(0.5)
 end
 warn("[Decline] Unable to install ResetButtonCallback")
end)
UserInputService.InputBegan:Connect(function(input, processed)
 if not processed and input.KeyCode == Enum.KeyCode.LeftShift then remotes.Sprint:FireServer(true) end
end)
UserInputService.InputEnded:Connect(function(input)
 if input.KeyCode == Enum.KeyCode.LeftShift then remotes.Sprint:FireServer(false) end
end)
UserInputService.WindowFocusReleased:Connect(function() remotes.Sprint:FireServer(false) end)
RunService:BindToRenderStep("DeclineCamera", Enum.RenderPriority.Camera.Value + 1, function()
 local character = player.Character
 local root = character and character:FindFirstChild("HumanoidRootPart")
 if not root then return end
 local camera = workspace.CurrentCamera
 camera.CameraType = Enum.CameraType.Scriptable
 camera.FieldOfView = 55
 camera.CFrame = CFrame.lookAt(root.Position + Vector3.new(0, Config.CameraHeight, 0), root.Position, Vector3.new(0, 0, -1))
 local humanoid = character:FindFirstChildOfClass("Humanoid")
 if humanoid then
  humanoid.AutoRotate = false
  if not player:GetAttribute("Knockout") and not menu.Visible then
   local mouse = UserInputService:GetMouseLocation()
   local ray = camera:ScreenPointToRay(mouse.X, mouse.Y)
   if math.abs(ray.Direction.Y) > 0.001 then
    local t = (root.Position.Y - ray.Origin.Y) / ray.Direction.Y
    local point = ray.Origin + ray.Direction * t
    local direction = Vector3.new(point.X - root.Position.X, 0, point.Z - root.Position.Z)
    if direction.Magnitude > 0.1 then root.CFrame = CFrame.lookAt(root.Position, root.Position + direction) end
   end
  end
 end
end)
task.spawn(function()
 while gui.Parent do
  local id = player:GetAttribute("Town_ID") or 0
  local name = player:GetAttribute("Profession") or ""
  status.Text = string.format("HP %.1f   Їжа %.1f   Вода %.1f   Sick %.1f\nМісто: %s   %s%s\nWASD — рух   Shift — біг   E — термінал",
   player:GetAttribute("Health") or 100, player:GetAttribute("Food") or 100,
   player:GetAttribute("Water") or 100, player:GetAttribute("Sick") or 100,
   id == 0 and "не обрано" or tostring(id), Config.ProfessionNames[name] or "",
   player:GetAttribute("Leader") and " • Мер" or "")
  local now = workspace:GetServerTimeNow()
  if player:GetAttribute("Knockout") then
   message.Text = "НЕПРИТОМНИЙ\nДо смерті: " .. math.max(0, math.ceil((player:GetAttribute("KnockoutEnd") or now) - now)) .. " с"
  elseif (player:GetAttribute("CorpseProtectedUntil") or 0) > now then
   message.Text = "Твій труп захищений від жителів міста: " .. math.ceil(player:GetAttribute("CorpseProtectedUntil") - now) .. " с"
  elseif id == 0 then
   message.Text = "Підійди до термінала та натисни E"
  else message.Text = "" end
  message.Visible = message.Text ~= ""
  task.wait(0.1)
 end
end)
