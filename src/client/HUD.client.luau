local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "CharacterHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")
local strip = Instance.new("Frame")
strip.Name = "BottomStrip"
strip.AnchorPoint = Vector2.new(0, 1)
strip.Position = UDim2.fromScale(0, 1)
strip.Size = UDim2.new(1, 0, 0, 82)
strip.BackgroundColor3 = Color3.fromRGB(18, 23, 27)
strip.BorderSizePixel = 0
strip.Parent = gui
local padding = Instance.new("UIPadding")
padding.PaddingLeft, padding.PaddingRight = UDim.new(0, 12), UDim.new(0, 12)
padding.PaddingTop, padding.PaddingBottom = UDim.new(0, 12), UDim.new(0, 12)
padding.Parent = strip
local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.Padding = UDim.new(0, 8)
layout.Parent = strip
local entries = {}
local definitions = {
 {"Health", "Health", Color3.fromRGB(85, 191, 128)},
 {"Food", "Food", Color3.fromRGB(218, 169, 82)},
 {"Water", "Water", Color3.fromRGB(87, 169, 226)},
 {"Sickness", "Sick", Color3.fromRGB(216, 99, 99)},
 {"Weight", "LoadKg", Color3.fromRGB(177, 188, 199)},
}
for index, definition in ipairs(definitions) do
 local card = Instance.new("Frame")
 card.Name = definition[1]
 card.LayoutOrder = index
 card.Size = UDim2.new(0.2, -6.4, 1, 0)
 card.BackgroundTransparency = 1
 card.Parent = strip
 local text = Instance.new("TextLabel")
 text.Name = "Value"
 text.Size = UDim2.new(1, 0, 0, 36)
 text.BackgroundTransparency = 1
 text.TextColor3 = Color3.fromRGB(235, 240, 244)
 text.Font = Enum.Font.GothamMedium
 text.TextSize = 16
 text.TextWrapped = true
 text.Text = definition[1] .. " —"
 text.Parent = card
 local track = Instance.new("Frame")
 track.Position = UDim2.new(0, 0, 1, -10)
 track.Size = UDim2.new(1, 0, 0, 8)
 track.BorderSizePixel = 0
 track.BackgroundColor3 = Color3.fromRGB(43, 51, 58)
 track.Visible = definition[1] ~= "Weight"
 track.Parent = card
 local fill = Instance.new("Frame")
 fill.Name = "Fill"
 fill.BorderSizePixel = 0
 fill.BackgroundColor3 = definition[3]
 fill.Size = UDim2.fromScale(0, 1)
 fill.Parent = track
 entries[index] = {text = text, fill = fill, definition = definition}
end
local elapsed = 0
RunService.Heartbeat:Connect(function(dt)
 elapsed += dt
 if elapsed < 0.1 then return end
 elapsed = 0
 local character = player.Character
 for _, entry in ipairs(entries) do
  local name, attribute = entry.definition[1], entry.definition[2]
  local value = character and character:GetAttribute(attribute)
  if typeof(value) ~= "number" then
   entry.text.Text = name .. " —"
   entry.fill.Size = UDim2.fromScale(0, 1)
   continue
  end
  local maximum = name == "Health" and (character:GetAttribute("MaxHealth") or 100) or 100
  if name == "Weight" then
   entry.text.Text = string.format("Weight %.1f kg", value)
  else
   entry.text.Text = string.format("%s %.1f / %.0f", name, value, maximum)
   entry.fill.Size = UDim2.fromScale(math.clamp(value / math.max(maximum, 0.001), 0, 1), 1)
  end
 end
end)
