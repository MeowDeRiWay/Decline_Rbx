# Pressure mines

Item ID: `Mine`. Put the existing mine Model/BasePart at `ServerStorage/Items/Mine`
(category folders are supported). If missing, the server creates a small green
placeholder. A custom model replaces it on the next server startup. The mine
uses the PrimaryWeapon slot and key 1, then LMB to install in front of the player.
It is not a melee weapon. No crafting recipe was added.

## Model configuration

Number attributes `KillRadius=5` and `BlastRadius=20` define blast zones exactly
as on rocket ammunition. Optional `AnimationSet=Mine` selects two-hand support;
missing values use the mine default. Optional `Sounds/ExplosionSound` supplies
the blast clip; otherwise the server uses AT4's configured ExplosionSound.

## Installation and activation

The actor crouches, lowers the mine to the placement point, works with both
hands, and rises. The held mine is consumed once at the 2.5-second commit.
Cancellation/KO before commit leaves it in inventory; stale callbacks cannot
consume it later. The deployed mine arms five seconds after commit. Until then
it is safe to step on. After arming, owners, allies and enemies all trigger it.
A swept horizontal pressure check catches fast runners between server samples,
with height separation to prevent triggering through another floor. Teleports
are not swept across the map. Mines last for the current server session and
remain active if their owner leaves.

## Discovery

Detection radius in studs is `20 * (.25 * Attention/10 + .75 * Traps/300)`.
Attention is clamped to 0–10, Traps to 0–300. Attention 10/Traps 300 gives 20;
Attention 10/Traps 0 gives 5. This implementation treats lower skill as a shorter
radius, not a hard requirement to reach 300. LOS is required for first discovery.
The owner knows their own placement. Discovery is remembered per player until
respawn or removal, announced once as 'Помічена пастка' in the events/chat log,
and shown with a red blinking fill. Only detected players receive visual clones;
undetected mines do not have visible art replicated to everyone. The marker is
an invisible, non-queryable server anchor. Known art displays only within 20 studs.

## Disarming

Approach a discovered mine without stepping on it and use its E prompt from
within 2.5 studs. The same crouch/work/rise animation runs. The server checks
range, LOS, discovery, life state and a per-mine lock. Only one disarmer can work
on a mine at a time. There is no immunity to pressure while disarming.

Setting skill is snapshotted at installation. Other players' success chance is
`clamp(.90 + (disarmerTraps - settingTraps)*.0085, .05, 1)`.
Equal skill is 90%; a deficit of 100+ is 5%; superior skill can reach 100%.
The owner's own recovery is unconditionally 100%, without a random roll.
Success puts exactly one mine into the disarmer's inventory. Failure detonates
it immediately, including while unarmed. Cancellation releases the lock.

## Explosion and accountability

Mine blasts explicitly enable friendly fire. The lethal core causes final death;
the outer zone uses ordinary wall/armor/KO rules. All actual player victims get
a private events/chat notice naming the planter's @username, including KO victims.
For same-team/group/allied-town damage, the victim town's online mayor receives
an additional notice naming planter and victim. The username and affiliation
are stored when planted, so notices still work after the owner disconnects.
The blast records LastDamagerID and LastHitItem=Mine. There is no offline mayor
notification queue and no deployed-mine persistence across server shutdown.
