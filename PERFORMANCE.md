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
