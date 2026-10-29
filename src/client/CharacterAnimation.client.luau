local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
require(Shared:WaitForChild("CharacterAnimationDriver")).Start(game:GetService("Players").LocalPlayer,false)
