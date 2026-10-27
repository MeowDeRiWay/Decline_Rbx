return {
 StartingPoints=6,
 Stats={"Strength","Attention","Endurance","Intelligence","Agility","Luck"},
 Skills={"LightWeapons","HeavyWeapons","Unarmed","Melee","Throwing","FirstAid","Doctor","Sneak","Traps","Repair","Cook","Farmer"},
 PassiveSkills={"Lumberjack","Miner","Scavenger"},
 Names={LightWeapons="Light weapons",HeavyWeapons="Heavy weapons",Unarmed="Unarmed",Melee="Melee",Throwing="Throwing",FirstAid="First aid",Doctor="Doctor",Sneak="Sneak",Traps="Traps",Repair="Repair",Cook="Cook",Lumberjack="Lumberjack",Miner="Miner",Scavenger="Scavenger",Farmer="Farmer"},
 -- Skills/Attributes require all entries; AnySkills requires at least one.
 StationRequirements={},BuildingRequirements={Workbench={Skills={Repair=50}},Kitchen={Skills={Cook=50}},Hospital={AnySkills={Doctor=50,FirstAid=50}}},
 -- Perk definitions and requirements live in ProgressionRules.Perks.
}
