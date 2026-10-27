local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Context=game:GetService("ContextActionService")
local Run=game:GetService("RunService")
local TextService=game:GetService("TextService")
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
-- Fixed logical dimensions keep text measurement and scrolling independent of UIScale.
local PANEL_WIDTH,PANEL_HEIGHT=900,620
local CONTENT_WIDTH=656
local BODY_WIDTH=CONTENT_WIDTH-40
local panel=make("Frame",overlay,{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),
 Size=UDim2.fromOffset(PANEL_WIDTH,PANEL_HEIGHT),BackgroundColor3=Theme.Panel})
Theme.Bevel(panel)
local scale=make("UIScale",panel,{Scale=1})
label(panel,"HOW TO PLAY",UDim2.fromOffset(24,18),UDim2.fromOffset(800,32),24).TextColor3=Theme.Accent
label(panel,"Build a home. Find your role. Write your own story.",UDim2.fromOffset(24,57),UDim2.fromOffset(820,30),14)
local close=button(panel,"X",UDim2.new(1,-52,0,18),UDim2.fromOffset(28,28))
local navigation=make("Frame",panel,{Name="HelpTabs",Position=UDim2.fromOffset(24,100),
 Size=UDim2.new(0,180,1,-210),BackgroundColor3=Theme.Card,BorderSizePixel=0})
local page=make("Frame",panel,{Name="HelpPage",Position=UDim2.fromOffset(220,100),
 Size=UDim2.new(0,CONTENT_WIDTH,1,-210),BackgroundColor3=Theme.Card,BorderSizePixel=0})
local heading=label(page,"",UDim2.fromOffset(18,14),UDim2.new(1,-40,0,30),20)
heading.Name="PageHeading";heading.TextColor3=Theme.Accent
local scroll=make("ScrollingFrame",page,{Name="HelpScroll",Position=UDim2.fromOffset(0,54),Size=UDim2.new(1,0,1,-54),
 BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=7,ScrollBarImageColor3=Theme.Accent,
 ScrollingDirection=Enum.ScrollingDirection.Y,VerticalScrollBarInset=Enum.ScrollBarInset.Always,
 Active=true,ClipsDescendants=true,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.None})
local body=label(scroll,"",UDim2.fromOffset(18,0),UDim2.fromOffset(BODY_WIDTH,0),16)
body.Name="PageBody"
local pages={
 {Name="Controls",Title="CONTROLS",Text=[[MOVEMENT
WASD - Move
Shift - Run
Mouse - Face / aim

COMBAT
LMB - Attack
RMB - Aim
R - Reload
V - Change fire mode
B - Change ammunition type

INTERACTION & MENUS
E - Interact
Q - Inventory / close container
C - Character and attributes
T - Skills and perks
G - Group
H - Use an equipped bandage
4 - Doctor: click a nearby knocked-out player to try to revive them. Press 4 again to cancel.

CAMERA
Mouse wheel - Zoom
Hold MMB and move the mouse - Rotate camera]]},
 {Name="Getting started\n& builds",Title="GETTING STARTED & BUILDS",Text=[[Before you begin, take a good look at the available skills, perks and attributes. A thoughtful combination can make your life a lot more comfortable.

Your role will usually be a specialized one. You cannot be everyone at once. The development paths currently available are:

- Crafter
- Doctor
- Cook
- Farmer
- Resource gatherer
- Melee fighter
- Ranged fighter

Of course, you can mix in a few skills for convenience and greater independence. Just remember: every point spent on a side job is a point you are not putting into your main specialty.

If you plan to build a workshop, a hospital or another specialist building, check its requirements BEFORE spending your skill points.]]},
 {Name="Society",Title="SOCIETY",Text=[[THE MAYOR
The first player in a town becomes its mayor. Residents can elect a replacement: approach the town flag and choose the relevant voting option.

YOUR STORY
Your actions are a mirror of your soul. Do what you need to do: play a raider, or become someone your community can rely on. Your in-game choices are yours to make. You write your own story.

TOWN LIFE
While there is only one town in the game, the mayor has no other towns to conduct foreign policy with. Inside the town, however, the mayor decides which buildings get approved and which do not.

PLAN BEFORE YOU BUILD
If you want a workshop, a hospital or something similar, read the requirements first and only then allocate your skills. A poor build means grinding more levels - or leaving for 10-15 minutes so the server has time to clear your character after reconnect protection expires.

Reconnect protection is there to save your character if you lose your connection.

A LITTLE MEDICAL ADVICE
If you find someone's body, take a moment to try your Doctor skill with 4: activate it, then click the nearby knocked-out player. You might save someone a lot of time and earn a pleasant "Thank you!"

If they are from another settlement... well, you could always wait out the two-minute knockout and loot them instead.

Patience and looting solve a surprising number of problems.]]},
 {Name="Resources",Title="RESOURCES",Text=[[YES, IT STARTS WITH TREES
Sorry I could not think of a better opening than chopping wood. Cliche? Absolutely. Guilty as charged. I will come up with something better later.

For now, a good start is to send your strongest resident to chop trees for the town. Send your fastest resident to loot buildings and haul everything back to the settlement.

WANT TO MAKE SOME MONEY?
Build a Market - it is a free town building - and sell your resources there.

Keep in mind that passive income is $1 x player level per payout. That very important crafter might not have any money at the start...

Help the people who know how to make things, and they will help you.]]},
}
local tabs={}
local function setPage(index)
 local selected=pages[index]
 heading.Text=selected.Title;body.Text=selected.Text
 -- Measure wrapped text at its actual logical width instead of nesting automatic
 -- canvas sizing and automatic row heights (which produced the broken scrollbar).
 local bounds=TextService:GetTextSize(selected.Text,body.TextSize,body.Font,Vector2.new(BODY_WIDTH,100000))
 body.Size=UDim2.fromOffset(BODY_WIDTH,math.ceil(bounds.Y)+4)
 scroll.CanvasSize=UDim2.fromOffset(0,math.ceil(bounds.Y)+24)
 scroll.CanvasPosition=Vector2.zero
 for tabIndex,tab in ipairs(tabs) do
  tab.TextColor3=tabIndex==index and Theme.Accent or Theme.Text
  tab.BackgroundColor3=tabIndex==index and Theme.Button or Theme.Card
  tab:SetAttribute("Selected",tabIndex==index)
 end
end
for index,entry in ipairs(pages) do
 local tab=button(navigation,entry.Name,UDim2.fromOffset(8,8+(index-1)*62),UDim2.fromOffset(164,54))
 tab.Name="HelpTab"..index;tab.TextWrapped=true;tabs[index]=tab
 tab.Activated:Connect(function() setPage(index) end)
end
setPage(1)
local check=button(panel,"[ ]  Don't show on login",UDim2.new(0,24,1,-87),UDim2.fromOffset(380,34))
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
 if value then shown=true;setPage(1) end
 gui.Enabled=value;player:SetAttribute("HelpOpen",value)
 if value then
  player:SetAttribute("MedicalMode",nil)
  Context:BindActionAtPriority("HelpBlockInput",function() return Enum.ContextActionResult.Sink end,false,Enum.ContextActionPriority.High.Value+10,
   Enum.PlayerActions.CharacterForward,Enum.PlayerActions.CharacterBackward,Enum.PlayerActions.CharacterLeft,Enum.PlayerActions.CharacterRight,Enum.PlayerActions.CharacterJump,
   Enum.KeyCode.Q,Enum.KeyCode.E,Enum.KeyCode.C,Enum.KeyCode.T,Enum.KeyCode.G,Enum.KeyCode.H,Enum.KeyCode.R,Enum.KeyCode.V,Enum.KeyCode.B,Enum.KeyCode.F6,Enum.KeyCode.Four,Enum.KeyCode.KeypadFour)
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
 if camera then scale.Scale=math.min(1,(camera.ViewportSize.X-24)/PANEL_WIDTH,(camera.ViewportSize.Y-24)/PANEL_HEIGHT) end
end)
task.spawn(function()
 -- Show once per login, after the splash and mandatory character creation screens.
 repeat task.wait(.2) until player:GetAttribute("HelpPreferenceReady")==true
 if player:GetAttribute("HelpHidden") or shown then return end
 repeat task.wait(.2) until not busy() and player.Character and player:GetAttribute("AttributesConfirmed")==true
 if not player:GetAttribute("HelpHidden") and not shown then setOpen(true) end
end)
