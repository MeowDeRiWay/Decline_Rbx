# Backpacks — 30 October 2026

Keep the existing model at `ServerStorage/Items/BackSlot/Backpack1`.
The uploaded `StarterCharacter+Backpack1.rbxm` contains both reference models;
only Backpack1 belongs in the item folder. No character copy, extra anchor,
manual weld or model script is needed.

BackVisuals measures the common model pivot relative to UpperTorso from that
reference. The backpack pivot offset is (-0.00836181640625,
0.000006198883056640625, 0.25269100069999695) in torso space, without rotation.
The provided PrimaryPart has identity PivotOffset. Geometry stays relative to
Model:GetPivot(); new larger/decorated variants keep the same pivot/orientation
and can reuse this fit. Optional item BackOffset overrides this shared default.

The rendered EquippedBack is separate from Body armor and HeldItem. Each piece
has a massless, non-colliding/non-queryable BackWeld to UpperTorso, following its
animation. BodyFall also tracks BackWeld when moving anchored KO/death bodies.
Removing/replacing the Back item clears the previous backpack only.

| Parameter | Backpack1 |
| --- | --- |
| Slot | Back |
| Weight | 1 kg |
| Capacity bonus | +10 kg while equipped |
| Recipe | 3 Cloth |
| Repair | 60 |
| Reusable tool | SewingKit |
| Station | Workstation |
| Duration | 60 seconds |

MakeSewingKit now also requires Repair60. Its existing 5 Scrap cost and 20-second
duration are unchanged. Neither recipe consumes the sewing kit.

InventoryService derives EquipmentCarryBonusKg from equipped Back only.
ProgressionService preserves BaseCarryLimitKg from Strength/level/perks; effective
CarryLimitKg adds the equipped bonus. Inventory refreshes, leveling and changing
attributes cannot accumulate or erase the same bonus. Character stats, inventory
weight display and movement overload use the effective limit. The backpack's own
1 kg remains part of carried weight whether worn or in inventory. Unequipping,
resetting and corpse extraction remove the capacity bonus immediately; items
remain in the normal shared inventory rather than a separate backpack container.

Tests: run_backpack_visuals.py (actual uploaded pivot, rotated/bent torso and
larger variant), run_holster_service.py (equip/weight/removal/extraction),
run_progression_service.py (derived capacity), run_cooking_progression.py
(crafting requirements and outputs), run_body_fall.py (anchored backpack during
KO/death), craft_update.test.luau and run_localization.py. Studio rendering still
needs a playtest with the authored item template.
