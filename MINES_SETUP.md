# Pressure mines

Item ID: `Mine`. Put the existing mine Model/BasePart at `ServerStorage/Items/Mine`
(category folders are supported). If missing, the server creates a small green
placeholder. A custom model replaces it on the next server startup. The held mine preserves its authored horizontal pose and has two side grips
close to the torso for bent elbows. The mine
uses the PrimaryWeapon slot and key 1, then LMB to install in front of the player.
It is not a melee weapon. No crafting recipe was added.

## Model configuration

Number attributes `KillRadius=5` and `BlastRadius=20` define blast zones exactly
as on rocket ammunition. Optional `AnimationSet=Mine` selects two-hand support;
missing values use the mine default. Optional `Sounds/ExplosionSound` supplies
the blast clip; otherwise the server uses AT4's configured ExplosionSound.

## Installation and activation

The actor crouches, lowers the mine to the placement point, works with both
hands, and rises. The held mine is consumed once at the 2.5-second commit. If pockets contain
another mine, exactly one replaces it in the same active primary slot and stays
drawn. With no spare, the slot and hands become empty.
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
Owners use the same skill-weighted discovery radius; installation does not auto-reveal a mine. Discovery is remembered per player until
respawn or removal, announced once as 'Помічена пастка' in the events/chat log,
and shown with a red blinking fill. Only detected players receive visual clones;
undetected mines do not have visible art replicated to everyone. The marker is
an invisible, non-queryable server anchor. Known art is displayed only within the current skill-weighted radius, at most 20 studs.

## Disarming

Approach a discovered mine without stepping on it and click it with LMB from
within the normal interaction distance (ItemConfig.PickupDistance, currently 2 studs). There is no E prompt, and that click takes priority over shooting/punching. The same crouch/work/rise animation runs. The server checks
range, LOS, discovery, life state and a per-mine lock. Only one disarmer can work
on a mine at a time. There is no immunity to pressure while disarming.

Setting skill is snapshotted at installation. Other players' success chance is
`clamp(.90 + (disarmerTraps - settingTraps)*.0085, .05, 1)`.
Equal skill is 90%; a deficit of 100+ is 5%; superior skill can reach 100%.
The owner's own recovery is unconditionally 100%, without a random roll.
Success puts exactly one mine into the disarmer's inventory. Failure detonates
it immediately, including while unarmed. Cancellation releases the lock.

## Explosion and accountability

Mine blasts explicitly enable friendly fire. The lethal core causes final death only with no intervening obstacle; a wall
turns even inner-core damage into an ordinary reduced hit that can cause KO;
the outer zone uses ordinary wall/armor/KO rules. All actual player victims get
a private events/chat notice naming the planter's @username, including KO victims.
For same-team/group/allied-town damage, the victim town's online mayor receives
an additional notice naming planter and victim. The username and affiliation
are stored when planted, so notices still work after the owner disconnects.
The blast records LastDamagerID and LastHitItem=Mine. There is no offline mayor
notification queue and no deployed-mine persistence across server shutdown.
