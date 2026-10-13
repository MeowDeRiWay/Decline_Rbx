local realTypeof = typeof
local function typeof(value) return type(value)=="table" and value.__instance and "Instance" or realTypeof(value) end
local function event()
 local e={handlers={}}
 function e:Connect(fn) table.insert(self.handlers,fn); return {Disconnect=function() end} end
 function e:Fire(...) for _,fn in ipairs(self.handlers) do fn(...) end end
 return e
end
local clock=1000
local os={clock=function() return clock end}
local loops={}
local task={}
function task.spawn(fn,...)
 local co=coroutine.create(fn); local ok,err=coroutine.resume(co,...); assert(ok,err)
 if coroutine.status(co)~="dead" then table.insert(loops,co) end
end
function task.defer(fn,...) task.spawn(fn,...) end
function task.wait() coroutine.yield() end
local function tick(seconds)
 clock+=seconds
 for _,co in ipairs(loops) do local ok,err=coroutine.resume(co); assert(ok,err) end
end
local Vector3={}
local vmeta={}
function Vector3.new(x,y,z) return setmetatable({X=x,Y=y,Z=z},vmeta) end
function vmeta.__add(a,b) return Vector3.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
function vmeta.__sub(a,b) return Vector3.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
function vmeta.__index(a,key) if key=="Magnitude" then return math.sqrt(a.X*a.X+a.Y*a.Y+a.Z*a.Z) end end
Vector3.zero=Vector3.new(0,0,0)
local CFrame={}
function CFrame.new(position) return {Position=position or Vector3.zero,RightVector=Vector3.new(1,0,0),UpVector=Vector3.new(0,1,0),LookVector=Vector3.new(0,0,-1)} end
local methods={}
local meta={}
function meta.__index(a,key)
 if key=="Parent" then return rawget(a,"_parent") end
 if methods[key] then return methods[key] end
 for _,child in ipairs(a.children) do if child.Name==key then return child end end
end
function meta.__newindex(a,key,value)
 if key~="Parent" then rawset(a,key,value); return end
 local old=rawget(a,"_parent")
 if old then local index=table.find(old.children,a); if index then table.remove(old.children,index) end end
 rawset(a,"_parent",value)
 if value then table.insert(value.children,a) end
end
local Instance={}
function Instance.new(class)
 local object=setmetatable({__instance=true,ClassName=class,Name=class,attrs={},children={},CFrame=CFrame.new(),Size=Vector3.new(2,1,2)},meta)
 if class=="RemoteEvent" then
  object.OnServerEvent=event(); object.sent={}
  function object:FireClient(player,data) table.insert(self.sent,{player=player,data=data}) end
 end
 return object
end
function methods:IsA(class) return self.ClassName==class or (class=="BasePart" and self.ClassName=="Part") end
function methods:SetAttribute(key,value) self.attrs[key]=value end
function methods:GetAttribute(key) return self.attrs[key] end
function methods:GetChildren() return table.clone(self.children) end
function methods:GetDescendants()
 local out={}
 for _,child in ipairs(self.children) do table.insert(out,child); for _,nested in ipairs(child:GetDescendants()) do table.insert(out,nested) end end
 return out
end
function methods:FindFirstChild(name,recursive)
 for _,item in ipairs(recursive and self:GetDescendants() or self.children) do if item.Name==name then return item end end
end
function methods:FindFirstChildWhichIsA(class,recursive)
 for _,item in ipairs(recursive and self:GetDescendants() or self.children) do if item:IsA(class) then return item end end
end
function methods:FindFirstChildOfClass(class) return self:FindFirstChildWhichIsA(class) end
function methods:WaitForChild(name) return self:FindFirstChild(name) end
function methods:IsDescendantOf(other)
 local parent=self.Parent
 while parent do if parent==other then return true end; parent=parent.Parent end
 return false
end
function methods:GetFullName() return self.Name end
function methods:GetPivot() return self.CFrame end
function methods:GetBoundingBox() return self.CFrame,self.Size end
function methods:PivotTo(frame) self.CFrame=frame end
function methods:Destroy() self.Parent=nil; self.destroyed=true end
function methods:Clone()
 local clone=Instance.new(self.ClassName); clone.Name=self.Name; clone.attrs=table.clone(self.attrs)
 for _,child in ipairs(self.children) do child:Clone().Parent=clone end
 return clone
end
local function make(class,name,parent,attrs)
 local object=Instance.new(class); object.Name=name; object.Parent=parent
 for key,value in pairs(attrs or {}) do object:SetAttribute(key,value) end
 return object
end
local workspace=make("Workspace","Workspace")
function workspace:GetServerTimeNow() return clock end
function workspace:Raycast() return nil end
local Players=make("Players","Players")
Players.PlayerAdded,Players.PlayerRemoving=event(),event()
function Players:GetPlayers() return self:GetChildren() end
function Players:GetPlayerByUserId(id) for _,p in ipairs(self.children) do if p.UserId==id then return p end end end
function Players:GetNameFromUserIdAsync(id) return "User"..id end
local Teams=make("Teams","Teams")
local ReplicatedStorage=make("ReplicatedStorage","ReplicatedStorage")
local ServerStorage=make("ServerStorage","ServerStorage")
local game={}
function game:GetService(name) return ({Players=Players,Teams=Teams,ReplicatedStorage=ReplicatedStorage,ServerStorage=ServerStorage})[name] end
local BrickColor={new=function() return {Color={}} end}
local RaycastParams={new=function() return {} end}
local Enum={RaycastFilterType={Exclude=1}}
local Interaction={NearestPoint=function(_,position) return position end}
local flagA=make("Model","Flag",workspace,{TownID=1,Team=10,Town_name="Alpha",LeaderID=0,Main=true})
make("Part","Pole",flagA)
local flagB=make("Model","Flag",workspace,{TownID=2,Team=20,Town_name="Beta",LeaderID=0})
make("Part","Pole",flagB)
make("Part","TownSpawn",workspace,{TeamID=10})
make("Part","TownSpawn",workspace,{TeamID=20})
local plot=make("Model","BuildingSpace",workspace,{TownID=1,TeamID=10,OwnerID=0})
local space=make("Model","Space",plot); make("Part","Floor",space)
local menu=make("Model","BuildingMenu",plot); make("Part","Sign",menu)
local flagC=make("Model","Flag",workspace,{TownID=3,Team=1,Town_name="Gamma",LeaderID=0})
make("Part","Pole",flagC)
local spawnC=make("Part","TownSpawn",workspace,{TeamID=1})
spawnC.CFrame=CFrame.new(Vector3.new(33,5,12))
local folder=make("Folder","Buildings",ServerStorage)
local kitchen=make("Model","Kitchen_1",folder); make("Part","Floor",kitchen)
local function player(id)
 local p=make("Player","User"..id,Players); p.UserId=id; p.CharacterAdded=event()
 function p:LoadCharacterAsync()
  self.Character=make("Model",self.Name,workspace)
  local hp=make("Humanoid","Humanoid",self.Character); hp.Health=100; hp.MaxHealth=100; hp.HipHeight=0
  local root=make("Part","HumanoidRootPart",self.Character); root.Position=Vector3.zero
  self.CharacterAdded:Fire(self.Character)
  -- Roblox may place the model after CharacterAdded callbacks run.
  self.Character:PivotTo(CFrame.new(Vector3.new(-999,0,-999)))
 end
 return p
end
local a,b,c,d=player(101),player(102),player(103),player(104)
