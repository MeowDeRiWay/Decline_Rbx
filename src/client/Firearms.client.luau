local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Input=game:GetService("UserInputService")
local RunService=game:GetService("RunService")
local GuiService=game:GetService("GuiService")
local Debris=game:GetService("Debris")
local RocketAudio=require(script.Parent.RocketAudio)
local Items=require(ReplicatedStorage.Shared.ItemConfig).Items
local player=Players.LocalPlayer
local action=ReplicatedStorage:WaitForChild("FirearmAction")
local effects=ReplicatedStorage:WaitForChild("FirearmEffects")
local MineTarget=require(script.Parent.MineTarget)
local firing,ready=false,0
local function blocked()
 if (player:GetAttribute("PlayerContextOpen") or player:GetAttribute("ExchangeOpen")) then return true end
 return (player.Character and (player.Character:GetAttribute("InteractionLocked") or player.Character:GetAttribute("HandsBusy") or player.Character:GetAttribute("MedicalHeld"))) or Input:GetFocusedTextBox() or GuiService.MenuIsOpen or player:GetAttribute("MedicalMode") or (((player:GetAttribute("MapOpen") or player:GetAttribute("HelpOpen")) or player:GetAttribute("AdminOpen")) or player:GetAttribute("InventoryOpen")) or player:GetAttribute("TownMenuOpen") or (player:GetAttribute("ProgressionOpen") or player:GetAttribute("GroupOpen"))
end
Input.InputBegan:Connect(function(input,processed)
 if processed or blocked() then return end
 if input.UserInputType==Enum.UserInputType.MouseButton1 then
  if MineTarget.Get() then return end
  firing=true
 elseif input.KeyCode==Enum.KeyCode.R then action:FireServer("Reload")
 elseif input.KeyCode==Enum.KeyCode.V then action:FireServer("Mode")
 elseif input.KeyCode==Enum.KeyCode.B then action:FireServer("Type") end
end)
Input.InputEnded:Connect(function(input) if input.UserInputType==Enum.UserInputType.MouseButton1 then firing=false end end)
Input.WindowFocusReleased:Connect(function() firing=false end)
RunService.Heartbeat:Connect(function()
 if not firing or blocked() or MineTarget.Get() or os.clock()<ready then return end
 local character=player.Character
 local definition=character and Items[character:GetAttribute("HandsItem")]
 if not definition or not definition.Firearm or character:GetAttribute("Reloading") then return end
 local held=character:FindFirstChild("HeldItem")
 local muzzle=held and (held:FindFirstChild("_ShotOrigin",true) or held:FindFirstChild("Muzzle",true))
 local camera=workspace.CurrentCamera
 if not muzzle or not camera then return end
 local origin=muzzle:IsA("Attachment") and muzzle.WorldPosition or muzzle:GetPivot().Position
 local mouse=Input:GetMouseLocation()
 local ray=camera:ViewportPointToRay(mouse.X,mouse.Y)
 if math.abs(ray.Direction.Y)<.0001 then return end
 local distance=(origin.Y-ray.Origin.Y)/ray.Direction.Y
 if distance<=0 then return end
 local target=ray.Origin+ray.Direction*distance
 local direction=target-origin
 if direction.Magnitude<.05 then return end
 ready=os.clock()+60/definition.Firearm.RPM
 if (character:GetAttribute("MagazineAmmo") or 0)<=0 then
  ready=os.clock()+.25
  if definition.Firearm.ManualReload then firing=false else action:FireServer("Reload") end
 else
  action:FireServer("Fire",direction.Unit)
  if definition.Firearm.SingleOnly or character:GetAttribute("FireMode")=="Single" then firing=false end
 end
end)
local traces={}
local colors={Brick=Color3.fromRGB(160,95,70),Wood=Color3.fromRGB(150,110,65),Aluminum=Color3.fromRGB(195,205,215),Glass=Color3.fromRGB(185,220,230),Metal=Color3.fromRGB(255,210,100),ArmorSteel=Color3.fromRGB(255,210,100),Concrete=Color3.fromRGB(160,160,155),Flesh=Color3.fromRGB(125,55,50)}
local function effectPart()
 local part=Instance.new("Part")
 part.Anchored=true;part.CanCollide=false;part.CanTouch=false;part.CanQuery=false;part.CastShadow=false
 part.Size=Vector3.new(.02,.02,.02);part.Transparency=1;part.Parent=workspace
 return part
end
local impactBudget=0
local lastImpact=0
local function impact(event)
 if os.clock()-lastImpact>1 then impactBudget=0;lastImpact=os.clock() end
 if impactBudget>=80 then return end
 impactBudget+=1
 local part=effectPart();part.CFrame=CFrame.lookAt(event.Point,event.Point+event.Direction)
 local attachment=Instance.new("Attachment");attachment.Parent=part
 local emitter=Instance.new("ParticleEmitter")
 emitter.Texture="rbxasset://textures/particles/smoke_main.dds"
 emitter.Color=ColorSequence.new(colors[event.Material] or colors.Concrete)
 emitter.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.035),NumberSequenceKeypoint.new(1,.12)})
 emitter.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.2),NumberSequenceKeypoint.new(1,1)})
 emitter.Lifetime=NumberRange.new(.12,.35);emitter.Speed=NumberRange.new(1,3)
 emitter.SpreadAngle=Vector2.new(35,35);emitter.EmissionDirection=Enum.NormalId.Front
 emitter.Rate=0;emitter.Parent=attachment;emitter:Emit(event.Exit and 8 or 5)
 Debris:AddItem(part,.5)
end
effects.OnClientEvent:Connect(function(events)
 for _,event in ipairs(events) do
  if event.Kind=="Trace" then
   local record=traces[event.ID]
   if not record then record={Part=effectPart()};traces[event.ID]=record;record.Part.Material=Enum.Material.Neon;record.Part.Color=Color3.fromRGB(255,225,150);record.Part.Transparency=.15 end
   record.Expires=os.clock()+.25
   record.Part.Size=event.Rocket and Vector3.new(.18,.18,1.2) or Vector3.new(.015,.015,1.5)
   if event.Rocket then record.Part.Color=Color3.fromRGB(255,150,65) end
   record.Part.CFrame=CFrame.lookAt(event.Point-event.Direction*.75,event.Point)
   if event.Rocket then
    record.Velocity=event.Velocity or Vector3.zero
    record.Part.AssemblyLinearVelocity=record.Velocity
    RocketAudio.Start(record,event.FlightSound,event.FlybySound)
   end
  elseif event.Kind=="Stop" then
   local record=traces[event.ID];if record then RocketAudio.Stop(record);record.Expires=os.clock()+.035 end
  elseif event.Kind=="Backblast" then
   local part=effectPart();part.CFrame=CFrame.lookAt(event.Point,event.Point+event.Direction)
   local a=Instance.new("Attachment");a.Parent=part
   local particles=Instance.new("ParticleEmitter");particles.Rate=0
   particles.EmissionDirection=Enum.NormalId.Front;particles.SpreadAngle=Vector2.new(30,30)
   particles.Speed=NumberRange.new(20,35);particles.Lifetime=NumberRange.new(.15,.3)
   particles.Color=ColorSequence.new(Color3.fromRGB(255,180,70),Color3.fromRGB(90,90,85))
   particles.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.2),NumberSequenceKeypoint.new(1,1.5)})
   particles.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.1),NumberSequenceKeypoint.new(1,1)})
   particles.LightEmission=.7;particles.Parent=a;particles:Emit(35)
   local light=Instance.new("PointLight");light.Color=Color3.fromRGB(255,170,70);light.Range=8;light.Brightness=3;light.Parent=part
   Debris:AddItem(light,.12);Debris:AddItem(part,.5)
  elseif event.Kind=="Explosion" then
   RocketAudio.Explode(event.Sound,event.Point)
   local part=effectPart();part.Shape=Enum.PartType.Ball;part.Position=event.Point
   part.Size=Vector3.new(.5,.5,.5);part.Color=Color3.fromRGB(255,145,40);part.Material=Enum.Material.Neon;part.Transparency=.25
   local light=Instance.new("PointLight");light.Color=part.Color;light.Range=20;light.Brightness=5;light.Parent=part
   local tween=game:GetService("TweenService"):Create(part,TweenInfo.new(.35),{Size=Vector3.one*(event.Radius or 10)*2,Transparency=1})
   tween:Play();Debris:AddItem(part,.4)
  elseif event.Kind=="Impact" then impact(event)
  elseif event.Kind=="Muzzle" then
   -- Invisible anchor preserves flash lighting without a delayed visible orb.
   local part=effectPart();part.Position=event.Point
   local light=Instance.new("PointLight");light.Color=Color3.fromRGB(255,205,90);light.Range=4;light.Brightness=2;light.Parent=part
   Debris:AddItem(part,.045)
  end
 end
end)
local lastListener
RunService.Heartbeat:Connect(function(dt)
 local character=player.Character
 local head=character and (character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart"))
 local listener=head and head.Position or workspace.CurrentCamera and workspace.CurrentCamera.CFrame.Position
 local velocity=listener and lastListener and dt>0 and (listener-lastListener)/dt or Vector3.zero
 if velocity.Magnitude>200 then velocity=Vector3.zero end -- teleport/respawn
 lastListener=listener
 for id,record in pairs(traces) do
  if os.clock()>=record.Expires then RocketAudio.Stop(record);record.Part:Destroy();traces[id]=nil
  else RocketAudio.Update(record,listener,velocity,dt) end
 end
end)
