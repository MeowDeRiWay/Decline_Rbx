# Farming model setup

All names are exact and case-sensitive. Game text is English.

| Model | Location | Purpose |
| --- | --- | --- |
| `Greenhouse (T1)` | `ServerStorage/Buildings` | Town building menu: Greenhouse. Costs 4 TreeLog + 4 Stone, no skill requirement; normal mayor approval. |
| `GardenBed` | Inside greenhouse | A 1×10 bed. Numeric `MaxPlants` sets capacity (default5, safe range1–100); numeric `MaxWatering` sets stored water capacity (default100). |
| `Well` | Inside greenhouse | Unlimited dirty water; requires EmptyBucket equipped in hands. |
| `EmptyBucket` | Any category under `ServerStorage/Items` | Craft on Workstation: Repair80, provisional3Scrap/20seconds, one at a time. |
| `DirtyWaterBucket` | Same item tree; model optional | Holds100 watering units. Drinking from pockets restores100Water, adds80Sick and returnsEmptyBucket. Filled visual falls back to EmptyBucket. |
| `PotatoStage1`…`PotatoStage4` | `ServerStorage/Farming/PotatoStages` | Exactly four states: early growth, late growth, ripe, rotten. |

Bed parts should be anchored; arbitrary part names supported. Optional `CropAnchor` Part/Model defines the center/orientation of the plant row, otherwise the initial bed bounding-box surface is used. Crop bottoms are aligned to the bed top regardless of the authored crop pivot; CropAnchor keeps its horizontal position/orientation. Plants are evenly spaced along the bed's longer horizontal axis, inside its initial bounds. Use consistent pivots across all four potato models. Visuals are anchored, non-colliding and non-queryable. Missing stage models do not stop simulation.

## Interaction

Aim and press E. Server checks reach, line of sight, life, knockout and creation/crafting locks. Hover shows water, plant count, ready and rotten counts.

- E with empty hands opens the crop menu. Select Plant potatoes to fill free slots. The menu shows the base growth time and water requirements. No seeds or raw potatoes consumed. Potato is the only crop currently available.
- Only a DirtyWaterBucket equipped in hands waters. Pocket buckets are never used. Each use adds up to100units, capped by MaxWatering, and returns an empty bucket. A full bed does not consume a bucket.
- Each bush consumes20units gradually across its complete growth, not upfront. Five bushes therefore need100units total. Water is shared across growing bushes; ripe/rotten bushes stop consuming it.
- Empty hands harvest ripe bushes and clear rotten ones, leaving immature bushes. Each ripe bush rolls0–4potatoes independently, before greenhouse yield bonuses. Zero yield is valid. Harvest grants 25 character XP per actual potato and 1 Farmer practice XP per harvested ripe bush (including zero-yield bushes). Rotten clearing grants no XP. Good student applies as before.

## Water and rot

Water thresholds use percentage of MaxWatering, so different-capacity beds behave consistently.

| Water | Growth duration multiplier | Rot chance per bush per minute |
| --- | --- | --- |
| 80–100% | 1 | 0 |
| 60–under80% | 1.2 | 0 |
| 40–under60% | 1.5 | 10% |
| Above0–under40% | 2 | 20% |
| 0 | No growth | 50% |

Stages1and2 each take120seconds at full watering (240seconds total). Each minute of growth gets an independent rot roll using current water. A ripe bush becomes rotten after a 180seconds if uncollected. Stage3is harvestable; stage4is rotten and yields nothing. Rotten plants persist indefinitely until cleared with E; then plant again. Water is retained after harvest/clearing. Timings and yields live in FarmingConfig.

The owner's Kherson watermelons perk multiplies yield by1.5, with fair fractional rounding. Set OwnerID on Greenhouse or parent BuildingSpace. The owner's bonus is cached through disconnect and reset on transfer. No farming perk requirements have been invented yet.

Farmer remains passive like Miner: one practiceXP per harvested ripe bush, 10×next-rank thresholds, no manual/tagged training. Farming bonuses still need review. Access is physical/public like chests. Crop and water state lasts only within the running server; crop/water persistence across server restarts and greenhouse upgrades remain pending.

Botanist (Рослинознавець) costs one normal perk point, with no additional requirement. It reveals each plant's stage and estimated harvest time in the bed menu and hover. Estimates use current watering and change as water falls; dry plants show paused. Missing stage models warn once and are retried.

Filled bottles and buckets have Drink and Pour out actions in the inventory. Pour out empties one container without nutrition/sickness effects and returns its empty version; a held bucket stays equipped as EmptyBucket. Equip is shown independently from consumption. Food uses Consume.
