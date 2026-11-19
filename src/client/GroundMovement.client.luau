-- Roblox's automatic step-up is oversized for this small character. Sweep the
-- space above the feet before locomotion, allowing shallow floor steps/slopes
-- while preventing walking onto tables, cabinets and other interior obstacles.
local Players=game:GetService("Players")
local Run=game:GetService("RunService")
local params=RaycastParams.new()
params.FilterType=Enum.RaycastFilterType.Exclude
params.RespectCanCollide=true
local function road(part)
 while part and part~=workspace do
  if part:GetAttribute("Road")==true or part.Name:lower()=="roads" then return true end
  part=part.Parent
 end
 return false
end
local function stepRoad(root,hp,frame,size,move,reach,hit)
 if not road(hit.Instance) then return false end
 local maximum=.35
 local feet=root.Position.Y-root.Size.Y/2-hp.HipHeight
 -- Probe beyond the leading edge of the root, independent of facing direction.
 local direction=move.Unit
 local radius=(math.abs(direction:Dot(root.CFrame.RightVector))*root.Size.X+math.abs(direction:Dot(root.CFrame.LookVector))*root.Size.Z)/2
 local ahead=root.Position+direction*(radius+reach+.03)
 local support=workspace:Raycast(Vector3.new(ahead.X,feet+maximum+.04,ahead.Z),Vector3.new(0,-maximum-.08,0),params)
 if not support or support.Normal.Y<.7 or not road(support.Instance) then return false end
 local rise=support.Position.Y-feet
 if rise<=.01 or rise>maximum then return false end
 local lift=Vector3.new(0,rise+.02,0)
 -- A low curb is traversable only if the torso/head and the raised path fit.
 if workspace:Blockcast(frame,size,lift,params)
  or workspace:Blockcast(frame+lift,size,direction*reach,params) then return false end
 root.CFrame=root.CFrame+lift
 return true
end
local function slide(vector,normal)
 local inward=vector:Dot(normal)
 return inward<0 and vector-normal*inward or vector
end
Run.PreSimulation:Connect(function(dt)
 local character=Players.LocalPlayer.Character
 local root=character and character:FindFirstChild("HumanoidRootPart")
 local hp=character and character:FindFirstChildOfClass("Humanoid")
 if not root or not hp or root.Anchored or hp.Health<=0 or hp.Sit or hp.PlatformStand or character:GetAttribute("Knockout") or character:GetAttribute("IsDead") or hp.FloorMaterial==Enum.Material.Air then return end
 local move=hp.MoveDirection
 if move.Magnitude<.001 then return end
 params.FilterDescendantsInstances={character}
 local clearance=.15
 local height=math.max(.05,root.Size.Y+hp.HipHeight-clearance)
 local center=root.Position+Vector3.new(0,(root.Size.Y-height)/2,0)
 local frame=CFrame.new(center)*root.CFrame.Rotation
 local size=Vector3.new(root.Size.X*.9,height,root.Size.Z*.9)
 local velocity=root.AssemblyLinearVelocity
 local reach=math.max(hp.WalkSpeed,Vector3.new(velocity.X,0,velocity.Z).Magnitude)*math.min(dt,.1)+.08
 local hit=workspace:Blockcast(frame,size,move.Unit*reach,params)
 if not hit or hit.Normal.Y>=.7 then return end
 if stepRoad(root,hp,frame,size,move,reach,hit) then return end
 local normal=Vector3.new(hit.Normal.X,0,hit.Normal.Z)
 if normal.Magnitude<.001 then return end
 normal=normal.Unit
 hp:Move(slide(move,normal),false)
 local horizontal=slide(Vector3.new(velocity.X,0,velocity.Z),normal)
 root.AssemblyLinearVelocity=Vector3.new(horizontal.X,velocity.Y,horizontal.Z)
end)

