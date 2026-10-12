-- A local ground grid supports the custom small rigs and non-collidable homes.
local Navigation = {}
Navigation.__index = Navigation
function Navigation.New(model,root)
 return setmetatable({Model=model,Root=root,Cell=math.max(.5,math.sqrt(root.Size.X^2+root.Size.Z^2)+.12),Route={},Index=1,NextPlan=0},Navigation)
end
function Navigation:Parameters(ignored)
 local excluded={self.Model}
 if ignored then table.insert(excluded,ignored) end
 for _,object in ipairs(workspace:GetDescendants()) do
  if object:IsA("Humanoid") and object.Parent:IsA("Model") then table.insert(excluded,object.Parent) end
 end
 local ray=RaycastParams.new()
 ray.FilterType=Enum.RaycastFilterType.Exclude
 ray.FilterDescendantsInstances=excluded
 ray.RespectCanCollide=true
 local overlap=OverlapParams.new()
 overlap.FilterType=Enum.RaycastFilterType.Exclude
 overlap.FilterDescendantsInstances=excluded
 overlap.RespectCanCollide=true
 return ray,overlap
end
function Navigation:Ground(point,ray)
 local root=self.Root
 local step=math.max(.15,root.Size.Y*.2)
 local origin=point+Vector3.new(0,step,0)
 local delta=Vector3.new(0,-step-root.Size.Y/2-.3,0)
 local hit=workspace:Raycast(origin,delta,ray)
 local reference=self.Model:FindFirstChild("ZombieHome")
 local home=reference and reference.Value
 if home and home:IsDescendantOf(workspace) then
  local params=RaycastParams.new()
  params.FilterType=Enum.RaycastFilterType.Include
  params.FilterDescendantsInstances={home}
  local surface=workspace:Raycast(origin,delta,params)
  if surface and (not hit or surface.Position.Y>hit.Position.Y) then hit=surface end
 end
 if not hit or hit.Normal.Y<.85 then return nil end
 local height=hit.Position.Y+root.Size.Y/2+.02
 if math.abs(height-point.Y)>step then return nil end
 return Vector3.new(point.X,height,point.Z)
end
function Navigation:Clear(a,b,ray)
 local delta=b-a
 if delta.Magnitude<.001 then return true end
 local width=self.Cell-.05
 return workspace:Blockcast(CFrame.new(a),Vector3.new(width,self.Root.Size.Y*.9,width),delta,ray)==nil
end
function Navigation:Plan(goal,ignored)
 local start=self.Root.Position
 local ray,overlap=self:Parameters(ignored)
 self.Ray=ray
 self.Route={}
 self.Index=1
 self.Goal=goal
 local target=self:Ground(Vector3.new(goal.X,start.Y,goal.Z),ray)
 if not target then return false end
 local clearance=self.Cell-.05
 if #workspace:GetPartBoundsInBox(CFrame.new(target),Vector3.new(clearance,self.Root.Size.Y*.9,clearance),overlap)>0 then return false end
 if self:Clear(start,target,ray) then self.Route={target}; return true end
 local cell=self.Cell
 local function key(x,z) return x..":"..z end
 local function heuristic(position) return Vector3.new(position.X-goal.X,0,position.Z-goal.Z).Magnitude end
 local first={X=0,Z=0,Position=start,Cost=0,Score=heuristic(start)}
 local open={first}
 local best={[key(0,0)]=first}
 local closed={}
 local found
 local limit=math.min(40,heuristic(start)+12)
 for _=1,500 do
  if #open==0 then break end
  local index=1
  for i=2,#open do if open[i].Score<open[index].Score then index=i end end
  local current=table.remove(open,index)
  local currentKey=key(current.X,current.Z)
  if closed[currentKey] then continue end
  closed[currentKey]=true
  if heuristic(current.Position)<=cell and (not target or self:Clear(current.Position,target,ray)) then found=current; break end
  for x=-1,1 do for z=-1,1 do
   if x==0 and z==0 then continue end
   local nx,nz=current.X+x,current.Z+z
   local nextKey=key(nx,nz)
   if closed[nextKey] or math.abs(nx)*cell>limit or math.abs(nz)*cell>limit then continue end
   local point=self:Ground(Vector3.new(start.X+nx*cell,current.Position.Y,start.Z+nz*cell),ray)
   if not point then continue end
   local width=cell-.05
   if #workspace:GetPartBoundsInBox(CFrame.new(point),Vector3.new(width,self.Root.Size.Y*.9,width),overlap)>0 or not self:Clear(current.Position,point,ray) then continue end
   local cost=current.Cost+(point-current.Position).Magnitude
   local previous=best[nextKey]
   if not previous or cost<previous.Cost then
    local node={X=nx,Z=nz,Position=point,Cost=cost,Score=cost+heuristic(point),Parent=current}
    best[nextKey]=node
    table.insert(open,node)
   end
  end end
 end
 if not found then return false end
 local route={}
 while found.Parent do table.insert(route,1,found.Position); found=found.Parent end
 if target then table.insert(route,target) end
 -- Skip intermediate cells only when the whole corridor is clear.
 local simplified={}
 local from=start
 local index=1
 while index<=#route do
  local last=index
  for i=index+1,#route do if self:Clear(from,route[i],ray) then last=i else break end end
  table.insert(simplified,route[last]); from=route[last]; index=last+1
 end
 self.Route=simplified
 return #simplified>0
end
function Navigation:Waypoint(goal,ignored)
 local now=os.clock()
 local changed=not self.Goal or (Vector3.new(goal.X,0,goal.Z)-Vector3.new(self.Goal.X,0,self.Goal.Z)).Magnitude>self.Cell
 local waypoint=self.Route[self.Index]
 if waypoint and Vector3.new(waypoint.X-self.Root.Position.X,0,waypoint.Z-self.Root.Position.Z).Magnitude<.12 then
  self.Index+=1; waypoint=self.Route[self.Index]
 end
 if now>=self.NextPlan and (changed or not waypoint or (self.Ray and not self:Clear(self.Root.Position,waypoint,self.Ray))) then
  self:Plan(goal,ignored)
  self.NextPlan=now+1
  waypoint=self.Route[self.Index]
 end
 return waypoint
end
function Navigation:Blocked() self.NextPlan=math.min(self.NextPlan,os.clock()+.2) end
return Navigation
