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
