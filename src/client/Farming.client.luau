local Players=game:GetService("Players")
local Replicated=game:GetService("ReplicatedStorage")
local Run=game:GetService("RunService")
local Input=game:GetService("UserInputService")
local player=Players.LocalPlayer
local Theme=require(Replicated.Shared.UITheme)
local Config=require(Replicated.Shared.FarmingConfig)
local Items=require(Replicated.Shared.ItemConfig)
local Interaction=require(Replicated.Shared.Interaction)
local remote=Replicated:WaitForChild("FarmingMenu")
local action=Replicated:WaitForChild("InventoryRemotes"):WaitForChild("Action")
local function make(class,parent,props)
 local o=Instance.new(class);for k,v in pairs(props) do o[k]=v end;o.Parent=parent;return o
end
local gui=make("ScreenGui",player:WaitForChild("PlayerGui"),{Name="FarmingUI",ResetOnSpawn=false,DisplayOrder=50})
local panel=make("Frame",gui,{Size=UDim2.fromOffset(440,430),Position=UDim2.fromScale(.5,.5),AnchorPoint=Vector2.new(.5,.5),BackgroundColor3=Theme.Panel,BorderColor3=Theme.Border,Visible=false})
local function text(value,y,height)
 return make("TextLabel",panel,{Text=value,Position=UDim2.fromOffset(18,y),Size=UDim2.new(1,-36,0,height),BackgroundTransparency=1,TextColor3=Theme.Text,Font=Theme.Font,TextSize=14,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top})
end
text("GARDEN BED",16,24)
text("Choose a crop",52,24)
text("Potato | Base growth: "..Config.GrowthSeconds.."s\nWater: 20 per plant. Low water slows growth.\nPlants all free slots; no seeds required.",82,64)
local plant=make("TextButton",panel,{Text="Plant potatoes",Position=UDim2.fromOffset(18,156),Size=UDim2.new(1,-36,0,36),BackgroundColor3=Theme.Button,TextColor3=Theme.Accent,Font=Theme.Font,TextSize=16,BorderColor3=Theme.Border})
local status=text("",210,40)
local details=make("ScrollingFrame",panel,{Position=UDim2.fromOffset(18,254),Size=UDim2.new(1,-36,0,112),BackgroundColor3=Theme.Card,BorderSizePixel=0,ScrollBarThickness=5,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y})
local info=make("TextLabel",details,{Size=UDim2.new(1,-12,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,Text="",TextColor3=Theme.Text,Font=Theme.Font,TextSize=13,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top})
local closeButton=make("TextButton",panel,{Text="Close [Q / Esc]",Position=UDim2.fromOffset(18,382),Size=UDim2.new(1,-36,0,30),BackgroundColor3=Theme.Button,TextColor3=Theme.Text,Font=Theme.Font,TextSize=14,BorderColor3=Theme.Border})
local bed
local function close() bed=nil;panel.Visible=false;player:SetAttribute("FarmMenuOpen",false) end
closeButton.Activated:Connect(close)
remote.OnClientEvent:Connect(function(model)
 if typeof(model)~="Instance" or not model:IsDescendantOf(workspace) then return end
 bed=model;panel.Visible=true;player:SetAttribute("FarmMenuOpen",true)
end)
plant.Activated:Connect(function() if bed then action:FireServer("PlantCrop",bed,"Potato");close() end end)
Input.InputBegan:Connect(function(input,processed)
 if panel.Visible and not Input:GetFocusedTextBox() and (input.KeyCode==Enum.KeyCode.Q or input.KeyCode==Enum.KeyCode.Escape) then close() end
end)
Run.Heartbeat:Connect(function()
 if not bed then return end
 local char=player.Character;local root=char and char:FindFirstChild("HumanoidRootPart");local hp=char and char:FindFirstChildOfClass("Humanoid")
 if not bed:IsDescendantOf(workspace) or not root or not hp or hp.Health<=0 or char:GetAttribute("Knockout") or (Interaction.NearestPoint(bed,root.Position)-root.Position).Magnitude>Items.PickupDistance or player:GetAttribute("InventoryOpen") or player:GetAttribute("AdminOpen") or player:GetAttribute("TownMenuOpen") or player:GetAttribute("ProgressionOpen") then close();return end
 local count=bed:GetAttribute("PlantCount") or 0
 status.Text="Plants: "..count.." | Water: "..math.floor(bed:GetAttribute("Watering") or 0).."/"..(bed:GetAttribute("MaxWatering") or 100)
 plant.Active=count<(bed:GetAttribute("MaxPlants") or 5);plant.Text=plant.Active and "Plant potatoes" or "Garden bed is full"
 info.Text=player:GetAttribute("PlantKnowledge") and ((bed:GetAttribute("CropDetails") or "").."\nEstimates use current watering and may change.") or "Botanist perk reveals growth stages and harvest estimates."
end)
player.CharacterRemoving:Connect(close)
