-- Ownership stays in the inventory's two weapon slots; timed commits only select
-- what is in the hands. A stale callback can never draw/heal after a KO or respawn.
local Players=game:GetService("Players")
local Shared=game:GetService("ReplicatedStorage").Shared
local Pose=require(Shared.HandActionPose)
local Motion=require(Shared.WeaponMotion)
local Inventory=require(script.Parent.InventoryService)
local Service={}
local active=setmetatable({},{__mode="k"})
local function valid(r)
 local c=r.Character
 return r.Player.Parent==Players and r.Player.Character==c and Inventory.Export(r.Player)==r.State and c.Parent and r.HP.Health>0 and not c:GetAttribute("Knockout") and not c:GetAttribute("IsDead") and not c:GetAttribute("HospitalResting") and not c:GetAttribute("CarryingUserId") and not c:GetAttribute("CraftingLocked") and not c:GetAttribute("InteractionLocked") and not r.Player:GetAttribute("TradeOpen")
end
function Service.Cancel(player)
 local r=active[player];if not r then return end
 active[player]=nil
 local c=r.Character
 for _,key in ipairs({"HandsBusy","HandAction","HandActionStartedAt","HandActionSlot","HandActionFromSlot","MedicalTreating","HandTreatmentPoint"}) do c:SetAttribute(key,nil) end
 local held=c:FindFirstChild("HeldItem");local motor=held and held:FindFirstChild("WeaponGrip")
 if motor then motor.Transform=CFrame.identity end
 Inventory.Refresh(player)
end
local function begin(player)
 local c=player.Character;local hp=c and c:FindFirstChildOfClass("Humanoid")
 local root=c and c:FindFirstChild("HumanoidRootPart")
 if not root or not hp or root.Anchored or hp.Sit or hp.PlatformStand or active[player] or player:GetAttribute("AttributesConfirmed")~=true or c:GetAttribute("Reloading") or c:GetAttribute("HandsBusy") then return end
 local r={Player=player,Character=c,HP=hp,Root=root,State=Inventory.Export(player)}
 if not valid(r) then return end
 local held=c:FindFirstChild("HeldItem");local motor=held and held:FindFirstChild("WeaponGrip")
 if motor then Motion.Cancel(motor);motor.C0=motor:GetAttribute("RestC0") or motor.C0;motor.Transform=CFrame.identity end
 c:SetAttribute("InteractionSequence",(c:GetAttribute("InteractionSequence") or 0)+1)
 c:SetAttribute("PunchStartedAt",nil);c:SetAttribute("HandsBusy",true)
 active[player]=r;return r
end
local function phase(r,mode,slot,duration,contact,commit,done)
 local c=r.Character
 c:SetAttribute("HandActionFromSlot",mode=="Draw" and r.StowedSlot or nil)
 c:SetAttribute("HandActionSlot",slot);c:SetAttribute("HandActionStartedAt",workspace:GetServerTimeNow());c:SetAttribute("HandAction",mode)
 task.delay(contact,function()
  if active[r.Player]~=r then return end
  if not valid(r) then Service.Cancel(r.Player);return end
  if commit()==false then Service.Cancel(r.Player) end
 end)
 task.delay(duration,function()
  if active[r.Player]~=r then return end
  if not valid(r) then Service.Cancel(r.Player);return end
  done()
 end)
end
local function stow(r,done)
 local state=Inventory.Export(r.Player)
 local slot=state and (state.ActiveWeaponSlot or (state.MedicalHeld and "Medicine") or (state.Equipment.Hands and "Hands"))
 if not slot then done();return end
 r.StowedSlot=slot
 phase(r,"Stow",slot,Pose.StowDuration,Pose.StowContact,function() return Inventory.ClearHands(r.Player) end,done)
end
function Service.Stow(player,finished)
 local r=begin(player);if not r then return false end
 stow(r,function() Service.Cancel(player);if finished then finished() end end)
 return true
end
local function select(player,slot)
 local r=begin(player);if not r then return false end
 stow(r,function()
  if not slot then Service.Cancel(player);return end
  phase(r,"Draw",slot,Pose.DrawDuration,Pose.DrawContact,function()
   return slot=="Medicine" and Inventory.ActivateMedicine(player) or slot~="Medicine" and Inventory.ActivateWeapon(player,slot)
  end,function() Service.Cancel(player) end)
 end)
 return true
end
function Service.Switch(player,slot)
 if slot~="PrimaryWeapon" and slot~="SecondaryWeapon" then return false end
 local state=Inventory.Export(player)
 if not state or not state.Equipment[slot] then return false end
 if state.ActiveWeaponSlot~=slot and not Inventory.CanActivateWeapon(player,slot) then return false end
 return select(player,state.ActiveWeaponSlot~=slot and slot or nil)
end
function Service.Medicine(player,ready)
 local state=Inventory.Export(player)
 if not state or (ready and not state.Equipment.Medicine) then return false end
 return select(player,ready and "Medicine" or nil)
end
function Service.Toggle(player)
 local state=Inventory.Export(player);if not state then return false end
 if state.ActiveWeaponSlot or state.MedicalHeld or state.Equipment.Hands then return select(player,nil) end
 return state.LastWeaponSlot and Service.Switch(player,state.LastWeaponSlot) or false
end
function Service.Treat(player,target,apply)
 local state=Inventory.Export(player)
 if not state or not state.MedicalHeld or not state.Equipment.Medicine then return false end
 local medicine=state.Equipment.Medicine
 local r=begin(player);if not r then return false end
 local patient=target.Character
 local body=patient and (patient:FindFirstChild("UpperTorso") or patient:FindFirstChild("HumanoidRootPart"))
 if not body then Service.Cancel(player);return false end
 r.Character:SetAttribute("MedicalTreating",true);r.Character:SetAttribute("Running",false)
 r.HP.WalkSpeed=0
 r.Character:SetAttribute("HandTreatmentPoint",body.Position)
 if target~=player then
  local delta=Vector3.new(body.Position.X-r.Root.Position.X,0,body.Position.Z-r.Root.Position.Z)
  if delta.Magnitude>.01 then r.Root.CFrame=CFrame.lookAt(r.Root.Position,r.Root.Position+delta) end
 end
 phase(r,target==player and "TreatSelf" or "TreatOther","Medicine",Pose.TreatDuration,Pose.TreatContact,function()
  if target.Character~=patient or state.Equipment.Medicine~=medicine or not state.MedicalHeld then return false end
  return apply()
 end,function() Service.Cancel(player) end)
 return true
end
Players.PlayerRemoving:Connect(Service.Cancel)
return Service
