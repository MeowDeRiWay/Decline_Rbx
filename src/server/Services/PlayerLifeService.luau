local Defense=require(game:GetService("ReplicatedStorage").Shared.DefenseRules)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Inventory = require(script.Parent.InventoryService)
local Chests = require(script.Parent.ChestService)
local Motion = require(ReplicatedStorage.Shared.WeaponMotion)
local Service = {}
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
local function fall(character)
 local root=character:FindFirstChild("HumanoidRootPart")
 if not root then return end
 local start=character:GetPivot()
 local position=root.Position
 local direction=character:GetAttribute("LastHitDirection") or root.CFrame.LookVector
 direction=Vector3.new(direction.X,0,direction.Z)
 direction=direction.Magnitude>.001 and direction.Unit or Vector3.new(0,0,-1)
 local pose=CFrame.lookAt(position,position+direction)*CFrame.Angles(-math.pi/2,0,0)*root.CFrame:Inverse()*start
 character:PivotTo(pose)
 local bottom=math.huge
 local held=character:FindFirstChild("HeldItem")
 for _,part in ipairs(character:GetDescendants()) do
  if part:IsA("BasePart") and part.Transparency<1 and not (held and part:IsDescendantOf(held)) then
   local cf,size=part.CFrame,part.Size
   local radius=math.abs(cf.RightVector.Y)*size.X/2+math.abs(cf.UpVector.Y)*size.Y/2+math.abs(cf.LookVector.Y)*size.Z/2
   bottom=math.min(bottom,cf.Position.Y-radius)
  end
 end
 local excluded={character}
 local homes={}
 for _,model in ipairs(workspace:GetDescendants()) do
  if model:IsA("Model") then
   if model:FindFirstChildOfClass("Humanoid") then table.insert(excluded,model) end
   if model:GetAttribute("Zombie_home")==true then table.insert(homes,model) end
  end
 end
 local params=RaycastParams.new()
 params.FilterType=Enum.RaycastFilterType.Exclude
 params.FilterDescendantsInstances=excluded
 params.RespectCanCollide=true
 local origin=position+Vector3.new(0,2,0)
 local floor=workspace:Raycast(origin,Vector3.new(0,-100,0),params)
 if #homes>0 then
  params.FilterType=Enum.RaycastFilterType.Include
  params.FilterDescendantsInstances=homes
  params.RespectCanCollide=false
  local homeFloor=workspace:Raycast(origin,Vector3.new(0,-100,0),params)
  if homeFloor and (not floor or homeFloor.Position.Y>floor.Position.Y) then floor=homeFloor end
 end
 if floor and bottom<math.huge then character:PivotTo(pose+Vector3.new(0,floor.Position.Y-bottom+.02,0)) end
end
function Service.Finish(player,character)
 if finished[character] or player.Character~=character then return end
 finished[character]=true
 character:SetAttribute("IsDead",true)
 character:SetAttribute("Knockout",false)
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
 local humanoid=character:FindFirstChildOfClass("Humanoid")
 if humanoid then humanoid.Health=0 end
 -- Hide the old character during the normal respawn delay; the persistent clone
 -- is the sole corpse and is not destroyed by LoadCharacterAsync.
 for _,part in ipairs(character:GetDescendants()) do if part:IsA("BasePart") then part.Transparency=1; part.CanQuery=false end end
 task.delay(Players.RespawnTime,function()
  if player.Parent==Players and player.Character==character then require(script.Parent.TownService).LoadCharacter(player) end
 end)
end
function Service.Knockout(player,character)
 if character:GetAttribute("Knockout") or finished[character] then return end
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
 fall(character)
 task.delay(120,function()
  if player.Parent==Players and player.Character==character and character:GetAttribute("Knockout") then Service.Finish(player,character) end
 end)
end
function Service.Damage(player,humanoid,amount,hitChecked,defenseChecked)
 if player:GetAttribute("AttributesConfirmed")==false then return 0 end
 local character=humanoid.Parent
 if humanoid.Health<=0 or character:GetAttribute("Knockout") or finished[character] then return 0 end
 if not hitChecked and amount>0 and math.random()<math.clamp((player:GetAttribute("DodgeChance") or 0)/100,0,1) then return 0 end
 if not defenseChecked then
  amount=Defense.Resolve(amount,(player:GetAttribute("ArmorResistance") or 0)+(player:GetAttribute("DamageResistance") or 0),(player:GetAttribute("ArmorAbsorption") or 0)+(player:GetAttribute("DamageAbsorption") or 0))
 end
 local actual=math.min(humanoid.Health,amount)
 if amount>=humanoid.Health then Service.Knockout(player,character)
 else humanoid.Health-=amount end
 return actual
end
return Service
