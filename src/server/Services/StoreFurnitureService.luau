local ServerStorage=game:GetService("ServerStorage")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Rules=require(ReplicatedStorage.Shared.CityGenerationRules)
local Service={}
local warnings=setmetatable({},{__mode="k"})
local function box(object)
 if object:IsA("Model") and object:FindFirstChildWhichIsA("BasePart",true) then return object:GetBoundingBox() end
 if object:IsA("BasePart") then return object.CFrame,object.Size end
 return nil
end
local function furnitureBox(source)
 local parts=source:IsA("BasePart") and {source} or source:GetDescendants()
 local points={}
 for _,part in ipairs(parts) do
  if part:IsA("BasePart") then
   for _,x in ipairs({-1,1}) do for _,y in ipairs({-1,1}) do for _,z in ipairs({-1,1}) do
    table.insert(points,part.CFrame:PointToWorldSpace(Vector3.new(x*part.Size.X/2,y*part.Size.Y/2,z*part.Size.Z/2)))
   end end end
  end
 end
 if #points==0 then return nil end
 return Rules.UprightFurnitureBox(source:GetPivot(),points)
end
local function warnOnce(marker,message)
 if warnings[marker]~=message then warnings[marker]=message; warn("[Decline Furniture] "..message) end
end
local function fill(marker)
 local name=marker:GetAttribute("StoreFurniture")
 if typeof(name)~="string" or name=="" then return end
 if marker:FindFirstChild("GeneratedFurniture") then return end
 local zoneFrame,zoneSize=box(marker)
 if not zoneFrame then return end
 -- Hide only the authored marker; generated furniture is inserted afterward.
 local parts=marker:IsA("BasePart") and {marker} or marker:GetDescendants()
 for _,part in ipairs(parts) do
  if part:IsA("BasePart") then
   part.Transparency=1; part.CanCollide=false; part.CanTouch=false; part.CanQuery=false; part.Anchored=true
   part:SetAttribute("BlocksVision",false)
  end
 end
 marker:SetAttribute("BlocksVision",false)
 local root=ServerStorage:FindFirstChild("CityGeneration")
 local templates=root and root:FindFirstChild("StoreFurniture")
 local source=templates and templates:FindFirstChild(name)
 -- Preserve existing store templates when both libraries contain the name.
 if not source then
  local furniture=root and root:FindFirstChild("Furniture")
  source=furniture and furniture:FindFirstChild(name)
 end
 local sourceFrame,sourceSize
 if source and (source:IsA("Model") or source:IsA("BasePart")) then sourceFrame,sourceSize=furnitureBox(source) end
 if not sourceFrame then warnOnce(marker,"Add a furniture Model or Part named "..name.." in ServerStorage/CityGeneration/StoreFurniture or ServerStorage/CityGeneration/Furniture"); return end
 local columns,rows=Rules.FurnitureGrid(zoneSize,sourceSize)
 if columns==0 or rows==0 then warnOnce(marker,string.format("%s footprint %.3fx%.3f does not fit %s area %.3fx%.3f",name,sourceSize.X,sourceSize.Z,marker:GetFullName(),zoneSize.X,zoneSize.Z)); return end
 local group=Instance.new("Folder"); group.Name="GeneratedFurniture"
 local offset=sourceFrame:ToObjectSpace(source:GetPivot())
 for x=1,columns do for z=1,rows do
  local target=Rules.FurnitureFrame(zoneFrame,zoneSize,sourceSize,columns,rows,x,z)
  local clone=source:Clone()
  clone:PivotTo(target*offset)
  if clone:IsA("BasePart") then clone.Anchored=true end
  for _,part in ipairs(clone:GetDescendants()) do if part:IsA("BasePart") then part.Anchored=true end end
  clone.Parent=group
 end end
 group.Parent=marker
 marker:SetAttribute("FurnitureCount",columns*rows)
 warnings[marker]=nil
end
function Service.Fill(root)
 local markers={}
 if root.Name=="AutoPlacer" then table.insert(markers,root) end
 for _,object in ipairs(root:GetDescendants()) do if object.Name=="AutoPlacer" then table.insert(markers,object) end end
 for _,marker in ipairs(markers) do
  local ancestor=marker.Parent
  local generated=false
  while ancestor and ancestor~=root do
   if ancestor.Name=="GeneratedFurniture" then generated=true; break end
   ancestor=ancestor.Parent
  end
  if not generated then fill(marker) end
 end
end
return Service
