# Decline — передача контексту наступному чату

Оновлено: 13 жовтня 2026, після додавання міст і будівництва.
Репозиторій: https://github.com/MeowDeRiWay/Decline_Rbx
База реалізації міст: e235775fe775a9bcd0ecbc0313a0abc94dea7711. Читай актуальний main.

## Weapon-state stacks, persistent magazines and viewer narration — 21 October

- InventoryRules keeps aggregate Items/Conditions for compatibility plus aligned Weapons records and EquipmentWeapon. Records carry UID, Loaded, Type, Mode, ReadyAt. Stacks groups by ID+condition+loaded+type; snapshot Stacks/ChestStacks, client actions use server-validated ID/Key selectors. Equip/drop/transfer/all target the selected variant; stale/forged keys rejected. Holster restores exact UID (not arbitrary same-ID gun).
- Magazines now physically own their rounds: reload transfers loose ammo on completion; shot decrements magazine only; type switch unloads old rounds. Save/Get/Reload/UnloadMagazine methods in InventoryService. Reserve HUD is loose ammo only. All loaded weapons/equipment contribute ammunition weight with Hunter multiplier. Runtime Firearms keys on UID; same-ID gun swaps cancel reload, holster retains charge/type/mode and shot cooldown. Old ammo-allocation/clamping design superseded.
- Metadata follows chest transfers, WorldItems WeaponData JSON drops/pickups and ExtractAll corpse storage. Fresh spawned loot clears inherited template metadata before normalization. Server-local state only, no DataStore. Inventory row/tooltip/details show actual condition, loaded count and ammo type; selected chest actions stay expandable.
- CombatReport includes actor/target UserIds and creature flags; JournalPresentation receives viewer ID: own actions You, incoming target you, observers names; creature names lower-case mid-sentence. Integer HP, visibility filtering and kill/KO clauses retained.
- Checks actual firearm service for reload/shot/type ammo conservation, independent same-ID magazines, holster cooldown, cancellation, existing guards/audio/condition; actual InventoryService + WorldItemService for state stacks, selected transfers, persistent charged drop/pickup, mass/condition/type, exact UID and corpse extraction; existing pickup/cooking/projectile/damage/progression tests, compile/Rojo. No Studio visual playtest.

## Witnessed journal, personal events, holster toggle — 21 October

- CombatReport now sends structured actor/target refs, display names, attack kind, actual damage, critical, death and newly entered knockout. Nearby observers receive payload; HUD EventVisibility.Witnessed requires BOTH participants visible under the renderer's exact screen/sector/occlusion function (CreatureVisibility installs Check). Hidden attackers' identities are not revealed. Own knockout hit is allowed; later events while unconscious suppressed. 250+10*ViewBonus server distance bound. No client request/authoritative damage changes.
- JournalPresentation renders English action sentences, rounded integer HP, kill/KO clauses, miss/dodge. Plain strips markup and decodes entities, so chat/system tags do not print literally. Damage over-head billboards remain removed.
- New server JournalService PersonalNotice remote sends only to owner: XP awarded, completed crafting outputs, one weapon break notification when condition crosses zero, no ammunition on failed empty reload (2s throttle). Existing level-up notice remains.
- Holster command toggles server InventoryService memory; un/equip through existing inventory rules preserves condition. Restores only from existing Items count, no grants. Drop/remove/transfer to storage/reset/extract invalidate remembered ID, even if another same-ID item is later acquired. Silent invalid restore.
- Removed numeric Run20s text; sprint bar remains. Combat and personal message visibility are separate: personal notices always go to owner.
- Tests actual visibility gate + screen/sector/wall function, structured death/KO report, holster condition/drop/replacement/transfer/reset, private actual notice remote and one break notice; no-ammo throttle, XP/crafting/projectile regressions; compile/Rojo. Studio screenshots supplied this turn were unavailable at provided local paths; no visual claim.

## Bottom console, chat journal, sprint and firing modes — 21 October

- HUDLayout client module owns shared 1020x170 bottom console, viewport-scaled; WeaponHUD mounts in its center instead of separate screen. Left persistent 100-row bounded journal + input (/ or click); filtered TextChatService.MessageReceived Success messages, SendAsync via selected/RBXGeneral channel, permissions checked, default window/input/bubbles disabled. No custom server chat relay. Live multiplayer/chat Studio test remains user-side.
- DamageService CombatReport RemoteEvent replaces ALL overhead damage text. Attacker/victim only receive damage/critical/miss/dodge; melee/projectiles pass actual server attacker. No broadcast exposing hidden targets to observers. Tests now exercise real report recipient routing.
- Holster calls existing Unequip Hands, Inv and Cha/Level bind through local HUDLayout events to existing menus. Level visible whenever AttributePoints or TalentPoints >0; level-up journal entry. Skills shows profession specialty stations/buildings; Menu is a closable future settings placeholder (no audio/graphics controls yet).
- HP numeric, AC shows existing DodgeChance percentage (zero without dodge talents), no duplicate damage calculation. Red combat square when zombie TargetName targets local player OR another player whose root projects onscreen; dark otherwise. Tracks TargetName changes/removed models, polls .25s, no raycasts or server AI changes.
- Server SprintRules: capacity20+Endurance seconds; moving sprint drains1/s. Not sprinting restores max/10 per second (ten-second full recovery). Empty locks until20% recovered, stops speed bonus, holding shift cannot bypass. Replicated SprintRemaining rounded .1 +SprintMaximum drive green bar/time. Existing speed/HP Endurance bonuses retained. Respawn full. Server owns reserve/Running.
- V toggles Auto/Single server state, .25s mode debounce; client releases firing after one accepted single trigger request, RPM authority unchanged. Weapon hover shows mode. Inventory switch resets mode with existing firearm session reset. No burst mode yet.
- Checks full Luau compilation/Rojo, SprintRules depletion/recovery/locks, actual firearm service mode/no-ammo/no-condition side effects, projectile regression, real damage absorption/crit + private report tests. No Studio UI, input, chat or audio playtest.

## Fallout-inspired inventory and compact HUD — 20 October

- Shared UITheme: warm metal frames, muted olive phosphor text, RobotoMono, bevel gradients on main panels/buttons. Inventory, progression, town menus and HUD use it. Talent/item/recipe display names use sentence case; internal IDs unchanged.
- Needs HUD now health only at bottom left. Inventory SurvivalStatus column left of Pockets shows Food/Water/Sickness/Weight and carry limit, updated while visible. Inventory fixed 1060x600 canvas scales to viewport; chest/cooking/equipment actions retained.
- Weapon HUD bottom right now 150x96 model preview plus vertical condition and magazine gauges on its right; ammo hidden for melee. Hover reveals numeric condition/ammo/reserve/type/reload. No permanent name/damage/APM labels.
- Both per-point benefits for Strength, Endurance, Attention already existed in shared presentation; tooltip minimum height now explicitly accounts for every newline plus padding to prevent losing lines. Rules unchanged.
- Luau compile, progression presentation/rules tests and Rojo build; no Studio visual playtest available.

## Compact attributes and grouped click-to-upgrade talents — 20 October

- Progression.client rebuilt right list: Requires level N headings,2columns compact58px name/rank cards; MouseEnter shows current/next rank cumulative numeric bonuses via new shared ProgressionPresentation; click sendsTalent directly ifCanLearn. Bottom details/Learn removed, list usesavailableheight484. Correct percent sign instead percentagepoints wording, English text maintained.
- Attribute tooltip only Per point lines; no name/current totals/caps/extras. Auto-size usingTextService and padding, viewport-clamped mouse positioning, original MouseEnter/Leave prevents inset offset. Shared presentation covers ALL remainingCook/Worker/Huntertalents, locked/nopoints/max states.
- Cook SurpriseServing/GrandmasMethod/RamsayMethod deleted fromConfig; CraftEffects no longer reads them, CraftOutputs clonesbaseoutputs. Oldrankdata inert, not merely hidden. Cook KnifeMaster/KevlarApron retained; GoldenHands/Luck unchanged. Updated tests retiredcook assertions and added run_progression_presentation.py. Compile, progressionrules/service/cooking andRojo. Studio visual check still user.

## Hunter profession and critical/dodge combat — 20 October

- Hunter added to P choice and tree (English), max10ranks/1point each; talent levels1/5/10 per user. All exact descriptions/formula PROGRESSION_SETUP.md. Hunter no assigned buildings/stations yet, public Workstation retained. Rifle223 Category Automatic (not rifle talent); future Pistol/Rifle/MachineGun mapped by Firearm.Category.
- ProgressionRules.CombatBonuses exports category AccuracyBonus/CritChance, CriticalNegation, PreserveDurabilityChance, AmmoWeightMultiplier, DodgeChance. Attention ViewBonus now.5/point (UI/docs/tests updated). Existing sync copies derived attrs player+character. Accuracy cap.9 total incl talents; hit probability=max(0,min(.9,Accuracy+bonus)-targetDodge), one roll via Damage.RollHit for player melee/projectiles. Zombie/no-accuracy attacks Apply rolls100%-dodge. Life.Damage handles environmental dodge and hitChecked avoids double rolls.
- Projectile crit chance category, multiplier uniforminteger2..4. Damage.Apply options CriticalMultiplier/HitChecked, defenderUnbeliever cancels critmult nothit; popupCritical/LastDamageCritical. Careful per-shot condition-saving roll, ammo alwaysconsumed. NotSoHeavy -8%/rank affects looseammo including allocatedmag in inventory Weight/LoadKg/total; attributechange triggersliveweightrefresh. UI playerammo stack/tooltip displays reducedweight, chestweights normal.
- Tests progressionrules/service Hunter gates/scalars, actualDamage hit subtraction/critnegation/no double dodge, actualLife environmental guard, firearm preservation/critcategory, ammo weight, cooking/zombieactivityregressions; compile/Rojo. Session-only profession choice still cannot change mid-session; user needs freshPlay tochooseHunter. Studio not tested.

## Character-position audio listener — 20 October

- ReloadSound max25 vs overhead cameraheight30 meant even own reload could be inaudible; same issue affected new12stud footsteps. AudioListener.client now sets legacy SoundService listener CFrame each renderstep to character root position + camera rotation, so zoom/Attention do not alter perceived distances and stereo stays camera-relative. Falls back to camera without character/root, binds automatically afterrespawn. Spatial ranges unchanged. Official Roblox SetListener docs verified; no Studio audio audition.

## Quieter player footsteps — 20 October

- Footsteps.client configures default Roblox Sound named Running on ALL player characters on EACH listener client, including respawns/late sound creation. GameConfig FootstepVolume=.15 ceiling, RollOffMinDistance2, MaxDistance12, InverseTapered. Volume watcher prevents default controller raising it, preserving quieter/silent values. Other sounds untouched. No per-frame work; old character listeners cleaned on respawn/removal.

## Shoulder-height rifle — 20 October

- Rifle223.Firearm.HoldHeightRatio=.4 raises equipped pivot to root.Size.Y*.4 above root center, preserving gripX/Z/rotation and supporting customHandsGrip. Melee held positions unchanged. _ShotOrigin derives AFTER raised placement, so visual/shot/sound align.
- Muzzle anti-wall guard now checks root->vertical shoulder at origin.Y then horizontal shoulder->muzzle instead of waist->muzzle diagonal, allowing clear window openings while retaining wall/overhead obstruction checks. tests/run_firearm_service covers raised guard origin and solidwall no shot/noammo.

## Rifle sound templates — 20 October

- FirearmAudio.Play reads held weapon/Sounds/ShotSound and ReloadSound Sound templates, clones onto _ShotOrigin Attachment or root for spatial replication. User has public Roblox audio but has not provided IDs; instruct them to set SoundId. Authored Volume/PlaybackSpeed retained, nonloop/PlayOnRemovefalse, default3..150shot/3..25reload; optionalMinDistance/MaxDistance attributes override. Ended cleanup +Debris15s.
- Firearms server plays only accepted shots and valid reload starts; reload sound stops on completion/type/swap/reset/removal. Reload invalidation at delayed completion now clears Reloading and sound (fixes KO-at-completion stuck state). Missing sound optional. Testsrun_firearm_audio plus service audio lifecycle; compile/Rojo.

## Rifle223 firearms — 20 October

- Implemented first firearm, not pistol yet. FIREARMS_SETUP.md authoritative. ItemConfig Rifle223 Firearm+Weapon, Ammo223FMJ/AP loose stacks and AmmoBox223FMJ/AP box definitions. World boxes rollAmmoCount1..MaxAmmo once, pickup converts to loose rounds; world ammo drops retain exactQuantity and can reuse box art. Caliber223 string, AmmoTypeFMJ/AP. User corrected screenshot FJM typo, retained Model Muzzle and set pivot.
- EquipmentVisuals derives internal _ShotOrigin Attachment from Muzzle pivot for weld-safe origin; authored model kept. Combat melee excludes Firearm items server/client. New Firearms.server owns30mag/600RPM/2.5reload/750speed/350range/25damage/3000condition, Inventory.Changed clamps allocations. Ammo stays in total inventory until shot (reserve=total-loaded), no duplication/loss on drops/death/swap. Ttype,Rreload,holdLMB and emptyautoReload. HUD ammo/reloading attributes.
- Shared FirearmRules block OBB slab, merged contiguous/overlapping intervals, resistance budget. FirearmProjectiles sharedHeartbeat swept rays, serverdamage/Accuracy/killtag, origin guard, lifetime range, AP half hard resistance, wall entry/exit FXbatched200stud nearby clients. Limits256bullets/64impacts/128materialparts. Thickness only blockParts; unknownmaterials/nonblock stop. Livinghit stops bullet. No compositeembeddedmaterial/verticalaim/audio/ricochet/destruction yet. Game balance not physicalballistics.
- Tests rules/service/projectiles/ammo_pickup actualmodules inengine mocks; auto reloadrate/ammo/swap, thin2layer wall FXmerge, AP, movingtarget/exactrange, boxesrollonce/dropcount. Compile/Rojo. User must Studio-test grip/visuals/performance.

## Nested Items categories — 20 October

- User organizes ServerStorage/Items into CookedFood,Materials,RawFood,Food,Tools,Weapons/Close,Weapons/Range; arbitrary Folder nesting now supported. EquipmentVisuals.Template performs category-Folder-only recursive lookup of valid Model/BasePart; does NOT descend into item models, so embedded Handle is not an item template. WorldItemService.makeItem shares resolver for drops/crafts. Existing nested equipment prevents duplicate root capture. Unique item names required; ItemConfig IDs unchanged. Tests run_equipment_templates covers nested weapons/materials/food, no duplicate capture, embedded Handle ignored.

## Door timing clarification — 20 October

- Mayor-approved outsider passage is20seconds again (Admit + English prompts). Ordinary authorized E opening remains5seconds. Tests verify both durations. This supersedes the preceding all-five-second change.

## Five-second automatic door closing — 20 October

- All authorized E openings and mayor-approved gate passages now auto-close after5seconds. Authorized activation always opens/restarts timer; no invisible-door closing interaction required. English prompts updated. This supersedes prior20second/toggle behavior. run_town_doors covers both approval and member auto-close with authored-property restoration.

## Server zombie activity bands — 20 October

- ZombieActivity service centralizes movement: Zombie.server registers AI callbacks instead of one Heartbeat per zombie. Active only executes AI; Minimal/AFK callbacks never run. Server reclassifies against ALL living players' screen ground footprints every~0.5s, yielding every32zombies. ActivityMode replicated for inspection.
- Exact distance OUTSIDE nearest player's whole screen footprint (not facing cone/root): <=50 Active, >50..200 Minimal, >200 AFK. No living players => AFK. Existing active vision/chase/combat unchanged; transitions clear stale routes/targets and stagger detection. Delayed attacks guard ActivityMode.
- Main camera reports actual smoothed height/aspect every0.5s via ZombieActivityView. Server trusts no position/CFrame, validates finite data/throttles, clamps height to server Progression.ZoomBounds and aspect0.5..4, builds fixed-camera screen quadrilateral itself. Before first report conservative maximumheight/aspect4 avoids premature sleep. Attention/zoom/resize affect footprint; facing does not.
- Minimal: one nearby1..10stud candidate every120seconds, randomized initial timer. Only destination ground/slope/same-level support(including noncollidable ZombieHome) and full model bbox overlap, no route/sweep along travel. Reject if destination leaves Minimal band. Occupied/missing ground=>skip until next120s. AFK does no teleport physics. AFK timers re-stagger when overdue. Endpoint includes held-item bbox conservatively.
- tests/zombie_activity_rules.test.luau exact bands/edge/corner/zoom/aspect. tests/run_zombie_activity.py runs real dispatcher with mocked engine:1000frames zero sleeping AI calls, timing/endpoint collision/wake/no-player/cleanup. Studio performance not measured. Setup ZOMBIE_ACTIVITY.md. No model changes needed.

## Screen-limited creature vision — 20 October

- CreatureVisibility rejects targets whose root AND head project outside viewport (or behind camera) before sector/Sight checks. Hidden creatures no longer reapply all part modifiers every frame/check; visible creatures still reapply after camera. Debug part counts update only on visibility/descendant changes.
- VisionShade rays now clip individually to screen-corner ground quadrilateral, removing old farthest-corner +5 overshoot. Sector remains160 degrees; zoom/Attention unchanged. No claim of eliminating all Studio lag; shadow still casts angular rays and keeps existing screen mask.
- tests/run_screen_visibility.py exercises actual visible function:1000offscreen checks->0Sight casts, onscreen still raytests, rear hidden; shared screen boundaries/camera depth and four-edge/diagonal ray clipping.

## City walls and doors — 20 October

- TownDoors service starts from TownService after town/plot registration. WallPlace uses TownID + WallTemplate exact name under ServerStorage/Buildings/Wall, aligns WallYard pivot to marker pivot (rotation authored by user), anchors/hides marker, output GeneratedWall. No T2/cost/flag-upgrade UI yet because only T1 assets exist.
- Door=true on ONE outer moving Model; group six GateDoor pieces together first. TownGate inferred from GateDoor descendant on generated gate wall. Owner/co-owner/mayor private-door access; town members gate access. Owner+mayor only manage coowners (server + UI corrected; coowner can no longer delegate).
- Door client green/red hover, E toggle; invisible open door uses ray/bounds for closing. Server range/liveness/occlusion/rate checks, authored part properties restored. Unaffiliated requester at exact gate -> existing mayor approval Y/N, 20-second open on acceptance and auto-close; request does not join town. Existing pending prompt IDs/expiry/leadership cancellation reused. Current requester must still be at gate and unaffiliated on approval. Docs CITY_GENERATION.md.
- New tests/run_town_doors.py exercises real service via mock; Studio visual playtest remains for user.

## Виправлення полиці за реальними rbxm — 19 жовтня

- Користувач надавStore.rbxm/Shelf.rbxm. Прочитано черезrbxmkv0.9.1 в/tmp: FoodShelf(iron) фізично1.000021x2.000012x1.000064; Model.WorldPivotData нахил90°X, PrimaryPartnull. СтарийGetBoundingBoxміг рахуватиоснову1x2черезpivot, відхиляючиїївсіхзонахZ1.
- Rules.UprightFurnitureBox рахуєкутовіточкивсіхчастинджерелаувертикальнійсистеміYup,зберігаєyaw/ігноруєpitchrollpivot; StoreFurnitureService використовуєцігабарити йзберігаєoffsetbox→pivot підчасPivotTo,тожфізичнуполицюнеперевертає. SourceмоделіНЕмодифіковано.
- РеальніShelfзониStore:9.999933x1,3.999933x1,3.999933x1→10+4+4=18полок, floatnoiseвміщуєтьсянаявноюtolerance. FourthAutoPlacer stringStoreFurniture="StoreСheckout (wood)" міститькириличнуС(U+0421); templateкасимаєназиватисьідентично. Моделькасине надана. Yardіснує; Floor Zombie_home=true іBlocksVision=false.
- tests/fixtures/shelf_geometry.luauміститьлише24кутитрьохреальнихPartsтаpivot,новийregression уrun_city_geometry. Cityservice/furnituremockтежоновленопідреальнегеометричневимірювання. ПопередженняfitтеперміститьточніXZджерелатазони.
- Перевіркиactualassetgeometry regression, cityservice,compile/Rojo. Studioнебуло.

## Магазини й AutoPlacer — 19 жовтня ввечері

- CityGenerationConfig.StoreChance=.05; YardPlace ForZHouse=true тепер95%Houses/5%Stores за незалежнимroll. ШаблониServerStorage/CityGeneration/Stores/<назва> зYard20x20; дляStoresнепотрібнийZHouse,не додаєтьсясам. HousesякбулиZHouse=true. Обидва орієнтуються+ZдоRoad, offset/fitзбережено.
- Якщообранакатегоріяне маєпридатнихшаблонів—fallbackінша; порожняобидвіretry. Rollкешуєтьсядоуспіху, готовіділянкинеперегенеровуються. OutputGeneratedCityHousesзалишивсядлясумісності, GenerationCategory=Houses/Stores, старіObjectValuelinksнезмінні. Workspace/roads іYardsпідтримані.
- StoreFurnitureService.Fill вызываєтьсянаcloneдоparentінапісляGenerate(workspace)дляretry. AutoPlacerModel/Part зіStoreFurniturestringShelf; джерелоServerStorage/CityGeneration/StoreFurniture/Shelf Model/Part. Областьbboxрозбиваєтьсянаціліbboxмеблів,поворотзонивизначаєосі; offsetpivotзбережений, низнадповерхнеюmarker. 1x10→10штук1x1або1штука1x10; oversizedнеставиться.
- МаркерсхованийCanQuery/Collide/Touchfalse, мебліAnchoredімаютьавторськіcollision/BlocksVision. РезультатAutoPlacer/GeneratedFurniturefolder +FurnitureCount. Існуючийgroupнеперезаповнюється,видаленнявсьогобудинкуприбираємеблі. Лут/магазиннізапасиНЕдодані. ПовніінструкціїCITY_GENERATION.md.
- Перевірки: реальнийcityservice+furnitureserviceнаmockAPI(StoresбезZHouse,вкладеніplots,10полок,anchor/hidemarker,missingfallback/retry/idempotence/cleanup); geometry4rotations,1x1/1x10grid,probabilityboundary; compile/Rojo. Studioнебуло.

## Щільність ресурсів1% — 19 жовтня

- Післяскрінуобласті40x100 користувач попросивзменшити загальнущільність. ResourceConfig.SpawnChance=.01дляTree/StoneVein/ScrapPile, замість.1. На4000квстудс середнє40кандидатівнаодинтипобласті, перевіркинеперекриття/земліякбули. Перекритіобластірізнихтипів додаютькандидатів(40+40тощо).
- Перевіркиresource_rules/density/service,compile/Rojo.

## Виправлення тканини — 19 жовтня

- Користувач уточнив: Redhead має давати наявний Rags, не новий Cloth. Reward/config/tests замінено наRags; Cloth видалений зItemConfig/fallback. Крафти не змінені, шанс7%/ранг лишився.

## Ранги талантів, Worker і ручний зум — 19 жовтня ввечері

- Найсвіжіші повні правила PROGRESSION_SETUP.md. Автозум від facing прибраний: колесоInputChanged змінює targetHeight, smooth exp, min18, max30+ViewBonus/tan(FOV/2); не змінюється при наведеннімиші/повороті, scrollменю не зумить. ViewBonus тепер2*Attention замість5. Старий ViewScale видалений, новийZoomBounds.
- TalentPoints0 наLevel0,+1на коженрівень; купівля1рангу=1point,Max10. Talentsтеперnumericrank, Rank суміснийзістаримtrue→1. UIпоказуєpoints/rank0..10/Upgrade, server перевіряєpoints/level/profession. Усі нинішніталантиLevel1, незалежні. AttributePoints5старт/+5рівень незмінні.
- Cook: KnifeMaster+5%APM/базовоїшкоди ножів наранг, serverclientcooldown/animationузгоджені, Strengthдодаєтьсяпіслямножника. KevlarApron+1passiveMeleeAbsorption/ранг; DamageServiceмаєattackKindMelee тількидлярукопашнихвикликів, 0damageclamp. Apronitem0.5kgSlotAdditional зареєстрований, ServerStorage/Items/Apron, безвізуалів/armorстатівпредмета(припасуємопотім).
- СтаріCooktalentsтеж10рангів: SurpriseServing+rankпорційзаbatch5; Grandmas/Ramsay duration*.8^rank(щобнестати0/від’ємним); effectsнаjobstart, потімLuckякбув.
- Worker професія будуєWorkbench, specialtyXP10заWorkstation. Redhead:7%*rank, на10ранзі70%,1ClothзаkillзомбіShovelкатегорією, кількістьне масштабуєтьсярангом. LastHitItemзберігаєтьсяпередшкодою. ClothокремийвідRags, .05kg, шаблонServerStorage/Items/Cloth +fallbackFabric. ТалантдодаєClothдоcorpseLoot передLuck(окремийбонусможеще додати).
- GoldenHands linear durationMultiplier1-.04*rank лишеWorkstation, rank10=.6. НеКухня. Workstationдосіgeneralaccessдлявсіх, алеXPзафахWorker.
- Перевірки progressionrules/service/cooking/meleeabsorption/Apronequip, town/resource regressions, всіLuaucompile/Rojo; Studioнебуло. Рівністарихталантів1тагеометріюзуму/візуалперевіритькористувач.

## Стартові5очок і таланти Cook — 19 жовтня

- ProgressionConfig.StartingPoints=5; Rules.New дає5всім гравцям наLevel0, +5за кожен рівень лишається. Це не одноразовий admin grant, а стартовий баланс.
- Три Cookталанти, поки всіLevel0 і безRequires (рівні користувач не задав, не вигадувати): SurpriseServing — Whoa, Where Did That Come From?; GrandmasMethod — Grandma Said to Do It Something Like This...; RamsayMethod — Just Like Ramsay Did on TV.
- SurpriseServing: Stove batchcount==5 додає1порцію recipe.OutputCount до готового output. Часткові партії/дошка/верстак не зачіпаються. GrandmasMethod duration*.8 дляStove; RamsayMethod duration*.8 дляCuttingBoard. Сервер бере effectssnapshot на старті job, після завершення застосовує bonusserving потімluck. Скасування не дає нагород.
- Наведенняатрибутів виправлено за скріном: замість порівняння rawmouse таAbsolutePosition використовує card.MouseEnter/MouseLeave, що враховують inset/UIScale. Tooltip усеще білякурсора й clampedviewport.
- Перевірки progression rules/service/cooking workflows (5→6, 60→48,10→8, partial/noextra, luckstack,5початковихочок), compile/Rojo. ВізуальногоStudioplaytest немає.

## Стиль інвентаря та hover атрибутів — 19 жовтня

- Користувач уточнив: бонуси/обмеження атрибутів видимі лише при наведенні, палітра має відповідати Inventory. Progression.client тепер використовує фон22/28/33, cards30/38/45, buttons42/53/62, текст235/240/244, divider63/73/82 та Gotham/GothamMedium; бронзові рамки/Garamond прибрані.
- На картках лише назва/вкладене значення/+; постійні описи, derived totals і рядокcaps видалено. AttributeTooltip біля курсора показує лише відповідні бонуси/поточні значення/ліміти наведеного атрибута. Схований поза картками та при закритті; позиція обмеженаviewport. Двіколонки та талантдерево лишились.
- Перевірки: Luaucompile/Rojo/diff check. Studio не запускався.

## Двоколонкове меню P — 19 жовтня

- Progression.client перероблено: ліворуч Attributes (XPbar/points/4stats із окремим+/totals), праворуч Talents (professionchoice/tree/details). Темне оформлення з бронзовими рамками в дусі DiabloII, UIScale під viewport. Праворуч власний ScrollFrame для дерева, ліві характеристики не прокручуються з ним.
- Вузли майбутніх талантів групуються рядками за requiredLevel, зв’язки за Requires, натискання показуєDescription/level/prerequisites іLearn/Locked/Learned. Cook.Talents усе ще порожній; чесний empty state без вигаданих здібностей. Серверні правила не змінені.
- Перевірки: компіляція клієнта, Rojo build, diff check. Візуального Studio playtest немає.

## Прогресія, характеристики та Cook — 19 жовтня

- Детальна актуальна інструкція: PROGRESSION_SETUP.md. Додано ProgressionConfig/Rules/Service, Progression.server, меню P. Session-only, зберігається після смерті, без DataStore. Вибір Cook один раз, XP до вибору не губиться.
- Рівень0, XP0, очки0; поріг100*(level+1), переносXP, +5очки/рівень. +10XP за повністю видобутий вузол, +10XP вбивці зомбі (LastDamagerID перед влучанням, один die). Тимчасово +10XP/завершена кухарська операція, не за кожну одиницю партії, безXP за скасування чи Workstation.
- Сила +1кг поріг перенесення та +1melee по живих; витривалість +.2 лише біг, +5MaxHealth без лікування поточногоHP. Уважність +.02 до базової.25 точності (cap.9), +5студс видимого простору вперед через perspective camera scaling за напрямком. Перешкоди й сектор незмінні. Удача +.03chance cap.5; бонус1+floor(Luck/3) за успіх незалежно на item type.
- Luck тільки нові resource drops, zombie corpse loot, completed craft output; не pickup/transfer/collectready (не дублювати вже наявні речі). Нульовий лут новихтипів не вигадує.
- Melee по живих після range/LOS кидає accuracy; Miss англійською над ціллю,0шкоди,1знос. Ресурси accuracy не мають; шкода5/10/15 без бонусуStrength. Ножі10/20+Strength по живих.
- Cook потрібний дляStove/CuttingBoard, будування/upgrade лишеKitchen. Workstation загальний. Без вибраної професії старі buildingchoices лишаються, післяCook Workshop будувати не можна. Сервер перевіряє при запиті та при погодженні, мер не обходить фах.
- Cook.Talents поки порожній, меню прямо каже not defined. Каркас перевіряєLevel/Requires і дублікати, атрибутніочки не витрачає; конкретні таланти/ефекти треба уточнити в користувача. Не стверджувати, що дерево талантів уже наповнене.
- Перевірено: progression_rules, realProgressionService та crafting workflows на mockAPI, town/resource workflows, всіLuaucompile/Rojo. Studio playtest не було.

## Крафти та майбутні професії — 19 жовтня

- Усі Workstation-рецепти MaxBatch=1; MakePlanks залишається1TreeLog→3Plank за одне виготовлення. MakeHandle1Plank→1Handle. StoneAxe/StoneShowel тепер1Stone+1Handle. ScrapAxe/ScrapShowel3Scrap+1Handle, ScrapKnife3Scrap. Плита BoilPotatoes до5Potato+відповідна CleanWater, як раніше.
- Користувач запропонував професії: дозволи на станки/будівлі, досвід за фаховий крафт, дерево талантів з вимогою рівня професії. Перелік професій/талантів/XP ще не визначений, реалізацію не додано; узгодити наступним кроком. Не вигадувати перелік самовільно.
- Перевірки: tool_tiers (одиничні партії/ціни/варіння5), resource_density, compile/Rojo.

## HP першої появи — 18 жовтня

- Перша успішна поява гравця в поточній сесії сервера має100HP; новий персонаж після смерті —2HP без лікарні, повне HP в лікарні як раніше.
- TownService тримає серверні weak-key spawnedPlayers/initializedCharacters; повторний PlaceCharacter того самого персонажа не перепризначає HP (не лікує/не знижує при зміні міста). Першу появу рахує лише після валідного spawn/humanoid/root.
- Перевірки town scenarios:100 при вступі, повторне розміщення зберігає41HP, наступний персонаж2HP; compile/Rojo. Studio не було.

## Екіпірування моделей із карти — 18 жовтня

- Користувач не міг екіпірувати нові предмети: попередній скрін показує їх у Workspace/WorldItems, тоді як EquipmentVisuals.Validate вимагає ServerStorage/Items/<ID>. Inventory pickup не створював шаблон.
- WorldItemService.register тепер викликає EquipmentVisuals.CaptureTemplate для Hands-предметів: сервер клонує світову модель в ServerStorage/Items, якщо валідного шаблону немає, перед pickup. Існуючий валідний authored шаблон має пріоритет. Зберігаються pivot/PrimaryPart/деталі, Quantity не копіюється. Це шаблон лише поточної сесії, не редакторське збереження. Для крафту без світової копії шаблони слід як і раніше класти в ServerStorage/Items.
- Перевірки: capture/validate на mock Instances, tool tiers, компіляція, Rojo; Studio не запускався.

## Рівні інструментів — 18 жовтня ввечері

- Нові точні ID зі скріну: StoneAxe, ScrapAxe, IronAxe, StoneShowel, ScrapShowel, IronShowel, ScrapKnife, IronKnife. Шаблони ServerStorage/Items. Showel — саме така назва! Старі Axe/Showel/Knife підтримані як сумісність, нові рецепти їх не видають.
- Сокири/лопати Weapon.Damage=5 по живих, HarvestTier=1/2/3 і HarvestMultiplier=1/2/3; ResourceService окремо рахує 5/10/15 по відповідних вузлах через ResourceRules.HarvestDamage. Швидкість25/хв, міцність1000 без змін.
- ResourceConfig.MinHarvestTier=1 для нинішніх ресурсів. ScrapPile вимагає мінімум кам’яну лопату; unranked інструмент не годиться. Майбутня залізна жила мусить мати MinHarvestTier=2. Саме залізо/жила/рецепти залізних ще не додані за словами користувача «потім додам».
- ScrapKnife Damage10, IronKnife20; CraftTool=Knife обом для дошки; параметри атаки старого ножа збережені.
- Рецепти кам’яних видають StoneAxe/StoneShowel (Handle+3Stone); додані ScrapAxe/ScrapShowel (Handle+3Scrap); MakeKnife тепер ScrapKnife за3Scrap. Кам’яного ножа немає.
- HP нинішніх вузлів100: 20/10/7 влучань по рівнях. Нові tools не видаються автоматично при спавні: стартові означає перший рівень розвитку.
- Перевірено tool_tiers, resource_rules/density, справжній ResourceService на mock API (видобування 20/10/7 ударами), компіляція, Rojo. Studio playtest не було.

## Камінь і генерація за площею — 18 жовтня

- StoneVein template: ServerStorage/Resources/StoneVeins/StoneVein; Stone item model: ServerStorage/Items/Stone; зона Workspace/StoneYard з плоскими Parts. Stone0.2кг, жила100HP, лопата HarvestTool=Shovel, лут1–5Stone на землю. Тимчасові значення HP/виходу/ваги задані агентом.
- Axe/Showel/Knife залишаються тими ж ID; користувач переробляє моделі під кам’яні. Рецепти Workstation замінено3Scrap→3Stone (Handle для сокири/лопати збережено).
- УСІ ресурсні області: 1незалежний шанс10% на кожну1x1 клітинку; дробова крайова площа пропорційна. Позиція випадкова в клітинці, поворот випадковий. 10x10=100спроб, середнє10кандидатів, не гарантовані10.
- MinCount/MaxCount/Spacing/EdgeGap видалено. Перевіряється лише неперекриття горизонтальних bbox ресурсів; дотик дозволено. Просторовий індекс8студс. Центр у маркері, краї можуть виступати. Невдалі кандидати пропускаються.
- Старий таймер30–300с після спустошення; валідний нульовий результат також чекає30–300с, без повторних шансів кожні5с. Відсутні шаблони/маркери retry5с.
- Перевірки: resource rules/clearance/density, реальний ResourceService на mock API (100клітинок, дубль маркера, лопата/знос/одноразовий лут), town scenarios, Luau compile, Rojo build. Studio playtest не було.

## Рецепти Workstation — 18 жовтня

- Plank (0.6кг) і Handle (0.3кг) зареєстровані в ItemConfig; моделі ServerStorage/Items/Plank і Handle.
- Workstation: 1TreeLog→3Plank; 1Plank→1Handle; 1Handle+3Scrap→1Axe або окремо1Showel; 3Scrap→1Knife.
- Тимчасові тривалості10/10/20/20/15с за партію, MaxBatch5, RequiresPresence=true; додаткового інструмента не потрібно. Закриття/відхід скасовує роботу за наявною логікою з поверненням інгредієнтів.

## Майстерня — 18 жовтня ввечері

- ServerStorage/Buildings/Workbench (T1), BuildingID=Workbench, UI Workshop, ціна1TreeLog з дозволом мера. Space/BuildingMenu як у кухні.
- Workstation Model працює як crafting station, без рецептів, highlight/E і empty state англійською. Chest загальнодоступний.
- BuildingStorage.PrepareUpgrade до списання ресурсів перевіряє відповідність скринь, потім переносить самі live Chest у новий рівень замість порожніх шаблонів: зберігає ChestService storage/identity й вигляд старої скрині. Для кількох потрібні унікальні StorageID, однакові на рівнях. Немає відповідника — скасування без втрат. Знесення/рестарт не зберігають вміст. T2 ще немає.
- Перевірки: компіляція Luau, town scenarios + chest migration scenarios, Rojo build; Studio не запускався.

## Підменю власності та випадкова забудова — 18 жовтня вдень

- Користувач підтвердив кухню і попросив Owner/Co-owners як окремі підменю. Реалізовано окремі сторінки з власним заголовком і Back to building; основні будівельні дії на цих сторінках не показуються. Оновлення стану зберігає обрану сторінку, втрата прав/знесення скидає її.
- Повторення будинків після рестарту спричиняв фіксований Seed=1843. CityGenerationConfig.Seed тепер false: кожен старт сервера/Play отримує новий випадковий числовий seed. Числове значення в конфігу залишається режимом відтворення карти.
- Реальний GenerationSeed записується на Workspace/GeneratedCityHouses і кожен будинок. Будинки не перегенеровуються всередині поточної сесії; випадкові збіги можливі. Підбір за вміщенням 20x20 збережено.
- Перевірки: Luau compile, Rojo build, city service mock scenarios, town service mock scenarios. Власного Studio playtest немає.

## Кухня Kitchen (T1), колода та дозвіл самому собі — 18 жовтня

- Користувач зробив модель Kitchen (T1), всередині Space 20x20, BuildingMenu і Stove. Шаблон **ServerStorage/Buildings/Kitchen (T1)**; старий Kitchen_1 лише fallback.
- TownConfig: Kitchen Costs[1]={TreeLog=1}. TreeLog вже зареєстрований у ItemConfig, новий предмет не додається.
- Завжди requestApproval, навіть коли заявник сам мер. Y списує колоду через Inventory.ConsumeIngredients і будує; N/timeout нічого не списують. Перед запитом перевірка матеріалів, на погодженні повторна атомарна перевірка/списання, живий заявник/членство/досяжність таблички.
- Kitchen.Space суміщається з оригінальним Space, враховано pivot offset. Зберігається Stove, права/TeamID/TownID копіюються зі стану ділянки.
- buildingMenu(plot) використовує вкладену табличку збудованої кухні. Стара табличка BuildingSpace тимчасово detached, щоб не дублювати; після знесення повертається з оригінальним Space. Клієнт піднімається по предках до BuildingSpace для вкладеної таблички.
- Тести town service додали self-approval/decline, рівно1log, повторне погодження, втрату ресурсів під час очікування та повернення таблички.
- Користувач прийняв поточних зомбі: через двері йдуть/б'ють; NoRoute біля деяких вікон залишається відомим обмеженням. **Не продовжувати цю оптимізацію без нового запиту.**

## NoRoute біля підвіконня — додаткове виправлення 18 жовтня

- Нові скріни показали NoRoute при Visible target і гравцеві впритул до стіни. Exact goal overlap перевіряв, чи вміститься все тіло зомбі на позиції гравця, і відсікав пошук ще до дверного графа.
- Navigation.Target спершу перевіряє точну ціль, потім найближчі вільні точки поруч. Колізійний ray до гравця не дозволяє вибрати точку з іншого боку стіни. Grid шукає обраний досяжний endpoint.
- Прибрано unconditional зупинку за близькістю до гравця: в межах stoppingDistance тепер перевіряється і прямий вільний прохід; близькість крізь стіну/підвіконня не означає прибуття.
- Доданий регресійний тест: ціль впритул до стіни, bbox зомбі на точній позиції не вміщується, але маршрут через двері до endpoint на правильному боці існує.

## Обхід вікна через двері — 18 жовтня

- Користувач підтвердив, що зомбі виходять через двері. Наступний скрін: Visible target / Chasing, але зомбі не обходив підвіконня до дверей.
- Додано ZombieNavigation.DoorRoute: граф проміжних точок по центру та з обох сторін найближчих дверних проємів. Визначення за Model із назвою, що починається DoorWay (регістр не важливий), або NavigationDoor=true. Модель мусить мати Parts; нормаль визначається за горизонтальними розмірами bounding box.
- Спершу перевіряється пряма дорога, потім дверний граф, потім попередній grid fallback. Кожне ребро графа має реальну Blockcast-перевірку; вікна й стіни не ігноруються.
- Це дозволяє робити довгий обхід, який дрібна сітка могла не знаходити в межах ліміту. Граф бере до 24 дверей у радіусі 40 студів.
- Збережена lastSeenPosition логіка: після втрати огляду йде до останньої побаченої позиції. На Model додаються діагностичні NavigationStatus (FollowingRoute/NoRoute) та LastSeenPosition.
- tests/run_zombie_navigation.py тепер перевіряє саме обхід від вікна через зміщені вбік двері, а також старі перевірки вузьких дверей/порога.
- BlocksVision не змінювали: на скріні вже Visible target. CanCollide визначає рух окремо від огляду. Studio playtest у агента не було.

## Виправлення проходу зомбі через двері — 18 жовтня

- Користувач підтвердив генерацію, але зомбі застрягав у проємі, куди фізично вміщується.
- ZombieNavigation раніше використовував діагональ тіла + запас як ширину колізійного боксу й крок сітки. Тепер сітка окрема, а swept-box за реальними X/Z тіла з .02 stud tolerance, орієнтований уздовж руху.
- Крок сітки .1–.25 з уточненням невдалого пошуку до .05, щоб знайти центр вузького проходу. Кожен сегмент перевіряє колізію; занадто вузькі двері не пропускаються.
- Рух Zombie.server використовує ту ж геометрію та напрямок тіла. Пошук підлоги обмежений висотою кроку root.Size.Y*.5, щоб не приймати верх одвірка за підлогу. Невеликий поріг підтримується.
- tests/run_zombie_navigation.py перевіряє вузький прохід, зміщення від центру, реальні колізійні сегменти, непрохідні вузькі двері, поріг і відсікання верхньої перемички (mock геометрія).
- Атаку не вимикали: гравець мав 2HP після спавну, один удар у межах досяжності може нокаутувати навіть зомбі, що застряг. Фактична атака вже має перевірки дальності, сектора та лінії видимості.

## Генератор будинків — реалізовано 18 жовтня

- CityGeneration.server запускає CityGenerationService.Start; автоматично заповнює наявні Workspace/YardPlace з ForZHouse=true. **Дороги й нові ділянки поки не генеруються.**
- Шаблони: ServerStorage/CityGeneration/Houses, довільна назва, Model ZHouse=true з безпосередньо вкладеним Yard. Повний House клонується в Workspace/GeneratedCityHouses.
- Суміщення центрів bounding box Yard і YardPlace враховує зміщення pivot будинку. Перед +Z повертається до найближчого краю Road=true по одному з чотирьох напрямків ділянки. Yard/ділянки 20x20, перевіряється вміщення; діагональні/завеликі шаблони не ставляться.
- Source YardPlace не знищується: невидимий, CanCollide/CanTouch/CanQuery=false. Клонований Yard теж невидимий; Floor і Zombie_home зберігаються, ZNumber діє. Усі деталі клону Anchored.
- ObjectValue GeneratedHouse на ділянці і GenerationSource на будинку запобігають дублям. Повторний Generate/Start не заміняє вже поставлені будинки. Нові/невдалі ділянки перевіряються через 5с; видалення ділянки прибирає її будинок.
- Seed і tolerance у CityGenerationConfig. Точні інструкції CITY_GENERATION.md.
- Перевірки: компіляція, Rojo build, tests/run_city_geometry.py, tests/run_city_service.py (mock API), zombie_home_rules.test.luau. Власного Studio playtest немає.

## Підготовка генератора міста та ZNumber — 18 жовтня

- Початкові заготовки (після цього реалізовано заповнення ділянок, див. вище): користувач підготував HouseA (brick), HouseB (brick), YardPlace ForZHouse=true і дороги з Road=true; назви шаблонів можуть змінюватися.
- Прочитано реальний HouseA (brick).rbxm: зовнішня Model ZHouse=true, усередині Yard/Part, Floor з Zombie_home=true, вкладені Wall/Corner/DoorWay/Window (brick) з Parts. **Yard усередині будинку**, а не будинок усередині Yard.
- Перед будинку за домовленістю **+Z, синя стрілка pivot**; Front Part користувач не хоче. Не переплутати з LookVector=-Z. Це узгоджений напрямок, який тепер використовує автоповернення.
- Додано числовий атрибут ZNumber на зовнішню Model будинку: рекомендовано 3, 0 вимикає спавн, без атрибута/невалідне значення fallback3. Користувач додає атрибут у Studio; завантажений rbxm не змінювався.
- ZombieHomeRules визначає найближчу Model-предка з ZHouse=true і рахує живих зомбі по їхньому ObjectValue ZombieHome. Кілька підлог у одному будинку ділять квоту. Ті, що вийшли з дому, рахуються; мертві/трупи — ні. Стара логіка зайнятості та 180 с блокування спавну збережена.
- Перевірка tests/zombie_home_rules.test.luau. Структура й правила описані в RESOURCE_SETUP.md.

## Спочатку прочитай це

Це **Decline**, Roblox-проєкт. Не змішуй його з іншим проєктом користувача Grey Warfare.
Після цієї нотатки читай актуальні файли main: код може бути новішим за опис.
Додаткові інструкції з моделей і механік є в RESOURCE_SETUP.md.

Користувач прямо попросив вносити готові зміни **одразу в main**, як у попередньому чаті; не залишати їх у draft PR чи окремій гілці без причини. Цей порядок уже погоджений. Нові зміни потрібно перевіряти перед записом, зберігати свіжі правки користувача і не робити force push.
Розбіжності назв користувач сам виправляє на моделях у Studio; повідомляй точні ID і папки.
Кожен новий предмет спершу реєструється в src/shared/ItemConfig.luau.
Після змін повідомляй, що вони в main, та нагадуй git pull.
Не вважай автоматичні перевірки доказом власного playtest у Studio.

## Остаточне уточнення сценаріїв виборів мера

- Resign негайно знімає мера й запускає вибори нового. Це більше не голосування за прийняття відставки.
- Усунення: **Y зняти / N залишити**. За успішного усунення автоматично починаються вибори нового мера.
- Повідомлення виборів: Would you like to take part in electing a new mayor? Y відкриває список гравців міста справа, N відмова від участі. Можна голосувати за себе, один кандидат на виборця, найбільше голосів перемагає.
- Кожен етап 30 с або відповіді всіх. Y на участь не є голосом: треба обрати кандидата. На тайм-ауті враховують лише обраних кандидатів.
- Нічия виборів — один повторний тур серед лідерів; повторна нічия/відсутність голосів залишає посаду вакантною. Start election біля прапора запускає нові вибори; ClaimMayor прибрано.
- Кулдаун звичайного усунення 600 с після результату виборів, не блокує відставку чи наступні вибори. Вступ під час виборів не надає голосу та не робить нового учасника мером.
- Серверні сценарії перевіряють обидва переходи, сторонніх кандидатів/виборців, голос за себе, відмову від участі, дублікати й повторний тур.

## Додаткові правки меню прапора та голосування

- Відкритий розділ ховає інші назви розділів; повторне натискання повертає їх. Додано англійські пояснення.
- OwnAll видалено і на клієнті, і на сервері; мер може привласнювати окремі будівлі через BuildingMenu.
- Мер не може почати звичайне голосування проти себе. Resign негайно складає повноваження та починає вибори нового мера (див. остаточне уточнення вище).
- Голосування 30 секунд або закінчення одразу після всіх голосів. Після свого голосу гравець продовжує бачити таймер, але не може голосувати повторно.
- Усі town-сповіщення праворуч. Нижню підказку прибрано; Flag і BuildingMenu підсвічуються зеленим під курсором, E збережено. За уточненням зі скрінів додано підпис біля курсора як у Stove: Flag / Building Menu та [E] Open або Too far.

## Виправлення 13 жовтня після першого тесту користувача

- Усі програмні тексти гри — англійською (імена користувачів і задані Town_name не перекладаються).
- Choose a town — закріплений заголовок над списком; Join знаходиться всередині розкритого міста. Порядок UI задає LayoutOrder, а не Name.
- **Flag.Team**, НЕ Flag.TeamID, зіставляється з **TownSpawn.TeamID**. TownID незалежний від командного ID.
- TownService.LoadCharacter переносить після завершення LoadCharacterAsync, щоб стартове переміщення Roblox не перезаписувало TownSpawn. PlayerLifeService використовує той самий метод при відродженні.
- Тест відтворює переміщення персонажа після CharacterAdded; окремо перевіряє TownID=3/Flag.Team=1/TownSpawn.TeamID=1 і відродження з 2 HP.

## Що додано 13 жовтня — міста

Користувач задав Flag/TeamColor, BuildingSpace/BuildingMenu/Space, TownSpawn і повноваження мера. Реалізація: `TownService.luau`, `Towns.server.luau`, `Towns.client.luau`, `TownConfig.luau`, `TownRules.luau`. Точна інструкція та всі початкові правила — **TOWN_SETUP.md**.

- Початкове меню міст з Town_name, кількістю онлайн-членів, дипломатією, username мера й вступом. Перший персонаж завантажується тільки після вступу.
- Flag.Team → командний ID; TownSpawn.TeamID та BuildingSpace.TeamID мають збігатися з ним. TownID окремий.
- Flag.LeaderID — Roblox UserID. Перший член порожнього міста стає мером; для вакантної посади можна розпочати вибори біля прапора. Вихід із міста звільняє посаду, вихід із сервера — ні.
- 200 студів — територія навколо pivot по XZ; встановлює TerritoryTownID/TerritoryTeamID гравця. Це не автоматична зміна членства.
- Через прапор: покинути команду, голосування, посісти вакантну посаду, дипломатія. Привласнення — лише окремо через таблички.
- Голосування анонімне, 30 с або до голосу всіх, Y усунути/N залишити, більшість поданих голосів; нічия залишає мера. Кулдаун 600 с після завершення. Виборців фіксують на старті; при виході голос вилучають; повторний голос не змінює перший. Усунення залишає посаду вакантною.
- Нейтралітет за замовчуванням. Союз потребує згоди іншого мера, війна/нейтралітет односторонні та симетричні. Бойові правила дипломатії ще не підключено.
- BuildingMenu відкриває перший рівень або лише наступне покращення. Наразі визначено тільки кухню Kitchen_1; не вигадуй наступні рівні.
- **Шаблон кухні: ServerStorage/Buildings/Kitchen_1.** Користувач ще має зробити його в Studio. Pivot шаблону суміщається з pivot Space. Space тимчасово виймається з Workspace; після знесення повертається. BuildingMenu зберігається.
- Запит будівництва показує меру username заявника, Y/N, 60 с на відповідь, окремі ID та чергу. Мер сам будує без запиту. Немає ціни, витрат чи таймера робіт — це не задано.
- Основний власник — заявник. Мер змінює OwnerID, привласнює будівлі окремо через таблички, керує співвласниками й зносить. Власник/співвласник також керує співвласниками й своєю будівлею, але має лишатись членом міста.
- Co-OwnerID: початковий number для одного ID підтримано; сервер записує comma-separated string для кількох.
- Spawn на TownSpawn з 2 HP; закладено лікарняну точку HospitalSpawn в Model з BuildingID=Hospital та TownID. Саму лікарню не реалізовано.
- Дані в межах поточного сервера; DataStore немає. Моделі читаються на старті Play.
- Клієнтські атаки, прицілювання, біг, інвентар і підбирання враховують TownMenuOpen, щоб меню не запускало інші дії.
- Перевірки: компіляція всіх Luau, Rojo build, наявні resource/movement тести, town_rules, серверні сценарії `python tests/run_town_service.py /path/to/luau` на mock API. **Власного playtest Studio не було.**

Наступне: користувач додає кухню, перевіряє меню/спавн/запити в Studio; уточнення радіуса й політики влади можуть змінити початкові правила. Не змішувати з Grey Warfare.

## Що додано 12 жовтня

### Вода і крафти

- EmptyBottle: 0,1 кг.
- DirtyWater: 0,6 кг, +30 Water, +20 Sick.
- CleanWater: 0,6 кг, +50 Water.
- Після пиття повертається одна EmptyBottle; кнопка в UI — Drink.
- BoilPotatoes потребує Potato = 1 і CleanWater = 1 на кожну порцію. Партії обмежені чинним MaxBatch = 5.
- Поточний рецепт не повертає порожню пляшку після готування; не стверджуй протилежного.
- Рецепти в інвентарі згорнуті до кнопок із назвою. Клік відкриває опис, інгредієнти, кількість, крафт і збір; повторний клік закриває, вибір іншого згортає попередній.
- Основні файли: ItemConfig.luau, CraftConfig.luau, CraftRules.luau, ConsumableService.luau, Inventory.client.luau.

### Сокира і лопата

- Axe: 1,5 кг, HarvestTool = "Axe".
- Showel: саме такий внутрішній ID/назва моделі (не Shovel); англійська назва в UI — Shovel. 2 кг, HarvestTool = "Shovel".
- Обидві: Damage = 20, AttacksPerMinute = 25, MaxUses = 1000, Range = 1, Width = 1, Animation = "SwingLeft" як у руки зомбі.
- Axe — Slashing; Showel — Blunt.
- Влучання зброєю по ресурсу витрачає рівно 1 міцність. Непідходяща зброя теж зношується, але не пошкоджує ресурс. Порожній замах не витрачає міцність.
- Нові види сокир підтримуються через HarvestTool = "Axe".
- Шаблони: ServerStorage/Items/Axe і ServerStorage/Items/Showel. Pivot моделі задає точку тримання в руці.

### Ресурси

- Tree_1, Tree_2, Tree_3: 100 HP; пошкоджуються лише сокирами. Після 5 влучань дають 1–4 TreeLog.
- PileScrap: 100 HP; добувається лопатою. Дає незалежно 1–5 Scrap та 1–5 Rags.
- Чинна вага: TreeLog = **2 кг**, Scrap = **0,2 кг**, Rags = 0,05 кг. Старі 10 кг / 0,5 кг вже замінено.
- Лут **з'являється на землі на місці знищеного ресурсу**, а не в інвентарі гравця.
- Кожен тип луту — окремий світовий предмет зі стеком Quantity. Отримання — через звичайний Pickup.
- Моделі луту беруться з ServerStorage/Items/TreeLog, Scrap, Rags. Якщо їх немає або модель порожня, використовуються тимчасові блоки; вони доступні для підбирання й викидання.
- Дерева мають Wood material і ResourceMaterial = "Wood". Збережено їхні наявні BlocksVision. Деревам не додавали Humanoid, підсвічування чи popup здоров'я.
- Ключові файли: ResourceConfig.luau, ResourceRules.luau, ResourceService.luau, Resources.server.luau, Combat.server.luau, WorldItemService.luau.

### Генерація — важливе останнє уточнення

- Шаблони дерев: ServerStorage/Resources/Trees/Tree_1, Tree_2, Tree_3.
- Шаблон купи: ServerStorage/Resources/ScrapPiles/PileScrap.
- Моделі областей у Workspace: Forest і ScrapYard, усередині тільки плоскі Parts-маркери на рівні землі. Ресурси зберігаються окремо в Workspace/Resources.
- Маркери видимі в редакторі; сервер під час гри встановлює Transparency = 1, вимикає CanCollide/CanTouch/CanQuery, вмикає Anchored і задає BlocksVision = false.
- Початкова випадкова кількість — 1–20 на область. Розставлені вручну ресурси всередині відповідної області враховуються, тому тестові моделі не дублюються.
- Після знищення останнього ресурсу починається випадковий таймер 30–300 секунд, потім з'являється нова кількість 1–20.
- **3 студи — від краю моделі ресурсу до краю іншої моделі ресурсу, а НЕ від межі області.**
- **Центр bounding box моделі має бути всередині області; модель може частково виступати за край області.**
- Відступ від краю області прибрано. Це пряме виправлення користувача; не повертай попереднє правило.
- EdgeGap = 3 враховує розмір і поворот bounding box. Проєкції моделей на горизонтальну площину перевіряються на перекриття та відстань між краями.
- Початкові додаткові мінімальні відстані між центрами залишаються: Spacing = 8 для дерев, Spacing = 1 для куп. Зазор 3 студи перевіряється між усіма ресурсами, включно з різними типами/областями.
- Якщо випадкова кількість не вміщається за правилами, генерується менше, без порушення відстаней; спроби обмежені.
- За відсутності шаблонів або можливості розміщення порожня область повторює спробу через 5 секунд.

### Перенесення і взаємодія

- 20 кг — м'який поріг без штрафу, НЕ заборона підбирати більше.
- Кожен зайвий кг зменшує швидкість ходьби та бігу на 5%, пропорційно включно з дробовими кг.
- Формула множника: clamp(1 - max(0, LoadKg - 20) * 0.05, 0, 1).
- 25 кг → 75% швидкості; 30 кг → 50%; 40 кг і більше → 0.
- Вага враховує інвентар і спорядження в руках. Після зменшення ваги швидкість відновлюється.
- Running.server.luau застосовує штраф; Needs.server.luau визначає витрату потреб під час бігу через Running, щоб штраф не змінював класифікацію бігу.
- Shared/Interaction.luau обчислює найближчу точку bounding box моделі/Part.
- Підбирання предметів та взаємодія зі скринями, трупами, плитами й дошками рахують відстань **до краю**, а не до центру/pivot. Клієнт і сервер використовують той самий helper.
- Чинний PickupDistance = 1. Сервер перевіряє досяжність і відсутність перешкод.

### Зомбі-доми

- Як раніше: модель із Zombie_home = true; шаблон ServerStorage/Creatures/Zombie.
- Нові зомбі не з'являються, поки живий гравець стоїть на підлозі-маркері дому.
- Після виходу останнього гравця спавн блокується ще на 180 секунд. Повторний вхід скидає відлік.
- Чинний звичайний випадковий інтервал спавну 1–60 секунд збережено.
- Визначення зайнятості враховує локальні координати підлоги та висоту ніг; гравець на іншому вертикальному поверсі не повинен блокувати нижню підлогу.
- Файли: ZombieHomes.server.luau, AreaService.luau, ResourceRules.Occupancy.

## Перевірки та наступний початок роботи

Користувач підтвердив роботу основних доданих механік. Проведено компіляцію Luau, збірку Rojo та перевірки генерації/луту/геометрії в тестовому оточенні. Власного запуску актуальних моделей у Roblox Studio в агента не було.

Тести в репозиторії:
- tests/resource_rules.test.luau
- tests/movement_rules.test.luau
- tests/resource_clearance.test.luau

Для продовження:
1. Прочитай цей файл і актуальну версію коду main.
2. Прочитай TOWN_SETUP.md і прийми уточнення користувача щодо вже доданих міст.
3. Працюй у поточній структурі Rojo: src/shared, src/server, src/server/Services, src/client, src/character.
4. Перед записом перевіряй свіжий head main, щоб не затерти правки користувача.
