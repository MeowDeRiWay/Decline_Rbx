-- Shared only by this client's camera and cursor; never changes world collision.
local Stations=require(game:GetService("ReplicatedStorage").Shared.CraftStations)
local originals=setmetatable({},{__mode="k"})
local State={}
function State.Track(part,original) originals[part]=original end
function State.Forget(part) originals[part]=nil end
function State.CursorPasses(part)
 local original=originals[part]
 if original==nil or part.LocalTransparencyModifier<=math.max(.25,original+.05) then return false end
 -- A faded interactive object must still be selectable itself.
 local ancestor=part
 while ancestor and ancestor~=workspace do
  if ancestor:GetAttribute("Door")==true or ancestor:GetAttribute("MenuButton")==true
   or ancestor:GetAttribute("HospitalBed")==true or ancestor:GetAttribute("TradePost")==true
   or ancestor:GetAttribute("Item_ID")~=nil then return false end
  if ancestor:IsA("Model") and (Stations.Kind(ancestor) or ancestor.Name=="Chest"
   or ancestor.Name=="GardenBed" or ancestor.Name=="Well" or ancestor.Name=="TradePost"
   or ancestor:FindFirstChildOfClass("Humanoid")) then return false end
  ancestor=ancestor.Parent
 end
 return true
end
return State
