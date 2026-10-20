# City house generation

The first generator fills existing YardPlace markers. It does not create roads or place new plots.

## Studio setup

- Put complete house Models in **ServerStorage/CityGeneration/Houses**. Names are arbitrary; each needs **ZHouse=true** and an immediate child **Yard** containing its marker Part.
- Keep **ZNumber** on the outer house. Keep **Floor/Zombie_home=true** inside it for the existing zombie spawner.
- Leave **Workspace/YardPlace** Models with **ForZHouse=true** where houses should appear. Their marker Parts define the target center, level and 20x20 footprint.
- Roads stay in Workspace as Models with **Road=true**. Their names and Part names do not matter.
- Plots must be horizontal. Rotating them around Y is supported. Template Yard axes should align with the house pivot axes; do not tilt the marker.

## Placement

The generator clones the entire house, including its Yard and Floor. The Yard bounding-box center aligns with the YardPlace bounding-box center; the house pivot may be offset from that center.

The front of the house is **positive Z**, the blue pivot arrow. The generator finds the nearest point on road tile bounds and selects the closest of the four plot directions toward that road. House forward does not use LookVector, which points toward negative Z. No Front Part is needed.

Only templates whose rotated Yard footprint fits inside the plot are eligible. For matching 20x20 yards this supports quarter turns without diagonal spill. Oversized or misaligned yards are skipped and reported in Output. Match the marker heights to keep the finished floor at the intended level.

## During Play

- Generated houses appear in **Workspace/GeneratedCityHouses**.
- Source templates remain in ServerStorage. The original plot and cloned Yard marker are invisible and non-collidable; the plot's query/touch are disabled. Wall/floor collision and visibility attributes are preserved. All cloned Parts are anchored.
- The plot has a GeneratedHouse ObjectValue referencing its house. The house has a GenerationSource ObjectValue referencing its plot.
- Repeated generation leaves existing houses intact. It does not duplicate them or refill their loot.
- New/unresolved plots are retried every 5 seconds, allowing delayed template/road loading. Removing a plot also removes its generated house on the next pass.
- Generated Floor models are discovered by the existing zombie-home listener. House-wide ZNumber limits still apply.

Change **src/shared/CityGenerationConfig.luau** for Seed, fitting tolerance or retry interval. **Seed=false** (default) chooses a fresh random seed on each server/Play session, so restarting Play no longer repeats a fixed house sequence. A numeric Seed deliberately reproduces the same initial choices with the same uniquely named templates and initial plot layout. The actual numeric seed is recorded on Workspace/GeneratedCityHouses and on each generated house as GenerationSeed. Random choices may still coincide by chance, and only templates that fit each plot are eligible. Already generated houses stay unchanged during the same server session.

## Validation

`python tests/run_city_geometry.py /path/to/luau` checks four forward directions, offset Yard alignment, rotated plots, marker height, road-edge selection and rejection of oversized/diagonal yards.

`python tests/run_city_service.py /path/to/luau` exercises template discovery, marker hiding, attribute preservation, repeat calls and removed-plot cleanup with Roblox mocks.

Luau compilation and Rojo build are also checked. These tests do not replace checking the supplied models in Studio Play.

## Stores and AutoPlacer

The existing eligible YardPlace models (`ForZHouse=true`, including those in Workspace/Yards) now roll **Houses 95% / Stores 5%** independently. A small town is not guaranteed to have a store. Templates are:

- `ServerStorage/CityGeneration/Houses/<any name>`: Model with ZHouse=true and an inner Yard.
- `ServerStorage/CityGeneration/Stores/<any name>`: Model with an inner Yard; ZHouse is optional and not added automatically.
- Both use the same aligned 20x20 Yard footprint, +Z front, road-facing placement and fit checks. Roads inside Workspace/roads work normally.

If the rolled category has no fitting template, a fitting template from the other category is used. If neither fits, generation retries as before. The category roll is retained across unsuccessful retries; filled plots never reroll within the session. Generated stores share Workspace/GeneratedCityHouses for compatibility, with `GenerationCategory="Stores"` (houses use "Houses"). Existing GeneratedHouse/GenerationSource links and removal cleanup are unchanged. Adding Stores later does not replace already spawned houses; restart Play to regenerate.

For shelves, create **`ServerStorage/CityGeneration/StoreFurniture/Shelf`** as a Model or BasePart with the intended dimensions. Inside a store template place a **Model or Part named `AutoPlacer`**, with a string attribute **`StoreFurniture = "Shelf"`**. Its bounding box is the rectangular placement region. A Model region should contain only its authored flat marker Parts; use a sensible pivot/PrimaryPart so its box axes follow the desired orientation.

The filler tiles the named furniture's bounding-box footprint without overlap: a 1x10 area gets ten 1x1 shelves or one 1x10 shelf; a 1x1 area cannot hold a 1x10 shelf. Whole objects only, with any unused strip centered around the grid. Furniture bounds are measured from all part corners in upright (world-Y) axes while retaining the template pivot's yaw. Pitch or roll in the template pivot does not turn its height into footprint depth. The box-to-pivot offset remains preserved, so physically upright templates stay upright. Each furniture bounding box follows the region's rotation; its bottom sits on the marker's top surface. Template offsets between pivot and bounding box are preserved. Furniture templates should have their box axes/front aligned consistently; rotate the AutoPlacer to turn the shelves.

Marker Parts become invisible, anchored and non-colliding/non-queryable at runtime. Generated furniture retains authored collision and BlocksVision, and all its parts are anchored. It is parented into a reserved `AutoPlacer/GeneratedFurniture` folder; `FurnitureCount` records the number placed. A completed marker is not refilled, even when its contents are removed or its attributes change. Delete the generated group or restart Play to intentionally refill. Missing/oversized templates warn without placing invalid furniture; a missing template can be supplied before a later retry.

AutoPlacer also works in house templates and on directly authored Workspace objects. This step only places models; no shelf loot, shop inventories or additional interior rules are added.

## Town walls and doors

Place wall templates in `ServerStorage/Buildings/Wall`. Each Model needs a direct
`WallYard` Model or Part. Use unique names, for example `WallModelT1 (wood)`,
`WallCornerT1 (wood)`, `WallGateT1 (wood)`.
Each `WallPlace` Model/Part in Workspace needs `TownID` (number, matching Flag)
and `WallTemplate` (string, exact template name). Its pivot position/rotation
aligns with the template's WallYard pivot. All wall parts are anchored; markers
are hidden and non-collidable. Result: WallPlace/GeneratedWall. Walls start at T1;
no T2 upgrade or resource cost is implemented yet.

Put boolean `Door=true` on one Model containing ALL moving gate pieces (group
multiple GateDoor pieces first). Keep that assembly named `GateDoor`. The gate
wall receives `TownGate=true`; manually placed gates need TownGate and TownID
on their ancestor. On infrastructure, Door=true inherits TownID, OwnerID and
Co-OwnerID from the live building/BuildingSpace. Public town members can operate
town gates; private doors allow the owner, co-owners and mayor of the same town.
Only the owner and mayor can manage co-owners at BuildingMenu.

Hover: green allowed, red locked. E toggles authorized doors, preserving authored
part transparency/collision/query/touch/BlocksVision on closing. Opening disables
collision/query/touch/vision. Hovering the invisible open assembly allows closing.
A player without a town can press E on a locked town gate to request passage.
The current mayor receives an English Y/N approval on the right. Approval only
opens that specific Door assembly for 20 seconds, then restores it; no membership
is granted. The requester must still be alive, unaffiliated and at that gate when
approved. Other factions cannot request passage. Missing/offline mayor, denial,
expiry or invalidated leadership leave gates shut. This is passage authorization,
not a barrier against another player following someone through an open gate.
