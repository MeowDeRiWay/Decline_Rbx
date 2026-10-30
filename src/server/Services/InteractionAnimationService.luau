-- Short, server-authorized interaction phases. The held weapon never leaves the
-- character/inventory, so the cosmetic weapon on the ground is not a pickup.
local Shared=game:GetService("ReplicatedStorage").Shared
local Pose=require(Shared.InteractionPose)
local Interaction=require(Shared.Interaction)
local Motion=require(Shared.WeaponMotion)
local Service={}
local active=setmetatable({},{__mode="k"})
local function alive(r)
 return r.Player.Character==r.Character and r.Character.Parent and r.HP.Health>0 and not r.Character:GetAttribute("Knockout") and not r.Character:GetAttribute("IsDead")
end
local function phase(r,mode)
 r.Character:SetAttribute("InteractionStartedAt",workspace:GetServerTimeNow())
 r.Character:SetAttribute("InteractionMode",mode)
end
function Service.Cancel(c)
 local r=active[c]
 if not r then return end
 active[c]=nil
 for _,link in ipairs(r.Links) do link:Disconnect() end
 local held=c:FindFirstChild("HeldItem")
 local motor=held and held:FindFirstChild("WeaponGrip")
 if motor then motor.Transform=CFrame.identity end
 -- Lifecycle callers cancel BEFORE taking their own frozen-state snapshot.
 if r.Root.Parent and not c:GetAttribute("Knockout") and not c:GetAttribute("IsDead") then
  r.Root.Anchored=r.Anchored;r.HP.AutoRotate=r.AutoRotate;r.HP.WalkSpeed=r.Speed
 end
 c:SetAttribute("InteractionMode",nil)
 c:SetAttribute("InteractionLocked",nil)
 c:SetAttribute("InteractionPoint",nil)
 c:SetAttribute("InteractionHand",nil)
 c:SetAttribute("InteractionStartedAt",nil)
 c:SetAttribute("InteractionRiseFrom",nil)
 c:SetAttribute("InteractionLayFrom",nil)
end
local function begin(player,target,range,aimPoint)
 local c=player.Character
 local root=c and c:FindFirstChild("HumanoidRootPart")
 local hp=c and c:FindFirstChildOfClass("Humanoid")
 if not root or not hp or hp.Health<=0 or hp.Sit or hp.PlatformStand or root.Anchored or c:GetAttribute("InteractionLocked") or c:GetAttribute("Knockout") or c:GetAttribute("IsDead") or c:GetAttribute("HospitalResting") or c:GetAttribute("CraftingLocked") or (c:GetAttribute("Reloading") or c:GetAttribute("HandsBusy")) then return end
 if typeof(target)~="Instance" or not target:IsDescendantOf(workspace) or (not target:IsA("Model") and not target:IsA("BasePart")) then return end
 local point=Interaction.NearestPoint(target,root.Position)
 if (point-root.Position).Magnitude>range then return end
 local r={Player=player,Character=c,Root=root,HP=hp,Target=target,Anchored=root.Anchored,AutoRotate=hp.AutoRotate,Speed=hp.WalkSpeed,Links={}}
 active[c]=r
 local held=c:FindFirstChild("HeldItem")
 local motor=held and held:FindFirstChild("WeaponGrip")
 if motor then Motion.Cancel(motor);motor.C0=motor:GetAttribute("RestC0") or motor.C0;motor.Transform=CFrame.identity end
 c:SetAttribute("InteractionSequence",(c:GetAttribute("InteractionSequence") or 0)+1)
 c:SetAttribute("PunchStartedAt",nil)
 local aim=aimPoint or point
 c:SetAttribute("InteractionPoint",aim)
 c:SetAttribute("InteractionHand",held and "Left" or "Right")
 c:SetAttribute("InteractionLocked",true);c:SetAttribute("Running",false)
 hp.WalkSpeed=0;hp.AutoRotate=false
 root.AssemblyLinearVelocity=Vector3.zero;root.AssemblyAngularVelocity=Vector3.zero
 local delta=Vector3.new(aim.X-root.Position.X,0,aim.Z-root.Position.Z)
 if delta.Magnitude>.01 then root.CFrame=CFrame.lookAt(root.Position,root.Position+delta) end
 root.Anchored=true
 table.insert(r.Links,c:GetAttributeChangedSignal("Knockout"):Connect(function() if c:GetAttribute("Knockout") then Service.Cancel(c) end end))
 table.insert(r.Links,c:GetAttributeChangedSignal("IsDead"):Connect(function() if c:GetAttribute("IsDead") then Service.Cancel(c) end end))
 table.insert(r.Links,c.Destroying:Connect(function() Service.Cancel(c) end))
 table.insert(r.Links,player.CharacterRemoving:Connect(function(old) if old==c then Service.Cancel(c) end end))
 return r
end
function Service.Reach(player,target,range,activate)
 local r=begin(player,target,range)
 if not r then return false end
 phase(r,"Reach")
 task.delay(Pose.ReachContact,function()
  if active[r.Character]~=r or not alive(r) or not target:IsDescendantOf(workspace) then return end
  -- The actual action validates ownership, distance and LOS again at contact.
  local ok,err=xpcall(activate,debug.traceback)
  if not ok then warn("[Decline Interaction] "..err);Service.Cancel(r.Character) end
 end)
 task.delay(Pose.ReachDuration,function() if active[r.Character]==r then Service.Cancel(r.Character) end end)
 return true
end
function Service.BeginLoot(player,target,range,opened)
 -- A whole corpse bounding box includes root/limbs/equipment and may put its
 -- nearest point directly in the player's lap. Search the visible torso instead.
 local torso=typeof(target)=="Instance" and (target:FindFirstChild("UpperTorso") or target:FindFirstChild("LowerTorso"))
 local point=torso and torso:IsA("BasePart") and torso.Position or nil
 local r=begin(player,target,range,point)
 if not r then return false end
 phase(r,"LootDown")
 task.delay(Pose.DownDuration,function()
  if active[r.Character]~=r or r.Character:GetAttribute("InteractionMode")~="LootDown" then return end
  if not alive(r) then Service.Cancel(r.Character);return end
  if not target:IsDescendantOf(workspace) then Service.EndLoot(player);return end
  phase(r,"Loot")
  local ok,result=xpcall(opened,debug.traceback)
  if not ok then warn("[Decline Interaction] "..result) end
  if not ok or result==false then Service.EndLoot(player) end
 end)
 return true
end
function Service.EndLoot(player)
 local c=player.Character
 local r=c and active[c]
 local mode=c and c:GetAttribute("InteractionMode")
 if not r or (mode~="Loot" and mode~="LootDown") then return end
 if not alive(r) then Service.Cancel(c);return end
 local crouch,laid=Pose.State(mode,workspace:GetServerTimeNow()-(c:GetAttribute("InteractionStartedAt") or 0))
 c:SetAttribute("InteractionRiseFrom",crouch)
 c:SetAttribute("InteractionLayFrom",laid)
 phase(r,"LootUp")
 task.delay(Pose.UpDuration,function() if active[c]==r then Service.Cancel(c) end end)
end
return Service
