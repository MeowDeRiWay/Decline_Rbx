local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Items=require(ReplicatedStorage.Shared.ItemConfig)
local Interaction=require(ReplicatedStorage.Shared.Interaction)
local Journal=require(script.Parent.JournalService)
local Debuffs=require(script.Parent.DebuffService)
local Service={}
local patients,occupied={},{}
local function multiplier(bed)
 local value=bed:GetAttribute("HospitalRegenMultiplier")
 if typeof(value)~="number" or value~=value or math.abs(value)==math.huge then return 3 end
 return math.clamp(value,1,60)
end
local function bedFrame(bed)
 local surface=bed:FindFirstChild("BedSurface",true) or bed.PrimaryPart or bed:FindFirstChildWhichIsA("BasePart",true)
 if not surface or not surface:IsA("BasePart") then return nil end
 local point=bed:FindFirstChild("BedPoint",true)
 return point and point:IsA("Attachment") and point.WorldCFrame or surface.CFrame*CFrame.new(0,surface.Size.Y/2,0)
end
local function pose(record)
 local root=record.Root;local character=record.Character
 local frame=bedFrame(record.Bed)
 if not frame then return end
 root.Anchored=true;root.CanCollide=false;record.Humanoid.AutoRotate=false
 root.AssemblyLinearVelocity=Vector3.zero;root.AssemblyAngularVelocity=Vector3.zero
 local target=frame*CFrame.new(0,root.Size.Z/2+.03,0)*CFrame.Angles(-math.pi/2,0,0)
 character:PivotTo(target*root.CFrame:Inverse()*character:GetPivot())
end
function Service.CanPlace(player,bed,patient)
 if typeof(bed)~="Instance" or not bed:IsA("Model") or bed:GetAttribute("HospitalBed")~=true or not bed:IsDescendantOf(workspace) or occupied[bed] or not bedFrame(bed) then return false end
 local character=player.Character;local root=character and character:FindFirstChild("HumanoidRootPart")
 local hp=character and character:FindFirstChildOfClass("Humanoid")
 if not root or not hp or hp.Health<=0 or player:GetAttribute("AttributesConfirmed")~=true or character:GetAttribute("Knockout") or character:GetAttribute("IsDead") or character:GetAttribute("CraftingLocked") or character:GetAttribute("CreatingCharacter") or root.Anchored then return false end
 local nearest=Interaction.NearestPoint(bed,root.Position)
 if (nearest-root.Position).Magnitude>Items.PickupDistance then return false end
 local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances={character}
 if patient and patient~=player and patient.Character then table.insert(params.FilterDescendantsInstances,patient.Character) end
 local hit=workspace:Raycast(root.Position,nearest-root.Position,params)
 return not hit or hit.Instance:IsDescendantOf(bed)
end
function Service.Leave(player,transition)
 local record=patients[player]
 if not record then return false end
 patients[player]=nil;occupied[record.Bed]=nil;record.Bed:SetAttribute("HospitalBedUserId",nil)
 local character,root,hp=record.Character,record.Root,record.Humanoid
 character:SetAttribute("HospitalResting",false)
 if character.Parent and (hp.Health>0 or transition) and not character:GetAttribute("Knockout") and not character:GetAttribute("IsDead") then
  character:PivotTo(record.Pivot);root.Anchored=record.Anchored;root.CanCollide=record.CanCollide
  root.AssemblyLinearVelocity=Vector3.zero;root.AssemblyAngularVelocity=Vector3.zero;hp.AutoRotate=record.AutoRotate
 end
 return true
end
function Service.PlacePatient(operator,player,bed)
 if patients[player] or not Service.CanPlace(operator,bed,player) then return false end
 local character=player.Character;local hp=character and character:FindFirstChildOfClass("Humanoid")
 local root=character and character:FindFirstChild("HumanoidRootPart")
 if not root or not hp or hp.Health<=0 or character:GetAttribute("IsDead") then return false end
 if player~=operator and not character:GetAttribute("Knockout") then return false end
 local ko=character:GetAttribute("Knockout")
 if ko then require(script.Parent.BodyFallService).Restore(character) end
 local record={Bed=bed,Character=character,Root=root,Humanoid=hp,Pivot=character:GetPivot(),Anchored=not ko and root.Anchored or false,CanCollide=ko or root.CanCollide,AutoRotate=ko or hp.AutoRotate,LastStep=os.clock(),NextTick=os.clock()+60/multiplier(bed)}
 patients[player]=record;occupied[bed]=player;bed:SetAttribute("HospitalBedUserId",player.UserId)
 character:SetAttribute("HospitalResting",true);character:SetAttribute("Running",false)
 pose(record);return true
end
function Service.Reposition(player) if patients[player] then pose(patients[player]) end end
function Service.Use(player,bed)
 if patients[player] then
  if player.Character and player.Character:GetAttribute("Knockout") then return false end
  return Service.Leave(player)
 end
 return Service.PlacePatient(player,player,bed)
end
function Service.Step()
 local now=os.clock()
 for player,record in pairs(patients) do
  local character,hp=record.Character,record.Humanoid
  if player.Parent~=Players or player.Character~=character or not character.Parent or not record.Bed:IsDescendantOf(workspace) or record.Bed:GetAttribute("HospitalBed")~=true or hp.Health<=0 or character:GetAttribute("IsDead") then
   Service.Leave(player,hp.Health<=0 and not character:GetAttribute("Knockout") and not character:GetAttribute("IsDead"))
  else
   local dt=math.max(0,now-record.LastStep);record.LastStep=now
   local treating=(character:GetAttribute("Sick") or 0)>0 or character:GetAttribute("Poisoned")
   local clear=Debuffs.Treat(character,dt)
   if treating then record.NextTick=now+60/multiplier(record.Bed) end
   if clear and (character:GetAttribute("Food") or 100)>0 and (character:GetAttribute("Water") or 100)>0 and now>=record.NextTick then
    record.NextTick=now+60/multiplier(record.Bed)
    if character:GetAttribute("Knockout") then
     player:SetAttribute("ReviveLockedUntil",0)
     if require(script.Parent.PlayerLifeService).Revive(player,0,0) then pose(record) end
    end
    local amount=character:GetAttribute("Regeneration") or 0
    if typeof(amount)=="number" and amount==amount and amount>0 and amount<math.huge then
     local before=hp.Health;hp.Health=math.min(hp.MaxHealth,hp.Health+amount)
     if hp.Health>before then Journal.Send(player,string.format("Regeneration restored %g HP.",hp.Health-before)) end
     character:SetAttribute("Health",hp.Health)
    end
   end
  end
 end
end
Players.PlayerRemoving:Connect(function(player) Service.Leave(player) end)
task.spawn(function() while true do task.wait(.5);Service.Step() end end)
return Service
