local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local Theme = require(ReplicatedStorage.Shared.UITheme)
local items = require(ReplicatedStorage.Shared.ItemConfig).Items
local layout=require(script.Parent.HUDLayout)
local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0,0)
panel.Position = UDim2.fromOffset(442,26)
panel.Size = UDim2.fromOffset(204,112)
panel.BackgroundColor3 = Theme.Panel
panel.BackgroundTransparency = .12
panel.Visible = false
panel.Parent = layout.Bar
Theme.Bevel(panel)
local viewport = Instance.new("ViewportFrame")
viewport.Position = UDim2.fromOffset(8,8)
viewport.Size = UDim2.fromOffset(150,96)
viewport.BackgroundTransparency = 1
viewport.Ambient = Color3.fromRGB(190,190,190)
viewport.LightColor = Color3.new(1,1,1)
viewport.LightDirection = Vector3.new(-1,-1,-1)
viewport.Parent = panel
local camera = Instance.new("Camera")
camera.FieldOfView = 30
camera.Parent = viewport
viewport.CurrentCamera = camera
local world = Instance.new("WorldModel")
world.Parent = viewport
-- Two vertical gauges beside the item: condition, then loaded ammunition.
local function gauge(x,color)
 local track=Instance.new("Frame")
 track.Position=UDim2.fromOffset(x,10);track.Size=UDim2.fromOffset(12,92)
 track.BackgroundColor3=Theme.Card;track.BorderSizePixel=1;track.BorderColor3=Theme.Border;track.Parent=panel
 local fill=Instance.new("Frame")
 fill.AnchorPoint=Vector2.new(0,1);fill.Position=UDim2.fromScale(0,1);fill.Size=UDim2.fromScale(1,0)
 fill.BackgroundColor3=color;fill.BorderSizePixel=0;fill.Parent=track
 return track,fill
end
local conditionTrack,conditionFill=gauge(166,Theme.Green)
local ammoTrack,ammoFill=gauge(184,Theme.Accent)
local hint=Instance.new("TextLabel")
hint.AnchorPoint=Vector2.new(1,1);hint.Position=UDim2.fromOffset(204,-8);hint.Size=UDim2.fromOffset(280,78)
hint.BackgroundColor3=Theme.Card;hint.TextColor3=Theme.Text;hint.Font=Theme.Font;hint.TextSize=13
hint.TextWrapped=true;hint.Visible=false;hint.Parent=panel
panel.MouseEnter:Connect(function() hint.Visible=true end)
panel.MouseLeave:Connect(function() hint.Visible=false end)
local character,held,connections
connections = {}
local function preview(model)
 world:ClearAllChildren()
 if not model then return end
 local copy = model:Clone()
 for _,object in ipairs(copy:GetDescendants()) do
  if object:IsA("LuaSourceContainer") or object:IsA("JointInstance") or object:IsA("WeldConstraint") then object:Destroy() end
 end
 local parts = copy:GetDescendants()
 if copy:IsA("BasePart") then table.insert(parts,copy) end
 for _,part in ipairs(parts) do if part:IsA("BasePart") then part.Anchored = true end end
 copy:PivotTo(CFrame.identity)
 copy.Parent = world
 local box,size
 if copy:IsA("Model") then box,size = copy:GetBoundingBox() else box,size = copy.CFrame,copy.Size end
 -- View the authored model from its right (+X) side.
 local extent = math.max(size.Y,size.Z*96/150,.1)
 local distance = extent/(2*math.tan(math.rad(camera.FieldOfView/2))) + size.X/2
 camera.CFrame = CFrame.lookAt(box.Position+Vector3.new(distance*1.15,0,0),box.Position,Vector3.yAxis)
end
local function refresh()
 local id = character and character:GetAttribute("HandsItem")
 local definition = id and items[id]
 local weapon = definition and definition.Weapon
 local currentHeld = character and character:FindFirstChild("HeldItem")
 panel.Visible = true
 if not weapon then hint.Visible=false; held = nil; world:ClearAllChildren();conditionFill.Size=UDim2.fromScale(1,0);ammoTrack.Visible=false;return end
 if held ~= currentHeld then held = currentHeld; preview(held) end
 local uses = math.clamp(character:GetAttribute("WeaponCondition") or 0,0,weapon.MaxUses)
 local fraction = uses/math.max(1,weapon.MaxUses)
 conditionFill.Size=UDim2.fromScale(1,fraction)
 conditionFill.BackgroundColor3=fraction<.2 and Theme.Danger or Theme.Green
 hint.Text=string.format("%s\nCondition %d / %d",definition.Name or id,uses,weapon.MaxUses)
 ammoTrack.Visible=definition.Firearm~=nil
 if definition.Firearm then
  local loaded=character:GetAttribute("MagazineAmmo") or 0
  ammoFill.Size=UDim2.fromScale(1,math.clamp(loaded/math.max(1,definition.Firearm.Magazine),0,1))
  ammoFill.BackgroundColor3=character:GetAttribute("Reloading") and Theme.Danger or Theme.Accent
  hint.Text..="\nMode: "..(definition.Firearm.SingleOnly and "Single" or character:GetAttribute("FireMode") or "Auto")..(definition.Firearm.SingleOnly and "" or " · V to switch").."\nR reload · B ammo type"
  hint.Text..=string.format("\nAmmo %d / %d · %s · Reserve %d%s",loaded,definition.Firearm.Magazine,character:GetAttribute("AmmoType") or "FMJ",character:GetAttribute("ReserveAmmo") or 0,character:GetAttribute("Reloading") and " · Reloading" or "")
 end
end
local function bind(model)
 for _,connection in ipairs(connections) do connection:Disconnect() end
 table.clear(connections)
 character,held = model,nil
 for _,attribute in ipairs({"HandsItem","WeaponCondition","MagazineAmmo","ReserveAmmo","AmmoType","Reloading","FireMode"}) do table.insert(connections,model:GetAttributeChangedSignal(attribute):Connect(refresh)) end
 table.insert(connections,model.ChildAdded:Connect(refresh))
 table.insert(connections,model.ChildRemoved:Connect(refresh))
 refresh()
end
player.CharacterAdded:Connect(bind)
if player.Character then bind(player.Character) end
