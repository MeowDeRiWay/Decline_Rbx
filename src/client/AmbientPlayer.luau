-- One local non-positional playlist per mood, with cancellable crossfades.
local TweenService=game:GetService("TweenService")
local SoundService=game:GetService("SoundService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Player={}
Player.__index=Player
function Player.new(config)
 local self=setmetatable({Config=config,Channels={},Destroyed=false},Player)
 self.Container=Instance.new("Folder");self.Container.Name="DeclineAmbient";self.Container.Parent=SoundService
 for name,folder in pairs({Outside=config.OutsideFolder,Battle=config.BattleFolder}) do
  local group=Instance.new("SoundGroup");group.Name=name;group.Volume=0;group.Parent=self.Container
  self.Channels[name]={Name=name,Folder=folder,Group=group,Desired=false,Connections={},Generation=0,RetryAt=0}
 end
 return self
end
function Player:Clear(channel)
 if channel.Tween then local tween=channel.Tween;channel.Tween=nil;tween:Cancel() end
 channel.Generation+=1
 for _,connection in ipairs(channel.Connections) do connection:Disconnect() end
 table.clear(channel.Connections)
 if channel.Sound then channel.Sound:Stop();channel.Sound:Destroy();channel.Sound=nil end
 channel.Ready=false
end
function Player:Fade(channel,volume)
 if channel.Tween then channel.Tween:Cancel();channel.Tween=nil end
 local tween=TweenService:Create(channel.Group,TweenInfo.new(self.Config.FadeSeconds,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),{Volume=volume})
 channel.Tween=tween
 tween.Completed:Once(function(state)
  if channel.Tween~=tween then return end
  channel.Tween=nil
  if state==Enum.PlaybackState.Completed and not channel.Desired then self:Clear(channel) end
 end)
 tween:Play()
end
function Player:Start(channel)
 if self.Destroyed or not channel.Desired or channel.Sound or os.clock()<channel.RetryAt then return end
 local sounds=ReplicatedStorage:FindFirstChild("Sounds")
 local folder=sounds and sounds:FindFirstChild(channel.Folder)
 local tracks={}
 if folder then
  for _,sound in ipairs(folder:GetDescendants()) do
   if sound:IsA("Sound") and sound.SoundId~="" then table.insert(tracks,sound) end
  end
 end
 if #tracks==0 then channel.RetryAt=os.clock()+2;return end
 if #tracks>1 then
  for i=#tracks,1,-1 do if tracks[i]==channel.Last then table.remove(tracks,i) end end
 end
 local source=tracks[math.random(#tracks)];channel.Last=source
 self:Clear(channel)
 local generation=channel.Generation
 local sound=source:Clone();sound.Name=channel.Name.."Track"
 sound.Looped=false;sound.PlayOnRemove=false;sound.SoundGroup=channel.Group;sound.TimePosition=0
 channel.Sound=sound;channel.Group.Volume=0
 local function current() return not self.Destroyed and channel.Generation==generation and channel.Sound==sound end
 local function ready()
  if not current() or channel.Ready then return end
  channel.Ready=true
  if channel.Desired then self:Fade(channel,self.Config[channel.Name.."Volume"]) end
 end
 table.insert(channel.Connections,sound.Loaded:Connect(ready))
 table.insert(channel.Connections,sound.Ended:Connect(function()
  if not current() then return end
  self:Clear(channel)
  if channel.Desired then self:Start(channel) end
 end))
 sound.Parent=self.Container
 sound:Play()
 if sound.IsLoaded then ready() end
 task.delay(self.Config.LoadTimeoutSeconds,function()
  if not current() or channel.Ready then return end
  warn("[Decline] Ambient sound did not load: "..source.Name..". Check audio permissions for this experience.")
  self:Clear(channel)
  channel.RetryAt=os.clock()+1
 end)
end
function Player:SetMode(mode)
 if self.Destroyed then return end
 for name,channel in pairs(self.Channels) do
  local desired=name==mode
  if channel.Desired~=desired then
   channel.Desired=desired
   if desired then
    if channel.Sound then
     if channel.Ready then self:Fade(channel,self.Config[name.."Volume"]) end
    else self:Start(channel) end
   else self:Fade(channel,0) end
  elseif desired and not channel.Sound then self:Start(channel) end
 end
end
function Player:Destroy()
 if self.Destroyed then return end
 self.Destroyed=true
 for _,channel in pairs(self.Channels) do
  if channel.Tween then channel.Tween:Cancel();channel.Tween=nil end
  self:Clear(channel)
 end
 self.Container:Destroy()
end
return Player
