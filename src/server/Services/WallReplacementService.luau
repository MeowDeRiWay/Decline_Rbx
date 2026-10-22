-- Authored building pieces are assembled from the shared wall library.
local ServerStorage=game:GetService("ServerStorage")
local Service={}
local warnings=setmetatable({},{__mode="k"})
local function box(object)
 if object:IsA("BasePart") then return object.CFrame end
 if object:IsA("Model") and object:FindFirstChildWhichIsA("BasePart",true) then return object:GetBoundingBox() end
 return nil
end
local function warnOnce(marker,message)
 if warnings[marker]~=message then warnings[marker]=message;warn("[Decline Walls] "..message) end
end
local function hideYard(yard)
 local markerParts=yard:IsA("BasePart") and {yard} or yard:GetDescendants()
 for _,part in ipairs(markerParts) do
  if part:IsA("BasePart") then
   part.Transparency=1;part.CanCollide=false;part.CanTouch=false;part.CanQuery=false;part.CastShadow=false
   part:SetAttribute("BlocksVision",false)
  end
 end
end
local function replace(marker)
 local name=marker:GetAttribute("Replace")
 if typeof(name)~="string" or name=="" then return end
 local library=ServerStorage:FindFirstChild("CityGeneration")
 local walls=library and library:FindFirstChild("Walls")
 local source=walls and walls:FindFirstChild(name)
 local anchor=source and source:FindFirstChild("WallYard")
 local sourceFrame=anchor and box(anchor)
 local target=marker:FindFirstChild("YardPlacer")
 local targetFrame=box(target or marker)
 if not source or not source:IsA("Model") or not sourceFrame then
  warnOnce(marker,"Add a Model with WallYard at ServerStorage/CityGeneration/Walls/"..name);return
 end
 if not targetFrame then warnOnce(marker,"Replacement marker needs a physical YardPlacer: "..marker:GetFullName());return end
 local clone=source:Clone()
 -- Match reference frames, including authored pivot offsets; never resize geometry.
 clone:PivotTo(targetFrame*sourceFrame:ToObjectSpace(source:GetPivot()))
 clone:SetAttribute("Replace",nil)
 clone:SetAttribute("GeneratedWallPiece",true)
 for _,part in ipairs(clone:GetDescendants()) do if part:IsA("BasePart") then part.Anchored=true end end
 -- Parent beside the marker: an invisible marker's BlocksVision setting must not
 -- override real wall/window attributes, and no placeholder collision can remain.
 hideYard(clone:FindFirstChild("WallYard"))
 clone.Parent=marker.Parent
 warnings[marker]=nil
 marker:Destroy()
end
function Service.Fill(root)
 local markers={}
 local yards={}
 if root.Name=="WallYard" then table.insert(yards,root) end
 if typeof(root:GetAttribute("Replace"))=="string" then table.insert(markers,root) end
 for _,object in ipairs(root:GetDescendants()) do
  if object.Name=="WallYard" then table.insert(yards,object) end
  if (object:IsA("Model") or object:IsA("BasePart")) and typeof(object:GetAttribute("Replace"))=="string" then table.insert(markers,object) end
 end
 for _,yard in ipairs(yards) do hideYard(yard) end
 for _,marker in ipairs(markers) do
  if marker==root or marker:IsDescendantOf(root) then replace(marker) end
 end
end
return Service
