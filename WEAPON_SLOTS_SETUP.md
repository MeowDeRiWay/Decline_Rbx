# Two weapon slots and medical hand actions

## Player controls

Equip a weapon from inventory into its permanent slot, then press its number to
use it. `PrimaryWeapon` / **1** holds axes, shovels, SMGs, rifles, assault rifles
and light/heavy machine guns. `SecondaryWeapon` / **2** holds pistols (including
the pipe pistol) and knives. Numpad1/2 work as well. Pressing the selected number
stows that weapon and frees the hands; selecting the other number stows first,
then draws. The existing Holster button stows, or redraws the last weapon slot.
An empty slot cannot draw anything. Draw requirements are checked on the server.

`Hands` is retained for utility items such as buckets; it accepts no player
weapons. Drawing a weapon or medicine returns the held utility item to inventory.
Backpacks keep the separate `Back` slot. Unarmed combat still works with free hands.
Weapons assigned to slots stay equipped while stowed and cannot be dropped or
transferred as inventory stacks until unequipped. Replacing/unequipping the active
slot first stows it. Both weapon slots are lootable exactly once on KO/corpse
extraction; unique condition, magazine/type/mode/cooldown data stays with the item.
The weight perk for a held weapon applies only to the active weapon, not both.
Older Hands-only sessions migrate the held weapon into its correct slot once.

**H** stows the current hand item, then draws the equipped Medicine item.
Click yourself or a nearby player to treat. **H** again stows medicine; **1/2**
stows it and draws the selected weapon. The HUD Medicine button uses the same
flow. RMB > Apply medicine enters this targeting flow. Medicine includes ordinary,
great/sterile bandages and antiseptic. No change to Doctor's **4** animation yet.

## Visual placement

Existing item templates and their authored grip pivots are reused. Stowed weapons
are cosmetic copies named `HolsteredPrimaryWeapon` / `HolsteredSecondaryWeapon`,
not pickups or additional inventory items. They are massless, non-colliding,
non-touching and non-queryable. `HolsterWeld` follows torso and body-fall poses.

Defaults place the long weapon along the right back, magazine facing outward, and the one-handed weapon on
the right hip. If an authored rig needs a more exact fit, add optional attachments:

- `UpperTorso/PrimaryWeaponHolster`
- `LowerTorso/SecondaryWeaponHolster`
- `UpperTorso/MedicineHolster` (optional draw/stow pouch pivot)

Each attachment's WorldCFrame is the item template pivot when stowed. This is the
same pivot used when placing the item in the hand; the model's individual parts
keep their authored offsets. No separate holster/scabbard model is required.
Medical items use their existing model IDs under `ServerStorage/Items` categories.

## Timing and authority

`Shared/HandActionPose` owns timings: stow 0.50s (handoff 0.36s), draw 0.55s
(handoff 0.18s), treatment 2.20s (effect at 1.60s). All viewers pose nearby
characters using replicated phase/timestamp attributes and local IK; no per-frame
animation remotes. Walking continues during weapon switches. Medical treatment
stops walking/running and mouse-facing until the action completes.

`HandActionService` sequences ownership-neutral handoffs. `HandsBusy` blocks
weapon use, reload and competing interactions/slot changes. An attack already in
flight cannot complete after a hand action starts. KO/death, disconnect and
character/inventory replacement invalidate pending callbacks. Repeated inputs do
not overlap actions. The server rechecks target identity, distance, LOS, medicine
and healer state at treatment contact; invalid/cancelled treatment spends nothing.
Normal healing, poison/Sick rules and Doctor revival are otherwise unchanged.

## Verification

Automated tests exercise real inventory/hand action services with deterministic
clocks, separate weapon UIDs/magazines, timed stow-before-draw, combat locks,
medicine preparation/contact/cancellation, weight conservation, migration, loot,
disarm, reconnect and utility items. Geometry tests check actual rig IK, model
pivots, body/hip anchors and non-colliding holster copies. EN/UK/RU help is updated.
Studio multiplayer visual review remains necessary for the author's specific
weapon pivots, backpack overlap and self/other bandaging poses.

Verification run: all 79 Python integration runners pass; all 203 production Luau
files compile. Relevant pure medical, item requirements, new perks, character
stats, movement and sprint tests pass. Four older pure-test files
(progression_rules, tool_tiers, stove_fuel, resource_rules) already fail unchanged
on the parent commit f5012a9 due to old balance expectations; baseline failures
were reproduced separately and are not changes introduced by weapon slots.

## Right-hand draw refinement

Long weapons now use the right back with the grip above the mid-back and their
magazine/local -Y side facing outward. Their draw/stow path passes outboard and
above the right shoulder, not linearly through the torso. Both slots use only the
right hand during the transfer. The left support hand releases at the start of
stowing and smoothly joins the ordinary holding pose near the end of drawing;
it cannot jump to a pistol's forward grip on the item-spawn frame.
Uploaded Items.rbxm model measurements are included in a geometry regression
fixture to verify the real rifle/SMG pivots and magazine direction. Medicine
storage and self/other treatment paths retain their previous behavior.

## Remote animation frame stability

Remote IK is still calculated at approximately30Hz, but the resulting body and
held-item Motor6D.Transform values are reapplied every PreSimulation step. This
prevents intervening Animator/native updates from showing the authored pose on
skipped frames. The owner keeps its existing full-frequency pose calculation.
Cosmetic descendant changes (including shot sounds) no longer recreate the gait
record or discard planted feet when the rig joints are unchanged. Distance culling,
KO/death and streaming replacement invalidate caches and restart feet safely.
The regression simulates Transform resets at60/120/144Hz, verifies pose continuity,
keeps the IK budget, preserves feet across sounds, and checks KO/revival ownership.
