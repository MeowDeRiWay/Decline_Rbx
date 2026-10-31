local Players=game:GetService("Players")
local Replicated=game:GetService("ReplicatedStorage")
local Input=game:GetService("UserInputService")
local Locale=require(script.Parent.LocaleController)
local Theme=require(Replicated.Shared.UITheme)
local Items=require(Replicated.Shared.ItemConfig).Items
local player=Players.LocalPlayer
local remote=Replicated:WaitForChild("PlayerExchangeRemotes")
local action=remote:WaitForChild("Action")
local gui=Instance.new("ScreenGui");gui.Name="PlayerExchangeUI";gui.ResetOnSpawn=false;gui.DisplayOrder=45;gui.Enabled=false;gui.Parent=player:WaitForChild("PlayerGui")
local window=Instance.new("Frame");window.AnchorPoint=Vector2.new(.5,.5);window.Position=UDim2.fromScale(.5,.5);window.Size=UDim2.fromScale(.88,.78);window.BackgroundColor3=Theme.Panel;window.Parent=gui;Theme.Bevel(window)
local function text(parent,value,pos,size)
 local t=Instance.new("TextLabel");t.BackgroundTransparency=1;t.Text=value;t.TextColor3=Theme.Text;t.Font=Theme.Font;t.TextSize=14;t.TextWrapped=true;t.TextXAlignment=Enum.TextXAlignment.Left;t.Position=pos;t.Size=size;t.Parent=parent;return t
end
local function button(parent,value,pos,size,callback)
 local b=Instance.new("TextButton");b.Text=value;b.BackgroundColor3=Theme.Button;b.TextColor3=Theme.Text;b.Font=Theme.Font;b.TextSize=14;b.TextWrapped=true;b.Position=pos;b.Size=size;b.Parent=parent;Theme.Bevel(b);b.Activated:Connect(callback);return b
end
local function input(value,pos,size)
 local t=Instance.new("TextBox");t.Text=tostring(value);t.ClearTextOnFocus=false;t.BackgroundColor3=Theme.Card;t.TextColor3=Theme.Text;t.Font=Theme.Font;t.TextSize=16;t.Position=pos;t.Size=size;t.Parent=window;return t
end
local snapshot
local function send(command,key,count) if snapshot then action:FireServer(command,snapshot.ID,key,count) end end
local function hide() gui.Enabled=false;player:SetAttribute("ExchangeOpen",false);snapshot=nil end
local function cancel() send("Cancel");hide() end
local title=text(window,"Exchange",UDim2.fromOffset(16,8),UDim2.new(1,-72,0,34))
button(window,"×",UDim2.new(1,-48,0,10),UDim2.fromOffset(32,32),cancel)
local message=text(window,"",UDim2.fromOffset(16,47),UDim2.new(1,-32,0,44))
local moneyLabel=text(window,"Your money: $0",UDim2.fromOffset(16,93),UDim2.new(.35,-20,0,28))
local cash=input(0,UDim2.new(.35,0,0,93),UDim2.new(.17,-8,0,28))
local setCash=button(window,"Offer money",UDim2.new(.52,0,0,93),UDim2.new(.2,-8,0,28),function() local n=tonumber(cash.Text);if n then send("Cash",n) end end)
local quantityLabel=text(window,"Quantity:",UDim2.new(.72,0,0,93),UDim2.new(.14,-8,0,28))
local amount=input(1,UDim2.new(.86,0,0,93),UDim2.new(.14,-16,0,28))
local headings={}
local columns={}
for i,caption in ipairs({"Your pockets","Your offer","Their offer"}) do
 headings[i]=text(window,caption,UDim2.new((i-1)/3,16,0,130),UDim2.new(1/3,-24,0,30))
 local f=Instance.new("ScrollingFrame");f.Position=UDim2.new((i-1)/3,16,0,164);f.Size=UDim2.new(1/3,-24,1,-232);f.BackgroundColor3=Theme.Card;f.ScrollBarThickness=5;f.AutomaticCanvasSize=Enum.AutomaticSize.Y;f.CanvasSize=UDim2.new();f.Parent=window
 local layout=Instance.new("UIListLayout");layout.Padding=UDim.new(0,6);layout.SortOrder=Enum.SortOrder.LayoutOrder;layout.Parent=f;columns[i]=f
end
local function quantity() local n=tonumber(amount.Text);return n and n>=1 and n<math.huge and n==math.floor(n) and n or 1 end
local function caption(stack)
 local s=(Items[stack.ID] and Items[stack.ID].Name or stack.ID).." ×"..stack.Count
 if stack.Condition then s..=" · condition "..stack.Condition end
 if stack.Loaded and stack.Loaded>0 then s..=" · "..stack.Loaded.." "..(stack.AmmoType or "FMJ") end
 return s
end
local confirm
local function updateConfirm()
 if not snapshot then return end
 local invite=snapshot.Phase=="Invite"
 local ready=workspace:GetServerTimeNow()>=(snapshot.ConfirmAt or 0)
 confirm.Visible=not invite or snapshot.Incoming
 confirm.Active=invite or ready and not snapshot.Confirmed
 confirm.Text=invite and "Accept exchange" or snapshot.Confirmed and "Waiting for partner" or ready and "Confirm exchange" or "Review the offer..."
 confirm.TextTransparency=confirm.Active and 0 or .5
end
confirm=button(window,"Confirm exchange",UDim2.new(0,16,1,-52),UDim2.new(.7,-24,0,36),function()
 if not snapshot then return end
 if snapshot.Phase=="Invite" then send("Join")
 elseif not snapshot.Confirmed and workspace:GetServerTimeNow()>=(snapshot.ConfirmAt or 0) then send("Confirm",snapshot.Revision) end
end)
button(window,"Cancel",UDim2.new(.7,8,1,-52),UDim2.new(.3,-24,0,36),cancel)
local function render()
 local invite=snapshot.Phase=="Invite"
 title.Text="Exchange with "..Locale.Raw(snapshot.PartnerName)
 message.Text=snapshot.Message or (invite and (snapshot.Incoming and "You have been invited to exchange. Accept to review the offers." or "Waiting for the other player to accept.") or snapshot.OtherConfirmed and "Partner confirmed. Any offer change resets both confirmations." or "Review both offers, then confirm. Any change resets both confirmations.")
 moneyLabel.Text=player:GetAttribute("MoneyReady")==false and "Your money: $…" or "Your money: $"..(player:GetAttribute("Money") or snapshot.Money or 0)
 if not cash:IsFocused() then cash.Text=tostring(snapshot.Cash) end
 cash.Visible=not invite;setCash.Visible=not invite;amount.Visible=not invite;quantityLabel.Visible=not invite
 headings[2].Text="Your offer · $"..snapshot.Cash;headings[3].Text="Their offer · $"..snapshot.OtherCash
 for i,column in ipairs(columns) do
  column.Visible=not invite;headings[i].Visible=not invite
  for _,child in ipairs(column:GetChildren()) do if not child:IsA("UIListLayout") then child:Destroy() end end
 end
 if not invite then
  local offered={};for _,stack in ipairs(snapshot.Offer) do offered[stack.Key]=stack.Count end
  for i,list in ipairs({snapshot.Inventory,snapshot.Offer,snapshot.OtherOffer}) do
   for index,stack in ipairs(list) do
    local item=Items[stack.ID]
    if item and item.Lootable~=false then
     local c=Instance.new("Frame");c.Size=UDim2.new(1,-6,0,i==3 and 64 or 104);c.BackgroundColor3=Theme.Panel;c.LayoutOrder=index;c.Parent=columns[i];Theme.Bevel(c)
     text(c,caption(stack),UDim2.fromOffset(6,4),UDim2.new(1,-12,0,54))
     if i==1 then button(c,"Add to offer",UDim2.fromOffset(6,64),UDim2.new(1,-12,0,30),function() send("Offer",stack.Key,math.min(stack.Count,(offered[stack.Key] or 0)+quantity())) end)
     elseif i==2 then button(c,"Remove from offer",UDim2.fromOffset(6,64),UDim2.new(1,-12,0,30),function() send("Offer",stack.Key,math.max(0,stack.Count-quantity())) end) end
    end
   end
  end
 end
 updateConfirm()
end
local modals={"TradeOpen","InventoryOpen","TownMenuOpen","ProgressionOpen","GroupOpen","AdminOpen","FarmMenuOpen","HelpOpen","MapOpen","OutcastEnd"}
local function otherOpen() for _,key in ipairs(modals) do if player:GetAttribute(key) then return true end end;return false end
remote.State.OnClientEvent:Connect(function(value)
 if not value.Open then hide();return end
 snapshot=value
 if otherOpen() then cancel();return end
 player:SetAttribute("MedicalMode",nil);player:SetAttribute("PlayerContextOpen",false)
 player:SetAttribute("ExchangeOpen",true);gui.Enabled=true;render()
end)
for _,key in ipairs(modals) do player:GetAttributeChangedSignal(key):Connect(function() if gui.Enabled and otherOpen() then cancel() end end) end
player:GetAttributeChangedSignal("Money"):Connect(function() if gui.Enabled and snapshot then render() end end)
player:GetAttributeChangedSignal("MoneyReady"):Connect(function() if gui.Enabled and snapshot then render() end end)
player.CharacterRemoving:Connect(cancel)
Input.InputBegan:Connect(function(key,processed)
 if not processed and gui.Enabled and not Input:GetFocusedTextBox() and (key.KeyCode==Enum.KeyCode.Q or key.KeyCode==Enum.KeyCode.Escape) then cancel() end
end)
task.spawn(function() while true do task.wait(.2);if gui.Enabled then updateConfirm() end end end)
