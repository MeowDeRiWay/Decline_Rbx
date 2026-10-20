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
requests reload automatically. T switches FMJ/AP and clears the magazine
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
initial per-stud resistance. AP halves hard-material resistance; soft materials
use the same cost. Crossing reduces speed and damage via remaining budget.

Set custom string `Material` on the Wall/Corner/DoorWay Model or individual Part:
Wood,Glass,Brick,Concrete,Metal,ArmorSteel. Nearest attribute overrides ancestors.
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
