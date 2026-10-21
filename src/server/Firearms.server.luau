local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Inventory=require(script.Parent.Services.InventoryService)
local Projectiles=require(script.Parent.Services.FirearmProjectiles)
local Audio=require(script.Parent.Services.FirearmAudio)
local Progression=require(script.Parent.Services.ProgressionService)
local Items=require(ReplicatedStorage.Shared.ItemConfig).Items
local Rules=require(ReplicatedStorage.Shared.FirearmRules)
local Journal=require(script.Parent.Services.JournalService)
local states={}
local random=Random.new()
local action=Instance.new("RemoteEvent");action.Name="FirearmAction";action.Parent=ReplicatedStorage
local function context(player)
 local character=player.Character
 local hp=character and character:FindFirstChildOfClass("Humanoid")
 local root=character and character:FindFirstChild("HumanoidRootPart")
 local id=character and character:GetAttribute("HandsItem")
 local definition=id and Items[id]
 if not root or not hp or hp.Health<=0 or character:GetAttribute("Knockout") or character:GetAttribute("IsDead") or not definition or not definition.Firearm then return end
 if definition.Requirements and not Progression.Meets(player,definition.Requirements) then return end
 return character,root,id,definition.Firearm
end
local function stateFor(player,character,id)
 local data=Inventory.GetMagazine(player)
 local state=states[player]
 if not state or state.Character~=character or state.ID~=id or state.UID~=data.UID then
  if state then Audio.Stop(state.ReloadSound) end
  state={Character=character,ID=id,Type=data.Type,Loaded=data.Loaded,Ready=data.ReadyAt or 0,Token=0,Mode=data.Mode or "Auto",UID=data.UID};states[player]=state
 end
 return state
end
local function sync(player,state,gun)
 local data=Inventory.GetMagazine(player)
 if data and data.UID==state.UID then state.Loaded=data.Loaded;state.Type=data.Type;state.Mode=gun.SingleOnly and "Single" or data.Mode or "Auto" end
 local ammo=Rules.AmmoID(gun.Caliber,state.Type)
 local total=Inventory.Snapshot(player).Items[ammo] or 0
 local c=state.Character
 c:SetAttribute("MagazineAmmo",state.Loaded)
 c:SetAttribute("ReserveAmmo",total)
 c:SetAttribute("AmmoType",state.Type)
 c:SetAttribute("FireMode",state.Mode)
 c:SetAttribute("Reloading",state.Reloading==true)
end
-- Loaded rounds belong to this weapon record, separate from loose pocket ammunition.
Inventory.Changed:Connect(function(player)
 local character,_,id,gun=context(player)
 if not character then local old=states[player];if old then Audio.Stop(old.ReloadSound) end;states[player]=nil;return end
 local state=stateFor(player,character,id);sync(player,state,gun)
end)
action.OnServerEvent:Connect(function(player,command,direction)
 local character,root,id,gun=context(player)
 if not character or not Inventory.GetWeapon(player) then return end
 local state=stateFor(player,character,id)
 sync(player,state,gun)
 local now=os.clock()
 if command=="Mode" then
  if gun.SingleOnly then return end
  if now<(state.NextMode or 0) then return end
  state.NextMode=now+.25;state.Mode=state.Mode=="Auto" and "Single" or "Auto";Inventory.SaveMagazine(player,state.Loaded,state.Type,state.Mode);sync(player,state,gun);return
 elseif command=="Type" then
  if now<(state.NextType or 0) then return end
  Audio.Stop(state.ReloadSound);state.ReloadSound=nil
  state.NextType=now+.3;state.Token+=1;state.Reloading=false;state.Loaded=0
  state.Type=state.Type=="FMJ" and "AP" or "FMJ";Inventory.UnloadMagazine(player,state.Type);sync(player,state,gun);return
 elseif command=="Reload" then
  if state.Reloading or state.Loaded>=gun.Magazine then return end
  local total=Inventory.Snapshot(player).Items[Rules.AmmoID(gun.Caliber,state.Type)] or 0
  if total<=0 then
   local alternate=state.Type=="FMJ" and "AP" or "FMJ"
   local available=Inventory.Snapshot(player).Items[Rules.AmmoID(gun.Caliber,alternate)] or 0
   if available>0 then
    Inventory.UnloadMagazine(player,alternate)
    sync(player,state,gun)
   else
    if now>=(state.NextEmpty or 0) then state.NextEmpty=now+2;Journal.Send(player,"No ammunition available.") end
    return
   end
  end
  state.Token+=1;local token=state.Token;state.Reloading=true;sync(player,state,gun)
  state.ReloadSound=Audio.Play(character,"ReloadSound")
  task.delay(gun.ReloadTime,function()
   local current,_,currentID=context(player)
   if states[player]~=state or token~=state.Token then return end
   Audio.Stop(state.ReloadSound);state.ReloadSound=nil;state.Reloading=false
   if current~=character or currentID~=id then sync(player,state,gun);return end
   Inventory.ReloadMagazine(player)
   sync(player,state,gun)
  end)
  return
 elseif command~="Fire" or state.Reloading or now<state.Ready or state.Loaded<=0 then return end
 if typeof(direction)~="Vector3" or direction.X~=direction.X or direction.Y~=direction.Y or direction.Z~=direction.Z or direction.Magnitude<.9 or direction.Magnitude>1.1 then return end
 local held=character:FindFirstChild("HeldItem")
 local muzzle=held and (held:FindFirstChild("_ShotOrigin",true) or held:FindFirstChild("Muzzle",true))
 if not muzzle or not (muzzle:IsA("Model") or muzzle:IsA("BasePart") or muzzle:IsA("Attachment")) then return end
 local origin=muzzle:IsA("Attachment") and muzzle.WorldPosition or muzzle:GetPivot().Position
 if (origin-root.Position).Magnitude>5 then return end
 -- A muzzle embedded through a nearby wall must not bypass that wall.
 local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances={character}
 local shoulder=Vector3.new(root.Position.X,origin.Y,root.Position.Z)
 if workspace:Raycast(root.Position,shoulder-root.Position,params)
  or workspace:Raycast(shoulder,origin-shoulder,params) then return end
 direction=direction.Unit
 if not Projectiles.Fire(player,character,origin,direction,gun,state.Type,id) then return end
 Audio.Play(character,"ShotSound")
 state.Ready=now+60/gun.RPM;state.Loaded-=1
 Inventory.SaveMagazine(player,state.Loaded,state.Type,state.Mode,state.Ready)
 if random:NextNumber()>=(player:GetAttribute("PreserveDurabilityChance") or 0) then Inventory.UseWeapon(player) end
 sync(player,state,gun)
end)
Players.PlayerRemoving:Connect(function(player) local state=states[player];if state then Audio.Stop(state.ReloadSound) end;states[player]=nil end)
