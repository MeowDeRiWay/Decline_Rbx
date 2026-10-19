# Character progression and Cook

Press **P** to open the two-column Character panel: **Attributes** on the left, **Talents** on the right. The left panel holds XP, unspent points, allocation buttons. Attribute bonuses, derived values and caps appear only in a tooltip while hovering the relevant attribute card. The right panel holds profession selection, an independently scrolling talent tree with prerequisite connections, and a selected talent details pane. The interface matches the Inventory palette and Gotham fonts, and scales to the viewport. Choose **Cook**, inspect XP/bonuses and allocate attribute points with the corresponding [+] buttons. The profession can currently be selected once per server session; switching and DataStore persistence are not implemented. Progression and allocated points survive death/respawn within that server. All attributes start at zero, with **5 unspent attribute points at level 0**. Each later level still grants another five points.

## Experience

- Destroy a resource node: 10 XP once, after a successful loot drop. No XP per individual hit.
- Kill a zombie: 10 XP to the last player who successfully damaged it. Existing zombie death handling prevents duplicate awards. No XP from training targets or player kills.
- Complete Cook work at Stove or CuttingBoard: 10 XP per crafting operation, regardless of batch size. This is an initial balance choice; general Workstation work gives no specialty XP for Cook. Cancelled work gives none.
- Level 0 → 1 requires 100 XP; the next level requires 200, then 300, etc. Level 9 → 10 requires 1000 XP. XP rolls over and every level grants 5 unspent attribute points.

## Attributes

| Attribute | Per point | Cap |
| --- | --- | --- |
| Strength | +1 kg before overload penalties; +1 melee damage to living targets | None |
| Endurance | +0.2 studs/s while running only; +5 max HP | None |
| Attention | +2 percentage points living-target accuracy; +5 studs visible ahead | Accuracy 90%; view uncapped |
| Luck | +3 percentage points chance for extra newly generated loot | Chance 50% |

Base carry capacity is 20 kg, max HP 100, accuracy 25%, luck 0%. Walking and running base speeds are unchanged. Endurance increases max HP without healing current HP when points are assigned. First spawn/hospital spawns use the effective max HP; later TownSpawn respawns remain at 2 HP.

Living-target melee attacks roll accuracy after reach, target and obstruction checks. Failure shows **Miss**, inflicts no damage and costs one durability use. Resources do not roll accuracy and retain their tool-tier damage (5/10/15); Strength affects living-target melee damage only.

Attention scales camera distance so the viewport ground edge in the character's horizontal facing direction extends by 5 studs per point. The original field of view, sector and obstruction checks remain in effect; the camera also reveals more surrounding ground as it zooms out. This is geometrically checked with multiple facing directions; actual Studio presentation still needs a playtest.

Luck rolls independently for each output item type with a positive quantity. A success adds **1 + floor(Luck / 3)** items: 1–2 invested points add one, 3–5 add two, and so on. It applies to harvested resource drops, zombie loot credited to the killer, and completed crafting output. Opening chests/corpses, collecting ready crafts, dropping/picking up or transferring existing items do not reroll luck. Empty loot does not invent new item types.

## Profession permissions

Cook unlocks **Stove** and **CuttingBoard** and can request construction/upgrades of **Kitchen** only. Mayor approval and building ownership checks still apply. Mayor status does not bypass profession requirements. **Workstation** and its general recipes remain usable by everyone. Before choosing a profession, existing building choices remain available; after choosing Cook, Workshop construction is blocked. Existing public chests are unchanged.

## Cook talents

All three talents are currently available at profession level 0, independently, since the intended level requirements have not yet been specified. Learn them in the right-hand tree; they do not consume attribute points.

| Talent | Effect |
| --- | --- |
| Whoa, Where Did That Come From? | A full Stove batch of five raw ingredients produces six servings instead of five. Smaller batches get no extra serving. |
| Grandma Said to Do It Something Like This... | Stove recipes take 20% less time (60 seconds becomes 48). |
| Just Like Ramsay Did on TV. | CuttingBoard recipes take 20% less time (10 seconds becomes 8). |

Talent effects are captured when a job starts. The serving bonus is added to the base output before the independent Luck roll; it does not consume extra ingredients. Cancelled work grants no extra output. Workstation recipes are unaffected. The talent config retains `Level` and `Requires` support for future unlock thresholds and branches.

Attribute hover detection uses the cards' native MouseEnter/MouseLeave events, so it follows UI inset and scaling without mixing raw mouse coordinates with AbsolutePosition.

Server-owned progress is mirrored in Player attributes: Profession, ProfessionLevel, ProfessionXP, AttributePoints, Strength, Endurance, Attention, Luck and derived bonuses. Character attributes mirror derived carry, speed, HP and other bonuses. Remote requests cannot grant XP, select an unknown profession or spend unavailable points.

## Verification

`luau tests/progression_rules.test.luau` checks level thresholds, allocation, caps, luck, talent prerequisites, camera extent and carry capacity. `python tests/run_progression_service.py /path/to/luau` checks real server permission/allocation workflows on engine mocks. `python tests/run_cooking_progression.py /path/to/luau` checks real crafting access, batch-five cooking, cancellation refunds, completion XP and the luck hook. Existing town/resource scenarios and Rojo build are also run. These checks are not a Studio playtest.
