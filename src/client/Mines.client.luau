local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Input=game:GetService("UserInputService")
local RunService=game:GetService("RunService")
local GuiService=game:GetService("GuiService")
local Debris=game:GetService("Debris")
local TweenService=game:GetService("TweenService")
local player=Players.LocalPlayer
local remote=ReplicatedStorage:WaitForChild("MineAction")
local template=ReplicatedStorage:WaitForChild("MineVisual")
local RocketAudio=require(script.Parent.RocketAudio)
local MineTarget=require(script.Parent.MineTarget)
local MineRules=require(ReplicatedStorage.Shared.MineRules)
local Visibility=require(ReplicatedStorage.Shared.VisibilityRules)
local Config=require(ReplicatedStorage.Shared.GameConfig)
local seen={}
local function clear(id)
 local r=seen[id];if r then MineTarget.Remove(r.Model);r.Model:Destroy();seen[id]=nil end
end
local function blocked()
 local c=player.Character
 return not c or c:GetAttribute("InteractionLocked") or c:GetAttribute("HandsBusy") or c:GetAttribute("Knockout") or c:GetAttribute("IsDead") or player:GetAttribute("InventoryOpen") or player:GetAttribute("PlayerContextOpen") or player:GetAttribute("TownMenuOpen") or player:GetAttribute("ProgressionOpen") or player:GetAttribute("GroupOpen") or player:GetAttribute("MapOpen") or player:GetAttribute("HelpOpen") or player:GetAttribute("TradeOpen") or player:GetAttribute("ExchangeOpen") or player:GetAttribute("AdminOpen") or player:GetAttribute("MedicalMode") or c:GetAttribute("MedicalHeld") or c:GetAttribute("CarryingUserId") or GuiService.MenuIsOpen or Input:GetFocusedTextBox()
end
Input.InputBegan:Connect(function(input,processed)
 if processed or input.UserInputType~=Enum.UserInputType.MouseButton1 or blocked() then return end
 local target=MineTarget.Get()
 if target then remote:FireServer("Disarm",target)
 elseif player.Character:GetAttribute("HandsItem")=="Mine" then remote:FireServer("Place") end
end)
remote.OnClientEvent:Connect(function(kind,id,frame,data)
 if kind=="Remove" then clear(id)
 elseif kind=="Reveal" then
  if seen[id] then return end
  local model=template:Clone();model.Name="DetectedMine";model:PivotTo(frame);model.Parent=workspace
  local part=model:IsA("BasePart") and model or model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart",true)
  if not part then model:Destroy();return end
  local highlight=Instance.new("Highlight");highlight.Adornee=model;highlight.FillColor=Color3.fromRGB(255,30,30);highlight.OutlineColor=highlight.FillColor
  highlight.DepthMode=Enum.HighlightDepthMode.Occluded;highlight.Parent=model
  local parts=model:GetDescendants();if model:IsA("BasePart") then table.insert(parts,model) end
  highlight.Enabled=false
  for _,v in ipairs(parts) do if v:IsA("BasePart") then v.LocalTransparencyModifier=1;v.CanQuery=false end end
  MineTarget.Register(id,model,data or frame.Position)
  seen[id]={Model=model,Highlight=highlight,Position=data or frame.Position,Parts=parts}
 elseif kind=="Explosion" then
  local point,radius=id,frame
  RocketAudio.Explode(data,point)
  local part=Instance.new("Part");part.Shape=Enum.PartType.Ball;part.Size=Vector3.new(.5,.5,.5);part.CFrame=CFrame.new(point)
  part.Anchored=true;part.CanCollide=false;part.CanTouch=false;part.CanQuery=false;part.Material=Enum.Material.Neon;part.Color=Color3.fromRGB(255,140,45);part.Transparency=.2;part.Parent=workspace
  local light=Instance.new("PointLight");light.Range=20;light.Brightness=5;light.Parent=part
  TweenService:Create(part,TweenInfo.new(.35),{Size=Vector3.one*radius*2,Transparency=1}):Play();Debris:AddItem(part,.4)
 end
end)
RunService.Heartbeat:Connect(function()
 local c=player.Character;local root=c and c:FindFirstChild("HumanoidRootPart")
 for id,r in pairs(seen) do
  local eye=c and (c:FindFirstChild("Head") or root)
  local radius=MineRules.DetectionRadius(player:GetAttribute("Attention"),player:GetAttribute("SkillTraps"))
  local visible=root and eye and not c:GetAttribute("Knockout") and not c:GetAttribute("IsDead") and (eye.Position-r.Position).Magnitude<=radius
  if visible then
   local forward=root.CFrame.LookVector
   local offset=r.Position-root.Position
   visible=Visibility.InSector(forward.X,forward.Z,offset.X,offset.Z,Config.CreatureViewAngle*(player:GetAttribute("ViewAngleMultiplier") or 1))
  end
  if visible~=r.Visible then
   r.Visible=visible
   for _,part in ipairs(r.Parts) do if part:IsA("BasePart") then part.LocalTransparencyModifier=visible and 0 or 1;part.CanQuery=visible==true end end
  end
  r.Highlight.Enabled=visible==true;r.Highlight.FillTransparency=.3+.4*(.5+.5*math.sin(os.clock()*7))
 end
end)
player.CharacterRemoving:Connect(function() for id in pairs(seen) do clear(id) end end)
