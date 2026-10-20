local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Inventory=require(script.Parent.Services.InventoryService)
local Projectiles=require(script.Parent.Services.FirearmProjectiles)
local Audio=require(script.Parent.Services.FirearmAudio)
local Items=require(ReplicatedStorage.Shared.ItemConfig).Items
local Rules=require(ReplicatedStorage.Shared.FirearmRules)
local states={}
local action=Instance.new("RemoteEvent");action.Name="FirearmAction";action.Parent=ReplicatedStorage
local function context(player)
 local character=player.Character
 local hp=character and character:FindFirstChildOfClass("Humanoid")
 local root=character and character:FindFirstChild("HumanoidRootPart")
 local id=character and character:GetAttribute("HandsItem")
 local definition=id and Items[id]
 if not root or not hp or hp.Health<=0 or character:GetAttribute("Knockout") or character:GetAttribute("IsDead") or not definition or not definition.Firearm then return end
 return character,root,id,definition.Firearm
end
local function stateFor(player,character,id)
 local state=states[player]
 if not state or state.Character~=character or state.ID~=id then
  if state then Audio.Stop(state.ReloadSound) end
  state={Character=character,ID=id,Type="FMJ",Loaded=0,Ready=0,Token=0};states[player]=state
 end
 return state
end
local function sync(player,state,gun)
 local ammo=Rules.AmmoID(gun.Caliber,state.Type)
 local total=Inventory.Snapshot(player).Items[ammo] or 0
 state.Loaded=math.min(state.Loaded,total)
 local c=state.Character
 c:SetAttribute("MagazineAmmo",state.Loaded)
 c:SetAttribute("ReserveAmmo",math.max(0,total-state.Loaded))
 c:SetAttribute("AmmoType",state.Type)
 c:SetAttribute("Reloading",state.Reloading==true)
end
-- Ammunition remains counted in inventory until fired. Magazine is an allocation
-- of that stock, preventing loss/duplication across drops, transfers and death.
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
 if command=="Type" then
  if now<(state.NextType or 0) then return end
  Audio.Stop(state.ReloadSound);state.ReloadSound=nil
  state.NextType=now+.3;state.Token+=1;state.Reloading=false;state.Loaded=0
  state.Type=state.Type=="FMJ" and "AP" or "FMJ";sync(player,state,gun);return
 elseif command=="Reload" then
  if state.Reloading or state.Loaded>=gun.Magazine then return end
  local total=Inventory.Snapshot(player).Items[Rules.AmmoID(gun.Caliber,state.Type)] or 0
  if total<=state.Loaded then return end
  state.Token+=1;local token=state.Token;state.Reloading=true;sync(player,state,gun)
  state.ReloadSound=Audio.Play(character,"ReloadSound")
  task.delay(gun.ReloadTime,function()
   local current,_,currentID=context(player)
   if states[player]~=state or token~=state.Token then return end
   Audio.Stop(state.ReloadSound);state.ReloadSound=nil;state.Reloading=false
   if current~=character or currentID~=id then sync(player,state,gun);return end
   state.Loaded=math.min(gun.Magazine,Inventory.Snapshot(player).Items[Rules.AmmoID(gun.Caliber,state.Type)] or 0)
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
 Inventory.Remove(player,Rules.AmmoID(gun.Caliber,state.Type),1)
 Inventory.UseWeapon(player)
 sync(player,state,gun)
end)
Players.PlayerRemoving:Connect(function(player) local state=states[player];if state then Audio.Stop(state.ReloadSound) end;states[player]=nil end)
