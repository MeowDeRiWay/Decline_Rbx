# Zombie server activity

No model changes or new authored attributes are required. Existing zombies with
`SightRange`, `ViewAngle` and `ZombieHome` retain their ordinary active behavior.

Distance is horizontal distance **outside the ground projection of the nearest
living player's entire screen**, independent of character facing:

| Gap outside screen | ActivityMode | Work |
| --- | --- | --- |
| 0–50 studs | Active | Existing sight, movement, paths and combat |
| >50–200 studs | Minimal | No regular AI; one endpoint-only teleport attempt per 120 seconds |
| >200 studs | AFK | No regular AI or teleport attempts |

No living players means AFK. Screen height, aspect and zoom are bounded by the
server; screen location always follows the authoritative player root. Camera
reports arrive twice per second. Until the first report the server uses a
conservative maximum footprint. Classification normally refreshes every half
second; large populations yield after every 32 records, so wake is not literally
instant. Attribute `ActivityMode` on each zombie exposes the current mode.

One shared Heartbeat dispatches active zombies only. Changing mode drops stale
pursuit/navigation state. Active sight/combat remain independent of what the
player can see; the 50-stud buffer allows off-screen detection and pursuit.

Minimal movement chooses a random nearby point 1–10 studs away. The timer starts
at a random phase to spread work, then attempts repeat at 120-second intervals.
Only the destination is checked: ground, slope, same-level height and available
space for the whole model. Existing non-collidable home floors support placement.
There is no path check, so crossing a wall between endpoints is intentionally
possible. Invalid destinations leave the zombie where it is. A destination must
remain in the Minimal band; a teleport cannot land inside the active screen
buffer. AFK zombies do no destination physics. Dead/removed zombies are unregistered.

This reduces idle AI work, not model/replication memory. Active population density
and the existing navigation implementation can still affect server frame time;
real performance should be measured in Studio with the intended map/population.
