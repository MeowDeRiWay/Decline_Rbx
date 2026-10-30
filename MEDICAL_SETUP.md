# Medical rescue and escalating zombies — 30 October 2026

## Authored items

Create the reusable Sound-free item models under an Items category folder, e.g.:

- `ServerStorage/Items/CraftMedicine/MedicalAlcohol`
- `ServerStorage/Items/CraftMedicine/Antiseptic`

IDs are exact; copying a water-bottle model is fine. Both items weigh 0.6 kg.
MedicalAlcohol is a crafting material, not a consumable. Add it to the pharmacy's
existing authored spawn pool as requested; no new loot frequency is invented.
Antiseptic is a medical material, never a drink. Equip it in Medicine and press H,
then click yourself or a nearby patient; RMB on a KO patient also offers Apply medicine.
H now first stows weapons and draws medicine; treatment uses an animation before
server-validated contact (see WEAPON_SLOTS_SETUP.md). Each application consumes one equipped bottle and returns one EmptyBottle; the slot
auto-refills from inventory. Neither MedicalAlcohol nor Antiseptic has a Drink action.

MedStation recipe MakeAntiseptic: 5 CleanWater + 1 MedicalAlcohol -> 5 Antiseptic
and 1 EmptyBottle (the extra alcohol container). Doctor50, one batch. Unspecified
craft duration/XP use initial defaults of 60 seconds and 100 XP per finished batch.
The three existing cloth/bandage recipes still need the reusable SewingKit.
SterileBandage is now defined: GreatBandage1 + Antiseptic1 -> SterileBandage1
and EmptyBottle1. Doctor100, MedStation, no sewing kit required,20seconds,100XP.
It weighs0.1kg like both existing bandages, uses the Medicine slot/H targeting,
and auto-refills from inventory. Healing matches GreatBandage: twice patient
Endurance plus2HP per complete20FirstAid (existing perk multipliers/bonuses apply).
It removes 20 + 2*floor(healer FirstAid/20) Sick points, plus10 with Paramedic,
and makes a fixed50% poison-cure roll, without Luck.
It may treat Sick/poison at fullHP but never revives a KO player. No HP/debuff need
means no item consumption; failed cure rolls still spend the bandage.

## Poison and sickness

Poisoned=true increases Sick by exactly 1 point per second; the background
threshold-based Sick growth is suppressed while poison itself supplies growth.
Applied antiseptic always removes 20 + floor(healer FirstAid/20) Sick, including
on a failed cure roll. Its poison cure chance is 0.25 + 0.05*healer Luck, clamped
at1 (Luck10 =75%). Paramedic affects neither its Sick reduction nor HP.
A successful roll additionally clears Poisoned. No roll without spending medicine.

MedicalConfig.ZombiePoisonEnabled=false, following the user's final instruction.
The optional chance is 0.05 and is checked only after actual positive zombie
melee damage to a live player. Direct per-hit infection remains disabled; the old
ZombieStats.Infection helper is preserved for future use. Poison can be tested by
setting a character's Poisoned attribute on the server.

HospitalResting suppresses poison/sickness progression and survival damage.
HospitalBedService treats Sick at 2 points/second, with no natural HP regeneration
until Sick reaches zero and poisoning clears. Normal bed regeneration then resumes
at the existing HospitalRegenMultiplier cadence (default every20seconds). A KO
patient accumulates normal bed HP while still unconscious. Only when Sick=0,
Poisoned=false and HP>=50%MaxHP does the bed automatically revive them, retaining
HP and the bed pose. Manual Doctor cannot bypass these bed conditions.
Empty Food or Water prevents HP regeneration even at a bed. These treatment rates
are explicit defaults in MedicalConfig, not hardcoded into authored models.

## Player actions and carrying

RMB on a knocked-out player offers Apply medicine, Doctor, Loot player, Pick up player. Doctor
uses the existing skill roll, cooldown and range/LOS authority; H and4 shortcuts
remain available. RMB on a corpse also offers Search body. Menus block local
weapon activation; all remote actions independently validate on the server.

Pickup requires an active confirmed carrier, another live knocked-out player,
3stud distance and clear LOS. Patients on beds, already carried players, chains
and self-carry are rejected. A carrier's weapon goes into inventory; weapons cannot
be equipped/used while carrying. Carried patients lie belly-down over the carrier's left shoulder with relaxed,
hanging arms and legs. The carrier supports them with the left hand, leaving
the right arm free. The server applies the replicated Carried C0 pose once and
moves its root with the shoulder; viewers never reuse the fetal ground pose.
Armor/backpack/holster attachments retain their body-relative offsets through
carry, drop and hospital transitions. The KO deadline does not reset. Running drains
sprint reserve twice as quickly, without changing recovery or ordinary walking.

RMB anywhere while carrying offers Put body down. RMB on a free tagged hospital
bed also offers Place on bed. Invalid/occupied beds leave the patient carried.
The existing Model HospitalBed=true, optional BedSurface/BedPoint and normal
2stud interaction reach are reused. Carry ownership clears on either participant
leaving, carrier KO/death, patient revival or replacement. Disconnect snapshots
release carried bodies before cloning them.

Loot reads the patient's current authoritative InventoryService state without
unequipping anything on open. Pocket stacks and equipped items have separate keys;
worn items are marked Equipped in the loot UI. Equipped Body armor is protected
while the patient is unconscious: the UI shows a locked label, and individual
transfers / TakeAll both enforce protection on the server. Spare armor in pockets
remains lootable; corpse armor is normal loot after actual death. Successful
transfers of other gear remove only the selected slot; TakeAll skips protected
armor and collects the remaining loot.
Condition, magazine/type/mode and UID transfer with the exact item, without a
storage copy. Invalid/stale transfers leave the original equipment untouched. The patient cannot receive
inserted items. Carrying or revival invalidates the loot route. Owner capacity and
visuals refresh as items leave. Money remains in the pre-existing protected system.

## Knockout treatment and examination

KO freezes Sick increases (poison and background progression) and prevents needs
or debuffs from draining accumulated HP. Hunger/thirst still consume normally.
Bandages and antiseptic can treat KO patients; neither wakes them. Successful
Doctor revival retains treated HP, with the existing revival HP floor/perk bonuses.
After waking, sickness/poison resume their ordinary progression.

QuickExamination (Quick examination), Doctor150, one rank, reveals a nearby
other KO patient's HP, Sick, poison, starvation and dehydration. The live readout
appears during medical targeting or in their RMB menu, within3studs. It grants
no healing, cure chance or revival bonus. Paramedic retains +10HP for every bandage
and Doctor revival, and adds10 extra Sick removal only to SterileBandage.

## Bullet filtering

BulletCast ignores WorldItems and Item_ID roots, plus entire KO characters.
They do not absorb damage, range/penetration budget or impact effects. Conscious
characters, including their equipped item geometry, remain valid targets. The
same filter guards muzzle clearance so a bottle cannot reject a shot. Dormant
WorldActivity item/KO records are also excluded from bullet-specific virtual rays.
Pickup, medical, carry and other interaction queries keep their existing rules.

## Voluntary respawn

The120second KO deadline now unlocks the on-screen Respawn button. It never
implicitly calls Finish. Patients may wait past it for rescue, carrying or bed
treatment. The server verifies the deadline and current KO record before accepting
respawn. Town members retain normal respawn afterward; unaffiliated characters
retain Game Over/new-character acknowledgement after choosing to finish.
Reconnect keeps the deadline and KO record; offline bodies still use the existing
300second disconnect grace, rather than the KO deadline causing earlier death.

## Needs and regeneration

Damage is proportional to maximum HP: empty hunger and empty thirst each deal
0.5%/3seconds; Sick100 deals1%/3seconds. Rates add and integrate across Needs updates,
independent of frame rate. Survival damage bypasses armor/dodge. Normal minute
regeneration checks the actual Food/Water/Sick values and is disabled by any active
need damage. The HUD updates health normally.

## Daily zombie progression

DayClockService publishes WorldDay, starting at1. Each real midnight crossed by
the advancing game clock increments it; directly setting admin clock hour does not
create free days. The initial game day has zombie level0; each completed day adds
one level and one flat pre-critical melee damage. Level HP follows the existing
attribute/level formula (+4MaxHP/level). Existing zombies retain their health
fraction; new spawns use the current day. Night attribute bonuses remain.

The handbook has a separate Zombies tab in EN/UK/RU, also explaining rescue,
voluntary respawn, current disabled zombie poisoning and percentage need damage.
No profanity is included in game text.

Tests cover actual damage/cure consumption, craft counts/Doctor gate, carrier
ownership/reach/LOS/bed rejection, nonduplicating KO loot, voluntary respawn and
reconnect, bed progression/regen, day transitions, needs scaling, doubled stamina,
localization and the five-tab help layout. Visual carrying/bed placement still
requires a Studio multiplayer playtest with the authored character and beds.

## Weapon dropped on knockout

Entering KO drops the weapon actually held in the active weapon slot into
WorldItems beside the character. Holstered weapons remain in their slots. The
same weapon condition, unique UID, magazine/type/mode/cooldown data moves into
that one pickup; it is removed from the owner's equipment before the body pose
is captured. Finishing death retries only if a held weapon still exists, so it
cannot duplicate a gun already dropped on KO. The nearby drop tests wall
clearance and floor placement; if it cannot place a pickup, ownership is retained.
