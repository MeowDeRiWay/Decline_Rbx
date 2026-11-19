-- Server registry shared by bullets, blasts and the vehicle simulation.
local Shared=game:GetService("ReplicatedStorage").Shared
local Rules=require(Shared.VehicleRules)
local Blast=require(Shared.ExplosionRules)
local Interaction=require(Shared.Interaction)
local BulletCast=require(Shared.BulletCast)
local Service={}
local registered={}
function Service.Register(vehicle,components,callback)
 registered[vehicle]={Components=components,Callback=callback}
end
function Service.Unregister(vehicle) registered[vehicle]=nil end
function Service.Component(part)
 if not part or not part.GetAttribute then return end
 local component
 local current=part
 while current and current~=workspace do
  if current:GetAttribute("VehicleComponent") then component=current end
  if registered[current] then return component,current end
  current=current.Parent
 end
end
function Service.Apply(component,amount,kind,attacker)
 local _,vehicle=Service.Component(component)
 local entry=vehicle and registered[vehicle]
 if not entry or not component or not component.Parent then return 0 end
 amount=Rules.Number(amount,0,0,1000000)
 local maximum=Rules.MaxHealth(component)
 if not maximum then return 0 end
 local previous=Rules.Number(component:GetAttribute("HP"),maximum,0,maximum)
 local hp=math.max(0,previous-((kind=="Fire" or kind=="Overrev") and amount or math.ceil(amount)))
 if hp==previous then return 0 end
 component:SetAttribute("HP",hp)
 if attacker then component:SetAttribute("LastDamagerID",attacker.UserId) end
 entry.Callback(component,previous,hp,kind,attacker)
 return previous-hp
end
function Service.Hit(part,amount,kind,attacker,hitComponents)
 local component=Service.Component(part)
 if not component or hitComponents and hitComponents[component] then return 0 end
 if hitComponents then hitComponents[component]=true end
 return Service.Apply(component,amount,kind,attacker)
end
function Service.Explosion(point,settings,attacker,baseDamage)
 local impacts={}
 for vehicle,entry in pairs(registered) do
  if not vehicle:IsDescendantOf(workspace) then continue end
  for _,component in ipairs(entry.Components) do
   if not component.Parent or not Rules.MaxHealth(component) then continue end
   local target=Interaction.NearestPoint(component,point)
   local amount=Blast.Sample((target-point).Magnitude,settings,baseDamage)
   if amount>0 then
    if BulletCast.Raycast(point,target-point,{vehicle}) then amount*=.5 end
    table.insert(impacts,{Component=component,Amount=amount})
   end
  end
 end
 -- Snapshot first; a tank explosion may schedule another blast during application.
 for _,hit in ipairs(impacts) do Service.Apply(hit.Component,hit.Amount,"Explosive",attacker) end
end
return Service
