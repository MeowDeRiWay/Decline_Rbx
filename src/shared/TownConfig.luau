return {
 Radius = 200,
 InteractionDistance = 2,
 VoteDuration = 30,
 VoteCooldown = 600,
 ApprovalDuration = 60,
 Relations = {"Neutral", "Ally", "War"},
 Buildings = {
  Market = {Name = "Market", Levels = {"Market (T1)"}, Costs = {{}}},
  Greenhouse = {Name = "Greenhouse", Levels = {"Greenhouse (T1)", "Greenhouse (T2)"}, Costs = {{TreeLog = 10, Scrap = 2}, {Plank = 10, Cloth = 5, TreeLog = 1, Scrap = 1}}},
  Hospital = {Name = "Hospital", Levels = {"Hospital (T1)", "Hospital (T2)"}, Costs = {{TreeLog = 8, Rags = 10}, {TreeLog = 5, Plank = 10, Cloth = 5, Rags = 15, Scrap = 2}}},
  Workbench = {Name = "Workshop", Levels = {"Workbench (T1)", "Workbench (T2)"}, Costs = {{TreeLog = 10, Scrap = 2}, {Plank = 10, Cloth = 5}}},
  Kitchen = {Name = "Kitchen", Levels = {"Kitchen (T1)", "Kitchen (T2)"}, Costs = {{TreeLog = 5, Scrap = 11}, {TreeLog = 3, Plank = 15, Cloth = 5, Scrap = 10}}},
 },
}
