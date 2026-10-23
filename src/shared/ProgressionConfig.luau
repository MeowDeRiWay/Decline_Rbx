return {
 StartingPoints=6,
 Stats={"Strength","Attention","Endurance","Intelligence","Agility","Luck"},
 Skills={"LightWeapons","HeavyWeapons","Unarmed","Melee","Throwing","FirstAid","Doctor","Sneak","Traps","Repair","Cook"},
 PassiveSkills={"Lumberjack","Miner","Scavenger","Farmer"},
 Names={LightWeapons="Light weapons",HeavyWeapons="Heavy weapons",Unarmed="Unarmed",Melee="Melee",Throwing="Throwing",FirstAid="First aid",Doctor="Doctor",Sneak="Sneak",Traps="Traps",Repair="Repair",Cook="Cook",Lumberjack="Lumberjack",Miner="Miner",Scavenger="Scavenger",Farmer="Farmer"},
 -- Requirements use {Skills={Repair=50},Attributes={Intelligence=6}}.
 StationRequirements={},BuildingRequirements={Workbench={Skills={Repair=100}},Kitchen={Skills={Cook=100}},Hospital={Skills={Doctor=100,FirstAid=100}}},
 -- Perk definitions and requirements live in ProgressionRules.Perks.
}
