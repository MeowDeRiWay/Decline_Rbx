# Міста, прапори та будівництво

## Моделі в Workspace

### Flag (Model)
- `BlocksVision` — boolean, залишається під керуванням чинної системи видимості.
- `Main` — boolean. Якщо є кілька прапорів одного TownID, головний визначає початкові назву та мера. Ставте рівно один Main=true на місто.
- `Team` — додатне ціле число, унікальне для міста.
- `Town_name` — string, назва міста в меню.
- `TownID` — додатне ціле число, унікальне для міста.
- `LeaderID` — Roblox UserID мера; 0 означає вакантну посаду.
- Дочірня модель `TeamColor`: усі її BaseParts фарбуються в колір команди міста.
- Прапор повинен мати фізичні Parts. Взаємодія курсором + E на відстані 1 студ до краю моделі; сервер перевіряє перешкоди.
- Радіус території 200 студів у горизонтальній площині від pivot прапора. Якщо території перекриваються, діє найближчий прапор. На гравцеві встановлюються `TerritoryTownID` і `TerritoryTeamID`. Вихід за межі не забирає членство; проходження чужої території не перемикає команду.

### TownSpawn (Part або Model)
- `TeamID` має збігатися з `Flag.Team`.
- `BlocksVision` — boolean за вашими правилами видимості.
- Рекомендований варіант — горизонтальний Part на рівні землі.
- Якщо для міста немає TownSpawn, сервер відмовляє у вступі з поясненням.
- До першого вибору міста персонаж не створюється. Після вступу та відродження він з'являється над TownSpawn з 2 HP.
- Підготовлена точка інтеграції лікарні: збудована Model з `BuildingID="Hospital"`, відповідним `TownID` та дочірнім `HospitalSpawn`. За її наявності гравець з'являється там з повним HP. Саму лікарню та її рецепт зараз не додано.

### BuildingSpace (Model)
- Дочірні `BuildingMenu` (функціональна табличка, Model або Part з фізичними Parts) та `Space` (Model або Part).
- `TownID` збігається з містом; `TeamID` збігається з Flag.Team.
- `OwnerID` — числовий Roblox UserID; 0 — немає власника.
- `Co-OwnerID` — для одного початкового співвласника можна задати number. Після змін сервер записує string зі списком UserID через кому, наприклад `12345,67890`. Список підтримує кількох співвласників. Використовується саме назва з дефісом.
- Space задає місце будівлі своїм pivot. Його **не знищують**: ховають із Workspace, а після знесення повертають.
- BuildingMenu залишається на місці й після будівництва. Розмістіть табличку зовні кухні, щоб вона залишалась досяжною.
- Не кладіть BuildingMenu усередину Space.
- Сервер додає `BuildingID` та `BuildingLevel` на BuildingSpace і збудовану модель. Власність також копіюється на будівлю.

## Перша кухня

Створіть **ServerStorage/Buildings/Kitchen (T1)** (Model) із фізичними Parts.

Pivot Kitchen (T1) суміщається з pivot Space: поставте їх у відповідне місце, наприклад по центру підлоги. Будівля клонується всередину BuildingSpace й замінює Space, не зачіпаючи табличку.

Кухня зараз — будівля першого рівня. Наступних рівнів, вартість будівництва — 1 TreeLog; таймера робіт поки немає. Меню показує тільки перший рівень для порожньої області та тільки наступне покращення для збудованої. Нові рівні задаються в `src/shared/TownConfig.luau`.

Якщо кухня має підтримувати чинні крафти, додайте всередину моделі `Stove` та/або `CuttingBoard` за вже наявними правилами RESOURCE_SETUP. Саме містобудівництво не додає кухні обладнання.

## Правила початкової версії

- На вході гравець бачить міста; натискання розгортає кількість учасників **у поточному сервері**, дипломатію, Roblox username мера та вступ.
- Членство зберігається між смертями в цьому сервері. Для зміни міста треба покинути свою команду через її прапор, потім вступити в іншу. Вступ переносить до спавну нового міста.
- Перший учасник міста з LeaderID=0 стає мером. Якщо після усунення/виходу мера посада вакантна, наявний член може розпочати вибори біля прапора. Мер, який просто відключився, зберігає посаду; члени можуть усунути його голосуванням.
- Голосування — 30 секунд або до голосу останнього виборця. Y усуває мера, N залишає. Перемагає більшість **поданих** голосів; нічия й відсутність голосів залишають мера. Кожен має один голос, змінити його не можна. Нові учасники не голосують у вже розпочатому голосуванні. При виході з міста/сервера голос вилучається.
- Ініціатора й індивідуальні голоси не публікують. Після завершення показують лише підсумкові числа. Мер отримує спеціальний текст про усунення. Кулдаун — 10 хв після завершення або скасування через зміну мера.
- Початкові відносини — нейтралітет. Союз потребує Y від іншого мера. Війна та нейтралітет встановлюються односторонньо, симетрично для обох міст. Відносини поки інформаційні: зміни шкоди та дружнього вогню не додано.
- Член міста обирає кухню біля BuildingMenu, мер отримує username заявника й відповідає Y/N протягом 60 секунд. Якщо мер офлайн або немає шаблону, з'являється пояснення. Запити мають окремі ID, чергу, перевірку ролі та строку дії.
- Мер також отримує запит Y/N і має погодити власне будівництво. Після будівництва заявник стає власником.
- Мер може призначити/прибрати основного власника, привласнювати будівлі окремо через їхні таблички, керувати співвласниками та знести будь-яку будівлю свого міста.
- Власник і співвласники можуть запросити покращення, керувати співвласниками та знести свою будівлю. Членство у відповідному місті обов'язкове. Знесення повертає Space без повернення ресурсів.
- Дані міст, голосувань, дипломатії й збудованих під час гри будівель зараз живуть у поточному сервері; DataStore між серверами/перезапусками ще немає.
- Моделі читаються при запуску сервера. Після зміни атрибутів/додавання нових моделей у Studio перезапустіть Play.

## Перевірка

1. Два Flag з різними TownID/Team і два відповідні TownSpawn.
2. BuildingSpace з TownID/TeamID першого міста; Kitchen (T1) у ServerStorage/Buildings.
3. Studio Start Server з 3 гравцями: два вступають у перше місто, третій у друге.
4. Перевірте 2 HP, ім'я мера, кількість учасників, колір прапора.
5. Другий учасник просить кухню, перший погоджує Y: Space зникає, кухня займає його місце.
6. Біля таблички перевірте власність, співвласників і знесення з поверненням Space.
7. Біля прапора перевірте союз між мерами та голосування, нічию, усунення й 10 хв кулдаун.

Автоматичні перевірки: `luau tests/town_rules.test.luau`, `python tests/run_town_service.py /path/to/luau`, `rojo build`. Серверні сценарії використовують mock Roblox API, а не запуск Studio.

## Update: English interface and spawn order

All built-in game UI and notifications are in English. User-supplied Town_name values retain their original text. Choose a town is a fixed title above the list; Join is inside the selected town details. UIListLayout uses explicit LayoutOrder.

Spawn identifiers are intentionally different attribute names: **Flag.Team** matches **TownSpawn.TeamID** and **BuildingSpace.TeamID**. TownID identifies the town separately. Character positioning runs after LoadCharacterAsync finishes so Roblox cannot overwrite the town position during loading; respawns use the same function.

## Flag menu and voting update

Opening Membership, Leadership or Diplomacy hides the other section headings until the open section is clicked again. Sections include short explanations. There is no bulk Claim all buildings action; mayors assign ownership individually through BuildingMenu.

Mayors cannot initiate their own removal vote. Resign as mayor immediately leaves office and starts an election. Successful removal also starts an election. In removal votes Y removes the mayor and N keeps the mayor. Voting ends after 30 seconds or immediately once all remaining eligible members have voted. The notification continues showing the countdown after voting.

Town notifications are on the right side. Flags and BuildingMenu use green cursor highlights plus a tooltip beside the cursor (Flag / Building Menu and [E] Open or Too far), matching Stove interactions. There is no bottom interaction hint. E remains the interaction key.

## Mayor election flow

Resignation immediately vacates the office. Successful removal (Y remove / N keep) vacates the office after the result. Both start a new 30-second election notification: Would you like to take part in electing a new mayor?

Y opens the town's candidate list on the right; N skips the election. Self-voting is allowed. Each eligible citizen has one candidate ballot. The candidate with the most votes becomes mayor; the election ends after 30 seconds or when all eligible voters have selected a candidate or declined. People who opt in but do not choose before the deadline abstain.

A tie starts one runoff between the tied leading candidates. A tied runoff or no ballots leaves the office vacant; citizens may start another election at the flag. Joining during an election does not grant voting eligibility or automatically make the newcomer mayor. Ballots and the initiator remain private. The 10-minute removal-vote cooldown starts again after the final election result; it does not block voluntary resignation or the election following removal.

## Kitchen (T1): materials and self-approval

Put the complete **Kitchen (T1)** Model in **ServerStorage/Buildings**. It may contain Space (the 20x20 ground marker), BuildingMenu and Stove. The cloned Space aligns with the original plot Space, including authored pivot offset/rotation. Ownership, team and town attributes are overwritten with current plot values, so the template may leave IDs at 0. Stove keeps its existing crafting behavior.

Kitchen construction requires **1 TreeLog from the builder's inventory**. The menu shows this cost. Materials are checked before requesting permission and consumed only after the mayor approves. If materials disappeared, the builder left the town, became incapacitated or moved away from the building sign, construction is cancelled. Declining or timing out spends nothing.

The mayor receives the same Y/N request when building for themselves. There is no automatic self-approval. A completed kitchen with its own BuildingMenu replaces the empty plot's sign; the original sign is detached and restored after demolition. Nested kitchen signs remain interactive. Legacy Kitchen_1 templates are accepted as a fallback, but Kitchen (T1) takes precedence.


## Ownership submenus

Owner and Co-owners now open separate menu pages instead of inserting controls into the building action list. Each page has its own title and Back to building button. Server refreshes preserve the open page; changed permissions or demolition return to the building view. All labels remain English.

## Workshop — Workbench (T1)

Place the authored model at **ServerStorage/Buildings/Workbench (T1)**. Use the same Space (20x20), BuildingMenu and ownership/team attributes as Kitchen (T1). Keep **Workstation** and **Chest** as nested Models with BaseParts. Workstation supports highlight, E and the recipes panel; it currently says “No recipes available yet.” No recipes were added.

Workshop T1 costs **1 TreeLog**, with the usual mayor approval (including self-approval). Chest remains public: town ownership does not restrict deposits or withdrawals.

On upgrades the live Chest model and its inventory are moved to the new level's Chest position, replacing the new empty chest. Its current appearance is retained. For multiple chests give each a unique string **StorageID**, identical across levels. An upgrade without a matching destination chest is rejected before spending materials or replacing the old building. Only T1 is configured for now; add actual level models and costs when ready. Storage survives building upgrades within this server session, not server restarts or demolition.

First successful character spawn in the current server session starts at 100 HP. Later respawns retain the existing rule: 2 HP at TownSpawn, full HP at an available hospital. Repositioning the same character does not reset health.
