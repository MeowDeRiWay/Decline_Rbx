# City house generation

The first generator fills existing YardPlace markers. It does not create roads or place new plots.

## Studio setup

- Put complete house Models in **ServerStorage/CityGeneration/Houses**. Names are arbitrary; each needs **ZHouse=true** and an immediate child **Yard** containing its marker Part.
- Keep **ZNumber** on the outer house. Keep **Floor/Zombie_home=true** inside it for the existing zombie spawner.
- Leave **Workspace/YardPlace** Models with **ForZHouse=true** where houses should appear. Their marker Parts define the target center, level and 20x20 footprint.
- Roads stay in Workspace as Models with **Road=true**. Their names and Part names do not matter.
- Plots must be horizontal. Rotating them around Y is supported. Template Yard axes should align with the house pivot axes; do not tilt the marker.

## Placement

The generator clones the entire house, including its Yard and Floor. The Yard bounding-box center aligns with the YardPlace bounding-box center; the house pivot may be offset from that center.

The front of the house is **positive Z**, the blue pivot arrow. The generator finds the nearest point on road tile bounds and selects the closest of the four plot directions toward that road. House forward does not use LookVector, which points toward negative Z. No Front Part is needed.

Only templates whose rotated Yard footprint fits inside the plot are eligible. For matching 20x20 yards this supports quarter turns without diagonal spill. Oversized or misaligned yards are skipped and reported in Output. Match the marker heights to keep the finished floor at the intended level.

## During Play

- Generated houses appear in **Workspace/GeneratedCityHouses**.
- Source templates remain in ServerStorage. The original plot and cloned Yard marker are invisible and non-collidable; the plot's query/touch are disabled. Wall/floor collision and visibility attributes are preserved. All cloned Parts are anchored.
- The plot has a GeneratedHouse ObjectValue referencing its house. The house has a GenerationSource ObjectValue referencing its plot.
- Repeated generation leaves existing houses intact. It does not duplicate them or refill their loot.
- New/unresolved plots are retried every 5 seconds, allowing delayed template/road loading. Removing a plot also removes its generated house on the next pass.
- Generated Floor models are discovered by the existing zombie-home listener. House-wide ZNumber limits still apply.

Change **src/shared/CityGenerationConfig.luau** for Seed, fitting tolerance or retry interval. **Seed=false** (default) chooses a fresh random seed on each server/Play session, so restarting Play no longer repeats a fixed house sequence. A numeric Seed deliberately reproduces the same initial choices with the same uniquely named templates and initial plot layout. The actual numeric seed is recorded on Workspace/GeneratedCityHouses and on each generated house as GenerationSeed. Random choices may still coincide by chance, and only templates that fit each plot are eligible. Already generated houses stay unchanged during the same server session.

## Validation

`python tests/run_city_geometry.py /path/to/luau` checks four forward directions, offset Yard alignment, rotated plots, marker height, road-edge selection and rejection of oversized/diagonal yards.

`python tests/run_city_service.py /path/to/luau` exercises template discovery, marker hiding, attribute preservation, repeat calls and removed-plot cleanup with Roblox mocks.

Luau compilation and Rojo build are also checked. These tests do not replace checking the supplied models in Studio Play.

## Stores and AutoPlacer

Furniture placers are identified by the Boolean attribute **`AutoPlacer = true`**
on a Model or BasePart. Its name can be anything, for example `KitchenShelves`.
The string attribute **`StoreFurniture`** selects the template by name from
`StoreFurniture` or `Furniture` under `ServerStorage/CityGeneration`.
Legacy objects named `AutoPlacer` still work when the Boolean attribute is absent;
explicit `AutoPlacer = false` disables a marker even with that legacy name.
Changing the attribute during Play updates the incremental marker index.

Furniture does not block world-item pickup reach rays. AutoPlacer clones receive
Boolean `Furniture = true` automatically, and furniture inside organizational
Folders named `Furniture`, `StoreFurniture`, or `GeneratedFurniture` is also ignored.
For manually placed furniture elsewhere, set Boolean `Furniture = true` on its
Model or Part. Apply this only to the furniture, not the whole building: unmarked
walls and closed doors continue to block pickup, even behind ignored furniture.
This affects pickup reach only, not movement collision, bullet penetration, or
cursor targeting. The pickup distance remains 2 studs.

The existing eligible YardPlace models (`ForZHouse=true`, including those in Workspace/Yards) now roll **Houses 95% / Stores 5%** independently. A small town is not guaranteed to have a store. Templates are:

- `ServerStorage/CityGeneration/Houses/<any name>`: Model with ZHouse=true and an inner Yard.
- `ServerStorage/CityGeneration/Stores/<any name>`: Model with an inner Yard; ZHouse is optional and not added automatically.
- Both use the same aligned 20x20 Yard footprint, +Z front, road-facing placement and fit checks. Roads inside Workspace/roads work normally.

If the rolled category has no fitting template, a fitting template from the other category is used. If neither fits, generation retries as before. The category roll is retained across unsuccessful retries; filled plots never reroll within the session. Generated stores share Workspace/GeneratedCityHouses for compatibility, with `GenerationCategory="Stores"` (houses use "Houses"). Existing GeneratedHouse/GenerationSource links and removal cleanup are unchanged. Adding Stores later does not replace already spawned houses; restart Play to regenerate.

For shelves, create **`ServerStorage/CityGeneration/StoreFurniture/Shelf`** or **`ServerStorage/CityGeneration/Furniture/Shelf`** as a Model or BasePart with the intended dimensions. `StoreFurniture` is searched first; if both folders contain the same name, its template wins. Inside a store template place a **Model or Part with Boolean `AutoPlacer = true`**, with a string attribute **`StoreFurniture = "Shelf"`**. The same attribute selects from either folder. Its bounding box is the rectangular placement region. A Model region should contain only its authored flat marker Parts; use a sensible pivot/PrimaryPart so its box axes follow the desired orientation.

The filler tiles the named furniture's bounding-box footprint without overlap: a 1x10 area gets ten 1x1 shelves or one 1x10 shelf; a 1x1 area cannot hold a 1x10 shelf. Whole objects only, with any unused strip centered around the grid. Furniture bounds are measured from all part corners in upright (world-Y) axes while retaining the template pivot's yaw. Pitch or roll in the template pivot does not turn its height into footprint depth. The box-to-pivot offset remains preserved, so physically upright templates stay upright. Each furniture bounding box follows the region's rotation; its bottom sits on the marker's top surface. Template offsets between pivot and bounding box are preserved. Furniture templates should have their box axes/front aligned consistently; rotate the AutoPlacer to turn the shelves.

Marker Parts become invisible, anchored and non-colliding/non-queryable at runtime. Generated furniture retains authored collision and BlocksVision, and all its parts are anchored. It is parented into a reserved `AutoPlacer/GeneratedFurniture` folder; `FurnitureCount` records the number placed. A completed marker is not refilled, even when its contents are removed or its attributes change. Delete the generated group or restart Play to intentionally refill. Missing/oversized templates warn without placing invalid furniture; a missing template can be supplied before a later retry.

AutoPlacer also works in house templates and on directly authored Workspace objects. This step only places models; no shelf loot, shop inventories or additional interior rules are added.

## Town walls and doors

Place wall templates in `ServerStorage/Buildings/Wall`. Each Model needs a direct
`WallYard` Model or Part. Use unique names, for example `WallModelT1 (wood)`,
`WallCornerT1 (wood)`, `WallGateT1 (wood)`.
Each `WallPlace` Model/Part in Workspace needs `TownID` (number, matching Flag)
and `WallTemplate` (string, exact template name). Its pivot position/rotation
aligns with the template's WallYard pivot. All wall parts are anchored; markers
are hidden and non-collidable. Result: WallPlace/GeneratedWall. Walls start at T1;
no T2 upgrade or resource cost is implemented yet.

Put boolean `Door=true` on one Model containing ALL moving gate pieces (group
multiple GateDoor pieces first). Keep that assembly named `GateDoor`. The gate
wall receives `TownGate=true`; manually placed gates need TownGate and TownID
on their ancestor. On infrastructure, Door=true inherits TownID, OwnerID and
Co-OwnerID from the live building/BuildingSpace. Public town members can operate
town gates; private doors allow the owner, co-owners and mayor of the same town.
Only the owner and mayor can manage co-owners at BuildingMenu.

Hover: green allowed, red locked. E opens authorized doors for 5 seconds, automatically closing them, preserving authored
part transparency/collision/query/touch/BlocksVision on closing. Opening disables
collision/query/touch/vision. Activating an already open door restarts its 5-second timer.
A player without a town can press E on a locked town gate to request passage.
The current mayor receives an English Y/N approval on the right. Approval only
opens that specific Door assembly for 20 seconds, then restores it; no membership
is granted. The requester must still be alive, unaffiliated and at that gate when
approved. Other factions cannot request passage. Missing/offline mayor, denial,
expiry or invalidated leadership leave gates shut. This is passage authorization,
not a barrier against another player following someone through an open gate.

## Incremental runtime retries

The initial Generate pass discovers authored plots, roads and wall/furniture markers.
Runtime retries use indexed candidates instead of enumerating Workspace descendants.
DescendantAdded/Removing, relevant attribute changes and renaming maintain the index;
generated buildings, wall pieces and furniture are excluded. Late/missing templates
are retried on the existing interval. Explicit Generate() still performs a full
rediscovery; the timer calls Generate(true). Per-object watchers are disconnected
when objects leave Workspace.

Client vision shade now uses241 rays at160degrees, at most30updates/sec while
moving and10updates/sec while stationary. Idle refresh still reacts to moving
blockers. View/camera/viewport/range/angle/KO changes invalidate the cached view.
Two-pixel raster rows reduce mask count. Creature LOS remains separate, now30Hz;
its sector and wall rules are unchanged. Moving shade ray budget is about81% below
641rays at60Hz; this is a work-count reduction, not a measured FPS improvement.
The MicroProfiler label Decline.VisionShade covers polygon/mask work. Live client
frame times and visual edge quality need laptop verification.

## Генерація поблизу гравців

Будинки, магазини та фабрики створюються, коли живий персонаж підходить на
240 studs до меж майданчика. Без живих гравців будинки не генеруються.
Черга перевіряється кожні 0,25 с; найближчі майданчики першими, максимум
4 будинки за прохід, із паузами за часовим бюджетом між операціями.
Маркери ділянок приховані від початку, навіть коли будинку ще немає.

Стіни та меблі всередині шаблону створюються разом із будинком. Окремі
маркери меблів/заміни стін поза шаблонами також чекають наближення гравця.
Невдалі спроби (наприклад, відсутній шаблон) повторюються через RetryInterval.

Створені будинки залишаються на сервері після відходу гравців, зберігаючи
поточні об'єкти й стан. StreamingEnabled керує доставкою та вивантаженням
далеких об'єктів на клієнті. Серверного знищення будинків при відході немає.

Налаштування у Shared/CityGenerationConfig: GenerationRadius, CheckInterval,
PlotsPerStep, RetryInterval. У Workspace/GeneratedCityHouses під час Play:
GenerationMode = NearbyPlots, GenerationRadius = 240.

Вибір шаблону використовує окремий seed для кожного майданчика, прив'язаний
до seed сервера, координат і повного імені майданчика: порядок відвідування
міст не змінює його початковий випадковий вибір.

### Плавне завантаження зони за 30 секунд

`ZoneLoadSeconds = 30` у Shared/CityGenerationConfig розподіляє кожну нову
групу близьких майданчиків від першого до останнього завдання на 30 секунд.
Найближчий починає одразу; наприклад, три будинки отримують час 0, 15 і 30 с.
Це фонове створення об'єктів; керування гравцем не блокується таймером.
Один майданчик може створюватися одразу. Реальний час залежить від вартості
шаблонів, кадрового бюджету та ліміту PlotsPerStep.

Повторні перевірки не зсувають уже призначені терміни. Коли гравці відходять,
далекі невиконані завдання скасовуються; при поверненні вони отримують новий
графік. Готові будинки зберігаються. Нові ділянки, що входять у радіус під час
руху, отримують власне вікно. Окремі маркери меблів/стін використовують таку
саму схему. Якщо сервер пропустив кілька термінів, наступні створення
розділяються щонайменше одним кадром. Готові маркери меблів не повторюються.

У Workspace/GeneratedCityHouses атрибут `GenerationLoadSeconds = 30` показує
активне налаштування. Для нового значення потрібен повний Stop/Play.
