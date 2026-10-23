local Storage=game:GetService("ServerStorage")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Items=require(ReplicatedStorage.Shared.ItemConfig).Items
local Rules=require(ReplicatedStorage.Shared.ItemPoolRules)
local WorldItems=require(script.Parent.WorldItemService)
local random=Random.new()
local Service={}
local states={}
local warnings=setmetatable({},{__mode="k"})
local function pool(path)
 local folder=Storage:FindFirstChild("Items")
 if typeof(path)~="string" or path=="" then return nil end
 path=path:gsub("^Items/", "")
 for name in path:gmatch("[^/]+") do
  folder=folder and folder:FindFirstChild(name)
  if not folder or not folder:IsA("Folder") then return nil end
 end
 return folder
end
local function entries(folder)
 local result={}
 local function visit(current)
  for _,source in ipairs(current:GetChildren()) do
   if source:IsA("Folder") then visit(source)
   elseif source:IsA("Model") or source:IsA("BasePart") then
    local id=source:GetAttribute("Item_ID") or source.Name
    local definition=Items[id]
    -- Ammunition pools contain authored boxes, never a single loose round.
    if definition and not definition.Ammo and definition.Lootable~=false and (source:IsA("BasePart") or source:FindFirstChildWhichIsA("BasePart",true)) then
     table.insert(result,{Source=source,ID=id,Weight=Rules.Weight(source:GetAttribute("SpawnWeight"))})
    end
   end
  end
 end
 visit(folder)
 table.sort(result,function(a,b) return a.Source:GetFullName()<b.Source:GetFullName() end)
 return result
end
local function hide(marker)
 if marker:IsA("BasePart") then marker.Transparency=1;marker.CanCollide=false;marker.CanTouch=false;marker.CanQuery=false;marker.Anchored=true end
 for _,p in ipairs(marker:GetDescendants()) do if p:IsA("BasePart") then p.Transparency=1;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.Anchored=true;p:SetAttribute("BlocksVision",false) end end
 marker:SetAttribute("BlocksVision",false)
end
function Service.Update()
 local now=workspace:GetServerTimeNow()
 for marker,state in pairs(states) do
  if not marker:IsDescendantOf(workspace) or typeof(marker:GetAttribute("ItemPool"))~="string" then
   if state.Item and state.Item.Parent then state.Item:Destroy() end
   states[marker]=nil
  end
 end
 for _,marker in ipairs(workspace:GetDescendants()) do
  local path=marker:GetAttribute("ItemPool")
  if typeof(path)~="string" or (not marker:IsA("Model") and not marker:IsA("BasePart")) then continue end
  if marker:IsDescendantOf(workspace:FindFirstChild("WorldItems")) then continue end
  local state=states[marker]
  if not state then state={Due=now};states[marker]=state;hide(marker) end
  if state.Item then
   if state.Item.Parent then continue end
   state.Item=nil;state.Due=now+Rules.Delay(marker:GetAttribute("RespawnSeconds"))
  end
  if now<state.Due then continue end
  local source=pool(path)
  local choices=source and entries(source) or {}
  if #choices==0 then
   if warnings[marker]~=path then warnings[marker]=path;warn("[ItemPool] No registered item models in ServerStorage/Items/"..path) end
   state.Due=now+5;continue
  end
  state.Due=now+Rules.Delay(marker:GetAttribute("RespawnSeconds"))
  if random:NextNumber()>=Rules.Chance(marker:GetAttribute("SpawnChance")) then continue end
  local chosen=Rules.Pick(choices,random:NextNumber())
  local frame,size
  if marker:IsA("Model") then
   if not marker:FindFirstChildWhichIsA("BasePart",true) then continue end
   frame,size=marker:GetBoundingBox()
  else frame,size=marker.CFrame,marker.Size end
  if chosen then state.Item=WorldItems.SpawnTemplate(chosen.Source,chosen.ID,frame.Position+Vector3.new(0,size.Y/2,0)) end
 end
end
function Service.Start()
 if Service.Started then return end;Service.Started=true
 Service.Update()
 task.spawn(function() while true do task.wait(5);Service.Update() end end)
end
return Service
