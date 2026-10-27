local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Context=game:GetService("ContextActionService")
local Run=game:GetService("RunService")
local player=Players.LocalPlayer
local Theme=require(ReplicatedStorage.Shared.UITheme)
local Layout=require(script.Parent.HUDLayout)
local remote=ReplicatedStorage:WaitForChild("HelpPreference")
local function make(class,parent,props)
 local object=Instance.new(class)
 for key,value in pairs(props) do object[key]=value end
 object.Parent=parent;return object
end
local function label(parent,text,position,size,textSize)
 return make("TextLabel",parent,{Text=text,Position=position,Size=size,BackgroundTransparency=1,
  Font=Theme.Font,TextSize=textSize or 15,TextColor3=Theme.Text,TextWrapped=true,
  TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top})
end
local function button(parent,text,position,size)
 local object=make("TextButton",parent,{Text=text,Position=position,Size=size,
  BackgroundColor3=Theme.Button,TextColor3=Theme.Text,Font=Theme.Font,TextSize=15})
 Theme.Bevel(object);return object
end
local gui=make("ScreenGui",player:WaitForChild("PlayerGui"),{Name="HowToPlay",ResetOnSpawn=false,DisplayOrder=80,Enabled=false})
local overlay=make("TextButton",gui,{Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.new(),
 BackgroundTransparency=.35,Text="",AutoButtonColor=false,Modal=true,Selectable=false})
local panel=make("Frame",overlay,{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),
 Size=UDim2.fromOffset(660,540),BackgroundColor3=Theme.Panel})
Theme.Bevel(panel)
local scale=make("UIScale",panel,{Scale=1})
label(panel,"HOW TO PLAY",UDim2.fromOffset(24,18),UDim2.fromOffset(550,32),24).TextColor3=Theme.Accent
label(panel,"Build a home. Find your role. Survive together.",UDim2.fromOffset(24,57),UDim2.fromOffset(610,30),14)
local close=button(panel,"X",UDim2.new(1,-52,0,18),UDim2.fromOffset(28,28))
local scroll=make("ScrollingFrame",panel,{Position=UDim2.fromOffset(24,100),Size=UDim2.new(1,-48,1,-205),
 BackgroundColor3=Theme.Card,BorderSizePixel=0,ScrollBarThickness=5,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y})
make("UIPadding",scroll,{PaddingTop=UDim.new(0,12),PaddingBottom=UDim.new(0,12),PaddingLeft=UDim.new(0,14),PaddingRight=UDim.new(0,18)})
make("UIListLayout",scroll,{Padding=UDim.new(0,14),SortOrder=Enum.SortOrder.LayoutOrder})
local sections={
 {"CONTROLS","WASD: Move   |   Shift: Run   |   Mouse: Face / aim\nLMB: Attack   |   RMB: Aim   |   E: Interact\nQ: Inventory / close container   |   C: Character   |   T: Skills\nR: Reload   |   V: Fire mode   |   B: Ammo type\nMouse wheel: Zoom   |   Hold MMB + move mouse: Rotate camera"},
 {"1. CHOOSE YOUR TOWN","Join a town at a flag. Cooperate with its residents, build your home and watch your relations with other towns."},
 {"2. FIND SUPPLIES","Collect food, water and materials. Open your inventory, select an item to inspect it, equip it or consume it. Carrying too much slows you down."},
 {"3. CRAFT AND BUILD","Press E near a workstation to see recipes and their requirements. Help develop your town; construction may require the mayor's approval."},
 {"4. STAY ALIVE","Watch your health, hunger, thirst and energy. Keep useful equipment ready. Zombies and hostile players can kill you, and your belongings can be looted."},
 {"5. DEVELOP YOUR CHARACTER","Use skills to improve them. Open Character [C] and Skills [T] to inspect your stats, spend available points and choose perks."},
}
for index,section in ipairs(sections) do
 local row=make("Frame",scroll,{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,LayoutOrder=index})
 make("UIListLayout",row,{Padding=UDim.new(0,6),SortOrder=Enum.SortOrder.LayoutOrder})
 local title=label(row,section[1],UDim2.new(),UDim2.new(1,0,0,22),16);title.LayoutOrder=1;title.TextColor3=Theme.Accent
 local body=label(row,section[2],UDim2.new(),UDim2.new(1,0,0,0),14);body.LayoutOrder=2;body.AutomaticSize=Enum.AutomaticSize.Y
end
local check=button(panel,"[ ]  Don't show on login",UDim2.new(0,24,1,-87),UDim2.fromOffset(380,30))
check.TextXAlignment=Enum.TextXAlignment.Left
local done=button(panel,"Got it",UDim2.new(1,-144,1,-87),UDim2.fromOffset(120,34))
local notice=label(panel,"",UDim2.new(0,24,1,-43),UDim2.new(1,-48,0,30),12)
local help=button(Layout.Bar,"?",UDim2.fromOffset(984,6),UDim2.fromOffset(24,28))
help.Name="HowToPlayButton"
local function refreshPreference()
 check.Text=(player:GetAttribute("HelpHidden") and "[X]" or "[ ]").."  Don't show on login"
 local ready=player:GetAttribute("HelpPreferenceReady")==true
 check.Active=ready;check.AutoButtonColor=ready
 local state=player:GetAttribute("HelpPreferenceStatus")
 notice.Text=not ready and "Loading preference..." or state=="Saving" and "Saving preference..."
  or state=="Failed" and "Could not save. Click the checkbox to retry."
  or state=="LoadFailed" and "Could not load preference. Help is shown for this visit."
  or "You can always open this guide with the ? button."
 notice.TextColor3=(state=="Failed" or state=="LoadFailed") and Theme.Danger or Theme.Muted
end
check.Activated:Connect(function()
 if not check.Active then return end
 remote:FireServer(player:GetAttribute("HelpPreferenceStatus")=="Failed" and player:GetAttribute("HelpHidden")==true or
  player:GetAttribute("HelpPreferenceStatus")~="Failed" and player:GetAttribute("HelpHidden")~=true)
end)
for _,name in ipairs({"HelpHidden","HelpPreferenceReady","HelpPreferenceStatus"}) do player:GetAttributeChangedSignal(name):Connect(refreshPreference) end
refreshPreference()
local shown=false
local function setOpen(value)
 if value then shown=true end
 gui.Enabled=value;player:SetAttribute("HelpOpen",value)
 if value then
  player:SetAttribute("MedicalMode",nil)
  Context:BindActionAtPriority("HelpBlockInput",function() return Enum.ContextActionResult.Sink end,false,Enum.ContextActionPriority.High.Value+10,
   Enum.PlayerActions.CharacterForward,Enum.PlayerActions.CharacterBackward,Enum.PlayerActions.CharacterLeft,Enum.PlayerActions.CharacterRight,Enum.PlayerActions.CharacterJump,
   Enum.KeyCode.Q,Enum.KeyCode.E,Enum.KeyCode.C,Enum.KeyCode.T,Enum.KeyCode.G,Enum.KeyCode.H,Enum.KeyCode.R,Enum.KeyCode.V,Enum.KeyCode.B,Enum.KeyCode.F6)
  Run:BindToRenderStep("HelpStopMovement",Enum.RenderPriority.Camera.Value+4,function()
   local character=player.Character
   local humanoid=character and character:FindFirstChildOfClass("Humanoid")
   if humanoid then humanoid:Move(Vector3.zero,false) end
  end)
 else Context:UnbindAction("HelpBlockInput");Run:UnbindFromRenderStep("HelpStopMovement") end
end
local function busy()
 for _,name in ipairs({"LoadingScreenOpen","TownMenuOpen","ProgressionOpen","InventoryOpen","TradeOpen","GroupOpen","AdminOpen","FarmMenuOpen","CharacterLoading"}) do
  if player:GetAttribute(name) then return true end
 end
 return false
end
close.Activated:Connect(function() setOpen(false) end)
done.Activated:Connect(function() setOpen(false) end)
help.Activated:Connect(function() if gui.Enabled then setOpen(false) elseif not busy() then setOpen(true) end end)
Run.RenderStepped:Connect(function()
 if not gui.Enabled then return end
 local camera=workspace.CurrentCamera
 if camera then scale.Scale=math.min(1,(camera.ViewportSize.X-24)/660,(camera.ViewportSize.Y-24)/540) end
end)
task.spawn(function()
 -- Show once per login, after the splash and mandatory character creation screens.
 repeat task.wait(.2) until player:GetAttribute("HelpPreferenceReady")==true
 if player:GetAttribute("HelpHidden") or shown then return end
 repeat task.wait(.2) until not busy() and player.Character and player:GetAttribute("AttributesConfirmed")==true
 if not player:GetAttribute("HelpHidden") and not shown then setOpen(true) end
end)
