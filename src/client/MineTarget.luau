-- Share click priority with gun/melee input so disarming cannot also fire.
local Players=game:GetService("Players")
local Cursor=require(script.Parent.CursorQuery)
local ItemConfig=require(game:GetService("ReplicatedStorage").Shared.ItemConfig)
local Interaction=require(game:GetService("ReplicatedStorage").Shared.Interaction)
local Target={}
local models={}
function Target.Register(id,model,point) models[model]={ID=id,Point=point} end
function Target.Remove(model) models[model]=nil end
function Target.Get()
 local c=Players.LocalPlayer.Character
 local root=c and c:FindFirstChild("HumanoidRootPart")
 if not root then return end
 local sample=Cursor.Get()
 local object=sample and sample.Hit and sample.Hit.Instance
 if object and object.CanQuery~=true then return end
 while object and object~=workspace do
  local entry=models[object]
  if entry and object.Parent and Interaction.Distance(object,root.Position)<=ItemConfig.PickupDistance then return entry.ID end
  object=object.Parent
 end
end
return Target
