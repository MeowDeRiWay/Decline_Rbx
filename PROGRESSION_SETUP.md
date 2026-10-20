# Progression, professions and talents

Press **P** for the two-column Character menu: attributes on the left, profession/talent tree on the right. The appearance matches Inventory. Attribute effects and caps appear only while hovering the relevant card. Choose Cook or Worker; selection lasts for the server session. Progression survives respawn, but has no DataStore persistence yet.

## Levels and points

Start at level 0 with zero invested attributes, 5 unspent attribute points, and **0 talent points**. Level 0→1 requires 100 XP; each subsequent transition requires another 100 (9→10 costs 1000). Each level gives **5 attribute points and 1 talent point**. One talent rank costs one talent point, up to **rank 10**. All currently configured talents require profession level 1 and have no prerequisite branches. Server checks points, profession, minimum level and rank cap.

Resource destruction grants 10 XP after a successful loot spawn; zombie kills grant 10 XP to the last successful attacker. Successful specialty crafting gives 10 XP per operation: Cook at Stove/CuttingBoard, Worker at Workstation. Cancelled work gives none. Existing build ownership and mayor approvals still apply.

## Attributes and camera

| Attribute | Per point | Limit |
| --- | --- | --- |
| Strength | +1 kg carry capacity, +1 living-target melee damage | None |
| Endurance | +0.2 running speed only, +5 maximum HP | None |
| Attention | +2 percentage points accuracy, +0.5 studs of additional view allowance | Accuracy 90% |
| Luck | +3 percentage points bonus loot chance | Chance 50% |

Base carry capacity is 20 kg, HP 100, accuracy 25%, Luck 0%. Endurance changes max HP without healing. First spawn/hospital starts at the effective max HP; ordinary respawns remain at 2 HP. Living-target accuracy failures show Miss and spend one weapon durability use. Resource hits retain tool-tier damage and do not roll accuracy.

**Mouse wheel controls zoom.** It changes target camera height by 2 per notch, smoothed toward the target. Camera orientation/height no longer changes when the character turns toward the mouse. Nearest height is 18; the base far height is 30. Attention expands the far limit by `ViewBonus / tan(verticalFOV/2)`, where ViewBonus is now 0.5 per invested point. This is a stable zoom allowance, not an automatic directional camera adjustment. Zoom is ignored while menus or a text field consume input.

Luck rolls independently for each positive output item type and adds `1 + floor(Luck / 3)` on success. It applies to newly harvested loot, zombie drops and completed crafting; pickup, transfer, chest opening and collecting finished crafts do not reroll existing items.

## Cook

Cook can build/upgrade Kitchen and use Stove/CuttingBoard. General Workstation remains usable by everyone. Each talent has 10 ranks:

| ID | English name | Effect per rank |
| --- | --- | --- |
| KnifeMaster | Knife Master | +5% knife attack speed and +5% base knife damage; rank 10 is ×1.5. Strength is added afterward. |
| KevlarApron | Kevlar Apron | Absorb 1 incoming melee damage, clamped at zero damage. Passive, currently independent of clothing. |
| SurpriseServing | Whoa, Where Did That Come From? | A full Stove batch of 5 gains 1 extra serving per rank. |
| GrandmasMethod | Grandma Said to Do It Something Like This... | Multiply remaining Stove duration by 0.8 per rank. Rank 2 is ×0.64; duration stays positive. |
| RamsayMethod | Just Like Ramsay Did on TV. | Multiply remaining CuttingBoard duration by 0.8 per rank. |

Crafting effects are captured at job start, and the serving bonus is applied before the independent Luck roll. Knife cooldown and attack animation use the same speed multiplier on client/server; server damage applies the damage multiplier. Melee absorption applies only to attacks explicitly classified Melee, not environmental or future projectile damage.

**Apron** is a registered item in slot **Additional**, weight 0.5 kg. Put its future art model at `ServerStorage/Items/Apron`. Wearing visuals and offsets will be fitted later; the item does not add its own armor value or require a new recipe yet.

## Worker

Worker can build/upgrade Workshop (`BuildingID=Workbench`) and receives specialty XP from Workstation crafting. Cook stations remain locked.

| ID | English name | Effect per rank |
| --- | --- | --- |
| Redhead | Redhead, Redhead... | A zombie killed with a shovel has a 7% chance per rank to yield 1 Rags; rank 10 is 70%. Only chance scales with this talent. |
| GoldenHands | Golden Hands | Workstation duration is reduced by 4% per rank: rank 10 takes 60% of the original time. |

The killing hit's item ID is recorded before damage, so switching weapons after the kill cannot change the talent roll. Only Shovel-category weapons qualify. The reward uses the existing `Rags` item and its model at `ServerStorage/Items/Rags`. The talent injects one Rags into the ordinary zombie loot before Luck processing; Luck remains an independent bonus source. No drops come from merely hitting a creature or training target.

## Verification

`tests/progression_rules.test.luau` covers XP, points, ranks, caps, recipes, stable zoom bounds, knife scaling, absorption totals and shovel drop probabilities. `tests/run_progression_service.py` checks real server permissions, allocation, Worker kill rewards and XP. `tests/run_cooking_progression.py` checks real cooking cancellation, serving bonuses and rank-ten Worker duration. `tests/run_melee_absorption.py` checks real damage routing and the Apron slot. Town/resource regressions, Luau compilation and Rojo build pass. These are engine mocks, not a Studio playtest.

## Hunter

Hunter is selectable at level0; existing1talentpoint/level and max10ranks apply.
No buildings or specialized crafting stations are assigned yet (public Workstation
access remains as before). All percentages below are per rank.

| Talent | Required level | Effect |
| --- | --- | --- |
| Automatics | 1 | +5pp accuracy, +1pp critical chance |
| Pistols | 1 | +5pp accuracy, +5pp critical chance |
| Rifles | 1 | +5pp accuracy, +2pp critical chance |
| Machine Guns | 1 | +5pp accuracy, +1pp critical chance |
| Unbeliever | 5 | 9% chance to turn incoming critical into normal hit |
| Careful | 5 | 9% chance to preserve condition on a shot; ammo still consumed |
| Not So Heavy | 5 | -8% carried ammunition weight |
| Like Walking on Water | 10 | subtract5pp incoming hit chance, all damage sources |
| Bullseye | 10 | +5pp rifle critical chance, stacking with Rifles |

Rifle223 is Automatic, not Rifle: "Rifle" here means the distinct rifle category.
Future Firearm.Category values: Automatic,Pistol,Rifle,MachineGun. Hit probability
is max(0,min(.9,baseAccuracy+categoryBonus)-defenderDodge). One roll, no second
dodge roll in damage application. Environmental damage/no accuracy attacker uses
100% minus dodge; existing player/zombie melee and ranged paths are covered.
Crits uniformly roll integer x2,x3,x4 after hit. Unbeliever cancels multiplier,
not the hit. Per-rank maximums:50%dodge,90%crit cancellation,90%condition saving,
80%ammo weight reduction; rifle crit20%+50%=70%at full ranks. Bonuses are passive
only for Hunter. Weight discount affects carried loose ammunition (including
allocated magazine rounds), not guns/resources/chests. Inventory total and LoadKg
refresh when the multiplier changes. Attention camera allowance is0.5stud/point.
