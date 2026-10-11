local World = {}
local function part(parent, name, size, position, color)
 local p = Instance.new("Part")
 p.Name, p.Size, p.Position = name, size, position
 p.Anchored = true
 p.Color = color or Color3.fromRGB(75, 80, 72)
 p.TopSurface = Enum.SurfaceType.Smooth
 p.Parent = parent
 return p
end
function World.Start(config)
 -- User-authored map objects remain outside this generated test world.
 local folder = workspace:FindFirstChild("DeclineWorld")
 if not folder then
  folder = Instance.new("Folder")
  folder.Name = "DeclineWorld"
  folder.Parent = workspace
  part(folder, "Ground", Vector3.new(1200, 1, 1200), Vector3.new(0, -0.5, 0))
 end
 local lobby = folder:FindFirstChild("Lobby")
 if not lobby then
  lobby = Instance.new("Model")
  lobby.Name, lobby.Parent = "Lobby", folder
  part(lobby, "Floor", Vector3.new(40, 1, 40), Vector3.new(0, 149.5, 0))
  for _, spec in ipairs({{40, 12, 1, 0, 156, 20}, {40, 12, 1, 0, 156, -20}, {1, 12, 40, 20, 156, 0}, {1, 12, 40, -20, 156, 0}}) do
   part(lobby, "Wall", Vector3.new(spec[1], spec[2], spec[3]), Vector3.new(spec[4], spec[5], spec[6]))
  end
  part(lobby, "Spawn", Vector3.new(1, 1, 1), Vector3.new(0, 150, 6)).Transparency = 1
  local terminal = part(lobby, "Terminal", Vector3.new(4, 4, 2), Vector3.new(0, 152, -10), Color3.fromRGB(65, 130, 140))
  local prompt = Instance.new("ProximityPrompt")
  prompt.ActionText, prompt.ObjectText = "Обрати місто", "Decline"
  prompt.HoldDuration, prompt.MaxActivationDistance = 0, 12
  prompt.Parent = terminal
 end
 local towns = folder:FindFirstChild("Towns")
 if not towns then
  towns = Instance.new("Folder")
  towns.Name, towns.Parent = "Towns", folder
  for id = 1, config.MaxTowns do
   local town = Instance.new("Model")
   town.Name, town.Parent = "Town_" .. id, towns
   local center = Vector3.new((id - 3) * 200, 0, -100)
   local flag = part(town, "Flag", Vector3.new(1, 12, 1), center + Vector3.new(0, 6, 0), Color3.fromHSV(id / config.MaxTowns, 0.6, 0.8))
   flag:SetAttribute("Town_ID", id)
   flag:SetAttribute("Town_name", "Місто " .. id)
   flag:SetAttribute("Team", id)
   flag:SetAttribute("LeaderUser_ID", 0)
   local spawn = part(town, "Spawn", Vector3.new(4, 0.2, 4), center + Vector3.new(0, 0.1, 8))
   spawn.CanCollide, spawn.Transparency = false, 1
   part(town, "Wall", Vector3.new(100, 8, 2), center + Vector3.new(0, 4, -50))
   part(town, "Wall", Vector3.new(2, 8, 100), center + Vector3.new(-50, 4, 0))
   part(town, "Wall", Vector3.new(2, 8, 100), center + Vector3.new(50, 4, 0))
   for _, x in ipairs({-30, 30}) do
    part(town, "Wall", Vector3.new(40, 8, 2), center + Vector3.new(x, 4, 50))
   end
   -- The opening between the walls is the placeholder gate entrance.
  end
 end
 return folder
end
return World
