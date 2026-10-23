# Farming model setup

The first farming loop is ready for models. All names below are exact and case-sensitive.

| Model | Location | Purpose |
| --- | --- | --- |
| `Greenhouse (T1)` | `ServerStorage/Buildings` | Future town building, 20×20 plot. Construction cost/requirements and its menu entry are still pending design. For current testing place a copy in Workspace. |
| `GardenBed` | Inside the greenhouse | One potato crop per bed. Any number of beds is supported. |
| `Well` | Inside the greenhouse | Unlimited dirty water. |
| `EmptyBucket` | Any category folder under `ServerStorage/Items` | Empty watering bucket, 1 kg. |
| `DirtyWaterBucket` | Same items tree, optional model | Filled bucket, 6 kg. Falls back to the empty bucket model until a separate filled model exists. |
| `PotatoStage1`, `PotatoStage2`, … | `ServerStorage/Farming/PotatoStages` | Ordered growing-potato models. Any positive numbered set is supported; highest number is the mature crop. |

Models should contain anchored parts. Part names do not matter. Add an optional `CropAnchor` Part/Model inside each GardenBed to define the crop pivot and rotation; without it the bed pivot is used. Crop visuals are anchored and non-colliding/non-queryable, with BlocksVision=false.

## Interaction

Aim and press E, as with existing interactables. Server checks distance, line of sight, living state and character confirmation.

- Well: fills one empty bucket or bottle. An empty bucket has priority if available; equipped buckets stay equipped during conversion. Bottles return the existing DirtyWater item. No container means no water.
- Empty bed: empty hands and one Potato are required to plant.
- Planted bed: use a DirtyWaterBucket to water. It becomes EmptyBucket. Watering once starts growth; further watering is not consumed.
- Mature bed: empty hands are required to harvest. Potatoes enter pockets, and each harvested potato awards one Farmer practice XP and one character XP, before Good student effects.

Initial test values in `FarmingConfig`: one seed, one bucket, 600 seconds of watered growth, 2–4 potatoes. These are provisional and should be revisited alongside Farmer progression. Farmer currently uses the same 10×next-rank XP curve as Miner, with no attribute bonus or manual/tagged training.

## Greenhouse perk ownership

Set numeric `OwnerID` on the greenhouse, or let it inherit OwnerID from its parent BuildingSpace. The owner's Kherson watermelons perk gives beds 50% more yield. Odd fractional yields use a fair extra-crop roll rather than always rounding up. The cached bonus survives owner disconnect and resets on ownership transfer. The perk currently has no added skill/attribute requirement pending farming design.

Beds and wells currently use physical access, like communal chests; future doors can limit access. Crop/water state exists only within the running server. Greenhouse construction pricing, upgrade persistence, detailed irrigation and farmer bonuses await the next design pass.
