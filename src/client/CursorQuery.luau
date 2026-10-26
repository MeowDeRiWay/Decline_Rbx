-- One hover dispatcher and one shared world ray per update, after camera/visibility.
local Players=game:GetService("Players")
local Run=game:GetService("RunService")
local Input=game:GetService("UserInputService")
local View=require(script.Parent.EventVisibility)
local player=Players.LocalPlayer
local Query={}
local listeners={}
local ordered={}
local cached,queried,creatureHit,creatureQueried
local elapsed=0
local function rebuild()
 table.clear(ordered)
 for _,entry in pairs(listeners) do table.insert(ordered,entry) end
 table.sort(ordered,function(a,b) return a.Order<b.Order or (a.Order==b.Order and a.Name<b.Name) end)
end
function Query.Subscribe(name,order,callback)
 local entry={Name=name,Order=order,Callback=callback,LastError=-math.huge}
 listeners[name]=entry;rebuild()
 return function() if listeners[name]==entry then listeners[name]=nil;rebuild() end end
end
function Query.Get()
 if queried then return cached end
 queried=true
 local camera=workspace.CurrentCamera
 if not camera then return nil end
 local mouse=Input:GetMouseLocation()
 if mouse.X<0 or mouse.Y<0 or mouse.X>camera.ViewportSize.X or mouse.Y>camera.ViewportSize.Y then return nil end
 local ray=camera:ViewportPointToRay(mouse.X,mouse.Y)
 local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude
 params.FilterDescendantsInstances=player.Character and {player.Character} or {}
 cached={Mouse=mouse,Ray=ray,Hit=workspace:Raycast(ray.Origin,ray.Direction*1000,params)}
 return cached
end
function Query.CreatureHit()
 if creatureQueried then return creatureHit end
 creatureQueried=true
 local sample=Query.Get();if not sample then return nil end
 local candidates={}
 for model in pairs(View.Targets) do
  if model~=player.Character and model.Parent and model:GetAttribute("ClientVisible")==true then table.insert(candidates,model) end
 end
 if #candidates==0 then return nil end
 local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Include;params.FilterDescendantsInstances=candidates
 creatureHit=workspace:Raycast(sample.Ray.Origin,sample.Ray.Direction*1000,params)
 return creatureHit
end
Run:BindToRenderStep("DeclineCursorQueries",Enum.RenderPriority.Last.Value+3,function(dt)
 elapsed+=dt;if elapsed<1/30 then return end;elapsed%=1/30
 cached,queried,creatureHit,creatureQueried=nil,false,nil,false
 debug.profilebegin("Decline.CursorQueries")
 for _,entry in ipairs(ordered) do
  local ok,message=xpcall(entry.Callback,debug.traceback)
  if not ok and os.clock()-entry.LastError>5 then entry.LastError=os.clock();warn("[Decline Hover] "..entry.Name..": "..message) end
 end
 debug.profileend()
end)
return Query
