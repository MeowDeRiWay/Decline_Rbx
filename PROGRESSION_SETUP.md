# Character progression and Cook

Press **P** to open Character. Choose **Cook**, inspect XP/bonuses and allocate attribute points with the corresponding [+] buttons. The profession can currently be selected once per server session; switching and DataStore persistence are not implemented. Progression and allocated points survive death/respawn within that server. All attributes start at zero, with no free points at level 0.

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

Shared `ProgressionConfig` contains profession station/building permissions and an empty Cook `Talents` table. The Character menu and server support talent IDs, level requirements and prerequisite IDs (`Requires`). No talent names, bonuses or tree entries have been invented: those must be specified next. Learning talents does not consume the five attribute points awarded per level. Effect implementations must be added with the actual talent design.

Server-owned progress is mirrored in Player attributes: Profession, ProfessionLevel, ProfessionXP, AttributePoints, Strength, Endurance, Attention, Luck and derived bonuses. Character attributes mirror derived carry, speed, HP and other bonuses. Remote requests cannot grant XP, select an unknown profession or spend unavailable points.

## Verification

`luau tests/progression_rules.test.luau` checks level thresholds, allocation, caps, luck, talent prerequisites, camera extent and carry capacity. `python tests/run_progression_service.py /path/to/luau` checks real server permission/allocation workflows on engine mocks. `python tests/run_cooking_progression.py /path/to/luau` checks real crafting access, batch-five cooking, cancellation refunds, completion XP and the luck hook. Existing town/resource scenarios and Rojo build are also run. These checks are not a Studio playtest.
