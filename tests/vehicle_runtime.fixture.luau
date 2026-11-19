-- Minimal scene, joints and event scheduler for the production vehicle modules.
local objects={}
local clock=100
local deferred={}
local function signal()
 local callbacks={}
 return {
  Connect=function(_,fn)
   callbacks[fn]=true
   return {Disconnect=function() callbacks[fn]=nil end}
  end,
  Fire=function(_,...)
   local snapshot=table.clone(callbacks)
   for fn in pairs(snapshot) do if callbacks[fn] then fn(...) end end
  end,
 }
end
local methods={}
local baseparts={Part=true,Seat=true,VehicleSeat=true,MeshPart=true,UnionOperation=true}
local function eventFor(self,key)
 self.Signals[key]=self.Signals[key] or signal()
 return self.Signals[key]
end
local function create(kind,parent)
 local object={ClassName=kind,Name=kind,Parent=parent,Attributes={},Signals={},
  Destroying=signal(),ChildAdded=signal(),DescendantAdded=signal(),HealthChanged=signal(),
  CharacterAdded=signal(),CharacterRemoving=signal(),PlayerAdded=signal(),PlayerRemoving=signal(),
  OnServerEvent=signal(),OnClientEvent=signal()}
 if baseparts[kind] then
  object.CFrame=CFrame.identity;object.Size=Vector3.new(1,1,1);object.PivotOffset=CFrame.identity
  object.Color={R=1,G=1,B=1,IsColor=true};object.Material="Plastic"
  object.Transparency=0;object.CanCollide=true;object.CanTouch=true;object.CanQuery=true
  object.AssemblyLinearVelocity=Vector3.zero;object.AssemblyAngularVelocity=Vector3.zero
 elseif kind=="Motor6D" or kind=="Weld" then object.C0=CFrame.identity;object.C1=CFrame.identity;object.Transform=CFrame.identity end
 setmetatable(object,{__index=function(self,key)
  if key=="Position" then return self.CFrame.Position end
  if methods[key] then return methods[key] end
  if key=="Parent" or key=="Deleted" or key=="PrimaryPart" or key=="Occupant" or key=="SeatPart" or key=="Part0" or key=="Part1" then return nil end
  return methods.FindFirstChild(self,key)
 end})
 table.insert(objects,object)
 return object
end
Instance={new=create}
local originalTypeof=typeof
typeof=function(value)
 if type(value)=="table" and rawget(value,"ClassName") then return "Instance" end
 if type(value)=="table" and value.IsColor then return "Color3" end
 return originalTypeof(value)
end
function methods:IsA(kind)
 return self.ClassName==kind or kind=="BasePart" and baseparts[self.ClassName]==true
  or kind=="JointInstance" and (self.ClassName=="Motor6D" or self.ClassName=="Weld")
  or kind=="LuaSourceContainer" and (self.ClassName=="Script" or self.ClassName=="LocalScript")
end
function methods:GetChildren()
 local result={}
 for _,object in ipairs(objects) do if not rawget(object,"Deleted") and rawget(object,"Parent")==self then table.insert(result,object) end end
 return result
end
function methods:IsDescendantOf(parent)
 local current=self.Parent
 while current do if current==parent then return true end;current=current.Parent end
 return false
end
function methods:GetDescendants()
 local result={}
 for _,object in ipairs(objects) do if not rawget(object,"Deleted") and object:IsDescendantOf(self) then table.insert(result,object) end end
 return result
end
function methods:FindFirstChild(name,recurse)
 for _,object in ipairs(recurse and self:GetDescendants() or self:GetChildren()) do if object.Name==name then return object end end
end
function methods:FindFirstChildOfClass(kind)
 for _,object in ipairs(self:GetChildren()) do if object.ClassName==kind then return object end end
end
function methods:FindFirstChildWhichIsA(kind,recurse)
 for _,object in ipairs(recurse and self:GetDescendants() or self:GetChildren()) do if object:IsA(kind) then return object end end
end
function methods:WaitForChild(name) return assert(self:FindFirstChild(name),"Missing child "..name) end
function methods:GetAttribute(key) return self.Attributes[key] end
function methods:SetAttribute(key,value)
 if self.Attributes[key]==value then return end
 self.Attributes[key]=value;eventFor(self,"Attribute:"..key):Fire()
end
function methods:GetAttributeChangedSignal(key) return eventFor(self,"Attribute:"..key) end
function methods:GetPropertyChangedSignal(key) return eventFor(self,"Property:"..key) end
function methods:GetFullName() return self.Name end
function methods:GetBoundingBox()
 local axes=self.PrimaryPart and self.PrimaryPart.CFrame or rawget(self,"WorldPivot") or rawget(self,"ModelFrame") or CFrame.identity
 local low,high
 for _,part in ipairs(self:IsA("BasePart") and {self} or self:GetDescendants()) do
  if not part:IsA("BasePart") then continue end
  for _,x in ipairs({-1,1}) do for _,y in ipairs({-1,1}) do for _,z in ipairs({-1,1}) do
   local p=axes:PointToObjectSpace(part.CFrame:PointToWorldSpace(Vector3.new(x*part.Size.X/2,y*part.Size.Y/2,z*part.Size.Z/2)))
   low=low and Vector3.new(math.min(low.X,p.X),math.min(low.Y,p.Y),math.min(low.Z,p.Z)) or p
   high=high and Vector3.new(math.max(high.X,p.X),math.max(high.Y,p.Y),math.max(high.Z,p.Z)) or p
  end end end
 end
 if not low then return axes,Vector3.zero end
 return axes*CFrame.new((low+high)/2),high-low
end
function methods:GetPivot()
 if self:IsA("BasePart") then return self.CFrame*self.PivotOffset end
 if self.PrimaryPart then return self.PrimaryPart:GetPivot() end
 if rawget(self,"WorldPivot") then return self.WorldPivot end
 local frame=self:GetBoundingBox()
 return frame
end
function methods:PivotTo(target)
 local delta=target*self:GetPivot():Inverse()
 if self:IsA("BasePart") then self.CFrame=delta*self.CFrame
 else
  for _,part in ipairs(self:GetDescendants()) do if part:IsA("BasePart") then part.CFrame=delta*part.CFrame end end
  self.WorldPivot=target
 end
end
function methods:Clone()
 local mapping={}
 local function clone(source,parent)
  local target=create(source.ClassName,parent);mapping[source]=target
  for _,key in ipairs({"Name","CFrame","Size","PivotOffset","Transparency","Anchored","CanCollide","CanQuery","CanTouch","Massless","Disabled","WorldPivot","ModelFrame","SoundId","Volume","IsPlaying","PlaybackSpeed","Looped"}) do
   if rawget(source,key)~=nil then target[key]=source[key] end
  end
  target.Attributes=table.clone(source.Attributes)
  for _,child in ipairs(source:GetChildren()) do clone(child,target) end
  return target
 end
 local result=clone(self,nil)
 for source,target in pairs(mapping) do
  if source.PrimaryPart then target.PrimaryPart=mapping[source.PrimaryPart] end
 end
 return result
end
function methods:Destroy()
 if self.Deleted then return end
 self.Destroying:Fire()
 for _,child in ipairs(self:GetChildren()) do child:Destroy() end
 local parent=self.Parent
 if self.ClassName=="Weld" and self.Name=="SeatWeld" and parent then
  local hp=parent.Occupant
  parent.Occupant=nil
  if hp then hp.SeatPart=nil;hp.Sit=false end
  eventFor(parent,"Property:Occupant"):Fire()
 end
 self.Deleted=true;self.Parent=nil
end
function methods:Fire(...) self.OnServerEvent:Fire(...) end
function methods:FireAllClients(...) self.LastBroadcast={...} end
function methods:FireClient(...) self.LastMessage={...} end
function methods:Sit(hp)
 assert(self:IsA("Seat") or self:IsA("VehicleSeat"))
 local weld=create("Weld",self);weld.Name="SeatWeld";weld.Part0=self;weld.Part1=hp.Parent:FindFirstChild("HumanoidRootPart")
 self.Occupant=hp;hp.Sit=true;hp.SeatPart=self
 eventFor(self,"Property:Occupant"):Fire()
end
function methods:Play() self.IsPlaying=true end
function methods:Stop() self.IsPlaying=false end
function methods:SetStateEnabled() end
function CFrame.lookAt(position,target,up)
 local forward=(target-position).Unit
 local right=forward:Cross(up or Vector3.yAxis).Unit
 local vertical=right:Cross(forward).Unit
 return cf(position,{right.X,vertical.X,-forward.X,right.Y,vertical.Y,-forward.Y,right.Z,vertical.Z,-forward.Z})
end
Color3={fromRGB=function(r,g,b) return {R=r/255,G=g/255,B=b/255,IsColor=true} end}
Enum={Material={Glass="Glass",Plastic="Plastic",Neon="Neon"},RaycastFilterType={Exclude="Exclude",Include="Include"},NormalId={Right="Right",Left="Left",Top="Top",Bottom="Bottom",Front="Front",Back="Back"}}
RaycastParams={new=function() return {} end}
OverlapParams={new=function() return {} end}
task={
 spawn=function(fn) fn() end,
 defer=function(fn) table.insert(deferred,{At=clock,Run=fn}) end,
 delay=function(delay,fn) table.insert(deferred,{At=clock+delay,Run=fn}) end,
}
local Players=create("Players")
local ReplicatedStorage=create("ReplicatedStorage")
create("Folder",ReplicatedStorage).Name="Shared"
local ServerStorage=create("ServerStorage")
local RunService={Heartbeat=signal()}
workspace=create("Workspace")
function workspace:GetServerTimeNow() return clock end
local groundY=-7.5
local blockMovement,blockExit=false,false
local wall=create("Part",workspace);wall.Name="Wall"
function workspace:Raycast(origin,direction)
 if direction.Y>=-.001 then return nil end
 local t=(groundY-origin.Y)/direction.Y
 if t<0 or t>1 then return nil end
 return {Position=origin+direction*t,Normal=Vector3.yAxis,Instance=wall,Distance=direction.Magnitude*t}
end
function workspace:Blockcast(frame,size,direction)
 if blockMovement then return {Position=frame.Position,Normal=-direction.Unit,Instance=wall,Distance=.01} end
end
function workspace:GetPartBoundsInBox() return blockExit and {wall} or {} end
function Players:GetPlayers() return self:GetChildren() end
function Players:GetPlayerFromCharacter(character)
 for _,p in ipairs(self:GetPlayers()) do if p.Character==character then return p end end
end
game={GetService=function(_,name) return ({Players=Players,ReplicatedStorage=ReplicatedStorage,ServerStorage=ServerStorage,RunService=RunService})[name] end}
local function physics()
 for _,joint in ipairs(objects) do
  if not joint.Deleted and joint.ClassName=="WeldConstraint" and joint.Part0 and joint.Part1 and not rawget(joint,"Rest") then
   joint.Rest=joint.Part0.CFrame:ToObjectSpace(joint.Part1.CFrame)
  end
 end
 for _=1,3 do
  for _,joint in ipairs(objects) do
   if joint.Deleted or not joint.Part0 or not joint.Part1 then continue end
   if joint:IsA("Motor6D") or joint:IsA("Weld") then joint.Part1.CFrame=joint.Part0.CFrame*joint.C0*(joint.Transform or CFrame.identity)*joint.C1:Inverse()
   elseif joint:IsA("WeldConstraint") and rawget(joint,"Rest") then joint.Part1.CFrame=joint.Part0.CFrame*joint.Rest end
  end
 end
end
local function tick(dt)
 clock+=dt
 local queue=deferred;deferred={}
 for _,entry in ipairs(queue) do if entry.At<=clock then entry.Run() else table.insert(deferred,entry) end end
 physics()
 RunService.Heartbeat:Fire(dt)
 physics()
end
local function near(a,b,message) assert((a-b).Magnitude<.0001,message or "position mismatch") end
local function loadGeometry(geometry)
 local mapping={}
 for _,entry in ipairs(geometry) do
  local object=create(entry.ClassName)
  for key,value in pairs(entry) do
   if key~="ID" and key~="ParentID" and key~="PrimaryPartID" then object[key]=key=="Attributes" and table.clone(value) or value end
  end
  mapping[entry.ID]=object
 end
 for _,entry in ipairs(geometry) do
  local object=mapping[entry.ID]
  object.Parent=mapping[entry.ParentID]
  object.PrimaryPart=mapping[entry.PrimaryPartID]
 end
 mapping[1].Parent=ServerStorage
 return mapping[1]
end
