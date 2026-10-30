local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Input=game:GetService("UserInputService")
local Context=game:GetService("ContextActionService")
local GuiService=game:GetService("GuiService")
local Examination=require(script.Parent.PatientExamination)
local Theme=require(ReplicatedStorage.Shared.UITheme)
local player=Players.LocalPlayer
local remote=ReplicatedStorage:WaitForChild("PlayerContextAction")
local medical=ReplicatedStorage:WaitForChild("MedicalAction")
local inventory=ReplicatedStorage:WaitForChild("InventoryRemotes"):WaitForChild("Action")
local gui=Instance.new("ScreenGui");gui.Name="PlayerContext";gui.ResetOnSpawn=false;gui.IgnoreGuiInset=true;gui.DisplayOrder=100;gui.Enabled=false;gui.Parent=player:WaitForChild("PlayerGui")
local overlay=Instance.new("TextButton");overlay.Size=UDim2.fromScale(1,1);overlay.BackgroundTransparency=1;overlay.Text="";overlay.Parent=gui
local panel=Instance.new("Frame");panel.BackgroundColor3=Theme.Panel;panel.Parent=overlay
Theme.Bevel(panel)
local exam=Instance.new("TextLabel");exam.BackgroundTransparency=1;exam.TextColor3=Theme.Text;exam.Font=Theme.Font;exam.TextSize=13;exam.TextWrapped=true;exam.Size=UDim2.new(1,-12,0,108);exam.Position=UDim2.fromOffset(6,0);exam.Visible=false;exam:SetAttribute("LocalizationIgnore",true);exam.Parent=panel
local examined
local function close() examined=nil;gui.Enabled=false;player:SetAttribute("PlayerContextOpen",false) end
local function blocked()
 if GuiService.MenuIsOpen or Input:GetFocusedTextBox() then return true end
 for _,key in ipairs({"InventoryOpen","TownMenuOpen","ProgressionOpen","GroupOpen","AdminOpen","MapOpen","HelpOpen","TradeOpen"}) do if player:GetAttribute(key) then return true end end
 local c=player.Character;local hp=c and c:FindFirstChildOfClass("Humanoid")
 return not hp or hp.Health<=0 or c:GetAttribute("Knockout") or c:GetAttribute("IsDead") or c:GetAttribute("HospitalResting") or player:GetAttribute("AttributesConfirmed")~=true
end
local function target()
 local camera=workspace.CurrentCamera;if not camera then return end
 local mouse=Input:GetMouseLocation();local ray=camera:ViewportPointToRay(mouse.X,mouse.Y)
 local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances={player.Character}
 local carried=player.Character and player.Character:GetAttribute("CarryingUserId")
 local patient=carried and Players:GetPlayerByUserId(carried)
 if patient and patient.Character then table.insert(params.FilterDescendantsInstances,patient.Character) end
 local hit=workspace:Raycast(ray.Origin,ray.Direction*1000,params)
 local object=hit and hit.Instance
 while object and object~=workspace do
  if object:IsA("Model") then
   if object:GetAttribute("HospitalBed")==true then return "Bed",object end
   local owner=Players:GetPlayerFromCharacter(object)
   if owner and owner~=player and object:GetAttribute("Knockout") then return "Patient",owner end
   if object:GetAttribute("IsCorpse") then return "Corpse",object end
  end
  object=object.Parent
 end
end
local function show(options,patient)
 for _,child in ipairs(panel:GetChildren()) do if child:IsA("TextButton") then child:Destroy() end end
 examined=patient
 local status=patient and Examination.Text(patient)
 local offset=status and 108 or 0
 exam.Visible=status~=nil;exam.Text=status or ""
 local size=Vector2.new(260,#options*36+offset)
 local mouse=Input:GetMouseLocation();local camera=workspace.CurrentCamera
 panel.Size=UDim2.fromOffset(size.X,size.Y)
 panel.Position=UDim2.fromOffset(math.clamp(mouse.X,0,math.max(0,camera.ViewportSize.X-size.X)),math.clamp(mouse.Y,0,math.max(0,camera.ViewportSize.Y-size.Y)))
 for i,option in ipairs(options) do
  local button=Instance.new("TextButton");button.Size=UDim2.new(1,0,0,34);button.Position=UDim2.fromOffset(0,offset+(i-1)*36);button.BackgroundColor3=Theme.Button;button.TextColor3=Theme.Text;button.Font=Theme.Font;button.TextSize=14;button.Text=option[1];button.Parent=panel
  button.Activated:Connect(function() close();option[2]() end)
 end
 player:SetAttribute("MedicalMode",nil);player:SetAttribute("PlayerContextOpen",true);gui.Enabled=true
end
Context:BindActionAtPriority("PlayerContextMenu",function(_,state)
 if state~=Enum.UserInputState.Begin then return gui.Enabled and Enum.ContextActionResult.Sink or Enum.ContextActionResult.Pass end
 if blocked() then close();return Enum.ContextActionResult.Pass end
 local kind,value=target();local c=player.Character
 local options={}
 if c:GetAttribute("CarryingUserId") then
  if kind=="Bed" and not value:GetAttribute("HospitalBedUserId") then table.insert(options,{"Place on bed",function() remote:FireServer("Bed",value) end}) end
  table.insert(options,{"Put body down",function() remote:FireServer("Drop") end})
 elseif kind=="Patient" then
  options={{"Apply medicine",function() player:SetAttribute("MedicalMode","Bandage");inventory:FireServer("ReadyMedicine",true) end},{"Doctor",function() medical:FireServer("Doctor",value) end},{"Loot player",function() remote:FireServer("Loot",value) end},{"Pick up player",function() remote:FireServer("Carry",value) end}}
 elseif kind=="Corpse" then options={{"Search body",function() inventory:FireServer("OpenChest",value) end}} end
 if #options==0 then close();return Enum.ContextActionResult.Pass end
 show(options,kind=="Patient" and value or nil);return Enum.ContextActionResult.Sink
end,false,Enum.ContextActionPriority.High.Value+30,Enum.UserInputType.MouseButton2)
overlay.Activated:Connect(close)
Input.InputBegan:Connect(function(input) if input.KeyCode==Enum.KeyCode.Escape then close() end end)
Input.WindowFocusReleased:Connect(close)
player.CharacterRemoving:Connect(close)
player:GetAttributeChangedSignal("InventoryOpen"):Connect(function() if player:GetAttribute("InventoryOpen") then close() end end)

game:GetService("RunService").Heartbeat:Connect(function()
 if gui.Enabled and blocked() then close();return end
 if gui.Enabled and examined then
  if not examined.Character or not examined.Character:GetAttribute("Knockout") then close();return end
  local status=Examination.Text(examined)
  if (status~=nil)~=exam.Visible then close();return end
  exam.Text=status or ""
 end
end)
