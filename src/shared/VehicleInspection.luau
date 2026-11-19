local Inspection={}
function Inspection.Read(part)
 local target,vehicle
 local current=part
 while current do
  local hp,maximum=current:GetAttribute("HP"),current:GetAttribute("MaxHP")
  if not target and typeof(hp)=="number" and typeof(maximum)=="number" and hp==hp and maximum==maximum
   and maximum>0 and maximum<math.huge and math.abs(hp)<math.huge then target=current end
  if current:GetAttribute("Vehicle")==true then vehicle=current;break end
  current=current.Parent
 end
 if not target or not vehicle then return end
 local maximum=target:GetAttribute("MaxHP")
 local hp=math.clamp(target:GetAttribute("HP"),0,maximum)
 return {
  Model=target,Vehicle=vehicle,HP=hp,MaxHP=maximum,
  Name=target:GetAttribute("DisplayName") or (target:GetAttribute("VehicleComponent") and "Vehicle "..target:GetAttribute("VehicleComponent")) or target.Name,
 }
end
return Inspection
