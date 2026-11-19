-- Driver-only hotkey ownership; ordinary passenger seats retain gameplay actions.
local Rules={}
function Rules.IsDriver(character)
 if not character then return false end
 if character:GetAttribute("VehicleDriver")==true or character:GetAttribute("VehicleEntering")=="Driver" then return true end
 local hp=character:FindFirstChildOfClass("Humanoid")
 local seat=hp and hp.SeatPart
 if not seat or not seat:IsA("VehicleSeat") then return false end
 local ancestor=seat.Parent
 while ancestor do
  if ancestor:GetAttribute("Vehicle")==true then return true end
  ancestor=ancestor.Parent
 end
 return false
end
return Rules

