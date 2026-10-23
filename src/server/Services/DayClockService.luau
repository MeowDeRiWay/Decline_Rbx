local Lighting=game:GetService("Lighting")
local Run=game:GetService("RunService")
local Service={}
local hour,speed,paused=8,1,false
local last=workspace:GetServerTimeNow()
local function advance()
 local now=workspace:GetServerTimeNow()
 if not paused then hour=(hour+(now-last)*speed/150)%24 end
 last=now
end
local function publish()
 Lighting.ClockTime=hour
 workspace:SetAttribute("DayClockHour",hour)
 workspace:SetAttribute("DayClockSpeed",speed)
 workspace:SetAttribute("DayClockPaused",paused)
 local night=hour<6 or hour>=18
 if workspace:GetAttribute("IsNight")~=night then workspace:SetAttribute("IsNight",night) end
end
function Service.SetHour(value) advance();hour=value;publish() end
function Service.SetSpeed(value) advance();speed=value;publish() end
function Service.SetPaused(value) advance();paused=value;publish() end
function Service.Start()
 if Service.Started then return end;Service.Started=true
 publish()
 local elapsed=0
 Run.Heartbeat:Connect(function(dt)
  elapsed+=dt
  if elapsed>=1 then elapsed=0;advance();publish() end
 end)
end
return Service
