-- Hear from the character, with stereo orientation matching the fixed camera.
-- Camera zoom must not move the player out of their own spatial sound radius.
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local SoundService=game:GetService("SoundService")
local player=Players.LocalPlayer
local bound=false
RunService:BindToRenderStep("DeclineAudioListener",Enum.RenderPriority.Camera.Value+5,function()
 local character=player.Character
 local root=character and character:FindFirstChild("HumanoidRootPart")
 local camera=workspace.CurrentCamera
 if root and camera then
  SoundService:SetListener(Enum.ListenerType.CFrame,CFrame.new(root.Position)*camera.CFrame.Rotation)
  bound=true
 elseif bound then
  SoundService:SetListener(Enum.ListenerType.Camera)
  bound=false
 end
end)
