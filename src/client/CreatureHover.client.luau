local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Input = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Theme=require(ReplicatedStorage.Shared.UITheme)
local Accuracy=require(ReplicatedStorage.Shared.AccuracyRules)
local Affiliation=require(ReplicatedStorage.Shared.AffiliationRules)
local Items=require(ReplicatedStorage.Shared.ItemConfig).Items
local View=require(script.Parent.EventVisibility)
local player = Players.LocalPlayer
local gui = Instance.new("BillboardGui")
gui.Name = "CreatureHover"
gui.Size = UDim2.fromOffset(190,66)
gui.AlwaysOnTop = true
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")
local panel = Instance.new("Frame")
panel.Size = UDim2.fromScale(1,1)
panel.BackgroundColor3 = Theme.Card
panel.BackgroundTransparency = .15
panel.BorderSizePixel = 0
panel.Parent = gui
Theme.Bevel(panel)
local function label(y,size,color)
 local text = Instance.new("TextLabel")
 text.Position = UDim2.fromOffset(8,y)
 text.Size = UDim2.new(1,-16,0,22)
 text.BackgroundTransparency = 1
 text.Font = Theme.Font
 text.TextSize = size
 text.TextColor3 = color
 text.Parent = panel
 return text
end
local name = label(4,16,Color3.fromRGB(238,241,245))
local chanceText=label(27,14,Theme.Accent)
local health = label(27,14,Color3.fromRGB(215,225,219))
local track = Instance.new("Frame")
track.Position = UDim2.fromOffset(10,55)
track.Size = UDim2.new(1,-20,0,4)
track.BackgroundColor3 = Color3.fromRGB(55,62,69)
track.BorderSizePixel = 0
track.Parent = panel
local fill = Instance.new("Frame")
fill.Size = UDim2.fromScale(1,1)
fill.BorderSizePixel = 0
fill.Parent = track
local function creature(part)
 local model,humanoid
 local ancestor = part.Parent
 while ancestor and ancestor ~= workspace do
  if ancestor:IsA("Model") then
   local candidate = ancestor:FindFirstChildOfClass("Humanoid")
   if candidate then model,humanoid = ancestor,candidate end
   if ancestor.Name == "Mannikin" then
    model = ancestor
    humanoid = candidate or humanoid or ancestor:FindFirstChildWhichIsA("Humanoid",true)
   end
  end
  ancestor = ancestor.Parent
 end
 return model,humanoid
end
RunService:BindToRenderStep("DeclineCreatureHover",Enum.RenderPriority.Last.Value+2,function()
 gui.Enabled = false
 local camera = workspace.CurrentCamera
 local character = player.Character
 if not camera or not character or player:GetAttribute("InventoryOpen") or player:GetAttribute("TownMenuOpen") or player:GetAttribute("ProgressionOpen") or player:GetAttribute("GroupOpen") or GuiService.MenuIsOpen or Input:GetFocusedTextBox() then return end
 local mouse = Input:GetMouseLocation()
 local size = camera.ViewportSize
 if mouse.X < 0 or mouse.Y < 0 or mouse.X > size.X or mouse.Y > size.Y then return end
 local ray = camera:ViewportPointToRay(mouse.X,mouse.Y)
 local params = RaycastParams.new()
 params.FilterType = Enum.RaycastFilterType.Include
 local candidates={}
 for model in pairs(View.Targets) do
  if model~=character and model.Parent and model:GetAttribute("ClientVisible")==true then table.insert(candidates,model) end
 end
 if #candidates==0 then return end
 params.FilterDescendantsInstances=candidates
 local hit = workspace:Raycast(ray.Origin,ray.Direction*1000,params)
 if not hit then return end
 local model,humanoid = creature(hit.Instance)
 if not model or not humanoid or humanoid.Health <= 0 or model:GetAttribute("ClientVisible") ~= true then return end
 local head = model:FindFirstChild("Head",true)
 local anchor = head and head:IsA("BasePart") and head or model:FindFirstChild("HumanoidRootPart",true) or model:FindFirstChildWhichIsA("BasePart",true)
 if not anchor then return end
 gui.Adornee = anchor
 gui.StudsOffsetWorldSpace = Vector3.new(0,anchor.Size.Y/2+1.1,0)
 local display = model:GetAttribute("DisplayName")
 if typeof(display) ~= "string" or display == "" then display = humanoid.DisplayName ~= "" and humanoid.DisplayName or model.Name end
 local owner=Players:GetPlayerFromCharacter(model)
 if owner and (player:GetAttribute("GroupID") or 0)~=0 and owner:GetAttribute("GroupID")==player:GetAttribute("GroupID") then return end
 name.Text=owner and (owner.DisplayName or owner.Name) or display
 health.Visible=owner==nil;track.Visible=owner==nil
 local root=character:FindFirstChild("HumanoidRootPart")
 local target=model:FindFirstChild("HumanoidRootPart",true) or anchor
 local definition=Items[character:GetAttribute("HandsItem")]
 local category=definition and definition.Firearm and (definition.Firearm.Category or "Rifle") or ""
 local friendly=Affiliation.Friendly(player,owner)
 chanceText.Visible=root~=nil and not friendly
 chanceText.Position=UDim2.fromOffset(8,owner and 27 or 65)
 if chanceText.Visible then
  local chance=Accuracy.Chance(Accuracy.ForWeapon(player,definition),(definition and definition.Firearm and Accuracy.SightBonus(character:FindFirstChild("HeldItem")) or 0),(target.Position-root.Position).Magnitude,owner and owner:GetAttribute("DodgeChance") or 0)
  chanceText.Text=string.format("Hit chance: %d%%",math.floor(chance))
 end
 gui.Size=UDim2.fromOffset(190,owner and (friendly and 30 or 54) or 90)
 local current,maximum = humanoid.Health,humanoid.MaxHealth
 health.Text = string.format("%.0f / %.0f HP",current,maximum)
 local ratio = maximum > 0 and math.clamp(current/maximum,0,1) or 0
 fill.Size = UDim2.fromScale(ratio,1)
 fill.BackgroundColor3 = Color3.fromRGB(215,65,65):Lerp(Color3.fromRGB(90,210,130),ratio)
 gui.Enabled = true
end)
