-- Sound templates live in ReplicatedStorage/Sounds; their names are unrestricted.
return {
 OutsideFolder="OutsideAmbient",
 BattleFolder="BattleAmbient",
 FadeSeconds=3,
 CombatSeconds=30, -- Refreshed only by real damage between non-allied players.
 LoadTimeoutSeconds=12,
 OutsideVolume=1, -- Multipliers on each template Sound's authored Volume.
 BattleVolume=1,
}
