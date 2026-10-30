local Players=game:GetService("Players")
local Run=game:GetService("RunService")
local Shared=game:GetService("ReplicatedStorage").Shared
local Config=require(Shared.MedicalConfig)
local Pose=require(Shared.CarryPose)
local Life=require(script.Parent.PlayerLifeService)
local Fall=require(script.Parent.BodyFallService)
local Beds=require(script.Parent.HospitalBedService)
local Inventory=require(script.Parent.InventoryService)
local Chests=require(script.Parent.ChestService)
local Service={}
local carrying,carriedBy={},{}
local function active(player)
 local c=player.Character;local hp=c and c:FindFirstChildOfClass("Humanoid")
 return player.Parent==Players and not player:GetAttribute("TradeOpen") and c and hp and hp.Health>0 and not c:GetAttribute("Knockout") and not c:GetAttribute("IsDead") and not c:GetAttribute("CraftingLocked") and not (c:GetAttribute("InteractionLocked") or c:GetAttribute("HandsBusy")) and not c:GetAttribute("HospitalResting") and player:GetAttribute("AttributesConfirmed")==true and c:FindFirstChild("HumanoidRootPart")
end
function Service.Patient(player) local r=carrying[player];return r and r.Patient end
function Service.Drop(player)
 local record=carrying[player]
 if not record then return false end
 carrying[player]=nil;carriedBy[record.Patient]=nil
 if record.CarrierCharacter then record.CarrierCharacter:SetAttribute("CarryingUserId",nil) end
 record.Character:SetAttribute("CarriedByUserId",nil)
 local root=record.CarrierCharacter and record.CarrierCharacter:FindFirstChild("HumanoidRootPart")
 local frame=root and root.CFrame or record.Upright
 if root then
  local desired=frame*CFrame.new(0,0,-1)
  local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances={record.CarrierCharacter,record.Character};params.RespectCanCollide=true
  if not workspace:Raycast(root.Position,desired.Position-root.Position,params) then frame=desired end
 end
 if record.Patient.Character==record.Character and record.Character.Parent and record.Character:GetAttribute("Knockout") then Life.MoveKnockout(record.Patient,frame) end
 return true
end
function Service.ReleasePlayer(player)
 Service.Drop(player)
 local carrier=carriedBy[player]
 if carrier then Service.Drop(carrier) end
end
function Service.Pickup(player,patient)
 if typeof(patient)~="Instance" or not patient:IsA("Player") or patient==player or patient.Parent~=Players or carrying[player] or carriedBy[player] or carriedBy[patient] or carrying[patient] then return false end
 local root=active(player);local character=patient.Character
 local body=character and character:FindFirstChild("HumanoidRootPart")
 if not root or not body or not character:GetAttribute("Knockout") or character:GetAttribute("HospitalResting") or character:GetAttribute("IsDead") or (root.Position-body.Position).Magnitude>Config.InteractionDistance then return false end
 local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances={player.Character};params.RespectCanCollide=true
 local hit=workspace:Raycast(root.Position,body.Position-root.Position,params)
 if hit and not hit.Instance:IsDescendantOf(character) then return false end
 Chests.Close(player);require(script.Parent.CraftingService).Close(player)
 Inventory.ClearHands(player)
 if not Fall.Carry(character,Pose.Frame(player.Character,body,root)) then return false end
 local record={Patient=patient,Character=character,CarrierCharacter=player.Character,Upright=root.CFrame}
 carrying[player]=record;carriedBy[patient]=player
 character:SetAttribute("CarriedByUserId",player.UserId);player.Character:SetAttribute("CarryingUserId",patient.UserId)
 for _,p in ipairs(character:GetDescendants()) do if p:IsA("BasePart") then p.Anchored=true;p.CanCollide=false end end
 return true
end
function Service.PlaceOnBed(player,bed)
 local patient=Service.Patient(player)
 if not patient or not active(player) or not Beds.CanPlace(player,bed,patient) then return false end
 Service.Drop(player)
 return Beds.PlacePatient(player,patient,bed)
end
Run.Heartbeat:Connect(function()
 for player,record in pairs(carrying) do
  local root=active(player)
  if not root or player.Character~=record.CarrierCharacter or record.Patient.Parent~=Players or record.Patient.Character~=record.Character or not record.Character.Parent or not record.Character:GetAttribute("Knockout") then Service.Drop(player)
  else
   record.Upright=root.CFrame
   local body=record.Character:FindFirstChild("HumanoidRootPart")
   if not body then Service.Drop(player)
   else
    local target=Pose.Frame(record.CarrierCharacter,body,root)
    record.Character:PivotTo(target*body.CFrame:Inverse()*record.Character:GetPivot())
   end
  end
 end
end)
Players.PlayerRemoving:Connect(Service.ReleasePlayer)
return Service
