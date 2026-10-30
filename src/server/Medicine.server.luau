local Literal=require(game:GetService("ReplicatedStorage").Shared.LocalizationRules)
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Inventory=require(script.Parent.Services.InventoryService)
local Progression=require(script.Parent.Services.ProgressionService)
local Life=require(script.Parent.Services.PlayerLifeService)
local Journal=require(script.Parent.Services.JournalService)
local Rules=require(ReplicatedStorage.Shared.ProgressionRules)
local Medical=require(ReplicatedStorage.Shared.MedicalRules)
local Config=require(ReplicatedStorage.Shared.MedicalConfig)
local Sight=require(ReplicatedStorage.Shared.Sight)
local remote=Instance.new("RemoteEvent");remote.Name="MedicalAction";remote.Parent=ReplicatedStorage
local Hands=require(script.Parent.Services.HandActionService)
local last,doctorReady={},{}
local random=Random.new()
local handle
handle=function(player,mode,target,contact)
 if mode~="Bandage" and mode~="Doctor" then return end
 if typeof(target)~="Instance" or not target:IsA("Player") or target.Parent~=Players then return end
 local now=workspace:GetServerTimeNow()
 if not contact then
  if now-(last[player] or -math.huge)<.5 then return end
  last[player]=now
 end
 local character=player.Character
 local root=character and character:FindFirstChild("HumanoidRootPart")
 local hp=character and character:FindFirstChildOfClass("Humanoid")
 if character and character:GetAttribute("HandsBusy") and not contact then return end
 if not root or not hp or hp.Health<=0 or player:GetAttribute("AttributesConfirmed")~=true or character:GetAttribute("Knockout") or character:GetAttribute("IsDead") or character:GetAttribute("CraftingLocked") then return end
 local patient=target.Character
 local body=patient and patient:FindFirstChild("HumanoidRootPart")
 local health=patient and patient:FindFirstChildOfClass("Humanoid")
 if not body or not health or health.Health<=0 or patient:GetAttribute("IsDead") or target:GetAttribute("AttributesConfirmed")~=true or (body.Position-root.Position).Magnitude>3 then return end
 if target~=player then
  local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances={character};params.RespectCanCollide=true
  local obstacle=workspace:Raycast(root.Position,body.Position-root.Position,params)
  if obstacle and not obstacle.Instance:IsDescendantOf(patient) then return end
  obstacle=Sight.Cast(root.Position,body.Position-root.Position,character)
  if obstacle and not obstacle.Instance:IsDescendantOf(patient) then return end
 end
 if mode=="Bandage" then
  if not character:GetAttribute("MedicalHeld") then return end
  if not contact then
   return Hands.Treat(player,target,function() return handle(player,mode,target,true) end)
  end
  local medicine=character:GetAttribute("MedicineItem")
  local sterile=medicine=="SterileBandage"
  local antiseptic=medicine=="Antiseptic"
  local reduction=Medical.SickReduction(medicine,player:GetAttribute("SkillFirstAid"),player:GetAttribute("Paramedic"))
  local sick=patient:GetAttribute("Sick") or 0
  local poisoned=patient:GetAttribute("Poisoned")==true
  if antiseptic and sick<=0 and not poisoned then return end
  if not antiseptic and health.Health>=health.MaxHealth and not (sterile and (sick>0 or poisoned)) then return end
  if not Inventory.UseMedicine(player) then Journal.Send(player,"Equip a medical item in the Medicine slot first.");return end
  local amount=antiseptic and 0 or math.min(health.MaxHealth-health.Health,Rules.FirstAid(player:GetAttribute("SkillFirstAid"),player:GetAttribute("FirstAidMultiplier"),target:GetAttribute("Endurance"),medicine,player:GetAttribute("MedicalHealingBonus")))
  health.Health+=amount;patient:SetAttribute("Health",health.Health)
  if sterile or antiseptic then
   local removed=math.min(sick,reduction)
   patient:SetAttribute("Sick",math.max(0,sick-reduction))
   Journal.Send(player,string.format("Treatment removed %g Sick.",removed))
   if target~=player then Journal.Send(target,string.format("Treatment removed %g Sick.",removed)) end
   if poisoned then
    local chance=antiseptic and Medical.CureChance(player:GetAttribute("Luck"),Config) or .5
    local cured=random:NextNumber()<chance
    if cured then patient:SetAttribute("Poisoned",false) end
    Journal.Send(player,cured and "Poisoning cured." or "The treatment did not cure poisoning.")
    if target~=player then Journal.Send(target,cured and "Poisoning cured." or "The treatment did not cure poisoning.") end
   end
  end
  if amount>0 then Journal.Send(player,string.format("You restored %g HP to %s.",amount,target==player and "yourself" or Literal.Protect(target.Name))) end
  if target~=player and amount>0 then
   Progression.Award(player,amount)
   Journal.Send(target,string.format("%s restored %g HP to you.",Literal.Protect(player.Name),amount))
  end
  return true
 else
  if target==player or not patient:GetAttribute("Knockout") then return end
  if now<math.max(doctorReady[player] or 0,player:GetAttribute("DoctorReadyAt") or 0) then Journal.Send(player,"Doctor is on cooldown.");return end
  if now<(target:GetAttribute("ReviveLockedUntil") or 0) then Journal.Send(player,"This patient cannot be revived yet.");return end
  doctorReady[player]=now+10;player:SetAttribute("DoctorReadyAt",now+10)
  if random:NextNumber()>=Rules.ReviveChance(player:GetAttribute("SkillDoctor")) then Journal.Send(player,"Your revival attempt failed.");return end
  local fortunate=random:NextNumber()<(player:GetAttribute("DoctorFortuneChance") or 0)
  if Life.Revive(target,fortunate and 0 or (player:GetAttribute("ReviveLockSeconds") or 600),player:GetAttribute("MedicalHealingBonus")) then
   if fortunate then health.Health=health.MaxHealth;patient:SetAttribute("Health",health.Health);target:SetAttribute("ReviveLockedUntil",0) end
   Progression.Award(player,100)
   Journal.Send(player,"You revived "..Literal.Protect(target.Name)..".")
   Journal.Send(target,Literal.Protect(player.Name).." revived you.")
  end
 end
end
remote.OnServerEvent:Connect(function(player,mode,target) handle(player,mode,target,false) end)
Players.PlayerRemoving:Connect(function(player) last[player]=nil;doctorReady[player]=nil end)
