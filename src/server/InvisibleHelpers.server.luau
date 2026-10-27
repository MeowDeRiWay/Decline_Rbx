-- Apply to authored templates as well as objects spawned later.
-- Names are exact; models/folders with this name are not affected.
local function hide(object)
 if object:IsA("BasePart") and object.Name == "InvisibleHelper" then
  object.Transparency = 1
 end
end

game.DescendantAdded:Connect(hide)
for _,object in ipairs(game:GetDescendants()) do hide(object) end
