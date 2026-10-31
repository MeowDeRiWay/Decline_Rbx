# Crafting: item queues and manual processing — 31 October 2026

The interface has two modes, with no material-quantity/batch-size input.

## Item stations

Workstation, MedStation, ArmsBench and CuttingBoard expose only Processes (1–1000),
Start queue and Queue all. Every process uses the recipe's fixed input/output
amounts. The creator stays at the station for the whole queue; closing/leaving
cancels unfinished work. Every completed process immediately delivers its products
and byproducts to pockets and grants its existing XP once. Other visitors cannot
cancel the creator's queue or receive its automatic outputs.

## Stove and Furnace

These run a single fixed batch, with no repeat field or queue-all action. Products
remain in the station until manually collected with one Collect all button above
the recipe list. Any remaining main product or byproduct blocks all new processes
on that station, even if another recipe is selected. Closing the interface does
not cancel processing; the player can return to collect it later.

Fixed batches:
- Potatoes: 5 Potato + 1 CleanWater + 1 TreeLog or Coal -> 5 BoiledPotato.
  Wood takes60seconds and returns1Coal; coal takes30seconds.
- Water: 5 DirtyWater + 1 chosen fuel -> 5 CleanWater,60/30seconds; no XP.
- Charcoal: 5 TreeLog -> 5 Coal,60seconds; or add1Coal for30seconds.
- Iron: 25 Scrap + 1 Coal -> 5 Iron,120seconds, Workshop T2 furnace.
- Steel: 5 Iron + 1 Coal -> 5 Steel,60seconds, Repair150 + Workshop T2 furnace.

ManualBatch=true recipes are represented as MaxBatch=1 full-process recipes;
input and output quantities already contain the full batch. Their fixed inputs do
not receive Economist discounts. XP is normalized to preserve the previous full
batch reward, and Ramsay quality still applies only to food (not fuel byproducts).
Manual queue requests with more than one repeat or Repeats="All" are rejected by
the server. Ordinary numeric1 requests remain a single process.

## Shared materials, tools and cancellation

Pockets supply materials first, then ordinary Chest models within5studs of the
station pivot (distance to chest bounds). Bodies, trade posts and wall-blocked
chests are excluded. Current ordinary-chest access rules remain unchanged. Reusable
tools may remain equipped, in pockets or in those chests; usable knives need
remaining condition. No extra attributes or wiring are needed.

The server atomically reserves all inputs before starting, including per-process
fuel, so two crafters cannot spend the same shared stock. Reusable tools are not
consumed and must remain available. Cancellation refunds only unfinished inputs
to their original sources with condition/weapon metadata preserved. A destroyed
source chest redirects the refund to the creator. Completed results/XP stay.
Disconnect, knockout, death, character/inventory replacement or station destruction
cancels unfinished work. KO cancellation runs before body anchor-state capture.
Stale/replayed callbacks cannot grant products twice. Source availability updates
only when it changes, preserving text entry between polling ticks.

New clients send Cook(recipeID,{Batch=1,Repeats=count_or_All}) for item queues and
Cook(recipeID,{Batch=1,Repeats=1}) for manual processes. CancelCraft is owner-checked.
CollectCrafted collects all ready station products/byproducts. Legacy collection
endpoints remain supported.

Validation: run_cooking_progression.py checks exact skill gates, regular queues,
fixed batches, manual results/restart gate, furnace tier, recipe cost/quality/XP
and cancellation. run_craft_queue.py exercises actual shared chest reservation,
contention, delivery/refunds and lifecycle; run_craft_queue_ui.py executes actual
UI callbacks and verifies no quantity/repeat controls on processing stations.
Studio rendering still needs a live playtest.
