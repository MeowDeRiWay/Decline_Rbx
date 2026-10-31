# Market, trading posts and money

## City market building

Put an authored Model **`Market (T1)`** in `ServerStorage/Buildings`. A plain
`Market` model is also accepted. Use the normal building `Space` alignment marker
and `BuildingMenu`. Market appears in the town building menu, costs no resources,
has no skill requirement, and still uses the normal mayor approval process.

The building itself has no automatic shops. Add as many trading post models as
needed, inside the market, hospital, farm, workshop, kitchen or other buildings.

## Trading post models

Inside a building, add one Model **`TradePost`** containing the anchored parts of
the counter. One model is used for both vacant and occupied posts; ownership is
shown in the trading menu. No `Active` or `Inactive` child models are needed.
The server does not change the authored appearance or collision of the counter.

Model name `TradePost` identifies it. A differently named Model may instead use
Boolean **`TradePost = true`**. TownID is inherited from the containing building;
standalone posts require a matching numeric TownID on the model or an ancestor.
`Furniture = true` is optional for ignoring the counter in loot pickup checks.
Never mark the entire building as furniture.

An optional small invisible, non-colliding but queryable Part can provide a consistent click/hover target. It must remain inside the
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

## Protected account money

Every 120 seconds an online confirmed player earns **$1 × current character level**.
There is no offline income; level 0 earns zero. Death, ordinary respawn and city
changes, new characters and server changes do not remove account money. The balance is shown in the HUD and shop.
It cannot be looted from a body, dropped, deposited in a chest or stolen from the
player inventory. Goods can be bought through the market; players can exchange money and items
locally. Existing mayoral tax also uses account money.

Money is an account balance, not an inventory item. Physical `Money`, `Bill` and
`bill` items are retired: they are excluded from item pools and admin item lists,
removed from old inventories and destroyed when registered in the world. They
cannot be picked up, dropped or used to credit an account.

The ledger is server-owned and keyed by Roblox UserId; modifying a display
attribute does not change money. `MoneyStore` persists balances in the
`DeclineMoney_v1` DataStore, using `User_<UserId>` keys. It saves changes after a
short 2-second coalescing delay, on departure and during server shutdown. Failed
saves retain the cached balance and retry after 10 seconds. An abrupt server crash
can still lose changes that have not reached DataStore.

Loading failures never replace saved money with zero: cash operations wait until
the account loads, and the HUD shows `$…`. A 180-second session lease, renewed
every 60 seconds, prevents another server from overwriting an active account.
After an unclean shutdown, access can wait for that lease to expire. Offline shop
payments load and save the seller's account, then release it. If that account is
active on another server, the payment is rejected without transferring goods.
Two-account payments are atomic within the running server, but their DataStore
writes are separate; this is not a cross-account durable transaction system.

For Studio persistence tests, enable **Enable Studio Access to API Services** in
Game Settings > Security. Verify a credit survives leaving and joining a fresh
server, and that starting a new character keeps the account balance. Shops,
goods and prices still follow in-memory session storage; only account money
persists across server shutdowns.


## Local player exchange

Right-click a conscious player and choose **Exchange**. Both players must be alive,
confirmed, within **5 studs**, with no solid wall between them. A player can have
only one invitation/exchange open. The recipient has 30 seconds to accept.

The window shows your pockets, your offer and the partner's offer. Choose a
quantity to add/remove items; enter a whole-dollar amount and press **Offer money**.
Equipped items must be unequipped first. Either side may offer only money or only
items, so gifts and barter are supported without dummy items or world cash.

Both players must confirm the same revision of the offer. Changing an item or
amount resets both confirmations and starts a 2-second review delay. Losing an
offered item resets consent too. There is no escrow before completion: cancelling
leaves the assets where they are. At the final confirmation, the server rechecks
characters, pocket inventories, distance, walls, balances and item quantities. It
stages both inventory changes before committing either side, preserving each
weapon's condition, unique identity and loaded magazine. Money comes from the
existing persistent account; its same DataStore crash limitations apply.

Moving away, a knockout/death, character replacement, leaving the server, closing
the window or 3 minutes without an offer change cancels the exchange. Other game
menus cancel the client window; combat and world controls respect ExchangeOpen.
Test with two Studio clients: money-only gift, bilateral item/cash barter, changed
proposal after one confirmation, depleted funds, wall/range rejection and leaving
mid-trade. Both clients should see the updated result, and a fresh server should
restore the final saved account money.
