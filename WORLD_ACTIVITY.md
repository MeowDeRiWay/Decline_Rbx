# Player-driven server world

`WorldActivity.server.luau` starts one shared lifecycle manager. Settings live in
`src/shared/WorldActivityConfig.luau`.

* New city buildings and resource chunks generate within 140 horizontal studs of
  a living player, measured from their footprint. Initial city jobs are spread
  across 10 seconds, nearest first. Roblox client StreamingEnabled remains useful
  independently of this server lifecycle.
* Generated buildings/resources, world pickups and registered NPCs remain active
  until no living player has been within 180 studs of their footprint for 10 seconds.
  The wider exit radius prevents repeated unloading at a boundary.
* Sleeping roots move to `ServerStorage/DormantWorld`: they leave active physics,
  Workspace queries and client replication. This move alone does not free RAM.
* After another 10 seconds, eligible static leaf parts are destroyed. One shared
  prototype per template/part slot plus each instance's transform/properties and
  attributes allow reconstruction. Stateful model/folder identities, chests,
  doors, workstations, pool markers, referenced/jointed parts, inventory state,
  loose items and NPC assemblies remain allocated. This is partial geometry
  release, not serialization of the entire world or guaranteed zero idle cost.
* Approaching within 140 studs rebuilds geometry in batches of 16 part operations,
  yielding between batches, before exposing the complete root to Workspace.
  Reconnect explicitly restores the player's immediate surroundings first.
* A cold world with no living players performs the lifecycle scan every 10 seconds.
  Player joins and new registrations reset that deadline. A spatial interest index
  limits exact proximity checks to nearby buckets, and registry scans yield after
  each 128 entries. The lightweight scheduler
  still polls every .25 seconds; other gameplay services retain their own timers.

Doors keep their collision state and auto-close deadlines while asleep. Farming
advances by elapsed time on a 10-second dormant cadence without rebuilding visuals.
Crafting jobs can finish while a station sleeps. Market stock and chest contents
retain their original objects. Item pools use an event-maintained marker index
instead of repeatedly scanning the whole world; sleeping/distant markers do not
roll new loot. Sleeping NPCs stop AI, retain home quota and resume on approach.
Custom roots containing runnable Scripts/LocalScripts are deliberately kept active:
reparenting them could reset authored coroutine state.

## Bullets

Sleeping roots have a spatially bucketed collision descriptor index. Swept bullet
segments test those descriptors alongside the usual Workspace raycast and choose
the closest hit. Block parts use the same oriented-box intersection, material
thickness merge and penetration cost as awake geometry. Consumed descriptors are
ignored by that projectile after penetration. Doors use their current retained
part's CanQuery/transform, including auto-close changes while sleeping.

Walls do not need to be reconstructed for a passing bullet. A struck sleeping NPC
and its immediate surroundings are restored before damage/death callbacks, so
existing corpse/loot handling runs in Workspace. This does not load the whole ray.
Non-block shapes currently use conservative oriented bounding boxes while asleep;
this can block shots through a mesh's empty space. Unsupported material/non-block
hits stop the projectile, matching the existing non-penetrable fallback. Precise
mesh collision would require a separate collision representation.

## Verify in Studio

Stop Play before syncing the updated project, then start a fresh session. Inspect
`ServerStorage/DormantWorld` attributes `Active`, `Sleeping`, `Cold`, `ReleasedParts` (refreshed at most every 5 seconds).
Walk away beyond 180 studs: sleep begins after 10 seconds and eligible geometry
is released another 10 seconds later. Return within 140 studs and check that loot,
open/closed doors, resource HP, crop progress and zombie population remain intact.
An empty server should settle to Cold records; the root containers and prototypes
are intentionally still present in ServerStorage.

The manager currently covers generated city buildings/resources, world pickups
and registered NPCs. Authored roads/terrain, arbitrary town construction and roots
with runnable scripts are not automatically unloaded. This is session memory:
no new cross-server persistence or DataStore format is introduced.

Automated checks exercise the real lifecycle and ballistics code with mocked
Instances, plus existing city, resource, firearm, door, farming, market, pool,
session and zombie service regressions. Actual Studio/client frame times, network
traffic and memory savings require a play session; they are not inferred from
these tests.

Validation at this change: 156 source files compile and Rojo builds. 79 of 82
automated runners pass. The three failures (`stove_fuel.test.luau:25`,
`resource_rules.test.luau:37`, `progression_rules.test.luau:56`) reproduce
unchanged on the previous commit; no affected-service regression failed.
