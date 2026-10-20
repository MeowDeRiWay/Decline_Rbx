return {
 StartingPoints = 5, XPPerLevel = 100, PointsPerLevel = 5, ZombieXP = 10, ResourceXP = 10, CraftXP = 10, MaxTalentRank = 10,
 Stats = {"Strength", "Endurance", "Attention", "Luck"},
 Professions = {
  Cook = {Name = "Cook", Stations = {Stove = true, CuttingBoard = true}, Buildings = {Kitchen = true}, Talents = {
   KnifeMaster = {Name = "Knife Master", Level = 1, Description = "+5% knife attack speed and +5% knife damage per rank."},
   KevlarApron = {Name = "Kevlar Apron", Level = 1, Description = "Absorb 1 point of incoming melee damage per rank. Passive defense."},
   SurpriseServing = {Name = "Whoa, Where Did That Come From?", Level = 1,
    Description = "Cooking a full batch of five raw ingredients on a stove produces one extra serving per rank."},
   GrandmasMethod = {Name = "Grandma Said to Do It Something Like This...", Level = 1,
    Description = "Each rank reduces remaining stove cooking time by 20%."},
   RamsayMethod = {Name = "Just Like Ramsay Did on TV.", Level = 1,
    Description = "Each rank reduces remaining cutting board time by 20%."},
  }},
  Hunter = {Name = "Hunter", Stations = {}, Buildings = {}, Talents = {
   Automatics={Name="Automatics",Level=1,Description="Per rank: +5 percentage points automatic accuracy; +1 percentage point critical chance."},
   Pistols={Name="Pistols",Level=1,Description="Per rank: +5 percentage points pistol accuracy; +5 percentage points critical chance."},
   Rifles={Name="Rifles",Level=1,Description="Per rank: +5 percentage points rifle accuracy; +2 percentage points critical chance."},
   MachineGuns={Name="Machine Guns",Level=1,Description="Per rank: +5 percentage points machine gun accuracy; +1 percentage point critical chance."},
   Unbeliever={Name="Unbeliever",Level=5,Description="Per rank: 9% chance to turn an incoming critical hit into a normal hit."},
   Careful={Name="Careful",Level=5,Description="Per rank: 9% chance not to lose weapon condition on a shot."},
   NotSoHeavy={Name="Not So Heavy",Level=5,Description="Per rank: ammunition weighs 8% less."},
   LikeOnWater={Name="Like Walking on Water",Level=10,Description="Per rank: subtract 5 percentage points from incoming hit chance. Also avoids environmental damage."},
   Bullseye={Name="Bullseye",Level=10,Description="Per rank: +5 percentage points rifle critical chance."},
  }},
  Worker = {Name = "Worker", Stations = {Workstation = true}, Buildings = {Workbench = true}, Talents = {
   Redhead = {Name = "Redhead, Redhead...", Level = 1, Description = "Shovel kills have a 7% chance per rank to yield 1 Rags. Only the chance increases."},
   GoldenHands = {Name = "Golden Hands", Level = 1, Description = "Workstation crafting takes 4% less time per rank."},
  }},
 },
}
