# Client performance changes

CursorQuery dispatches item, door, town and creature hovers at30Hz, after camera
and creature visibility updates. Items/doors/towns share one lazy world ray and
its camera ray; creature hover retains a separate Include ray over ClientVisible
targets, preserving its previous semantics. Open non-queryable doors retain their
manual bounds intersection. No server interaction checks or E handlers changed.
Queries are cleared each hover tick; respawn and camera/mouse motion are sampled
again. A failing consumer is isolated and its warning throttled. MicroProfiler
label: Decline.CursorQueries.

UIUpdates avoids property writes when displayed values have not changed. Applied
to town notifications/countdowns, HUD status, inventory status/cooking countdown
and inventory scale. HUD scale also only writes when the viewport-derived value
changes. Actual laptop frame-time improvement requires comparison in the client.

Validation: run_cursor_query.py tests shared/filtered ray counts,30Hz dispatch,
ordering, viewport/respawn guards, unsubscribe/failure isolation and UI write counts.
run_creature_hover.py checks KO revival, death and respawn; run_town_doors.py checks
authoritative door access. Compilation and Rojo build supplement engine mocks;
Studio/client hover interaction and visual quality still require manual QA.


# Server navigation and distant zombie homes — 28 October 2026

ZombieNavigation replaces its one-second GetDescendants refresh (and synchronous
planning fallback scans) with one initial discovery plus descendant, door-attribute
and name-change events. Only Humanoids and doorway Models enter immutable cached
snapshots; suspended path jobs keep safe old snapshots. Removed objects disconnect
their watchers. The global 2ms / 128-step path-planning budget is unchanged.

ZombieHomes now starts Services/ZombieHomeService instead of one coroutine per
home. Cached home bounds are spatially indexed in 256-stud buckets. Every second,
nearby homes are selected around all living players; wake distance is 300 studs
from the home footprint. Only these homes receive the 0.25-second occupancy and
spawn checks. No players nearby means no occupancy, quota or placement queries for
that home. Marker parts and player lists are reused; the old three-minute delay
after occupation, house-wide ZNumber quota and 1-60s spawn intervals remain.
Waking starts a fresh randomized deadline rather than catching up missed spawns.

Active work yields every 16 homes. At most two due homes are attempted per step,
oldest deadlines first. Placement retains up to 40 candidates but yields after
each eight candidates and rechecks proximity/occupancy before creating the zombie.
Changing marker geometry/enable state and generated/removed homes updates caches
through events. Existing zombie AI sleep modes are unchanged.

Tuning is in Shared/ZombieHomeRules: WakeRadius, BucketSize, HomesPerBatch,
SpawnsPerStep and SpawnAttemptsPerFrame. Server indexing is independent of client
StreamingEnabled; no streaming settings or client scripts were changed here.

Validation: actual navigation doorway/horde tests and event-index tests; scheduler
fixture with 1000 distant homes checks zero distant occupancy/spawn and one global
loop; actual placement fixture checks cached occupancy/altitude, 40 candidates,
8-attempt frame budget and cancellation after players leave. Existing zombie
activity, home quota and resource-service tests pass. Luau compile and Rojo build
pass. These are deterministic engine mocks, not a measured Studio FPS result;
compare the same two-town scene after a full Stop/Play restart.

# World.rbxm audit and resource generation — 28 October 2026

The supplied World.rbxm contains 5,838 instances: 4,614 Parts, 1,213 Models,
7 Folders and 4 WeldConstraints. Of the Parts, 4,612 are anchored. It contains
316 ForZHouse YardPlace Models, 735 Road=true Models, 60 Forest regions,
2 StoneYards and 3 ScrapYards. There are no resource templates or scripts in
this attachment, so the final generated instance count and measured Studio
frame time cannot be inferred from its compressed file size.

Forest marker area totals approximately 1,534,811 square studs. Previously the
first resource tick performed 1,535,040 forest cell rolls, averaging about
15,348 candidate trees before ray/overlap rejection, and rebuilt a footprint
index from every existing resource before each region. Client streaming did
not reduce this server generation work. This establishes substantial startup
work, not proof that every observed periodic stall had the same cause.

ResourceService now partitions each marker into virtual 20x20-stud chunks,
including fractional edges and rotated markers. No manual marker subdivision
is needed. A chunk generates only when a living player's root is within
180 horizontal studs of its bounds. No players means no generation. Density
and overlap rejection are unchanged. Empty chunks respawn independently after
the existing 30–300-second delay and only when approached; re-entry alone never
rerolls a populated chunk. Previously the entire region had to be emptied to
start its respawn timer. Already generated resource state remains on the server;
StreamingEnabled handles client delivery/unloading. Server-side destruction on
player departure is deliberately absent, so damage and harvesting state survive.

The spatial footprint index is maintained on registration/removal rather than
rebuilt per region. Generation and cleanup cooperate with the scheduler after
roughly 2ms; cell rolls offer checkpoints even when every roll fails. A single
engine clone/raycast can still exceed this cooperative budget. The Resources
folder advertises GenerationMode=NearbyChunks20 and GenerationRadius=180 so an
actual Studio session can confirm that the updated script is running.

CityGeneration still populates all building plots, but yields between plots,
marker jobs and batches of nearest-road comparisons. Completed plots return
before repeated hidden-marker writes on retry ticks. This reduces uninterrupted
startup work; it does not promise that total building generation completes faster.
Authored marker geometry should be edited outside Play and followed by Stop/Play.

Validation: run_resource_service.py covers no-player and distant suppression,
nearby 20-stud chunks, re-entry without duplication, depletion cooldown, deferred
respawn, footprint reuse and interrupted/resumed generation. Resource density
and clearance tests cover unchanged probabilities and persistent index removal.
City service/geometry fixtures, compilation of all 152 source files and Rojo
build pass. These are engine mocks/build checks; compare startup and frame-time
spikes in Studio after synchronizing and fully restarting Play. If stalls persist,
record both client and server MicroProfiler traces before further optimization.

# City retry spike found in a real Studio capture — 28 October 2026

microprofile-20261028-174031.x.html (received inside ZIP) opens in official
LibMP. It contains 38 frames. Frame 23 has a roughly 30.075ms uninterrupted
Script_CityGeneration scope, with 20,450 GetBoundingBox calls and 20,450
FindFirstChildWhichIsA calls. The generator's sort comparator recomputed both
models' bounds for every comparison on each retry, including completed plots.
This is a measured spike; the configured retry interval is five seconds, so it
does not by itself establish the cause of every reported one-second stall.

The generator now excludes completed live plots before placement preparation.
A settled town performs no road/template discovery or road/plot sorting.
When pending plots exist, sorting snapshots each model's position/name once,
yielding during key preparation, and compares only cached values. Removal of a
generated house still allows its source plot to generate again. Existing marker
retry, category selection, geometry ordering and incremental indexing remain.

The service fixture adds 120 roads, asserts zero road-bound work on settled
retries, linear geometry-query counts for a pending plot, late-plot generation,
and recovery after a generated house is removed. City service and actual
geometry fixtures pass; source compilation and Rojo build pass. No post-fix
Studio measurement is available yet. Other costs in the capture, including
StandardAdorns and frame presentation, have not been attributed to a game script
or changed without evidence.


# Nearby city generation — 28 October 2026

CityGeneration now places only pending plots within 240 horizontal studs of a
living player's plot-boundary distance. Every 0.25 seconds a single serialized
worker considers all players and places at most four houses, nearest first.
Existing cooperative 2ms checkpoints remain; a single clone or internal wall/
furniture fill can exceed that budget. Empty/dead-player worlds do not clone
buildings. Roads and authored plot bounds are cached with geometry/add/remove
invalidation; no recurring full-world scans were added. Completed plots retain
their existing objects and state. Server objects are not unloaded on departure.

Authored plot markers are hidden on discovery rather than waiting for a house.
Houses/stores/factories assemble their walls and furniture on demand. Standalone
furniture/wall-replacement markers also require proximity and are capped per
pass. Failed placements and standalone marker retries retain the five-second
retry delay. Geometry changes, new plots and removed generated houses continue
to work. Per-plot RNG derived from server seed/position/path makes the initial
choice independent of player visit order. GenerationMode=NearbyPlots on the
GeneratedCityHouses folder identifies the running version.

Validation: actual service engine mocks cover distant/no-player/dead-player
suppression, independent towns and multiple players, nearest-first queue limits,
re-entry without duplication or state replacement, hidden pending markers,
bounds invalidation, seeded replacement, existing furniture/factory placement,
removed plots/houses and no full-world retry scans. Resource generation and
zombie-home scheduler regressions pass. Source compilation and Rojo build pass.
This changes generation workload; the remaining Studio-only periodic stalls
have not been demonstrated to be caused by building generation.

# Thirty-second zone loading window — 28 October 2026

ZoneLoadSeconds=30 now paces newly eligible nearby plots across a stable
first-to-last 30-second window. Closest is due immediately; N>1 jobs use evenly
spaced deadlines through the end of the window. A singleton is immediate. The
setting is a pacing target, not a blocking startup delay or a hard wall-clock
completion guarantee for arbitrarily costly templates. Existing four-per-pass
and cooperative work limits still apply. Due jobs are selected before template/
road preparation, so waiting polls do not prepare placements unnecessarily.

Existing pending deadlines survive repeated polling. Distant/finished jobs are
pruned; returning unfinished work forms a fresh batch, avoiding overdue bursts.
Newly encountered plots form their own batch as the player moves. Standalone
furniture/wall markers have equivalent pacing. Already-filled furniture markers
are skipped, and removed replacement markers do not retain retry state. Catch-up
work yields a frame between jobs, including across plot and standalone marker
work. GeneratedCityHouses.GenerationLoadSeconds advertises the startup setting.

The engine-mock service tests assert three-plot creation at 0/15/30 seconds,
no early work or sliding deadlines, departure cancellation, paced re-entry,
state retention, missed-deadline catch-up across frames, serialized generation,
and standalone furniture timing. Existing placement, resource and zombie-home
regressions, source compilation and Rojo build pass. This does not subdivide a
single template's synchronous clone/internal assembly; that remains a possible
source of a short per-building hitch and requires live Studio comparison.
