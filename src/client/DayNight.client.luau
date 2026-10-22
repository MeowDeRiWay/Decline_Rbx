local Lighting=game:GetService("Lighting")
local function update()
 local hour=workspace:GetAttribute("DayClockHour")
 if typeof(hour)=="number" then Lighting.ClockTime=hour end
end
workspace:GetAttributeChangedSignal("DayClockHour"):Connect(update)
update()
