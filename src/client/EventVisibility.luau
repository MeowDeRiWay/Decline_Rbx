-- The creature renderer installs its screen/sector/occlusion test here.
local Visibility={Check=function() return false end}
function Visibility.Witnessed(event,character,camera)
 local root=character and character:FindFirstChild("HumanoidRootPart")
 if not root or not camera then return false end
 if character:GetAttribute("Knockout") and not (event.Target==character and event.Knockout) then return false end
 local function seen(model)
  return model and model:IsDescendantOf(workspace) and (model==character or Visibility.Check(model,root,character,camera))
 end
 -- Do not reveal the identity of an attacker hidden behind a wall or off screen.
 return seen(event.Target) and seen(event.Actor) or false
end
return Visibility
