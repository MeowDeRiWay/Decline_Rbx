local Lighting=game:GetService("Lighting")
local Run=game:GetService("RunService")
local start=workspace:GetServerTimeNow()
local elapsed=0
local function update()
 local hour=(8+(workspace:GetServerTimeNow()-start)/150)%24
 Lighting.ClockTime=hour
 workspace:SetAttribute("DayClockHour",hour)
 local night=hour<6 or hour>=18
 if workspace:GetAttribute("IsNight")~=night then workspace:SetAttribute("IsNight",night) end
end
update()
Run.Heartbeat:Connect(function(dt) elapsed+=dt;if elapsed>=1 then elapsed=0;update() end end)
