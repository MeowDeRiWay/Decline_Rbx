local GameConfig = {}
GameConfig.MaxTowns = 5
GameConfig.WalkSpeed = 1
GameConfig.RunSpeedBonus = 2
GameConfig.CarryLimitKg = 20
GameConfig.OverloadPenaltyPerKg = 0.05
-- Spatial player footsteps.
GameConfig.FootstepVolume = 0.15
GameConfig.FootstepMinDistance = 2
GameConfig.FootstepMaxDistance = 12
-- Almost overhead, slightly tilted. Distances are in studs.
GameConfig.CameraHeight = 30
GameConfig.CameraBack = 5
GameConfig.CameraFieldOfView = 40
-- Horizontal creature visibility, centered on the character facing direction.
GameConfig.CreatureViewAngle = 160
GameConfig.VisibilityInterval = 1 / 60
GameConfig.VisionShadeRowHeight = 1
GameConfig.VisionRaysPerDegree = 4
GameConfig.UnseenShadeTransparency = 0.55
-- Food/Water costs per second. Working and LoadKg are server-owned attributes.
GameConfig.NeedsInterval = 0.25
GameConfig.IdleConsumption = 0.01
GameConfig.WalkConsumption = 0.02
GameConfig.RunConsumption = 0.04
GameConfig.WorkConsumption = 0.01
GameConfig.WeightConsumption = 0.001
GameConfig.SickThreshold = 50
GameConfig.SickGrowth = 0.05
GameConfig.NeedsDamage = 0.1
return GameConfig
