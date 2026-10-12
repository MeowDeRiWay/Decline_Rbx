# Resource models and spawn areas

Names are case-sensitive. The shovel item ID is intentionally `Showel` to match the supplied model.

## Models in Studio

| Location | Model names |
| --- | --- |
| `ServerStorage/Items` | `Axe`, `Showel` |
| `ServerStorage/Resources/Trees` | `Tree_1`, `Tree_2`, `Tree_3` |
| `ServerStorage/Resources/ScrapPiles` | `PileScrap` |
| `ServerStorage/Items` | `TreeLog`, `Scrap`, `Rags` (optional art templates; temporary blocks are used until supplied) |

Tree and scrap-pile models placed in Workspace can be harvested directly for testing. Move their originals to the template folders after testing. Preserve their existing `BlocksVision` attributes. Trees are assigned Wood material and `ResourceMaterial = "Wood"`; no Humanoid, health popup or highlight is added.

Add Models named `Forest` and `ScrapYard` to Workspace. Each model contains one or more flat rectangular Parts marking the spawn surfaces. Keep only marker Parts inside these models; generated resources go into a separate `Workspace/Resources` folder. Give markers visible colors/transparency in Studio. The server hides and anchors them, disables collision, touch and queries, and makes them transparent to vision at runtime. Place the markers at ground level with real ground beneath them. Rotating markers around the vertical axis is supported.

Hand-placed resources inside a matching region count toward its current population. An empty region initially generates a random batch of 1–20 resources. Forest trees have at least 8 studs between model pivots in the horizontal plane; scrap piles have at least 1 stud. Only the resource bounding-box center must be inside a marker. The resource may protrude beyond a marker edge. There must be at least 3 studs between the horizontal bounding-box edges of resources, including rotated and differently sized models; this applies across overlapping regions and resource types. The original same-type center-spacing limits remain additional minimums. If the random batch cannot fit, the generator places fewer resources and warns in Output instead of breaking the spacing rule. Overlapping same-type regions also respect the minimum spacing.

Only after the last resource in a region is destroyed does a random 30–300 second timer start. When it expires, a new 1–20 batch is generated. Empty regions with missing templates or no valid placement retry every five seconds. Moving or deleting markers affects subsequent generation.

## Harvesting

Both Axe and Showel use the `SwingLeft` animation, deal 20 damage and attack 25 times/minute. Every actual weapon impact on a resource costs one durability use. Swinging into empty space costs none. An unsuitable weapon wears but deals no resource damage.

Trees have 100 HP and accept only items whose `HarvestTool` is `Axe`, allowing future axe variants. Five axe hits yield 1–4 TreeLog, each weighing 2 kg. Scrap piles have 100 HP and require `HarvestTool = "Shovel"`; five shovel hits yield independently rolled 1–5 Scrap (0.2 kg each) and 1–5 Rags (0.05 kg each). Loot is spawned once on the ground at the destroyed node. Each loot type is a separate world pickup with its rolled Quantity, not an automatic inventory grant. Add TreeLog, Scrap and Rags models to ServerStorage/Items for custom visuals. Missing resource art uses temporary blocks which can still be picked up and dropped.

Zombie homes keep their existing `Zombie_home = true` attribute and normal random spawn interval. Any living player standing on one of their marker surfaces blocks new spawns. After the last player leaves, spawning is blocked for another 180 seconds. Re-entry resets that delay. Players on another vertical floor do not occupy the lower marker.

## Carrying and interaction

The unpenalized carrying threshold is 20 kg. Additional weight applies a linear 5% movement-speed penalty per kilogram to both walking and running, including fractional kilograms. At 25 kg the multiplier is 0.75; at 30 kg it is 0.5; at 40 kg or more it is 0. Inventory weight includes held equipment. The speed returns as soon as weight is removed.

World items, chests, corpses, stoves and cutting boards share the same distance calculation on client and server: the nearest point on the model/part bounding box, never the pivot or center. Server reach and line-of-sight checks still apply.

## Validation

Run `luau tests/resource_rules.test.luau tests/movement_rules.test.luau tests/resource_clearance.test.luau` for tool, durability, loot, spacing and occupied-home timer checks. `rojo build default.project.json` validates project packaging. A Roblox Studio playtest is still required for the actual models, pivots, ground and hit boxes.
