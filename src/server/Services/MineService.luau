local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local ServerStorage=game:GetService("ServerStorage")
local RunService=game:GetService("RunService")
local Shared=ReplicatedStorage.Shared
local Rules=require(Shared.MineRules)
local Visibility=require(Shared.VisibilityRules)
local Config=require(Shared.GameConfig)
local ItemConfig=require(Shared.ItemConfig)
local Items=ItemConfig.Items
local MineGeometry=require(Shared.MineGeometry)
local Interaction=require(Shared.Interaction)
local ExplosionRules=require(Shared.ExplosionRules)
local Explosions=require(script.Parent.ExplosionService)
local Inventory=require(script.Parent.InventoryService)
local Visuals=require(script.Parent.EquipmentVisuals)
local Animation=require(script.Parent.InteractionAnimationService)
local Journal=require(script.Parent.JournalService)
local Progression=require(script.Parent.ProgressionService)
local Towns=require(script.Parent.TownService)
local Affiliation=require(Shared.AffiliationRules)
local Service={}
local mines,known,visits,lastPositions,lastCommand={},{},{},{},{}
local nextID=0
local random=Random.new()
local remote=Instance.new("RemoteEvent");remote.Name="MineAction";remote.Parent=ReplicatedStorage
local folder=Instance.new("Folder");folder.Name="MineMarkers";folder.Parent=workspace
local function text(player,uk,en,ru)
 local language=string.sub(string.lower(player.LocaleId or "en"),1,2)
 return language=="uk" and uk or language=="ru" and ru or en
end
local function template()
 local source=Visuals.Template("Mine")
 if not source then
  local items=ServerStorage:FindFirstChild("Items")
  if not items then items=Instance.new("Folder");items.Name="Items";items.Parent=ServerStorage end
  source=Instance.new("Part");source.Name="Mine";source.Size=Vector3.new(.9,.16,.9)
  source.Color=Color3.fromRGB(66,78,43);source.Material=Enum.Material.Metal;source.Anchored=true;source.Parent=items
 end
 return source
end
local source=template()
local visual=source:Clone();visual.Name="MineVisual"
local function prepare(model)
 model:SetAttribute("Item_ID",nil) -- detected art is not a loose inventory pickup
 local objects=model:GetDescendants();if model:IsA("BasePart") then table.insert(objects,model) end
 for _,v in ipairs(objects) do
  v:SetAttribute("Item_ID",nil)
  if v:IsA("LuaSourceContainer") or v:IsA("Highlight") or v:IsA("ProximityPrompt") then v:Destroy()
  elseif v:IsA("BasePart") then v.Anchored=true;v.CanCollide=false;v.CanTouch=false;v.CanQuery=false
  elseif v:IsA("Sound") then v:Stop();v.PlayOnRemove=false
  elseif v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Beam") or v:IsA("Light") then v.Enabled=false end
 end
end
prepare(visual);visual.Parent=ReplicatedStorage
local function context(player)
 local c=player.Character
 local root=c and c:FindFirstChild("HumanoidRootPart")
 local hp=c and c:FindFirstChildOfClass("Humanoid")
 if player:GetAttribute("AttributesConfirmed")~=true or not root or not hp or hp.Health<=0 or c:GetAttribute("Knockout") or c:GetAttribute("IsDead") or c:GetAttribute("CarryingUserId") or c:GetAttribute("HospitalResting") or c:GetAttribute("CraftingLocked") or c:GetAttribute("InteractionLocked") or c:GetAttribute("HandsBusy") or c:GetAttribute("Reloading") or player:GetAttribute("TradeOpen") then return end
 return c,root,hp
end
local function remove(mine)
 if mines[mine.ID]~=mine then return end
 mines[mine.ID]=nil;mine.State="Removed"
 mine.Marker:Destroy()
 for _,set in pairs(known) do set[mine.ID]=nil end
 for _,set in pairs(visits) do set[mine.ID]=nil end
 remote:FireAllClients("Remove",mine.ID)
end
local function reveal(player,mine,announce)
 known[player]=known[player] or {}
 if not known[player][mine.ID] then
  known[player][mine.ID]=true
  remote:FireClient(player,"Reveal",mine.ID,mine.Frame,mine.Point)
 end
 if announce then Journal.Send(player,text(player,"Помічена пастка","Trap spotted","Замечена ловушка")) end
end
local function lineOfSight(c,origin,point)
 local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances={c,folder}
 local delta=point-origin
 local hit=workspace:Raycast(origin,delta,params)
 return not hit or (hit.Position-point).Magnitude<.2
end
local function notify(mine,victim)
 if not victim then return end
 local nick="@"..mine.OwnerName
 Journal.Send(victim,text(victim,"Вас уразила міна гравця "..nick,"You were hit by a mine planted by "..nick,"Вас поразила мина игрока "..nick))
 local proxy={GetAttribute=function(_,key) return mine[key] end}
 local allied=Affiliation.Friendly(proxy,victim) or Towns.RelationBetween(proxy,victim)=="Ally"
 if allied then
  local town=Towns.TradeTown(victim:GetAttribute("TownID"))
  local mayor=town and Players:GetPlayerByUserId(town.LeaderID)
  if mayor and mayor~=victim then
   Journal.Send(mayor,text(mayor,"Союзна міна: "..nick.." уразив @"..victim.Name,"Friendly mine: "..nick.." hit @"..victim.Name,"Союзная мина: "..nick.." поразил @"..victim.Name))
  end
 end
end
local function explosionSound()
 local sounds=source:FindFirstChild("Sounds")
 local sound=sounds and sounds:FindFirstChild("ExplosionSound")
 if not sound or not sound:IsA("Sound") or sound.SoundId=="" then
  local launcher=Visuals.Template("AT4")
  sounds=launcher and launcher:FindFirstChild("Sounds")
  sound=sounds and sounds:FindFirstChild("ExplosionSound")
 end
 if not sound or not sound:IsA("Sound") or sound.SoundId=="" then return nil end
 return {SoundId=sound.SoundId,Volume=sound.Volume,PlaybackSpeed=sound.PlaybackSpeed,MinDistance=3,MaxDistance=150}
end
local function detonate(mine,trigger)
 if mines[mine.ID]~=mine then return end
 local owner=Players:GetPlayerByUserId(mine.OwnerID)
 local point=mine.Point+Vector3.new(0,.05,0)
 remove(mine)
 for _,listener in ipairs(Players:GetPlayers()) do
  local root=listener.Character and listener.Character:FindFirstChild("HumanoidRootPart")
  if root and (root.Position-mine.Point).Magnitude<=200 then remote:FireClient(listener,"Explosion",point,mine.Settings.BlastRadius,mine.Sound,workspace:GetServerTimeNow()) end
 end
 if owner and owner:GetAttribute("AttributesConfirmed")~=true then owner=nil end
 Explosions.Detonate(point,mine.Settings,owner,owner and owner.Character,"Mine",100,{FriendlyFire=true,OwnerUserId=mine.OwnerID,TriggerCharacter=trigger,OnDamage=function(hp,_,victim)
  notify(mine,victim)
  local model=hp.Parent
  if not victim and model and hp.Health<=0 and (model.Name=="Zombie" or model:GetAttribute("CreatureType")=="Zombie") then Progression.ZombieKillXP(model) end
 end})
end
function Service.Place(player)
 local c,root=context(player)
 if not c or c:GetAttribute("HandsItem")~="Mine" then return false end
 local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances={c,folder}
 local hit=workspace:Raycast(root.Position+root.CFrame.LookVector*1.3+Vector3.new(0,1,0),Vector3.new(0,-7,0),params)
 if not hit or hit.Normal.Y<.7 or math.abs(root.Position.Y-hit.Position.Y)>4 then return false end
 for _,mine in pairs(mines) do if (mine.Point-hit.Position).Magnitude<1 then return false end end
 local shape=MineGeometry.Measure(source)
 local yaw=math.atan2(-root.CFrame.LookVector.X,-root.CFrame.LookVector.Z)
 local bounds=CFrame.new(hit.Position)*CFrame.Angles(0,yaw,0)*CFrame.new(0,-shape.Bottom,0)*CFrame.new(shape.Center)
 nextID+=1
 local marker=Instance.new("Part");marker.Name="MineAnchor";marker.Size=shape.Size;marker.Anchored=true;marker.Transparency=1
 marker.CanCollide=false;marker.CanTouch=false;marker.CanQuery=false;marker.Position=bounds.Position;marker.CFrame=bounds;marker.Parent=folder
 local mine={ID=nextID,Marker=marker,Point=hit.Position,Frame=MineGeometry.Placed(hit.Position,math.atan2(-root.CFrame.LookVector.X,-root.CFrame.LookVector.Z),source),State="Installing",OwnerID=player.UserId,OwnerName=player.Name,Skill=Rules.Skill(player:GetAttribute("SkillTraps")),TeamID=player:GetAttribute("TeamID"),TownID=player:GetAttribute("TownID"),GroupID=player:GetAttribute("GroupID"),Sound=explosionSound(),Settings=ExplosionRules.Resolve(source,Items.Mine.Explosion)}
 mines[mine.ID]=mine
 local started=Animation.Work(player,marker,2.5,function()
  if mines[mine.ID]~=mine or mine.State~="Installing" or c:GetAttribute("HandsItem")~="Mine" or (root.Position-mine.Point).Magnitude>2.5 or not Inventory.ConsumeHeld(player,"Mine",true) then return false end
  mine.State="Arming";mine.ArmAt=workspace:GetServerTimeNow()+Rules.ArmDelay
  Journal.Send(player,text(player,"Міну встановлено. Активація через 5 секунд.","Mine planted. Arms in 5 seconds.","Мина установлена. Активация через 5 секунд."))
  return true
 end,function() if mine.State=="Installing" then remove(mine) end end,true)
 if not started then remove(mine);return false end
 return true
end
function Service.Disarm(player,id)
 local mine=mines[id]
 local c,root=context(player)
 if not c or not mine or mine.State=="Installing" or mine.Busy or not (known[player] and known[player][id]) then return false end
 if Interaction.Distance(mine.Marker,root.Position)>ItemConfig.PickupDistance or not lineOfSight(c,root.Position,mine.Point+Vector3.new(0,.1,0)) then return false end
 mine.Busy=player
 local function release() if mines[id]==mine then mine.Busy=nil end end
 local started=Animation.Work(player,mine.Marker,ItemConfig.PickupDistance,function()
  if mines[id]~=mine or mine.Busy~=player or Interaction.Distance(mine.Marker,root.Position)>ItemConfig.PickupDistance or not lineOfSight(c,root.Position,mine.Point+Vector3.new(0,.1,0)) then return false end
  if player.UserId==mine.OwnerID or random:NextNumber()<Rules.DisarmChance(player:GetAttribute("SkillTraps"),mine.Skill,false) then
   if not Inventory.Add(player,"Mine",1) then return false end
   local proxy={GetAttribute=function(_,key) return mine[key] end}
   local hostile=player.UserId~=mine.OwnerID and not Affiliation.Friendly(proxy,player) and Towns.RelationBetween(proxy,player)~="Ally"
   remove(mine)
   if hostile then Progression.Award(player,mine.Skill) end
   Journal.Send(player,text(player,"Міну знешкоджено й забрано.","Mine disarmed and recovered.","Мина обезврежена и подобрана."))
  else detonate(mine,c) end
  return true
 end,release,false)
 if not started then release() end
 return started
end
-- Track humanoids once; evaluate zombie identity at sampling time so late rig
-- initialization and CreatureType assignment work without rescanning the world.
local creatures={}
local function trackCreature(object)
 if object:IsA("Humanoid") and object.Parent and object.Parent:IsA("Model") then
  creatures[object.Parent]=creatures[object.Parent] or {}
 end
end
for _,object in ipairs(workspace:GetDescendants()) do trackCreature(object) end
workspace.DescendantAdded:Connect(trackCreature)
local tick=0
RunService.Heartbeat:Connect(function(dt)
 tick+=dt;if tick<.1 then return end;tick=0
 local now=workspace:GetServerTimeNow()
 for _,mine in pairs(mines) do if mine.State=="Arming" and now>=mine.ArmAt then mine.State="Armed" end end
 for _,player in ipairs(Players:GetPlayers()) do
  local c=player.Character
  local root=c and c:FindFirstChild("HumanoidRootPart")
  local hp=c and c:FindFirstChildOfClass("Humanoid")
  if root and hp and hp.Health>0 and not c:GetAttribute("Knockout") and not c:GetAttribute("IsDead") then
   local previous=lastPositions[player];lastPositions[player]=root.Position
   local eye=c:FindFirstChild("Head") or root
   visits[player]=visits[player] or {}
   local radius=Rules.DetectionRadius(player:GetAttribute("Attention"),player:GetAttribute("SkillTraps"))
   local forward=root.CFrame.LookVector
   local angle=Config.CreatureViewAngle*(player:GetAttribute("ViewAngleMultiplier") or 1)
   for _,mine in pairs(mines) do
    if mine.State=="Installing" then continue end
    if mine.State=="Armed" and Rules.Crossed(previous,root.Position,mine.Point,root.Size.Y/2+hp.HipHeight+.65) then
     detonate(mine,c)
    else
     local offset=mine.Point-root.Position
     if (eye.Position-mine.Point).Magnitude>radius then
      visits[player][mine.ID]=nil
     elseif not visits[player][mine.ID] and Visibility.InSector(forward.X,forward.Z,offset.X,offset.Z,angle) and lineOfSight(c,eye.Position,mine.Point+Vector3.new(0,.1,0)) then
      visits[player][mine.ID]=true
      reveal(player,mine,true)
     end
    end
   end
  else lastPositions[player]=nil;visits[player]=nil end
 end
 for model,record in pairs(creatures) do
  if not model:IsDescendantOf(workspace) then creatures[model]=nil;continue end
  local hp=model:FindFirstChildOfClass("Humanoid")
  local root=model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Body")
  if not hp or not root or not root:IsA("BasePart") or hp.Health<=0 or model:GetAttribute("IsDead") or model:GetAttribute("IsCorpse") or (model.Name~="Zombie" and model:GetAttribute("CreatureType")~="Zombie") then
   record.Previous=nil;continue
  end
  local previous=record.Previous;record.Previous=root.Position
  for _,mine in pairs(mines) do
   if mine.State=="Armed" and Rules.Crossed(previous,root.Position,mine.Point,root.Size.Y/2+hp.HipHeight+.65) then
    detonate(mine,model)
    -- One blast can kill the trigger; let the next sample check its life state.
    break
   end
  end
 end
end)
remote.OnServerEvent:Connect(function(player,command,id)
 local now=os.clock();if now<(lastCommand[player] or 0) then return end;lastCommand[player]=now+.3
 if command=="Place" then Service.Place(player)
 elseif command=="Disarm" and typeof(id)=="number" then Service.Disarm(player,id) end
end)
Players.PlayerRemoving:Connect(function(player) known[player]=nil;visits[player]=nil;lastPositions[player]=nil;lastCommand[player]=nil end)
local function bind(player)
 player.CharacterAdded:Connect(function() known[player]=nil;visits[player]=nil;lastPositions[player]=nil end)
 player.CharacterRemoving:Connect(function() known[player]=nil;visits[player]=nil;lastPositions[player]=nil end)
end
Players.PlayerAdded:Connect(bind)
for _,player in ipairs(Players:GetPlayers()) do bind(player) end
return Service
