local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Input=game:GetService("UserInputService")
local Theme=require(ReplicatedStorage.Shared.UITheme)
local Items=require(ReplicatedStorage.Shared.ItemConfig).Items
local player=Players.LocalPlayer
local remote=ReplicatedStorage:WaitForChild("TradeRemotes")
local action=remote:WaitForChild("Action")
local gui=Instance.new("ScreenGui");gui.Name="TradeUI";gui.ResetOnSpawn=false;gui.DisplayOrder=40;gui.Enabled=false;gui.Parent=player:WaitForChild("PlayerGui")
local window=Instance.new("Frame");window.AnchorPoint=Vector2.new(.5,.5);window.Position=UDim2.fromScale(.5,.5);window.Size=UDim2.fromScale(.86,.8);window.BackgroundColor3=Theme.Panel;window.Parent=gui;Theme.Bevel(window)
local function text(parent,caption,position,size)
 local t=Instance.new("TextLabel");t.BackgroundTransparency=1;t.Text=caption;t.TextColor3=Theme.Text;t.Font=Theme.Font;t.TextSize=15;t.TextWrapped=true;t.TextXAlignment=Enum.TextXAlignment.Left;t.Position=position;t.Size=size;t.Parent=parent;return t
end
local function button(parent,caption,position,size,callback)
 local b=Instance.new("TextButton");b.BackgroundColor3=Theme.Button;b.TextColor3=Theme.Text;b.Font=Theme.Font;b.TextSize=14;b.Text=caption;b.Position=position;b.Size=size;b.Parent=parent;Theme.Bevel(b);b.Activated:Connect(callback);return b
end
local function input(parent,value,position,size)
 local t=Instance.new("TextBox");t.Text=tostring(value);t.ClearTextOnFocus=false;t.BackgroundColor3=Theme.Card;t.TextColor3=Theme.Text;t.Font=Theme.Font;t.TextSize=16;t.Position=position;t.Size=size;t.Parent=parent;return t
end
local title=text(window,"Trade post",UDim2.fromOffset(16,10),UDim2.new(1,-230,0,32))
local balance=text(window,"$0",UDim2.new(1,-220,0,10),UDim2.fromOffset(160,32))
local snapshot
local function close() gui.Enabled=false;player:SetAttribute("TradeOpen",false);action:FireServer("Close") end
button(window,"×",UDim2.new(1,-48,0,10),UDim2.fromOffset(32,32),close)
text(window,"Quantity:",UDim2.fromOffset(16,53),UDim2.fromOffset(90,30))
local amount=input(window,1,UDim2.fromOffset(108,53),UDim2.fromOffset(90,30))
local controls=Instance.new("Frame");controls.Position=UDim2.fromOffset(218,53);controls.Size=UDim2.new(1,-234,0,32);controls.BackgroundTransparency=1;controls.Parent=window
local message=text(window,"",UDim2.fromOffset(16,92),UDim2.new(1,-32,0,36))
local function column(x,width)
 local frame=Instance.new("ScrollingFrame");frame.Position=UDim2.new(x,16,0,138);frame.Size=UDim2.new(width,-24,1,-154);frame.BackgroundColor3=Theme.Card;frame.ScrollBarThickness=6;frame.AutomaticCanvasSize=Enum.AutomaticSize.Y;frame.CanvasSize=UDim2.new();frame.Parent=window
 local layout=Instance.new("UIListLayout");layout.SortOrder=Enum.SortOrder.LayoutOrder;layout.Padding=UDim.new(0,8);layout.Parent=frame;return frame
end
local inventory,stock=column(0,.42),column(.42,.58)
local function clear(frame) for _,child in ipairs(frame:GetChildren()) do if not child:IsA("UIListLayout") then child:Destroy() end end end
local function quantity() local n=tonumber(amount.Text);return n and n==math.floor(n) and n>=1 and n<math.huge and n or 1 end
local function send(command,key,count) action:FireServer(command,key,count) end
local function name(stack)
 local caption=(Items[stack.ID] and Items[stack.ID].Name or stack.ID).." ×"..stack.Count
 if stack.Condition then caption..=" · condition "..stack.Condition end
 if stack.Loaded then caption..=" · "..stack.Loaded.." "..(stack.AmmoType or "FMJ") end
 return caption
end
local function card(parent,height)
 local c=Instance.new("Frame");c.Size=UDim2.new(1,-8,0,height);c.BackgroundColor3=Theme.Panel;c.LayoutOrder=#parent:GetChildren();c.Parent=parent;Theme.Bevel(c);return c
end
local function render()
 clear(inventory);clear(stock);clear(controls)
 local owner=snapshot.OwnerID==player.UserId
 title.Text="Trade post · "..(owner and "your shop" or snapshot.OwnerID>0 and snapshot.OwnerName or snapshot.Inherited and "reserved for the mayor" or "vacant")
 balance.Text="$"..tostring(player:GetAttribute("Money") or snapshot.Money or 0)
 message.Text=snapshot.Message or (owner and ("Tax: $"..snapshot.Tax.." per seller every 5 minutes. Prices are per item.") or "Anyone may buy. Only citizens may claim a vacant post.")
 if snapshot.CanClaim then button(controls,"Claim post",UDim2.new(),UDim2.fromOffset(160,30),function() send("Claim") end) end
 if owner then button(controls,"Release empty post",UDim2.new(),UDim2.fromOffset(200,30),function() send("Release") end) end
 text(inventory,owner and "Your inventory" or "Shop",UDim2.new(),UDim2.new(1,-8,0,30))
 if not owner then text(inventory,"Choose a quantity above, then buy from the listed stock.\n\nNo item can be sold to this post.",UDim2.new(),UDim2.new(1,-8,0,100)) end
 for _,stack in ipairs(snapshot.Inventory or {}) do
  if Items[stack.ID] and not Items[stack.ID].Currency then
   local c=card(inventory,100);text(c,name(stack),UDim2.fromOffset(8,4),UDim2.new(1,-16,0,48))
   button(c,"Put",UDim2.fromOffset(8,58),UDim2.new(.5,-12,0,30),function() send("Put",stack.Key,quantity()) end)
   button(c,"Put all",UDim2.new(.5,4,0,58),UDim2.new(.5,-12,0,30),function() send("Put",stack.Key,"All") end)
  end
 end
 text(stock,"Stock · price for one item",UDim2.new(),UDim2.new(1,-8,0,30))
 if #(snapshot.Stock or {})==0 then text(stock,"No goods yet.",UDim2.new(),UDim2.new(1,-8,0,40)) end
 for _,stack in ipairs(snapshot.Stock or {}) do
  local c=card(stock,owner and 150 or 100)
  text(c,name(stack)..(stack.Price>0 and ("\n$"..stack.Price.." each") or "\nPrice not set — not for sale"),UDim2.fromOffset(8,4),UDim2.new(1,-16,0,50))
  if owner then
   button(c,"Take",UDim2.fromOffset(8,58),UDim2.new(.5,-12,0,30),function() send("Take",stack.Key,quantity()) end)
   button(c,"Take all",UDim2.new(.5,4,0,58),UDim2.new(.5,-12,0,30),function() send("Take",stack.Key,"All") end)
   local price=input(c,math.max(1,stack.Price),UDim2.fromOffset(50,105),UDim2.fromOffset(90,30))
   button(c,"−",UDim2.fromOffset(8,105),UDim2.fromOffset(32,30),function() send("Price",stack.Key,math.max(1,(tonumber(price.Text) or 1)-1)) end)
   button(c,"+",UDim2.fromOffset(150,105),UDim2.fromOffset(32,30),function() send("Price",stack.Key,(tonumber(price.Text) or 1)+1) end)
   button(c,"Set price",UDim2.fromOffset(192,105),UDim2.new(1,-204,0,30),function() send("Price",stack.Key,tonumber(price.Text)) end)
  else
   local buy=button(c,"Buy",UDim2.fromOffset(8,58),UDim2.new(1,-16,0,30),function() if stack.Price>0 then send("Buy",stack.Key,quantity()) end end)
   buy.Active=stack.Price>0;buy.TextTransparency=stack.Price>0 and 0 or .5
  end
 end
end
remote.State.OnClientEvent:Connect(function(value)
 snapshot=value;gui.Enabled=value.Open==true;player:SetAttribute("TradeOpen",gui.Enabled)
 if gui.Enabled then render() end
end)
player:GetAttributeChangedSignal("Money"):Connect(function() balance.Text="$"..tostring(player:GetAttribute("Money") or 0) end)
player.CharacterAdded:Connect(close)
Input.InputBegan:Connect(function(key,processed) if not processed and gui.Enabled and not Input:GetFocusedTextBox() and (key.KeyCode==Enum.KeyCode.Q or key.KeyCode==Enum.KeyCode.Escape) then close() end end)
