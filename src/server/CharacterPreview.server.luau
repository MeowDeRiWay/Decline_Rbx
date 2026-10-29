-- Studio's server viewport can preview the same poses as a client.
-- Production servers never run this cosmetic loop.
if not game:GetService("RunService"):IsStudio() then return end
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
require(Shared:WaitForChild("CharacterAnimationDriver")).Start(nil,true)
require(Shared:WaitForChild("ZombieAnimationDriver")).Start(nil,true)
