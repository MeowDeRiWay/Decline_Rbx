-- A local ground grid supports the custom small rigs and non-collidable homes.
local Navigation = {}
Navigation.__index = Navigation
function Navigation.New(model,root)
 return setmetatable({Model=model,Root=root,Cell=math.clamp(math.min(root.Size.X,root.Size.Z)*.2,.1,.25),Route={},Index=1,NextPlan=0},Navigation)
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
 local step=math.max(.15,root.Size.Y*.5)
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
-- The grid spacing controls route resolution, not the size of the body.
-- Face the swept box along travel; an inflated diagonal square rejects real doors.
function Navigation:BodyFrame(position, toward)
 local delta = Vector3.new(toward.X-position.X,0,toward.Z-position.Z)
 return delta.Magnitude > .001 and CFrame.lookAt(position,position+delta) or CFrame.new(position)
end
function Navigation:BodySize()
 return Vector3.new(math.max(.01,self.Root.Size.X-.02),self.Root.Size.Y*.9,math.max(.01,self.Root.Size.Z-.02))
end
function Navigation:Clear(a,b,ray)
 local delta=b-a
 if delta.Magnitude<.001 then return true end
 return workspace:Blockcast(self:BodyFrame(a,b),self:BodySize(),delta,ray)==nil
end
-- A player's center may be too close to a wall for the wider zombie body.
-- Pick a nearby standing position on the same physical side of that wall.
function Navigation:Target(goal,ray,overlap)
 local start=self.Root.Position
 local best,score
 local radius=math.max(self.Root.Size.X,self.Root.Size.Z)/2+.05
 for _,r in ipairs({0,radius,radius*2}) do
  for index=0,(r==0 and 0 or 15) do
   local angle=index*math.pi/8
   local raw=Vector3.new(goal.X+math.cos(angle)*r,start.Y,goal.Z+math.sin(angle)*r)
   local point=self:Ground(raw,ray)
   if not point then continue end
   local frame=self:BodyFrame(point,goal)
   if #workspace:GetPartBoundsInBox(frame,self:BodySize(),overlap)>0 then continue end
   local sight=Vector3.new(goal.X,point.Y,goal.Z)-point
   if sight.Magnitude>.001 and workspace:Raycast(point,sight,ray) then continue end
   local cost=r*10+(point-start).Magnitude
   if not score or cost<score then best,score=point,cost end
  end
  if best then return best end
 end
 return nil
end
-- Door portals provide a coarse route around window sills and room walls.
-- Collision tests still decide whether an authored doorway can be traversed.
function Navigation:DoorRoute(target,ray,overlap)
 local start=self.Root.Position
 local nodes={{Position=start},{Position=target}}
 local doors={}
 for _, object in ipairs(workspace:GetDescendants()) do
  if object:IsA("Model") and (object:GetAttribute("NavigationDoor")==true or string.match(string.lower(object.Name),"^doorway"))
   and object:FindFirstChildWhichIsA("BasePart",true) then
   local frame,size=object:GetBoundingBox()
   local center=Vector3.new(frame.Position.X,start.Y,frame.Position.Z)
   local distance=(center-start).Magnitude
   if distance<=40 then table.insert(doors,{Frame=frame,Size=size,Center=center,Distance=distance}) end
  end
 end
 table.sort(doors,function(a,b) return a.Distance<b.Distance end)
 for index,door in ipairs(doors) do
  if index>24 then break end
  local normal=door.Size.X>=door.Size.Z and door.Frame.LookVector or door.Frame.RightVector
  normal=Vector3.new(normal.X,0,normal.Z)
  if normal.Magnitude<.001 then continue end
  normal=normal.Unit
  local thickness=math.min(door.Size.X,door.Size.Z)
  local offset=math.max(self.Root.Size.X,self.Root.Size.Z)/2+thickness/2+.3
  for _,sign in ipairs({-1,0,1}) do
   local point=self:Ground(door.Center+normal*(offset*sign),ray)
   if point and #workspace:GetPartBoundsInBox(self:BodyFrame(point,point+normal),self:BodySize(),overlap)==0 then
    table.insert(nodes,{Position=point})
   end
  end
 end
 if #nodes==2 then return nil end
 local costs={[1]=0}
 local parents,closed={},{}
 for _=1,#nodes do
  local current,score
  for id,cost in pairs(costs) do
   local estimate=cost+(nodes[id].Position-target).Magnitude
   if not closed[id] and (not score or estimate<score) then current,score=id,estimate end
  end
  if not current then return nil end
  if current==2 then
   local route={}
   while current~=1 do table.insert(route,1,nodes[current].Position); current=parents[current] end
   return route
  end
  closed[current]=true
  for id,node in ipairs(nodes) do
   if closed[id] or id==current then continue end
   local cost=costs[current]+(node.Position-nodes[current].Position).Magnitude
   if (not costs[id] or cost<costs[id]) and self:Clear(nodes[current].Position,node.Position,ray) then
    costs[id],parents[id]=cost,current
   end
  end
 end
 return nil
end
function Navigation:Plan(goal,ignored,cellOverride)
 local start=self.Root.Position
 local ray,overlap=self:Parameters(ignored)
 self.Ray=ray
 self.Route={}
 self.Index=1
 self.Goal=goal
 local target=self:Target(goal,ray,overlap)
 if not target then return false end
 if self:Clear(start,target,ray) then self.Route={target}; return true end
 if not cellOverride then
  local doors=self:DoorRoute(target,ray,overlap)
  if doors then self.Route=doors; return true end
 end
 local cell=cellOverride or self.Cell
 local function key(x,z) return x..":"..z end
 local function heuristic(position) return Vector3.new(position.X-target.X,0,position.Z-target.Z).Magnitude end
 local first={X=0,Z=0,Position=start,Cost=0,Score=heuristic(start)}
 local open={first}
 local best={[key(0,0)]=first}
 local closed={}
 local found
 local limit=math.min(40,heuristic(start)+12)
 for _=1,2000 do
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
   if #workspace:GetPartBoundsInBox(self:BodyFrame(point,point+(point-current.Position)),self:BodySize(),overlap)>0 or not self:Clear(current.Position,point,ray) then continue end
   local cost=current.Cost+(point-current.Position).Magnitude
   local previous=best[nextKey]
   if not previous or cost<previous.Cost then
    local node={X=nx,Z=nz,Position=point,Cost=cost,Score=cost+heuristic(point),Parent=current}
    best[nextKey]=node
    table.insert(open,node)
   end
  end end
 end
 if not found then
  -- A lattice may miss the center of a door only slightly wider than the body.
  -- Refine only failed plans; direct clear routes never pay for this search.
  if cell > .05 then return self:Plan(goal,ignored,math.max(.05,cell/2)) end
  return false
 end
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
