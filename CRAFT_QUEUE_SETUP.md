# Craft queues and nearby storage — 31 October 2026

The recipe panel now has a per-process batch size plus a Processes field (1–1000).
Start queue runs that many processes sequentially; Queue all reserves as many full
processes of the chosen batch size as current supplies permit, up to 1000. A batch
still respects the recipe's existing MaxBatch (e.g. 1 tool or up to 5 boiled water).
Duration is the sum of the unchanged per-process times; fuel is paid per process.
The panel shows the total estimate and current process / total with remaining time.

Each completed process immediately grants its products and byproducts to the
creator's pockets, with the existing quality/loot effects and XP applied once per
process. No Collect click is required, even for unattended furnace/stove jobs.
Other visitors can see the busy station but cannot cancel or receive its results.

Materials come from pockets first, then nearest ordinary Chest models within 5
studs of the station pivot (distance to chest physical bounds). Corpses, knocked-out
players, trade posts and wall-blocked chests are excluded. Current ordinary-chest
access rules are unchanged. Tools can stay equipped, in pockets, or in those
chests. Knives must have remaining condition. Reusable tools are not consumed and
must remain available during the queue. No attributes or extra wiring are needed.

The server reserves all material inputs for the whole queue before it starts,
including each process's fuel. This prevents two crafters spending the same shared
stock and rejects an unaffordable request without consuming anything. Products
from earlier processes are not counted as inputs when initially reserving a queue.
The merged stock/tools refresh on changes, rather than rebuilding input fields on
every polling tick. Shared chest viewers are notified when reservation/refund
changes their stock.

Cancel queue returns only unfinished inputs to the exact source inventory/chest,
preserving item condition and weapon metadata. If a source chest was destroyed,
its refund goes to the creator's inventory. Completed results and XP stay granted.
Presence-required jobs still cancel on closing/leaving the station. Unattended
jobs continue after closing. Disconnect, knockout, death, character/inventory
replacement or station destruction cancels unfinished work. KO cancellation runs
before the body captures its anchored state, so revival does not leave a former
crafter anchored. Timers validate their queue identity and process index, preventing
replayed/stale callbacks from granting duplicates.

Old single-batch numeric Cook requests remain supported. New clients send
`Cook(recipeID, {Batch = count, Repeats = integer_or_All})`; CancelCraft is checked
against the authoritative station job owner. Legacy Collect endpoints remain for
compatibility; newly completed outputs bypass the old station result buffer.

Validation: run_craft_queue.py exercises the actual crafting and chest services,
pooled reservation, radius/wall/body filters, two-player contention, per-process
output/XP/fuel, reusable tools, refunds, missing sources/stations, disconnect and
stale callbacks. run_craft_queue_ui.py executes the shipped recipe UI callbacks,
merged materials/tools, total time, insufficient-stock disablement, structured
requests and owner-only cancellation. Existing cooking/lifecycle tests are updated
for automatic pocket delivery. Roblox Studio rendering still needs a live playtest.
