local Appearance={}
local originals=setmetatable({},{__mode="k"})
local painted={Body=true,Door=true,Hood=true,Trunk=true}
local function paintable(part,vehicle)
 if not part:IsA("BasePart") or part.Transparency>=.95 or part.Name=="Mount" then return false end
 local component
 local ancestor=part
 while ancestor and ancestor~=vehicle do
  local name=ancestor.Name:lower()
  if ancestor:GetAttribute("Paintable")==false or ancestor:GetAttribute("NoPaint")==true
   or ancestor:GetAttribute("Window")==true or name:find("window",1,true) or name:find("glass",1,true) then return false end
  component=component or ancestor:GetAttribute("VehicleComponent")
  ancestor=ancestor.Parent
 end
 return painted[component]==true and part.Material~=Enum.Material.Glass
end
function Appearance.Paint(vehicle)
 local color=vehicle:GetAttribute("PaintColor")
 if color~=nil and typeof(color)~="Color3" then return false end
 for _,part in ipairs(vehicle:GetDescendants()) do
  if paintable(part,vehicle) then
   if originals[part]==nil then originals[part]=part.Color end
   part.Color=color or originals[part]
  end
 end
 return true
end
function Appearance.Lights(record,on,braking)
 local enabled=on and record.Model:GetAttribute("HP")~=0
 for _,part in ipairs(record.Parts) do
  if part==record.Mount or part.Transparency>=.95 then continue end
  record.LampMaterials=record.LampMaterials or {}
  if not record.LampMaterials[part] then record.LampMaterials[part]=part.Material end
  if record.Kind=="Headlight" then
   part.Color=enabled and Color3.fromRGB(255,244,210) or Color3.fromRGB(175,169,145)
  else
   part.Color=enabled and (braking and Color3.fromRGB(255,30,18) or Color3.fromRGB(185,25,18)) or Color3.fromRGB(90,12,8)
  end
  part.Material=enabled and Enum.Material.Neon or record.LampMaterials[part]
 end
end
return Appearance
