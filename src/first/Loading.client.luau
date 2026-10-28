-- A short opening splash, independent of world generation or character spawning.
local Players=game:GetService("Players")
local First=game:GetService("ReplicatedFirst")
local Content=game:GetService("ContentProvider")
local Tween=game:GetService("TweenService")
local player=Players.LocalPlayer
local gui=Instance.new("ScreenGui")
gui.AutoLocalize=false
gui.Name="DeclineLoading";gui.IgnoreGuiInset=true;gui.ResetOnSpawn=false;gui.DisplayOrder=1000
local function make(class,parent,props)
 local o=Instance.new(class)
 for key,value in pairs(props) do o[key]=value end
 o.Parent=parent;return o
end
local background=make("CanvasGroup",gui,{Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.fromRGB(18,19,16),BorderSizePixel=0})
make("TextButton",background,{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Text="",AutoButtonColor=false,Selectable=false})
local picture=make("ImageLabel",background,{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,ImageTransparency=1,ScaleType=Enum.ScaleType.Fit,Image=""})
local fallback=make("TextLabel",background,{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Text="DECLINE",TextTransparency=1,TextColor3=Color3.fromRGB(178,195,126),Font=Enum.Font.RobotoMono,TextSize=48})
gui.Parent=player:WaitForChild("PlayerGui")
First:RemoveDefaultLoadingScreen()
player:SetAttribute("LoadingScreenOpen",true)
local choices={}
local folder=First:WaitForChild("SplashImages",5)
if folder then
 for _,entry in ipairs(folder:GetChildren()) do
  if entry:IsA("StringValue") and string.match(entry.Name,"^Splash%d+$") then
   local id=string.match(entry.Value,"^%s*(%d+)%s*$") or string.match(entry.Value,"^%s*rbxassetid://(%d+)%s*$")
   if id and tonumber(id) and tonumber(id)>0 then table.insert(choices,"rbxassetid://"..id) end
  end
 end
end
local ready=false
if #choices>0 then
 local selected=choices[Random.new():NextInteger(1,#choices)]
 local finished=false
 local succeeded=false
 -- Only preload the selected picture, with a bounded wait for unavailable assets.
 task.spawn(function()
  local ok=pcall(function()
   Content:PreloadAsync({selected},function(_,status) succeeded=status==Enum.AssetFetchStatus.Success end)
  end)
  succeeded=ok and succeeded;finished=true
 end)
 local deadline=os.clock()+5
 while not finished and os.clock()<deadline do task.wait(.05) end
 ready=finished and succeeded
 if ready then picture.Image=selected end
end
local visible=ready and picture or fallback
local property=ready and "ImageTransparency" or "TextTransparency"
local appear=Tween:Create(visible,TweenInfo.new(.45),{[property]=0})
appear:Play();appear.Completed:Wait()
-- Three full seconds after the image is available and the fade-in has completed.
task.wait(3)
local disappear=Tween:Create(visible,TweenInfo.new(.45),{[property]=1})
disappear:Play();disappear.Completed:Wait()
local reveal=Tween:Create(background,TweenInfo.new(.35),{GroupTransparency=1})
reveal:Play();reveal.Completed:Wait()
player:SetAttribute("LoadingScreenOpen",false)
gui:Destroy()
