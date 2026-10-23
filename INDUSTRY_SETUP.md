# Factories, furnaces and authored item pools

All models below are authored in Studio. Code registers gameplay, recipes and
placement; it does not generate the factory art or item models.

## 40 × 40 infrastructure plots

Create a Model named `InfrastructurePlace` (any name works with the flag below).
Inside it put a horizontal marker Part with a footprint of **40 × 40 studs**.
Set the **Model** attribute:

| Attribute | Type | Value |
| --- | --- | --- |
| ForInfrastructure | Boolean | true |
| GenerationCategory | String | Factories (optional; this is the default for infrastructure) |

`ForInfrastructure=true` belongs on the placement marker in Workspace, not on
the factory template. Generated buildings and all their descendants are excluded
from plot discovery, even if they accidentally retain this attribute.

Put factory templates in `ServerStorage/CityGeneration/Factories`. Each is a Model
with a direct child `Yard` Model or Part matching the 40 × 40 plot footprint. Its
physical marker establishes the alignment and vertical level, as for houses.
Building forward remains +Z; the generator faces the nearest `Road=true` road.
Keep plots separate: a large marker does not merge or remove overlapping 20 × 20
plots. Factories are not inserted into the ordinary 95% house / 5% store roll.
Factory placement requires no ZHouse flag; add normal zombie attributes only if
that factory should host zombies. Existing wall/furniture placement runs normally.

An existing `YardPlace` with `ForZHouse=true` can instead set
`GenerationCategory="Factories"` and have a 40 × 40 footprint. A missing or oversized
factory leaves the plot unfilled and retries; it never silently becomes a house.

## Stations and the town workshop upgrade

| Model name | Optional String attribute for a differently named Model | Location / purpose |
| --- | --- | --- |
| Workstation | CraftStation = Workstation | Existing city crafting, including 9 mm |
| ArmsBench | CraftStation = ArmsBench | Factory weapons station, displayed as Arms Bench |
| Stove | CraftStation = Stove | Kitchen cooking and burning logs |
| Furnace | CraftStation = Furnace | Workshop furnace for charcoal and iron |

Each station needs a physical BasePart and uses the existing **E** interaction,
1-stud reach, obstruction checks, inventory and recipe UI. Put `ArmsBench` inside
the factory template. Merely putting a normal Workstation there does not change
its recipes; station kind selects the recipe catalog.

Add `ServerStorage/Buildings/Workbench (T2)` with the normal `Space`, building
structure and matching Chest/StorageID layout. Put a `Furnace` Model inside it.
Workshop T2 is now a normal mayor-approved upgrade. Its provisional material cost
is the same as T1: **10 TreeLog + 5 Scrap**, configurable in TownConfig; no new
Repair requirement was invented beyond the existing workshop requirement.
Chest migration remains active. Iron recipes require an actual ancestor with
`BuildingID="Workbench"`, `BuildingLevel>=2` (set by TownService). A loose Furnace
on the map or a T1 workshop cannot smelt iron. For a standalone Studio test, put
it in a Model with those attributes.

## Item model IDs

Place registered item models anywhere within category Folders below
`ServerStorage/Items`:

| Exact model name / item ID | Display name | Weight |
| --- | --- | --- |
| Coal | Charcoal | 0.2 kg |
| Chemicals | Chemicals | 0.2 kg |
| Iron | Iron | 1 kg |

Weapons and ammo use the existing IDs: Pistol9mm, SMG9mm, Rifle223,
AssaultRifle223, Ammo9mmFMJ, Ammo223FMJ. No duplicate weapon art is needed.
The new materials are also available in the admin item catalog automatically.
Chemicals have no synthesis recipe; author them into a map loot pool.

## Recipes

One queued batch at a time. The stated quantities are for one batch.
Unspecified weapon/ammunition craft times use the provisional defaults below.
Ammunition crafting produces **loose FMJ inventory rounds**, not a randomly filled
world box; AP recipes were not specified and have not been invented.

| Station | Recipe | Inputs | Output | Repair | XP | Seconds |
| --- | --- | --- | --- | --- | --- | --- |
| Workstation | 9 mm pistol | 20 Scrap | 1 Pistol9mm | 100 | 200 | 60 |
| Workstation | 9 mm SMG | 30 Scrap | 1 SMG9mm | 120 | 200 | 90 |
| Workstation | 9 mm rounds | 1 Coal + 1 Chemicals + 1 Scrap | 50 Ammo9mmFMJ | 100 | 100 | 30 |
| ArmsBench | .223 rounds | 1 Iron + 1 Coal + 1 Chemicals | 50 Ammo223FMJ | 170 | 200 | 60 |
| ArmsBench | .223 bolt-action rifle | 25 Iron | 1 Rifle223 | 170 | 500 | 120 |
| ArmsBench | .223 assault rifle | 25 Iron | 1 AssaultRifle223 | 170 | 500 | 120 |
| Stove / Furnace | Burn logs | 5 TreeLog | 5 Coal | — | default 50 | 60 |
| Stove / Furnace | Burn logs with charcoal | 5 TreeLog + 1 Coal | 5 Coal | — | default 50 | 30 |
| Furnace in Workshop T2 | Smelt iron | 25 Scrap + 1 Coal | 5 Iron | — | default 50 | 120 |
| Stove / Wood | Boil potatoes (1–5 servings) | 1 Potato + 1 CleanWater per serving; **1 TreeLog per batch** | 1 BoiledPotato per serving + **1 Coal per batch** | — | 50 per serving | 60 |
| Stove / Charcoal | Boil potatoes (1–5 servings) | 1 Potato + 1 CleanWater per serving; **1 Coal per batch** | 1 BoiledPotato per serving | — | 50 per serving | 30 |

The iron batch implements both specified quantities: **5 Scrap per Iron**, with
one charcoal fueling the full five-iron batch. No matches are required yet.
The stove UI has **Wood** and **Charcoal (2x)** tabs. Every stove food recipe is
boiling and automatically gets both variants: one log or one charcoal per entire
queued batch, irrespective of serving count. Charcoal halves the duration without
changing food yield or XP. The original fuel-free route and five-log cooking
duplicate are removed. Wood produces one charcoal as a byproduct; charcoal fuel
is consumed without returning itself. Ramsay quality applies only to cooked food.

Authoring rule: Stove food is exclusively boiled. If a future request puts a fried,
baked or otherwise non-boiled meal in the Stove, point out the mismatch before
adding it; use an appropriate different station. Separate five-log charcoal
processing recipes remain unchanged in their matching fuel tab.

Burning, cooking and smelting do **not** anchor the player or require an open menu.
Ingredients are consumed when starting; close the menu and return later to
collect the finished output. Each physical station has its own shared queue and
ready storage, so other players can see/collect it. Outputs remain for the server
session; a removed station/server shutdown is not persistent storage.
Weapon/ammunition crafting uses the normal stay-at-station rule; closing early
cancels/refunds it. Economist and Good student retain their existing effects.

## Item pool markers

Place a Model or Part on the surface where one item should appear. The marker
is hidden and its collision/query disabled on the server; the spawned pickup
appears at the top center in Workspace/WorldItems.

| Attribute | Type | Default / example |
| --- | --- | --- |
| ItemPool | String | Required: Food, Ammunition, Resources/Chemicals, or Items/Food |
| RespawnSeconds | Number | 300 seconds after the pickup disappears; minimum 1 |
| SpawnChance | Number | 1 = always; 0.25 = 25% per spawn attempt |

Paths are relative to `ServerStorage/Items`, are case sensitive, and may include
subfolders. All nested **Folders** are searched. Parts inside an item Model are
never treated as separate loot entries. Only registered physical item models
are eligible; ZombieHand / Lootable=false and loose ammo templates are excluded.

On each **item template**, optional Number `SpawnWeight` sets its relative weight
within that pool (default 1, zero excludes it). For example weight 3 competes three
times as often as weight 1. Marker SpawnChance is a separate chance that an item
appears at all. After a failed chance roll, the marker waits RespawnSeconds before
trying again. Empty/missing folders retry every five seconds so late templates
can become available. The server checks markers every five seconds, so timer
resolution is up to five seconds.

There is **one active pickup model per marker**, with Quantity=1. Ammo pools must
contain `AmmoBox9mmFMJ`, `AmmoBox223FMJ`, etc., with optional `MaxAmmo` on each
box template. A fresh box rolls its contents once using the existing distribution
(uniform integer 1..MaxAmmo, default 50), and picking it up grants those loose
rounds. It does not create fifty physical bullet models. Moving the item out of
the pool or picking it up cannot cause duplicates; replenishment begins after it
is removed/destroyed. Deleting a marker removes its remaining uncollected pickup.

Example: put potato/sausage/bottle models in Items/Food, ammo boxes in
Items/Ammunition, Chemicals in Items/IndustrialLoot. Add ItemPool="Food" to shelf
markers and ItemPool="IndustrialLoot" to factory markers. More folders need no
code changes as long as their item IDs exist in ItemConfig.

## Validation

Actual crafting service tests cover input consumption, skill/tier gates, station
separation, exact XP/output, unattended completion, charcoal byproducts and food
quality. Generator tests cover 40 × 40 factories, small-plot rejection, retries
and deletion. Pool tests cover nested folders, weights/chance, one pickup, ammo
box filtering, replenishment and missing-template retry. Actual world-item tests
verify fresh ammo-box rolls and single pickup. Luau compilation and Rojo build
pass. Visual placement, authored factory/T2 art and live interaction need Studio QA.
