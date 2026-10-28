# Resource models and spawn areas

Names are case-sensitive. Shovel model IDs intentionally use `Showel`: StoneShowel, ScrapShowel and IronShowel.

## Models in Studio

| Location | Model names |
| --- | --- |
| `ServerStorage/Items` | `StoneAxe`, `StoneShowel`, `ScrapAxe`, `ScrapShowel`, `IronAxe`, `IronShowel`, `ScrapKnife`, `IronKnife` |
| `ServerStorage/Resources/Trees` | `Tree_1`, `Tree_2`, `Tree_3` |
| `ServerStorage/Resources/ScrapPiles` | `PileScrap` |
| `ServerStorage/Resources/StoneVeins` | `StoneVein` |
| `ServerStorage/Items` | `TreeLog`, `Scrap`, `Rags`, `Stone` (optional art templates; temporary blocks are used until supplied) |

Hand-slot tools placed in Workspace/WorldItems automatically supply a session template in ServerStorage/Items when no valid template exists. This lets placed tools be picked up and equipped without a separate template copy. Existing templates take precedence. For crafting without any copy on the map, keep the authored model in ServerStorage/Items; the session cache does not save back to Studio.

Tree and scrap-pile models placed in Workspace can be harvested directly for testing. Move their originals to the template folders after testing. Preserve their existing `BlocksVision` attributes. Trees are assigned Wood material and `ResourceMaterial = "Wood"`; no Humanoid, health popup or highlight is added.

Add Models named `Forest`, `ScrapYard` and `StoneYard` to Workspace. Each model contains one or more flat rectangular Parts marking the spawn surfaces. Keep only marker Parts inside these models; generated resources go into a separate `Workspace/Resources` folder. Give markers visible colors/transparency in Studio. The server hides and anchors them, disables collision, touch and queries, and makes them transparent to vision at runtime. Place the markers at ground level with real ground beneath them. Rotating markers around the vertical axis is supported.

Hand-placed resources in a matching region count as its current population. When an area is empty, generation makes one independent 1% trial per 1x1 stud cell on each marker; successful trials place one randomly rotated template at a random point inside the cell. Partial edge cells scale the probability by their area. A 10x10 marker has 100 trials, averaging 1 candidate, with no minimum and no 20-object cap. Overlapping markers within one region do not double-populate the same space.

Only the resource bounding-box center must be inside a marker; models may protrude past the edge. There is no center-spacing or edge-gap requirement. Horizontal resource bounding boxes may touch, but not overlap, across all resource types and regions. Candidates that overlap, have no ground, or cannot fit are skipped without relocating or rerolling; large models therefore reduce actual density. A spatial index limits overlap checks in dense areas.

After the last resource is removed, the usual random 30–300 second respawn timer starts. The next generation performs fresh cell trials. A valid generation with zero placements also waits 30–300 seconds, so a failed probability roll is not immediately retried. Missing templates or empty marker lists retry every five seconds. Moving/deleting markers affects future generation.

## Harvesting

Axes and shovels deal **5 damage to living targets**, attack 25 times/minute and use SwingLeft. Against matching resources, stone tools multiply this by 1 (5), scrap by 2 (10), and iron by 3 (15). Tool category still matters: axes cut trees, shovels mine stone and scrap. Every actual impact costs one durability use, even with an unsuitable or insufficient-tier tool. Empty swings cost none.

HarvestTier and MinHarvestTier enforce access independently from damage. Current trees, stone veins and scrap piles require tier 1 (stone) or better; an unranked shovel cannot harvest scrap. Future iron deposits should require MinHarvestTier=2 (scrap or iron); no iron deposit or Iron ingredient is added yet.

All current resource nodes have 100 HP: 20 stone-tool hits, 10 scrap-tool hits, or 7 iron-tool hits. Trees yield 1–4 TreeLog (2 kg each); scrap piles yield independently 1–5 Scrap (0.2 kg each) and 1–5 Rags (0.05 kg each); stone veins yield 1–5 Stone (0.2 kg each).

Workstation: 1 Handle + 1 Stone makes StoneAxe or StoneShowel; 1 Handle + 3 Scrap makes ScrapAxe or ScrapShowel; 3 Scrap makes ScrapKnife. Iron tools are registered and usable but have no crafting recipe until the iron resource is supplied. No stone knife recipe remains. Log/plank/handle recipes are unchanged. Legacy Axe/Showel IDs map to stone stats; Knife maps to scrap knife stats for older placed models.

ScrapKnife deals 10 damage and IronKnife 20. Both share CraftTool="Knife", so either works for slicing sausage. Their attack speed, reach and durability remain the existing knife settings.

Loot is spawned once on the ground at the destroyed node. Each loot type is a separate world pickup with its rolled Quantity, not an automatic inventory grant. Add TreeLog, Scrap and Rags models to ServerStorage/Items for custom visuals. Missing resource art uses temporary blocks which can still be picked up and dropped.

Zombie homes keep their existing `Zombie_home = true` attribute and normal random spawn interval. Any living player standing on one of their marker surfaces blocks new spawns. After the last player leaves, spawning is blocked for another 180 seconds. Re-entry resets that delay. Players on another vertical floor do not occupy the lower marker.

## Carrying and interaction

The unpenalized carrying threshold is 20 kg. Additional weight applies a linear 5% movement-speed penalty per kilogram to both walking and running, including fractional kilograms. At 25 kg the multiplier is 0.75; at 30 kg it is 0.5; at 40 kg or more it is 0. Inventory weight includes held equipment. The speed returns as soon as weight is removed.

World items, chests, corpses, stoves and cutting boards share the same distance calculation on client and server: the nearest point on the model/part bounding box, never the pivot or center. Server reach and line-of-sight checks still apply.

## Validation

Run `luau tests/resource_rules.test.luau tests/movement_rules.test.luau tests/resource_clearance.test.luau tests/resource_density.test.luau` for tool, durability, loot, spacing and occupied-home timer checks. `python tests/run_resource_service.py /path/to/luau` exercises generation and stone harvesting through the real service on engine mocks. `rojo build default.project.json` validates project packaging. A Roblox Studio playtest is still required for the actual models, pivots, ground and hit boxes.


## Міста та кухня

Налаштування Flag, BuildingSpace, TownSpawn і першої кухні описані в [TOWN_SETUP.md](TOWN_SETUP.md). Шаблон кухні: `ServerStorage/Buildings/Kitchen_1`.


## Zombie houses: ZHouse and ZNumber

Reference structure inspected from the supplied HouseA (brick).rbxm:
- Outer house Model: any name, `ZHouse=true`, numeric `ZNumber` (recommended 3 for the small example).
- `Yard` is INSIDE the house Model and contains its marker Part. Do not wrap the house inside Yard.
- `Floor` is a Model inside the house, with `Zombie_home=true` and `BlocksVision=false`; its marker Parts remain non-collidable and queryable.
- Walls/corners/doorways/windows remain nested Models, with arbitrary Part names. Material attributes are reserved for later bullet/environment behavior.

ZNumber limits simultaneously living zombies spawned by this house. All Zombie_home floors in the same ZHouse share the limit. Zombies that leave the house still count, corpses/dead zombies do not. A freed slot can be replenished through the normal random 1–60 second spawn schedule, subject to occupancy and the existing 180-second post-exit delay.

ZNumber=0 disables spawning. Missing/invalid values use 3; fractional values round down, negative values become 0. The house attribute takes precedence over a floor-level fallback. Existing standalone Zombie_home floor models also support ZNumber and otherwise use 3.

City generator convention: house front is the pivot's **positive Z / blue arrow direction**, NOT CFrame.LookVector (which points toward negative Z). No Front Part is required. A future generator must clone and rotate the outer house including Yard and Floor. YardPlace with ForZHouse=true marks destinations; Road=true identifies road models independent of names.


City generation is now implemented for existing YardPlace markers. See [CITY_GENERATION.md](CITY_GENERATION.md) for template setup, source references, seed and validation.


## Zombie doorway movement

Navigation clearance now uses the travel-aligned root footprint rather than an inflated diagonal square. Route resolution refines on failed searches to center through narrow doors; actual movement uses the same footprint. Ground probes support small thresholds and reject high ledges/door lintels. Doors narrower than the body remain blocked. Test: `python tests/run_zombie_navigation.py /path/to/luau`.


## Window-to-door pursuit

Zombies that see a target through a window now try a coarse doorway route before the fine-grid search. Doorway models are recognized by a name starting with DoorWay (case-insensitive), or NavigationDoor=true. All portal edges still use physical collision checks; neither walls nor window sills are ignored. After losing sight, the same routing leads to the last observed position. NavigationStatus and LastSeenPosition on the zombie expose route status for Studio debugging.


Targets standing close to walls use a nearby collision-free standing endpoint when the zombie cannot fit at their exact center. Endpoint selection rejects points separated from the target by a physical wall. Close distance through a wall no longer stops route following automatically.


Kitchen template: **ServerStorage/Buildings/Kitchen (T1)**, with nested Space, BuildingMenu and optional Stove. Costs 1 TreeLog from the builder upon mayor approval; mayors must approve their own requests too. See TOWN_SETUP.md for details.

All Workstation recipes are limited to one crafting operation per batch. One log still yields three planks in that operation. Stove boiling accepts up to five raw food units per batch, with ingredients charged per unit.

Resource density is now **1% per square stud** for Forest, ScrapYard and StoneYard. A 40x100 region averages 40 candidates per resource type present, before ground/overlap rejection. If different resource region types share the same footprint their candidate counts add together.

## Nearby generation

Keep Forest/StoneYard/ScrapYard markers at their authored sizes. The server splits
them into virtual 20x20-stud chunks and rolls only within 180 horizontal studs
of a living player. Visited resources keep health/harvest state when players
leave. Client unloading uses StreamingEnabled; this does not unload server state.
Respawn now applies independently to an emptied chunk, with the same configured
30–300-second delay, and waits for a nearby player. No-player worlds stay empty.
See PERFORMANCE.md for the World.rbxm audit and validation limits.
