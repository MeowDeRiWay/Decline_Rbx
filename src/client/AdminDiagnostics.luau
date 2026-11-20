local Run=game:GetService("RunService")
local Service={Hidden=false}
local saved=setmetatable({},{__mode="k"})
local samples={}
local count,total,maximum,slow50,slow100=0,0,0,0,0
function Service.Reset()
 table.clear(samples);count,total,maximum,slow50,slow100=0,0,0,0,0
end
function Service.Frame(dt)
 if dt<=0 or dt~=dt or dt==math.huge then return end
 count+=1;total+=dt;maximum=math.max(maximum,dt)
 if dt>=.05 then slow50+=1 end
 if dt>=.1 then slow100+=1 end
 samples[(count-1)%600+1]=dt
end
function Service.Snapshot()
 local sorted=table.clone(samples);table.sort(sorted)
 return {FPS=total>0 and count/total or 0,MaxMS=maximum*1000,
  P95MS=(sorted[math.max(1,math.ceil(#sorted*.95))] or 0)*1000,
  Slow50=slow50,Slow100=slow100,Seconds=total}
end
local function decor(object)
 local marked=false
 local ancestor=object
 while ancestor and ancestor~=workspace do
  if ancestor:GetAttribute("Item_ID")~=nil or ancestor:GetAttribute("Vehicle")==true
   or ancestor:IsA("Model") and ancestor:FindFirstChildOfClass("Humanoid") then return false end
  if ancestor:GetAttribute("Furniture")==true or ancestor.Name=="GeneratedFurniture"
   or ancestor.Name=="Furniture" or ancestor.Name=="StoreFurniture" then marked=true end
  ancestor=ancestor.Parent
 end
 return marked
end
local function apply(object)
 if not Service.Hidden or saved[object] or not decor(object) then return end
 local key,value
 if object:IsA("BasePart") then key,value="LocalTransparencyModifier",1
 elseif object:IsA("Decal") or object:IsA("Texture") then key,value="Transparency",1
 elseif object:IsA("Light") or object:IsA("ParticleEmitter") or object:IsA("Beam")
  or object:IsA("Trail") or object:IsA("SurfaceGui") or object:IsA("BillboardGui") then key,value="Enabled",false end
 if key then saved[object]={Key=key,Value=object[key]};object[key]=value end
end
local function restore(object)
 local original=saved[object]
 if not original then return end
 saved[object]=nil
 object[original.Key]=original.Value
end
function Service.HideDecor(value)
 Service.Hidden=value==true
 if Service.Hidden then
  for _,object in ipairs(workspace:GetDescendants()) do apply(object) end
 else
  for object in pairs(saved) do restore(object) end
 end
end
function Service.Start()
 if Service.Started then return end
 Service.Started=true
 Run.RenderStepped:Connect(Service.Frame)
 workspace.DescendantAdded:Connect(function(object) if Service.Hidden then apply(object) end end)
 workspace.DescendantRemoving:Connect(restore)
end
return Service
