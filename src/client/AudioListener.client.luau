-- Character-height hearing, screen-relative yaw, independent of overhead-camera tilt.
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local SoundService=game:GetService("SoundService")
local Rules=require(ReplicatedStorage.Shared.AudioListenerRules)
local player=Players.LocalPlayer
local listeners,connections={},{}
local attachment,bound
local function restore()
 for listener,saved in pairs(listeners) do
  if listener.Parent then
   listener.PositionInstance=saved.Instance
   listener.PositionType=saved.Type
  end
 end
 table.clear(listeners)
 if attachment then attachment:Destroy();attachment=nil end
 if bound then SoundService:SetListener(Enum.ListenerType.Camera);bound=false end
end
local function register(object)
 if not object:IsA("AudioListener") or listeners[object] then return end
 -- Reuse existing engine-owned listeners/wires; never add a second output mix.
 listeners[object]={Type=object.PositionType,Instance=object.PositionInstance}
end
local function bind(camera,character)
 for _,connection in ipairs(connections) do connection:Disconnect() end
 table.clear(connections)
 restore()
 for _,parent in ipairs({camera or false,character or false}) do
  if parent then
   for _,object in ipairs(parent:GetDescendants()) do register(object) end
   table.insert(connections,parent.DescendantAdded:Connect(register))
  end
 end
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function() bind(workspace.CurrentCamera,player.Character) end)
player.CharacterAdded:Connect(function(character) bind(workspace.CurrentCamera,character) end)
player.CharacterRemoving:Connect(function() bind(workspace.CurrentCamera,nil) end)
bind(workspace.CurrentCamera,player.Character)
RunService:BindToRenderStep("DeclineAudioListener",Enum.RenderPriority.Camera.Value+5,function()
 local character=player.Character
 local root=character and character:FindFirstChild("HumanoidRootPart")
 local head=character and character:FindFirstChild("Head")
 local camera=workspace.CurrentCamera
 if not root or not camera then
  if bound then
   -- Restore modern defaults too while there is no character to listen from.
   for listener,saved in pairs(listeners) do
    if listener.Parent then listener.PositionInstance=saved.Instance;listener.PositionType=saved.Type end
   end
   SoundService:SetListener(Enum.ListenerType.Camera);bound=false
  end
  return
 end
 local position=head and head:IsA("BasePart") and head.Position or root.Position
 local frame=Rules.Frame(position,camera.CFrame.RightVector)
 SoundService:SetListener(Enum.ListenerType.CFrame,frame)
 bound=true
 if not attachment or attachment.Parent~=root then
  if attachment then attachment:Destroy() end
  attachment=Instance.new("Attachment");attachment.Name="_DeclineHearing";attachment.Parent=root
 end
 attachment.WorldCFrame=frame
 for listener in pairs(listeners) do
  if listener.Parent then
   if listener.PositionInstance~=attachment then listener.PositionInstance=attachment end
   if listener.PositionType~=Enum.ListenerPositionType.Instance then listener.PositionType=Enum.ListenerPositionType.Instance end
  else listeners[listener]=nil end
 end
end)
