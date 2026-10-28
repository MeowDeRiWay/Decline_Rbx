# Personal world map

Press **M** to open/close. Drag with left mouse or a touch to pan, scroll the
mouse wheel to zoom (50%-400%), and click **Center** to return to your position.
At 100%, each 20x20-stud cell is exactly 20x20 pixels. North is world -Z; only
your position/facing is shown. There are no placeable markers, other-player
positions, zombies, or full-world reveal requests.

Colors: peach houses; blue infrastructure; gray road strips and intersections;
solid dark green forests; gray/brown scrapyards with scrap symbols;
gray stone fields. Undiscovered cells are black. Exploration opens your current
cell and two surrounding rings (5x5 cells total), stays open after leaving, and is recorded while walking
with the map closed too. KO, death, unfinished creation, and transient character
loading do not reveal tiles. Opening the map blocks movement/combat/medical input
and camera orbit. The multiplayer world continues running.

## Automatic authored-world recognition

- GeneratedCityHouse=true / GenerationCategory=Houses => house; Stores/Factories
  => infrastructure. GenerationSource's plot or inner Yard gives the footprint.
- Workspace/roads Parts/Models and Road=true markers => actual road footprint
  coverage, sampled every 5 studs within each revealed 20-stud cell. Square road
  slabs fill their cells continuously; long/rotated roads use their real footprint
  instead of guessing an orientation and drawing disconnected center strips.
  Coverage is merged into rectangles for display, entirely inside revealed cells.
- Forest, ScrapYard, StoneYard Models => their existing marker Parts; harvesting
  individual nodes doesn't remove the area's map designation.
- BuildingSpace Models with a nonempty BuildingID => town infrastructure.
- Hand-placed ZHouse=true Models with a Yard => houses.

Grid origin aligns to the existing 20-stud YardPlace lattice. Footprints preserve
their horizontal rotation and larger factories can occupy several cells.
Live categories/footprints rebuild every 15 seconds; reopening refreshes all
previously explored cells. New geometry is indexed from descendant events;
updates do not repeatedly scan every descendant of the full world.

Only explored cells are sent by the server, in batches/deltas, with requests
throttled. Client rendering pools only explored cells in the current viewport.
The client cannot supply exploration coordinates or reveal a full map.

Exploration is personal to this character in this generated server world. It
survives normal town respawns and same-server reconnect. A genuinely new character
(after the outcast ending) clears it. It is not saved across different servers:
those can have different generated layouts. MapOpen is excluded from reconnect
snapshots; it cannot reopen an old modal on login.

## Installation / verification

Rojo maps Map.client, Map.server, Shared/MapRules and Server/Services/MapService
automatically. No manual models, attributes or configuration are required for the
existing Decline markers. Controls help now includes M.

Validated actual code using map_rules.test.luau, run_map_service.py and
run_map_ui.py: grid alignment, negative positions, rotated footprints, road
crossings, private fog, network deltas, request throttling, new-life/reconnect,
20px cells, map controls and modal cleanup. Existing camera, help, progression,
sessions, medicine and outcast tests also pass. Full Luau compile and Rojo build
pass. Live Studio layout/world playtesting is still required.
