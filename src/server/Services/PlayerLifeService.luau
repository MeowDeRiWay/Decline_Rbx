local Defense=require(game:GetService("ReplicatedStorage").Shared.DefenseRules)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Inventory = require(script.Parent.InventoryService)
local Chests = require(script.Parent.ChestService)
local Motion = require(ReplicatedStorage.Shared.WeaponMotion)
local Beds=require(script.Parent.HospitalBedService)
local BodyFall=require(script.Parent.BodyFallService)
local Animation=require(script.Parent.InteractionAnimationService)
local Service = {}
local knocked=setmetatable({},{__mode="k"})
local finished = setmetatable({},{__mode="k"})
local function freeze(character)
 local held=character:FindFirstChild("HeldItem")
 local motor=held and held:FindFirstChild("WeaponGrip")
 if motor then Motion.Cancel(motor) end
 for _,part in ipairs(character:GetDescendants()) do
  if part:IsA("BasePart") then
   part.Anchored=true
   part.CanCollide=false
   part.CanQuery=true
  end
 end
end
function Service.Finish(player,character)
 if finished[character] or player.Character~=character then return end
 Beds.Leave(player,true)
 Animation.Cancel(character)
 finished[character]=true
 character:SetAttribute("IsDead",true)
 character:SetAttribute("Knockout",false)
 BodyFall.Cancel(character)
 freeze(character)
 character.Archivable=true
 local corpse=character:Clone()
 corpse.Name=player.Name.."Corpse"
 corpse:SetAttribute("DisplayName",player.DisplayName)
 corpse:SetAttribute("IsDead",true)
 corpse:SetAttribute("Knockout",false)
 corpse:SetAttribute("BlocksVision",false)
 corpse:SetAttribute("KnockoutEndsAt",nil)
 corpse:SetAttribute("OwnerUserId",player.UserId)
 for _,object in ipairs(corpse:GetDescendants()) do
  if object:IsA("LuaSourceContainer") or object:IsA("ForceField") then object:Destroy() end
 end
 freeze(corpse)
 local hp=corpse:FindFirstChildOfClass("Humanoid")
 if hp then hp.BreakJointsOnDeath=false; hp.Health=0 end
 corpse:SetAttribute("Health",0)
 local storage=Inventory.ExtractAll(player)
 Chests.CreatePlayerCorpse(corpse,storage)
 local folder=workspace:FindFirstChild("PlayerCorpses")
 if not folder then folder=Instance.new("Folder"); folder.Name="PlayerCorpses"; folder.Parent=workspace end
 corpse.Parent=folder
 BodyFall.Play(corpse,"Death")
 local humanoid=character:FindFirstChildOfClass("Humanoid")
 if humanoid then humanoid.Health=0 end
 -- Hide the old character during the normal respawn delay; the persistent clone
 -- is the sole corpse and is not destroyed by LoadCharacterAsync.
 for _,part in ipairs(character:GetDescendants()) do if part:IsA("BasePart") then part.Transparency=1; part.CanQuery=false end end
 if not player:GetAttribute("TownID") then
  -- The existing 120-second knockout has ended. Only an acknowledgement may
  -- release this player into town selection and a completely new character.
  player:SetAttribute("OutcastEnd",true)
  return
 end
 task.delay(Players.RespawnTime,function()
  if player.Parent==Players and player.Character==character then require(script.Parent.TownService).LoadCharacter(player) end
 end)
end
function Service.Knockout(player,character)
 if character:GetAttribute("Knockout") or finished[character] then return end
 Beds.Leave(player,true)
 Animation.Cancel(character)
 local record={Pivot=character:GetPivot(),Parts={},BlocksVision=character:GetAttribute("BlocksVision")}
 for _,part in ipairs(character:GetDescendants()) do
  if part:IsA("BasePart") then record.Parts[part]={Anchored=part.Anchored,CanCollide=part.CanCollide,CanQuery=part.CanQuery} end
 end
 knocked[character]=record
 character:SetAttribute("Knockout",true)
 character:SetAttribute("Running",false)
 character:SetAttribute("BlocksVision",false)
 character:SetAttribute("KnockoutEndsAt",workspace:GetServerTimeNow()+120)
 local humanoid=character:FindFirstChildOfClass("Humanoid")
 humanoid.WalkSpeed=0
 humanoid.AutoRotate=false
 humanoid.PlatformStand=true
 humanoid.Health=1
 Chests.Close(player)
 freeze(character)
 BodyFall.Play(character,"Knockout")
 task.delay(120,function()
  if player.Parent==Players and player.Character==character and knocked[character]==record and character:GetAttribute("Knockout") then Service.Finish(player,character) end
 end)
end
function Service.Revive(player,lockSeconds,healingBonus)
 local character=player.Character
 local record=character and knocked[character]
 local hp=character and character:FindFirstChildOfClass("Humanoid")
 if not record or not hp or hp.Health<=0 or finished[character] or not character:GetAttribute("Knockout") then return false end
 if workspace:GetServerTimeNow()<(player:GetAttribute("ReviveLockedUntil") or 0) then return false end
 knocked[character]=nil
 BodyFall.Restore(character)
 character:PivotTo(record.Pivot)
 for part,flags in pairs(record.Parts) do
  if part.Parent then part.Anchored=flags.Anchored;part.CanCollide=flags.CanCollide;part.CanQuery=flags.CanQuery end
 end
 hp.PlatformStand=false;hp.AutoRotate=true;hp.Health=math.min(hp.MaxHealth,2+hp.MaxHealth*(player:GetAttribute("ReviveHealthBonus") or 0)+(healingBonus or 0))
 hp:ChangeState(Enum.HumanoidStateType.GettingUp)
 character:SetAttribute("Knockout",false);character:SetAttribute("KnockoutEndsAt",nil)
 character:SetAttribute("Health",hp.Health);character:SetAttribute("BlocksVision",record.BlocksVision)
 player:SetAttribute("ReviveLockedUntil",workspace:GetServerTimeNow()+math.max(0,lockSeconds-(player:GetAttribute("ReviveLockReduction") or 0)))
 return true
end
-- Reconnect clones keep the original knockout pose/flags and death deadline.
function Service.KnockoutRecord(character) return knocked[character] end
function Service.ResumeKnockout(player,character,record)
 knocked[character]=record
 BodyFall.Play(character,"Knockout")
 local remaining=math.max(0,(character:GetAttribute("KnockoutEndsAt") or 0)-workspace:GetServerTimeNow())
 task.delay(remaining,function()
  if player.Parent==Players and player.Character==character and knocked[character]==record and character:GetAttribute("Knockout") then Service.Finish(player,character) end
 end)
end
function Service.OfflineCorpse(character,storage,userID,displayName)
 Animation.Cancel(character)
 character:SetAttribute("IsDead",true);character:SetAttribute("Knockout",false)
 character:SetAttribute("KnockoutEndsAt",nil);character:SetAttribute("OfflineUserId",nil)
 character:SetAttribute("OfflineUntil",nil);character:SetAttribute("BlocksVision",false)
 character:SetAttribute("OwnerUserId",userID);character:SetAttribute("DisplayName",displayName)
 freeze(character)
 BodyFall.Play(character,"Death")
 local hp=character:FindFirstChildOfClass("Humanoid")
 if hp then hp.Health=0 end
 character:SetAttribute("Health",0)
 character.Name=character.Name.."Corpse"
 Chests.CreatePlayerCorpse(character,storage)
 local folder=workspace:FindFirstChild("PlayerCorpses")
 if not folder then folder=Instance.new("Folder");folder.Name="PlayerCorpses";folder.Parent=workspace end
 character.Parent=folder
end
-- Server-authorized acknowledgement; ordinary living players cannot reset a build.
function Service.RestartOutcast(player)
 if player.Parent~=Players or player:GetAttribute("OutcastEnd")~=true or player:GetAttribute("TownID") then return false end
 local character=player.Character
 if character and not character:GetAttribute("IsDead") then return false end
 -- Detach the dead shell before Sync, so creation protection cannot revive it.
 player.Character=nil
 if character then character:Destroy() end
 require(script.Parent.CraftingService).Close(player)
 Inventory.Reset(player)
 require(script.Parent.ProgressionService).NewCharacter(player)
 require(script.Parent.EconomyService).Reset(player)
 for _,key in ipairs({"DoctorReadyAt","ReviveLockedUntil","MedicalMode","Running"}) do player:SetAttribute(key,nil) end
 require(script.Parent.TownService).ResetForCreation(player)
 player:SetAttribute("OutcastEnd",nil)
 return true
end
function Service.Damage(player,humanoid,amount,hitChecked,defenseChecked)
 if player:GetAttribute("AttributesConfirmed")==false then return 0 end
 local character=humanoid.Parent
 if humanoid.Health<=0 or character:GetAttribute("Knockout") or finished[character] then return 0 end
 if not hitChecked and amount>0 and math.random()<math.clamp(((player:GetAttribute("DodgeChance") or 0)+((not character:GetAttribute("HandsItem") or character:GetAttribute("HandsItem")=="") and (player:GetAttribute("UnarmedArmorClass") or 0) or 0))/100,0,1) then return 0 end
 if not defenseChecked then
  amount=Defense.Resolve(amount,(player:GetAttribute("ArmorResistance") or 0)+(player:GetAttribute("DamageResistance") or 0)+(humanoid.Health<humanoid.MaxHealth*.25 and (player:GetAttribute("LowHealthResistance") or 0) or 0),(player:GetAttribute("ArmorAbsorption") or 0)+(player:GetAttribute("DamageAbsorption") or 0))
 end
 local actual=math.min(humanoid.Health,amount)
 if amount>=humanoid.Health then Service.Knockout(player,character)
 else humanoid.Health-=amount end
 return actual
end
return Service
