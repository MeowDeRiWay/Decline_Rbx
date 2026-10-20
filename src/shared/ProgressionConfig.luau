return {
 StartingPoints = 5, XPPerLevel = 100, PointsPerLevel = 5, ZombieXP = 10, ResourceXP = 10, CraftXP = 10, MaxTalentRank = 10,
 Stats = {"Strength", "Endurance", "Attention", "Luck"},
 Professions = {
  Cook = {Name = "Cook", Stations = {Stove = true, CuttingBoard = true}, Buildings = {Kitchen = true}, Talents = {
   KnifeMaster = {Name = "Knife master", Level = 1, Description = "+5% knife attack speed and +5% knife damage per rank."},
   KevlarApron = {Name = "Kevlar apron", Level = 1, Description = "Absorb 1 point of incoming melee damage per rank. Passive defense."},
  }},
  Hunter = {Name = "Hunter", Stations = {}, Buildings = {}, Talents = {
   Automatics={Name = "Automatics",Level=1,Description="Per rank: +5% automatic accuracy; +1% critical chance."},
   Pistols={Name = "Pistols",Level=1,Description="Per rank: +5% pistol accuracy; +5% critical chance."},
   Rifles={Name = "Rifles",Level=1,Description="Per rank: +5% rifle accuracy; +2% critical chance."},
   MachineGuns={Name = "Machine guns",Level=1,Description="Per rank: +5% machine gun accuracy; +1% critical chance."},
   Unbeliever={Name = "Unbeliever",Level=5,Description="Per rank: 9% chance to turn an incoming critical hit into a normal hit."},
   Careful={Name = "Careful",Level=5,Description="Per rank: 9% chance not to lose weapon condition on a shot."},
   NotSoHeavy={Name = "Not so heavy",Level=5,Description="Per rank: ammunition weighs 8% less."},
   LikeOnWater={Name = "Like walking on water",Level=10,Description="Per rank: subtract 5% from incoming hit chance. Also avoids environmental damage."},
   Bullseye={Name = "Bullseye",Level=10,Description="Per rank: +5% rifle critical chance."},
  }},
  Worker = {Name = "Worker", Stations = {Workstation = true}, Buildings = {Workbench = true}, Talents = {
   Redhead = {Name = "Redhead, redhead...", Level = 1, Description = "Shovel kills have a 7% chance per rank to yield 1 Rags. Only the chance increases."},
   GoldenHands = {Name = "Golden hands", Level = 1, Description = "Workstation crafting takes 4% less time per rank."},
  }},
 },
}
