local Locale=require(script.Parent.LocaleController)
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Input=game:GetService("UserInputService")
local Run=game:GetService("RunService")
local GuiService=game:GetService("GuiService")
local player=Players.LocalPlayer
local remote=ReplicatedStorage:WaitForChild("MedicalAction")
local Affiliation=require(ReplicatedStorage.Shared.AffiliationRules)
local Rules=require(ReplicatedStorage.Shared.ProgressionRules)
local View=require(script.Parent.EventVisibility)
local Theme=require(ReplicatedStorage.Shared.UITheme)
local Layout=require(script.Parent.HUDLayout)
local highlight=Instance.new("Highlight");highlight.Name="MedicalTarget";highlight.DepthMode=Enum.HighlightDepthMode.Occluded;highlight.FillTransparency=.65;highlight.OutlineTransparency=0;highlight.Enabled=false;highlight.Parent=workspace
local gui=Instance.new("ScreenGui");gui.Name="MedicalAim";gui.ResetOnSpawn=false;gui.IgnoreGuiInset=true;gui.Parent=player:WaitForChild("PlayerGui")
local hint=Instance.new("TextLabel");hint.Size=UDim2.fromOffset(250,58);hint.BackgroundColor3=Theme.Card;hint.TextColor3=Theme.Text;hint.Font=Theme.Font;hint.TextSize=14;hint.TextWrapped=true;hint.Visible=false;hint.Parent=gui
local function bandage(id) return id=="Bandage" or id=="GreatBandage" end
local selected
local function blocked()
 if player:GetAttribute("PlayerContextOpen") then return true end
 return (player:GetAttribute("MapOpen") or player:GetAttribute("HelpOpen")) or GuiService.MenuIsOpen or Input:GetFocusedTextBox() or (player:GetAttribute("AdminOpen") or player:GetAttribute("InventoryOpen")) or player:GetAttribute("TownMenuOpen") or player:GetAttribute("ProgressionOpen") or player:GetAttribute("GroupOpen")
end
local function cancel() player:SetAttribute("MedicalMode",nil);selected=nil;highlight.Enabled=false;hint.Visible=false end
Input.InputBegan:Connect(function(key,processed)
 if processed or Input:GetFocusedTextBox() then return end
 if key.KeyCode==Enum.KeyCode.H and not blocked() then
  if player:GetAttribute("MedicalMode")=="Bandage" then cancel();return end
  local c=player.Character
  if not c or not bandage(c:GetAttribute("MedicineItem")) then Layout.Log:Fire("Equip a bandage in the Medicine slot first.");return end
  player:SetAttribute("MedicalMode","Bandage")
 elseif (key.KeyCode==Enum.KeyCode.Four or key.KeyCode==Enum.KeyCode.KeypadFour) and not blocked() then
  if player:GetAttribute("MedicalMode")=="Doctor" then cancel();return end
  if player:GetAttribute("AttributesConfirmed")~=true then return end
  player:SetAttribute("MedicalMode","Doctor")
 elseif key.KeyCode==Enum.KeyCode.Escape then cancel()
 elseif key.UserInputType==Enum.UserInputType.MouseButton1 and not blocked() then
  local mode=player:GetAttribute("MedicalMode")
  if mode and selected then remote:FireServer(mode,selected) end
 end
end)
Run.RenderStepped:Connect(function()
 selected=nil;highlight.Enabled=false;hint.Visible=false
 local mode=player:GetAttribute("MedicalMode")
 if not mode then return end
 local character=player.Character;local hp=character and character:FindFirstChildOfClass("Humanoid")
 if not character or not hp or hp.Health<=0 or character:GetAttribute("Knockout") then cancel();return end
 if mode=="Bandage" and not bandage(character:GetAttribute("MedicineItem")) then cancel();return end
 if blocked() then cancel();return end
 local camera=workspace.CurrentCamera;local root=character:FindFirstChild("HumanoidRootPart")
 if not camera or not root then return end
 local mouse=Input:GetMouseLocation()
 local ray=camera:ViewportPointToRay(mouse.X,mouse.Y)
 local candidates={}
 for _,p in ipairs(Players:GetPlayers()) do
  local c=p.Character;local health=c and c:FindFirstChildOfClass("Humanoid")
  if health and health.Health>0 and (c==character or View.Check(c,root,character,camera)) then table.insert(candidates,c) end
 end
 local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Include;params.FilterDescendantsInstances=candidates
 local hit=workspace:Raycast(ray.Origin,ray.Direction*1000,params)
 if hit then
  for _,c in ipairs(candidates) do if hit.Instance:IsDescendantOf(c) then selected=Players:GetPlayerFromCharacter(c);break end end
 end
 if selected then
  local green=selected==player or Affiliation.SameFaction(player,selected)
  highlight.Adornee=selected.Character;highlight.FillColor=green and Theme.Green or Color3.fromRGB(215,65,65);highlight.OutlineColor=highlight.FillColor;highlight.Enabled=true
 end
 local text
 if mode=="Doctor" then
  local cooldown=math.max(0,math.ceil((player:GetAttribute("DoctorReadyAt") or 0)-workspace:GetServerTimeNow()))
  text=cooldown>0 and ("Doctor · ready in "..cooldown.."s") or string.format("Doctor · %g%% chance · 4 to cancel\nClick a nearby knocked-out player",Rules.ReviveChance(player:GetAttribute("SkillDoctor"))*100)
 else text=string.format("First aid · %g HP · H to cancel\nClick yourself or a nearby player",Rules.FirstAid(player:GetAttribute("SkillFirstAid"),player:GetAttribute("FirstAidMultiplier"),(selected or player):GetAttribute("Endurance"),character:GetAttribute("MedicineItem"),player:GetAttribute("MedicalHealingBonus"))) end
 if selected then
  local body=selected.Character:FindFirstChild("HumanoidRootPart")
  if body and (body.Position-root.Position).Magnitude>3 then text="Move closer to "..Locale.Raw(selected.Name) end
 end
 hint.Text=text;hint.Position=UDim2.fromOffset(math.clamp(mouse.X+18,0,math.max(0,camera.ViewportSize.X-250)),math.clamp(mouse.Y+18,0,math.max(0,camera.ViewportSize.Y-58)));hint.Visible=true
end)
player.CharacterRemoving:Connect(cancel)
