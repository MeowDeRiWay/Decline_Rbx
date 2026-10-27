local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Items=require(ReplicatedStorage.Shared.ItemConfig)
local Interaction=require(ReplicatedStorage.Shared.Interaction)
local Service={}
local patients,occupied={},{}
local function multiplier(bed)
 local value=bed:GetAttribute("HospitalRegenMultiplier")
 if typeof(value)~="number" or value~=value or math.abs(value)==math.huge then return 3 end
 return math.clamp(value,1,60)
end
function Service.Leave(player,transition)
 local record=patients[player]
 if not record then return false end
 patients[player]=nil;occupied[record.Bed]=nil
 record.Bed:SetAttribute("HospitalBedUserId",nil)
 local character,root,hp=record.Character,record.Root,record.Humanoid
 character:SetAttribute("HospitalResting",false)
 -- KO/death own their frozen pose. Never undo those lifecycle transitions.
 if character.Parent and (hp.Health>0 or transition) and not character:GetAttribute("Knockout") and not character:GetAttribute("IsDead") then
  character:PivotTo(record.Pivot)
  root.Anchored=record.Anchored;root.CanCollide=record.CanCollide
  root.AssemblyLinearVelocity=Vector3.zero;root.AssemblyAngularVelocity=Vector3.zero
  hp.AutoRotate=record.AutoRotate
 end
 return true
end
function Service.Use(player,bed)
 if patients[player] then return Service.Leave(player) end
 if player:GetAttribute("AttributesConfirmed")~=true then return false end
 if typeof(bed)~="Instance" or not bed:IsA("Model") or bed:GetAttribute("HospitalBed")~=true or not bed:IsDescendantOf(workspace) or occupied[bed] then return false end
 local character=player.Character
 local hp=character and character:FindFirstChildOfClass("Humanoid")
 local root=character and character:FindFirstChild("HumanoidRootPart")
 if not root or not hp or hp.Health<=0 or character:GetAttribute("Knockout") or character:GetAttribute("IsDead") or character:GetAttribute("CraftingLocked") or character:GetAttribute("CreatingCharacter") or root.Anchored then return false end
 local surface=bed:FindFirstChild("BedSurface",true) or bed.PrimaryPart or bed:FindFirstChildWhichIsA("BasePart",true)
 if not surface or not surface:IsA("BasePart") then return false end
 local nearest=Interaction.NearestPoint(bed,root.Position)
 if (nearest-root.Position).Magnitude>Items.PickupDistance then return false end
 local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances={character}
 local hit=workspace:Raycast(root.Position,nearest-root.Position,params)
 if hit and not hit.Instance:IsDescendantOf(bed) then return false end
 local point=bed:FindFirstChild("BedPoint",true)
 local frame
 if point and point:IsA("Attachment") then frame=point.WorldCFrame
 else frame=surface.CFrame*CFrame.new(0,surface.Size.Y/2,0) end
 local record={Bed=bed,Character=character,Root=root,Humanoid=hp,Pivot=character:GetPivot(),Anchored=root.Anchored,CanCollide=root.CanCollide,AutoRotate=hp.AutoRotate,NextTick=os.clock()+60/multiplier(bed)}
 patients[player]=record;occupied[bed]=player
 bed:SetAttribute("HospitalBedUserId",player.UserId)
 character:SetAttribute("HospitalResting",true);character:SetAttribute("Running",false)
 hp.AutoRotate=false;root.Anchored=true;root.CanCollide=false
 root.AssemblyLinearVelocity=Vector3.zero;root.AssemblyAngularVelocity=Vector3.zero
 local pose=frame*CFrame.new(0,root.Size.Z/2+.03,0)*CFrame.Angles(-math.pi/2,0,0)
 character:PivotTo(pose*root.CFrame:Inverse()*character:GetPivot())
 return true
end
function Service.Step()
 local now=os.clock()
 for player,record in pairs(patients) do
  local character,hp=record.Character,record.Humanoid
  if player.Parent~=Players or player.Character~=character or not character.Parent or not record.Bed:IsDescendantOf(workspace) or record.Bed:GetAttribute("HospitalBed")~=true or hp.Health<=0 or character:GetAttribute("Knockout") or character:GetAttribute("IsDead") then
   Service.Leave(player,hp.Health<=0 and not character:GetAttribute("Knockout") and not character:GetAttribute("IsDead"))
  elseif now>=record.NextTick then
   record.NextTick=now+60/multiplier(record.Bed)
   local amount=character:GetAttribute("Regeneration") or 0
   if typeof(amount)=="number" and amount==amount and amount>0 and amount<math.huge then
    hp.Health=math.min(hp.MaxHealth,hp.Health+amount)
    character:SetAttribute("Health",hp.Health)
    character:SetAttribute("Sick",math.max(0,(character:GetAttribute("Sick") or 0)-amount))
   end
  end
 end
end
Players.PlayerRemoving:Connect(function(player) Service.Leave(player) end)
task.spawn(function() while true do task.wait(.5);Service.Step() end end)
return Service
