# Hospital beds

Create an anchored bed Model anywhere in the hospital. Its name is arbitrary.
Add these attributes to the Model:

| Attribute | Type | Value |
| --- | --- | --- |
| HospitalBed | Boolean | true |
| HospitalRegenMultiplier | Number | 3 by default; optional, clamped to 1–60 |
| Furniture | Boolean | true (optional; ignore the bed when picking up loot) |

Place an **Attachment named `BedPoint`** at the center of the mattress's top
surface. Keep its Y axis pointing up and its local -Z pointing toward the pillow.
The character lies along that direction; code adds the body's thickness above
the surface. BedPoint should be inside an anchored mattress Part. Do not place
the marker above the headboard or set it at the mattress's bottom.

Alternatively name the mattress Part `BedSurface` or make it the Model's
PrimaryPart. Its top-center becomes the resting point when BedPoint is absent.
The final fallback is the first BasePart found, so an explicit mattress marker
is recommended for beds with multiple Parts. Models are never scaled.

Walk within the normal 2-stud interaction distance, hover the bed and press E.
One player can occupy a bed. While resting, E gets up and restores the standing
pose/position from before lying down. Movement/attacks and inventory actions are
blocked while resting; camera orbit/zoom and inspecting inventory remain available.
Closed walls/doors still block access to a bed. The attribute alone enables it;
no Hospital building ID, station attribute, extra script or town binding is needed.

Normal regeneration restores the player's `Regeneration` amount every 60 seconds.
On a hospital bed the interval is `60 / HospitalRegenMultiplier` seconds, with the
same amount per tick. The default ×3 means once every 20 seconds. Each hospital
tick also removes that same amount of Sick, clamped at zero, including when HP
are full or only partly missing. Example: Regeneration=6 restores up to 6 HP and
removes 6 Sick every 20 seconds. Ordinary regeneration is suppressed while in bed,
so there is no extra regular healing tick. Hunger, thirst and normal Sick growth
continue; the bed treats sickness rather than freezing survival needs.

Getting up, KO/death, leaving the server, replacing the character, removing the
bed or disabling HospitalBed frees the bed and stops treatment. Reconnecting
restores the standing character, not an occupied/anchored bed pose. Bed healing
never revives KO/dead characters. `HospitalBedUserId` and `HospitalResting` are
runtime state maintained by the server; do not set them manually.

MedStation is separate: it crafts bandages/medicines; HospitalBed enables resting.
