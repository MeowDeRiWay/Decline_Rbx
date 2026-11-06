# Explosion zones — projectile and trap attributes

Add two **Number** attributes on the projectile/trap Model or BasePart:

| Attribute | AT4 rocket value | Meaning |
| --- | --- | --- |
| `KillRadius` | `5` | Inner radius in studs; immediate final death, including KO victims |
| `BlastRadius` | `20` | Total outer radius, including the lethal core |

For AT4, put these on `ServerStorage/Items/AmmoAT4FMJ`, **not AT4**.
Missing/invalid attributes fall back to the ammo's Explosion configuration.
Settings are snapshotted at launch; editing the template does not change a
rocket already in flight. The launcher no longer defines a blast radius.

0–5 studs with unobstructed line of sight: instant final death, bypassing armor.
An obstacle cancels instant death even in the core: ordinary damage is halved
and then reduced by armor, with the normal KO rules.
Above 5 to 20 studs: base damage = `100 * (20 - distance) / 15`.
At 12.5 studs this is 50; at/beyond 20 it is 0. Outer-zone wall shielding
halves damage before explosive armor/resistance. It follows the usual KO rules.
The shooter is affected too. Existing ally protection and spawn ForceFields
remain in force. Startup rear exhaust is separate and keeps its existing rules.

Shared trap API (no trap deployment system currently exists):
`ExplosionRules.Resolve(trapModel, defaults)` returns validated settings;
`ExplosionService.Detonate(point, settings, ownerPlayer, ownerCharacter, itemID, baseDamage)`
applies the same zones. Resolve settings when arming a trap. KillRadius 0
disables instant death. BlastRadius is the total radius, not the width of the
falloff ring. Victims are deduplicated, and the visual rocket blast matches it.

# Rocket approach, departure and flyby audio

Rocket traces carry their actual velocity to the local anchored emitter.
Roblox's native Doppler handles the higher approaching pitch and lower receding
pitch (`SoundService.DopplerScale`, normally 1). The module does not change this
global property or apply another scripted Doppler pitch shift.

`RocketAudio` smooths an equalizer: distant sound loses high frequencies, and
receding sound is duller. A separate loop swells within 24 studs of the listener,
then fades on departure. Listener-relative speed gates this layer, so stationary
or co-moving sources do not create a false high-speed flyby. The mix uses the
character's head, matching Decline's hearing position, with camera fallback.

Optional `AT4/Sounds/FlybySound` is a dedicated seamless whistle loop. Without it,
the existing FlightSound supplies a quieter, higher-pitched high-frequency layer;
this fallback cannot turn a hiss recording into a clean tonal whistle. Main
FlightSound retains its authored volume through 40 studs. Both loops stop on
impact, range expiry or trace timeout; network updates never restart them.
No extra per-frame remotes are added.

For another project, copy `ProjectileAudioRules` (Shared) and `RocketAudio`
(client). Call Start once per projectile with flight/optional flyby settings,
set record.Part and record.Velocity, Update with listener position/velocity and
delta time, and Stop when the projectile ends. Sounds are local to each viewer.
Final timbre and native Doppler should be auditioned in Studio with the actual
chosen audio assets.

# AT4 audio

Inside the AT4 model add a Folder named `Sounds` containing four **Sound**
instances. Assign permitted Roblox audio assets to their `SoundId` properties:

| Sound name | Trigger / position |
| --- | --- |
| `ReloadSound` | Accepted reload; stops if interrupted |
| `ShotSound` | Accepted rocket launch at muzzle |
| `FlightSound` | Loops on the moving rocket; stops on impact, range expiry or trace timeout |
| `ExplosionSound` | Plays once at impact, independently of the short visual flash |

Volume and PlaybackSpeed are authored on each Sound. Optional numeric attributes
MinDistance/MaxDistance control spatial falloff for flight (default 40–100 studs)
and explosion (3–150 studs). Reload/launch retain existing weapon audio rules.
Rocket ignition emits the rear jet immediately; the rocket/muzzle effect begins
0.5 seconds later. Ammo is spent once on accepted ignition, and the movement
pause covers this delay. The existing launch sound starts with ignition.
FlightSound stays at authored volume through 40 studs (MinDistance floor 40),
then fades toward MaxDistance (default 100; always greater than MinDistance).
Flight and explosion remain spatial for the shooter as well as observers.
Their settings are captured on launch, so holstering or dying does not silence
an already airborne rocket or its later blast. Missing/empty audio is silent;
no placeholder audio IDs are supplied. Audio adds no damage or blast events.

# Weapon animation attributes — 5 November 2026

Add these **String** attributes to the top-level weapon Model/BasePart in
`ServerStorage/Items` (category folders are supported). They are copied to
`HeldItem`. Missing or invalid values use existing item defaults.

| Attribute | Supported values | Purpose |
| --- | --- | --- |
| `AnimationSet` | `Pistol`, `Rifle`, `Launcher`, `Knife`, `Axe`, `Shovel` | Held posture and one/two-hand support; pistol/launcher placement |
| `ReloadType` | `Pistol`, `AR`, `Bullpup`, `SingleRound`, `Rocket`, `None` | Cosmetic reload motion; `None` disables the motion |

Defaults: pistols use Pistol/Pistol; pipe pistol uses Pistol/SingleRound;
pipe rifle and Rifle223 use Rifle/SingleRound; LSW223 and MarksmanRifle223
(Enfild X7) use Rifle/Bullpup; other long guns, including MachineGun308,
use Rifle/AR; AT4 uses Launcher/Rocket; melee tools use their matching set
and None. There is no BeltFed type.

Rocket tips the muzzle forward/down by 90 degrees so the rear opening faces
up, feeds from above into that opening, and returns to the shoulder-ready pose. SingleRound repeats the
hand motion for the number of rounds loaded. Magazine types reach toward the
pistol grip, forward magazine, or rear bullpup magazine respectively.
Bullpup reloads use the right hand; the left hand stays on its support grip.
These are procedural hand/weapon gestures; they do not spawn loose cartridge,
rocket or magazine meshes or detach model parts.

Optional **Attachment** `ReloadGrip` marks the insertion point on a particular
model; place it on a weapon BasePart. Without it, magazine types use generic
positions and Rocket uses `_BackblastOrigin`. Existing RightHandGrip and
LeftHandGrip attachments still control the ready hand positions.

The server announces accepted reload start, duration and round count. Each
viewer samples the same timeline, and cancellation/expiry restores the grip.
Attributes do not change ammo capacity, damage, actual reload time, slot,
requirements, or melee attack/contact timing; those remain in ItemConfig.
Changing a template takes effect on the next equip. Verify the final hand fit
on authored models in Studio.

# Current wall and armor penetration — 23 October 2026

This section supersedes earlier ammunition penetration descriptions below.

For wall thickness 0.1 stud, both FMJ and AP follow identical rules:

| Caliber | Glass / wood / aluminum | Brick | Concrete |
| --- | --- | --- | --- |
| 9 mm | Penetrates if budget remains | Stops | Stops |
| .223 | Penetrates if budget remains | Penetrates if budget remains | Stops |
| .308 | Penetrates if budget remains | Penetrates if budget remains | Penetrates if budget remains |

Material/angle/thickness still consume the shared projectile range budget.
At 0.1 stud a brick wall costs180.1 and concrete costs320.1 budget units, plus air
travel. Current .223 range350 permits one near brick wall; .308 range450 permits
one near concrete wall. No infinite wall traversal. Unknown geometry/material
still stops the shot. AP never reduces world-material cost or changes speed/range.

| Ammunition | Ignore absorption | Ignore resistance (percentage points) |
| --- | --- | --- |
| .223 FMJ | 2 | 10 |
| .223 AP | 3 | 15 |
| .308 FMJ | 5 | 20 |
| .308 AP | 5 | 40 |

No values were specified for9mm FMJ/AP, so both remain0/0 until balanced.
Projectile caliber/type determines these server-side values; clients cannot set
them. They apply to both players and zombies through the common damage service.

Damage order: roll base damage and critical multiplier; reduce effective armor
by the ammunition's ignore values; apply percentage resistance first, then flat
absorption; clamp at zero; add the flat Bonus ranged damage perk last. Resistance
ignore subtracts percentage points (50%-15%=35%), not15% of the armor's value.
Ignore is bounded at zero and operates on capped90% effective resistance.
The flat perk bonus is not reduced by armor or multiplied by criticals and can
deal damage when the base bullet is completely absorbed. It does not bypass
creation/ForceField/friendly-fire protection. Existing Anatomy full bypass and
melee Piercing strike retain their original behavior. No firearm base-damage
rebalance has been invented from the qualitative automatic-weapon design note.

Actual projectile tests cover caliber gates, two-layer walls, FMJ/AP parity and
armor option propagation. Damage authority tests cover player/zombie armor values
and perk order. Compilation and Rojo build pass; no Studio playtest.

---

# Rifle and ammunition

## Studio models

- `ServerStorage/Items/Weapons/Range/Rifle223`: Model, grip pivot authored like other
  held tools. Include a Model named `Muzzle`; its pivot is the shot/flash origin.
  The equipment service generates an internal `_ShotOrigin` Attachment from that
  pivot so it follows welded weapon movement. Keep the authored Muzzle model.
- `ServerStorage/Items/Weapons/Ammo/AmmoBox223FMJ`: Model with string `Caliber="223"`,
  string `AmmoType="FMJ"`, number `MaxAmmo=50`. Optional AP template is
  `AmmoBox223AP` with `AmmoType="AP"`. Any category Folder hierarchy is supported.
- Put copies on the map to test. Existing item discovery moves them to WorldItems.
  Each fresh box rolls AmmoCount from1 through MaxAmmo once; repeated registration
  does not reroll. Collection unpacks it into Ammo223FMJ/AP inventory quantities.
  A box with a different caliber/type is rejected, not silently converted.

## Controls and initial gameplay values

Hold LMB for automatic fire; R reloads. Holding fire with an empty magazine
requests reload automatically. B switches FMJ/AP and clears the magazine
allocation; reload to use the new type. English weapon HUD shows magazine,
selected type, reserve, reload status and durability. Menus/text input block fire.
Aim uses the mouse projected on the muzzle's horizontal plane (no vertical aiming
or scope yet). Character facing still follows the existing mouse controller.

Rifle223:30rounds,600RPM,2.5second reload,750studs/s,350stud initial range budget,
25base damage,3000shots condition,3.2kg. Ammunition .012kg/round. These are initial
GAMEPLAY values, not a physical ballistics reference. All registered in ItemConfig.
Only .223 FMJ/AP are wired at this stage; the other discussed calibers need future
item/weapon definitions.

Loaded ammunition belongs to each weapon's inventory record. Reload completion
moves loose rounds into that weapon; firing consumes one loaded round and normally
one condition point. Switching ammo type returns the old loaded rounds to pockets.
The reserve HUD counts loose rounds only. Dropping loose ammunition never removes
the contents of a weapon's magazine.

Weapon records preserve condition, loaded count, FMJ/AP selection and fire mode
through holster/equip, chest transfers, world drops/pickups and corpse extraction.
Identical weapon condition + loaded count + ammo type share an inventory stack;
any difference creates a separate row. Actions select the exact displayed variant,
and inventory descriptions show condition and magazine contents. Holster remembers
the actual weapon UID, and cannot restore an item no longer owned. Its next-shot
cooldown survives holster to prevent bypassing the fire rate. Pending reloads cancel
on weapon/character changes and consume nothing until successful completion.
No standalone magazine items or cross-server persistence have been added.

## Projectile and materials

Server owns rate, ammo, reload, condition, origin, collision and damage. Client
sends only commands/normalized aiming direction. Muzzle cannot bypass a wall
between character root and origin. One shared server Heartbeat sweeps segments,
so750stud/s projectiles still hit .05stud Parts and moving targets. At most256live
projectiles; each is limited to64impacts. No physical bullet Parts on the server.

Air consumes range1:1. Material crossing additionally consumes resistance times
actual traversed thickness, including oblique angle. FirearmRules contains the
initial per-stud resistance. AP uses the same material resistance as FMJ; soft materials
use the same cost. Crossing reduces speed and damage via remaining budget.

Set custom string `Material` on the Wall/Corner/DoorWay Model or individual Part:
Wood,Aluminum,Glass,Brick,Concrete,Metal,ArmorSteel. Nearest attribute overrides ancestors.
For household metal shelves, counters and other light aluminum props, add the
string attribute `Material = "Aluminum"` to their Model or individual Parts.
Aluminum uses the same resistance as Wood (180 per stud; 18.1 total budget at
0.1 stud), so 9 mm, .223 and .308 can penetrate it while budget remains. This is
a gameplay material, not an inventory resource. Native Roblox Metal remains
heavy Metal unless overridden by this attribute; visual appearance is unchanged.
Without an attribute, supported native Roblox materials are used; unknown ones
stop bullets. Current thickness calculation supports BLOCK Parts. MeshParts,
Unions,Terrain and non-block shapes stop bullets conservatively; their hollow
geometry is not approximated as a box for penetration.

A material Model's adjacent/overlapping block intervals are merged (max128parts
per impact), so Inside/Outside .05+.05 gives .1 thickness, no overlap double cost,
and one entry/exit effect. Gaps remain gaps. Different embedded materials are not
a composite armor simulation. Bullets currently stop on a living target; existing
Accuracy roll applies and displays Miss on failure. Ranged hits do not use melee
Strength/Knife bonuses or KevlarApron's melee-only absorption. Existing kill XP
and LastDamagerID/LastHitItem tagging are preserved.

Nearby clients (200studs) receive batched flash, moving short trail and material
entry/exit particle events. Trace Parts are non-queryable client-only visuals and
expire; impact particles are capped80events/s per client. No ricochets,
wall destruction or persistent bullet holes in this first implementation.

Validation: run_firearm_rules.py, run_firearm_service.py,
run_firearm_projectiles.py, run_ammo_pickup.py, equipment regression, Luau compile
and Rojo build. These use mocks; actual Studio visual/grip/performance testing
remains necessary with the authored models.

## Gun sounds

Inside Rifle223 add a Folder named `Sounds` with two Sound instances:
`ShotSound` and `ReloadSound`. Set each SoundId to the Roblox audio asset URI,
e.g. rbxassetid://123456789; author Volume and PlaybackSpeed there. Keep the
sound templates stopped. The same convention works for future firearm models.
Do not put the templates in SoundService: the equipped copy supplies its own art.

Server-confirmed shots clone ShotSound at the generated muzzle Attachment;
rapid shots overlap without restarting the previous one. ReloadSound starts only
when a valid reload begins and stops at completion, ammo-type change, weapon
change, character reset or player removal. Missing sounds are optional and do
not prevent shooting. Sounds use spatial rolloff: default3..150stud shot,
3..25stud reload. Optional number attributes MinDistance/MaxDistance on each
Sound override those ranges. Volume/PlaybackSpeed remain authored. Clips clean up
on Ended and have a15second safety expiry. Roblox asset access must allow the
experience to play the chosen SoundIds; no audio IDs were supplied by the user.

Rifle held height uses Firearm.HoldHeightRatio=.4 of root height above root center
(shoulder). Existing grip X/Z and rotation are retained; melee tools keep their
old positions. Muzzle safety ray follows a vertical-then-horizontal path through
shoulder height, so a low window sill does not block a clear raised muzzle.

AudioListener.client positions the legacy Sound listener at the player root with
camera orientation. Overhead camera height and zoom no longer attenuate the
player's own reload/footsteps. Without a character it restores default camera
listening. This affects spatial Sound instances; no new audio assets are required.


Current controls: C character, T talents, Q inventory, R reload, B ammunition type, V fire mode. R prefers the selected ammo type; if none is available, it automatically reloads the other available type. Existing cartridges are returned to inventory before changing types, without mixing types in one magazine.


### Own weapon audio

The shooter hears shot/reload through a local non-positional copy, preserving the authored Sound volume and playback speed. The original muzzle source is muted only on that shooter's client, so other listeners keep the normal spatial sound and distance attenuation. Cancelling reload, holstering or respawning stops the local copy. No new audio assets or model changes are required.

## Updated .223 lineup

| Item/model ID | Damage per bullet | Magazine | RPM | Skill | Mode |
| --- | --- | --- | --- | --- | --- |
| Rifle223 | 23–27 | 5 | 40 | LightWeapons | Bolt-action |
| ServiceRifle223 | 21–25 | 20 | 300 | LightWeapons | Semi-auto only |
| MarksmanRifle223 (Enfild X7) | 21–25 | 20 | 300 | LightWeapons | Semi-auto only |
| AssaultRifle223 | 19–23 | 24 | 600 | LightWeapons | Auto/single |
| LSW223 | 18–22 | 30 | 700 | HeavyWeapons | Auto/single |

LSW223 represents the classic Fallout 2 model. Its authored Sight supplies the
AccuracyBonus through the existing mechanic; no extra accuracy is added in item
configuration. New item templates go under any category in ServerStorage/Items
with these exact IDs. Models retain their authored scale. Existing generic admin,
loot and equipment systems discover the new definitions. SR explicitly excludes
bolt-action Sniper/disarm effects, including the character panel's critical chance.

New SR and LSW recipes use ArmsBench, 25 Iron, Repair170, 120seconds, 500XP,
matching the current .223 weapon crafting tier. SR300RPM, LSW6kg and existing
.223 range/reload defaults are initial tuning values.

## Player equipment slots — 27 October 2026

Equipment uses exactly Body, Hands, Back, Additional and Medicine. There is no
Head equipment slot; the character's physical Head remains for aiming/hearing.
Armor suits use `Slot = "Body"` and their Armor absorption/resistance are the only
equipment armor values counted. Back/Additional/Hands/Medicine remain usable for
their own items but do not add separate armor layers. Items in retired equipment
slots are returned to inventory with their condition and weapon/ammo metadata
preserved when inventory state is refreshed or extracted into a corpse.

Enfild X7 initially uses ServiceRifle223 combat values (Strength 4, 3.2 kg, 2.5 s reload). Its Sight uses the existing model accuracy mechanic. Both X7 and LSW cost 7 Iron + 2 Plank; X7 requires ArmsBench/Repair 150, 120 s, 500 XP. Standard .223 FMJ and Rifle223 now use Workstation.

## .308 marksman rifle

`MarksmanRifle308` uses the X7 configuration with .308 ammunition and 30–34 damage: 20 rounds, semi-auto only, 300 RPM, LightWeapons, Strength 4, 3.2 kg, 2.5 s reload. Sight accuracy comes from the authored model. No crafting recipe until steel and its crafting station exist.

## Component-based weapon models

A firearm Model can contain `Stock`, `Receiver`, `Grip`, `Magazine`,
`Handguard`, `Barrel`, and `Sight` (each a Model or BasePart). `Sounds` stays
separate. Sight replacement/modification is reserved for a later update.

The right hand uses the geometric center of `Grip`; the left hand uses the
center of `Handguard`. No manually authored hand Attachments are required.
The model pivot may stay elsewhere: equipping aligns the Grip bounding-box
frame to the existing held pose. Keep the Grip frame axes consistent between
weapons, with forward along local -Z. An empty component is ignored.
Legacy models still use their existing attachment/pivot fallbacks.

All reload types, including Bullpup, keep the right hand on Grip and load with
the left hand. Magazine reloads reach the center of `Magazine`; SingleRound
reaches `Receiver`. Rocket rear loading retains its existing rear-opening
fallback. This update animates the hands; detachable moving magazines and
Sight swaps are not implemented here.

No visible Muzzle object is necessary. With no explicit marker, the code creates
an invisible `_ShotOrigin` Attachment at the forward face of `Barrel`, using the
Grip forward axis. Optional `ShotOrigin` or legacy `Muzzle` markers override
this; their marker geometry is hidden on the held clone. The actual Barrel
geometry remains visible. Runtime-generated helpers need no Studio setup.

Rifles and automatic weapons rest across the waist with their muzzle pointing
left, held with both hands. Pistols point down in the right hand, with the left
arm free. Launchers stay on the shoulder and release the left support hand.
Support release and return blend smoothly; reload always restores its left-hand
action. MachineGun category retains its previous carry pose pending a separate
design. An accepted shot keeps the ready pose active for four seconds; reload
poses take priority. This is a
cosmetic timer, not a new aiming control, accuracy modifier, or damage rule.
Check each weapon's fit, barrel direction, and hand reach in Studio before release.
