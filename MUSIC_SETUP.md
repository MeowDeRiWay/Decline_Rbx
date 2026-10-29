# Ambient music — 29 October 2026

Use the existing Sound templates in these folders:

- `ReplicatedStorage/Sounds/OutsideAmbient`
- `ReplicatedStorage/Sounds/BattleAmbient`

Names are unrestricted, and nested Sound templates are supported. Each Sound
needs its uploaded SoundId and desired Volume. The mixer clones templates locally
into SoundService; the original Sounds are never played or modified. Playlists
choose randomly without repeating the immediately previous track when alternatives
exist. Tracks play once; the next track is selected when the current one ends.

## Switching

Outside music starts only after TownService has resolved the first territory
check and the player is outside every town flag's existing radius. Entering any
city fades outside music to silence. This uses location (`TerritoryTownID`), not
city membership. Existing town-radius rules and their one-second update remain.

Actual positive damage by one live player against another starts Battle music
for both participants. The damage is reported only after the authoritative
DamageService has resolved dodge, armor, immunity and life damage. Same faction,
same group, own town and diplomatically allied towns are excluded. Both Neutral
and War relations qualify, including unaffiliated players. NPC hits, hitting NPCs,
misses and fully absorbed hits do not start or extend battle music. Nearby
bystanders do not receive battle state merely for hearing a shot.

Battle overrides city silence or outside music. Each qualifying hit refreshes
`BattleAmbientUntil` using server time, default 30 seconds after the latest hit.
Expiry smoothly restores outside music or city silence. KO/death, removal and
respawn clear that player's battle music; the surviving opponent keeps their
existing timer. No music plays without a living active character or during
character creation. Playlists are local; song choice/time is not synchronized
between participants.

## Configuration

`src/shared/AmbientConfig.luau` contains:

| Setting | Default | Meaning |
| --- | --- | --- |
| FadeSeconds | 3 | Smooth fade/crossfade duration |
| CombatSeconds | 30 | Time since latest qualifying PvP damage |
| OutsideVolume | 1 | Multiplier on authored outside Sound volume |
| BattleVolume | 1 | Multiplier on authored battle Sound volume |
| LoadTimeoutSeconds | 12 | Skip a track that does not load |

Late-loading tracks remain muted until Loaded, then fade in. Failed loads are
cleaned up and retried with another selection; Output identifies the failed
source for audio-access troubleshooting. Empty/missing folders are retried without
blocking the client. Rapid mood changes cancel obsolete fades and can resume an
outgoing track before it has finished fading; no duplicate copies accumulate.

## Verification

Run with a Luau executable:

- `python tests/run_ambient_player.py /path/to/luau`
- `python tests/run_ambient_server.py /path/to/luau`
- `python tests/run_melee_absorption.py /path/to/luau`
- `python tests/run_town_service.py /path/to/luau`

These execute the production mixer/client selection, combat timer script,
authoritative damage observer and actual town diplomacy through engine mocks.
Audio asset playback and audible mix must still be checked in Studio with the
experience's actual uploaded Sounds.
