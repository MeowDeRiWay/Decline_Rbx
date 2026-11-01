# 2026-11-01

- Practiced hands / Набиті руки: Repair 200, one rank, halves duration only for recipes requiring Repair. Stacks with crafting tool speed.
- ItemPool loot rerolls every RespawnSeconds (default 300), replacing leftovers before chance selection. Pickup does not reset the timer. Inactive points reroll once on waking.
- Door reach preserves carried patients and left-hand support.
- Crafting chest range measures five studs between oriented model bounds, with line of sight between closest points.

Validation: crafting queues, cooking progression, item pools, carry/loot, door access, interaction animations, bounding-box geometry, new perk, progression service, localization and changed Luau compilation passed. Existing progression_rules.test.luau fails at line 56 (old medical bonus expectations).
