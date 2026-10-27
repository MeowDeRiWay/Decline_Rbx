# Market, trading posts and money

## City market building

Put an authored Model **`Market (T1)`** in `ServerStorage/Buildings`. A plain
`Market` model is also accepted. Use the normal building `Space` alignment marker
and `BuildingMenu`. Market appears in the town building menu, costs no resources,
has no skill requirement, and still uses the normal mayor approval process.

The building itself has no automatic shops. Add as many trading post models as
needed, inside the market, hospital, farm, workshop, kitchen or other buildings.

## Trading post models

Inside a building, create this authored structure:

```text
TradePost (Model)
  Active (Model)       -- claimed shop, including inherited/reserved shops
  Inactive (Model)     -- unclaimed shop
```

Both visual models must contain anchored Parts and be positioned at the intended
counter position. Author their normal visible transparency/collision/query/touch
and BlocksVision values. The server hides and disables the unused version,
restoring the selected version's authored values. Do not save either version
already completely invisible: both should be visible while authoring.

Model name `TradePost` identifies it. A differently named Model may instead use
Boolean **`TradePost = true`**. TownID is inherited from the containing building;
standalone posts require a matching numeric TownID on the model or an ancestor.
`Furniture = true` is optional for ignoring the counter in loot pickup checks.
Never mark the entire building as furniture.

An optional small invisible, non-colliding but queryable Part outside Active and
Inactive can provide a consistent click/hover target. It must remain inside the
TradePost model. Keep the model's bounds close to the physical counter.

For buildings with multiple posts, set unique string **`TradePostID`** attributes
and keep them the same in the next building stage. A single old/new post matches
automatically. Upgrades preserve the live post instance, owner, stock and prices;
an upgrade without matching posts is rejected. Empty and release occupied posts
before demolishing a building so goods are not silently destroyed.

Runtime attributes `TradeOwnerID`, `TradeInherited` and `TradeHasStock` are managed
by the server. Do not author them as a way to assign stock or ownership.

## Using a post

Approach within 2 studs and press E. Walls and closed doors block access.
Any confirmed player, including guests and other towns' citizens, may browse and
buy. Only a member of the post's town can claim a vacant counter. A citizen may
own multiple posts. Only its seller can deposit, withdraw, set prices or release
an empty post; building owners and mayors cannot edit someone else's active shop.

The owner has quantity controls, Put/Put all, Take/Take all, unit-price minus/plus
and direct numeric price entry. Price must be a positive whole number of dollars.
Unpriced stock is shown but cannot be bought. Buyers choose quantity and Buy.
The post only sells: it never buys visitors' goods, and no barter is implemented.

Stacks retain weapon condition, loaded ammunition/type and metadata. A purchase
checks live stock, price and account balance on the server, transfers the exact
items and credits the seller in one operation without yielding. Failed sales
charge nothing. The last item cannot be sold twice. Q/Escape or the close button
closes trading; walking away, death or KO ends the session. Attacks and ordinary
inventory commands are blocked by the server while a trading session is open.

## Ownership when a seller leaves

Leaving or being expelled from the town transfers every shop in that town to
the current mayor, with all stock and prices intact. Sales then credit the new
owner. Disconnecting retains ownership for the existing reconnect grace period
(currently 300 seconds); returning to the same server in time retains the shop.
After the grace period, ownership transfers to the mayor.

Inherited shops remain attached to the mayoral office: leadership changes transfer
them to the new mayor. If the office is vacant, inherited goods stay reserved and
cannot be claimed by another citizen; the next mayor receives them. Voluntarily
claimed personal shops remain personal while their owner stays a town citizen.

## Tax and wall level

At the town flag, the mayor opens **Market tax** and sets a whole-dollar tax from
0 through the town's highest built wall level. Default is 0. No walls means a
zero cap; T1 permits $1, T2 permits $2, and so on. The server validates the cap.

Wall candidates are cached, not rediscovered by scanning the world on every
snapshot. Generated walls/WallYard markers are recognized. For custom wall models
set numeric **`WallLevel`** and ensure TownID is on the wall or an ancestor.
Existing wall template names such as `WallModelT2 (wood)` and WallTemplate values
also supply their level. A workshop/hospital building's level does not count as
a wall level. Changes/removal refresh the cap within about one second.

Every 300 seconds, each seller pays once per town regardless of the number of
owned posts. The payment goes to the current mayor's account, not an inventory.
The mayor does not pay themselves. Insufficient funds collect only the current
balance, without debt or a negative balance. A wall downgrade clamps the effective
tax to the new maximum. Sales have no separate percentage tax.

## Protected money account and banknotes

Every 120 seconds an online confirmed player earns **$1 × current character level**.
There is no offline income; level 0 earns zero. Death, ordinary respawn and city
changes do not remove account money. The balance is shown in the HUD and shop.
It cannot be looted from a body, dropped, deposited in a chest or stolen from the
player inventory. Buying goods and mayoral tax are the only implemented payments.

For a physical banknote, create a Model or Part named **`Money`**, with numeric
**`BanknoteValue`** (a positive integer, for example 1, 5, 10, 20, 50 or 100).
A different name may use string `Item_ID = "Money"`. Put map notes in WorldItems
or directly in Workspace/organizational folders as with other world loot; place
templates in `ServerStorage/Items` to use authored item pools. A money pool template
must retain Item_ID=Money and its BanknoteValue. Each note credits its denomination
times Quantity, then disappears. It never becomes a droppable inventory item.
Invalid denominations are rejected. Admin GiveItem Money credits $1 per unit.

The ledger is server-owned and keyed by UserId; modifying a display attribute
does not change money. Returning to the same running server restores the account,
including shop proceeds earned while disconnected. This currently follows the
game's in-memory session storage: account balances, shops, goods and prices do
**not** persist across server shutdowns or transfers to a different server.
