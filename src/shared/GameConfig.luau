local Config = {}
Config.MaxTowns = 5
Config.WalkSpeed = 14
Config.RunSpeed = 22
Config.MaxHealth = 100
Config.CameraHeight = 75
Config.KnockoutSeconds = 120
Config.CorpseProtectionSeconds = 60
Config.CorpseLifetime = 300
Config.Professions = { "Scavenger", "Medic", "Farmer", "Fighter", "Hunter", "Crafter", "Cook" }
Config.ProfessionNames = {
 Scavenger = "Збирач", Medic = "Медик", Farmer = "Фермер", Fighter = "Боєць",
 Hunter = "Мисливець", Crafter = "Майстер", Cook = "Кухар",
}
return Config
