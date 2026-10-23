local Players=game:GetService("Players")
local StarterPlayer=game:GetService("StarterPlayer")
local Audio=require(script.Parent.Services.CombatAudio)
local template=StarterPlayer:FindFirstChild("StarterCharacter")
if template then Audio.Prepare(template) end
local function bind(player)
 player.CharacterAdded:Connect(Audio.Prepare)
 if player.Character then Audio.Prepare(player.Character) end
end
Players.PlayerAdded:Connect(bind)
for _,player in ipairs(Players:GetPlayers()) do bind(player) end
