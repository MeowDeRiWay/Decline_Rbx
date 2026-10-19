return {
 StartingPoints = 5, XPPerLevel = 100, PointsPerLevel = 5, ZombieXP = 10, ResourceXP = 10, CraftXP = 10,
 Stats = {"Strength", "Endurance", "Attention", "Luck"},
 Professions = {
  Cook = {Name = "Cook", Stations = {Stove = true, CuttingBoard = true}, Buildings = {Kitchen = true}, Talents = {
   SurpriseServing = {Name = "Whoa, Where Did That Come From?", Level = 0,
    Description = "Cooking a full batch of five raw ingredients on a stove produces one extra serving."},
   GrandmasMethod = {Name = "Grandma Said to Do It Something Like This...", Level = 0,
    Description = "All stove cooking takes 20% less time."},
   RamsayMethod = {Name = "Just Like Ramsay Did on TV.", Level = 0,
    Description = "All cutting board recipes take 20% less time."},
  }},
 },
}
