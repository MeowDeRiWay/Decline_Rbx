# Administration

Open **ADMIN [F6]** or press **F6**. The menu is available only to Roblox UserIds
`8335513512` and `4455566626`, with identical permissions. The allowlist lives in
`src/server/Services/AdminRules.luau`; every remote invocation checks the sender's
actual UserId. Changing the client-side AdminAccess attribute grants no authority.

## Time

Set the server's hour (0–23.999), day speed (0.01–100x), or pause/resume the clock.
At 1x, one complete game day takes 60 real minutes. Pause retains the chosen speed.
Changes immediately update DayClockHour and IsNight, including night zombie stats
and accuracy. All players in this server see the same time. A new server starts at
08:00 with the normal speed.

## Characters

Select an online player; the current selection's name, level and HP appear above
the controls. Operations require a completed character creation.

- Add 1–100 levels at a time, with the normal Intelligence-based skill point and
  perk point rewards (one at each third level, ten total by level 30). Current XP is retained; Good student does not multiply the
  granted levels. Grants stop at the level-30 cap, discard excess XP at the cap,
  and report the number actually added. The automatic level-30 perk is awarded normally.
- Reset progression to level 1: clear all trained skills, practice progress,
  perks (including the level-30 perk) and XP. Preserve attributes and chosen
  main skills. Restore the normal level-1 unspent point budget: two skill-point
  bundles of `5 + Intelligence` and zero perk points, since creation starts at
  level zero. Repeated resets do not accumulate points. Inventory is retained.
- Heal to maximum HP and remove sickness.
- Restore food and water to 100 and remove sickness.
- Revive a knocked-out character, ignoring the medical revival lock, restoring
  maximum HP, and using the normal pose/collision restoration. This action does
  not resurrect a dead character or create a replacement character.

## Items

Search the complete ItemConfig catalog by English name or ID. Give 1–1000 copies
to yourself. New registered items appear automatically. Items are added through
InventoryService, retaining normal inventory synchronization, weapon metadata,
weight and equip requirements. Firearms are issued unloaded; ammunition can be
issued separately from the same catalog. Issuing items to a selected player is
not supported: item grants always target the invoking administrator.

Actions report success or errors in the menu; successful character/item actions
also appear in the journal. Server output records successful admin commands.
The menu persists across respawns and supports use while knocked out. Opening
another major menu closes it; attacks, aiming, sprint and medical targeting are
blocked while it is open.

Changes use the game's existing session lifecycle and do not add persistent
storage across server shutdowns.

## Validation

- `python tests/run_admin.py <luau>`: actual remote authorization, forged client
  flags, both administrator identities, bounds/malformed values, cooldown,
  self-only inventory grants, player targeting, healing, needs and revival routing.
- `python tests/run_progression_service.py <luau>`: actual level grants, normal
  rewards, retained XP, Good student, creation guard and level-30 perk.
- `python tests/run_day_night.py <luau>`: default day cycle, zombie transitions,
  night accuracy, clock overrides, pause/resume, speed and midnight wrap.
- `python tests/run_medicine.py <luau>`: existing real knockout/revival lifecycle.

Rojo build and Luau compilation pass. Visual and multiplayer verification in
Roblox Studio is still needed: sign in as an allowed account, open F6, change the
clock, grant levels/items, and revive another knocked-out player. Confirm an
unlisted account has no menu and cannot invoke administrative actions.
