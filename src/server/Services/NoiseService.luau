local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Run=game:GetService("RunService")
local Config=require(ReplicatedStorage.Shared.GameConfig)
local Rules=require(ReplicatedStorage.Shared.NoiseRules)
local Activity=require(script.Parent.ZombieActivity)
local Service={}
local events,sequence={},0
function Service.Emit(position,radius,kind)
 if radius<=0 then return end
 sequence+=1
 table.insert(events,{ID=sequence,Position=position,Radius=math.clamp(radius,0,500),Kind=kind,At=os.clock()})
 while #events>256 or (#events>0 and os.clock()-events[1].At>3) do table.remove(events,1) end
 Activity.Alert(position,math.clamp(radius,0,500))
end
function Service.Listen(position,attention,cursor)
 local best,score=nil,-math.huge
 for _,event in ipairs(events) do
  if event.ID>(cursor or 0) and os.clock()-event.At<=3 then
   local distance=(event.Position-position).Magnitude
   if Rules.Audible(distance,event.Radius,attention) then
    local strength=event.Radius/math.max(1,distance)
    if strength>=score then best=event;score=strength end
   end
  end
 end
 return best,sequence
end
function Service.Start()
 if Service.Started then return end;Service.Started=true
 local positions={};local elapsed=0
 Players.PlayerRemoving:Connect(function(p) positions[p]=nil end)
 Run.Heartbeat:Connect(function(dt)
  elapsed+=dt;if elapsed<.25 then return end;elapsed=0
  for _,p in ipairs(Players:GetPlayers()) do
   local c=p.Character;local root=c and c:FindFirstChild("HumanoidRootPart");local hp=c and c:FindFirstChildOfClass("Humanoid")
   local previous=positions[p]
   if not previous or not root or previous.Root~=root then positions[p]=root and {Root=root,Position=root.Position} or nil end
   if not root or not hp or hp.Health<=0 or p:GetAttribute("AttributesConfirmed")~=true or c:GetAttribute("Knockout") or c:GetAttribute("CraftingLocked") or root.Anchored or hp.FloorMaterial==Enum.Material.Air or not previous or previous.Root~=root then
    positions[p]=root and {Root=root,Position=root.Position} or nil;continue
   end
   local delta=root.Position-previous.Position;local moved=Vector3.new(delta.X,0,delta.Z).Magnitude
   if moved>=.15 then
    positions[p]={Root=root,Position=root.Position}
    if moved>8 then continue end
    Service.Emit(root.Position,Rules.StepRadius(p:GetAttribute("SkillSneak"),c:GetAttribute("Running"),c:GetAttribute("Running") and Config.RunFootstepMaxDistance or Config.FootstepMaxDistance),"Footsteps")
   end
  end
 end)
end
return Service
