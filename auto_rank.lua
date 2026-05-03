--[[
	Auto Rank — PS99, клиентский executor Luau.
	Прогресс: фарм breakable (farmBreakableClasses: Normal + Present/Gift/… для ранговых квестов) + орбы (Orb).
	Клейм: Network.Fire("Ranks_ClaimReward", rewardKey).
	Rank up: MiddleRankUpReady + getconnections.
	Зоны: Zones_RequestPurchase, телепорт на фарм — по умолчанию только клиентский PivotTo (без Teleports_RequestTeleport / пушки); опционально серверный Invoke.
	Квесты / цели HUD: те же Callback(), что GoalCmds → GoalsFrontend (приоритет как в игре) —
	  телепорт к Displays[].Target (Part), клик по Displays[].Target (GuiButton / GUI из ProcessClickSequence),
	  разблок яйца Eggs_RequestUnlock, хэтч: CustomEggsCmds / SetupEgg + AttemptHatch (без Infinity по умолчанию); после purchase клиент ждёт «Click to open!» (Egg Opening Frontend),
	  авто-покупка слотов питомцев EquipSlotsMachine_RequestPurchase,
	  слотов яиц EggHatchSlotsMachine_RequestPurchase (логика Egg Slots Machine: NEXT + Balancing.CalcEggSlotPrice),
	  дешёвый доступный апгрейд UpgradeCmds.Purchase,
	  опционально закрытие вкладки машины через TabController.CloseTab (если открыта EggSlotsMachine / EquipSlotsMachine / …),
	  повторный Pivot после телепорта; один активный runner — getgenv().AutoRankRuntime, выгрузка AutoRankUnload().
	  UI ребитха: autoDismissRebirthUi — только GUI-сигналы на «Click for more» (без мыши экзекьютора).
	  Хэтч: hatchBusy + task.spawn (не task.wait в Heartbeat); hatchAfterPivotDelay; телепорт на зону яйца из текста квеста (questEggTeleportIfWrongZone).
	  В Studio: Physical Eggs Frontend зовёт Eggs_RequestPurchase после BuyMultiple; HatchingCmds.AttemptHatch — другой вход. Оверлей «Click to open!» — Egg Opening Frontend (+ Variables.OpeningEgg); без клика яйцо не продолжает сцену.
	  Яйца: preferZoneEggWhenProgress — приоритет яйца, стенд которого в текущей зоне (GetEggPart + MapCmds/ZoneCmds по позиции).
	  Продвинутый фарм: advancedRemoteFarm — якорь макс. зоны; remoteFarmSkipMaxZoneTeleport отключает TP (оставляет «не ту» зону).
	  forceTeleportWhenBehindMaxZone — если curZone ≠ maxOwned, телепорт на maxOwned всё равно (общая прогрессия монет/гейтов).
	  Кнопка «Return to Area»: autoClickReturnToAreaButton — дополнительно жмёт GUI при cur ~= maxOwnedZone.
	  Executor (UNC): getconnections / fireproximityprompt / fireclickdetector / firetouchinterest;
	  Смена Place (TeleportService → Tech World и т.д.): новый клиент — crossPlaceAutoReload + queue_on_teleport (URL или readfile), иначе инжект не продолжается.
	  GUI через getconnections / firesignal на RBXScriptSignal (Activated, MouseButton1Click; для оверлея яйца — также LocalPlayer:GetMouse().Button1Down). Без синтетической мыши (mousemoveabs / mouse1click).
	  Автобаффы (Heartbeat): PotionCmds.Consume (см. questConsumePotionsPreferMaxTier для tier), FruitCmds.Consume, ConsumableCmds.Consume → Consumables_Consume (Studio ActionMenu).
	  Активные бусты Save.Boosts синхронизирует BoostCmds с сервером — отдельного клиентского «Use» для слотов нет.
	  Известные инвоки (клиент): Zones_RequestPurchase, InstanceZones_RequestPurchase, Ranks_ClaimReward,
	  Eggs_RequestPurchase, Eggs_RequestUnlock, EquipSlotsMachine_RequestPurchase, EggHatchSlotsMachine_RequestPurchase,
	  Upgrades_Purchase, Teleports_RequestTeleport, Orbs: Collect.

	Не покрыто автоматикой (нужны отдельные инвоки/GUI): гильдии, дейли из других окон,
	ивенты Basketball/EventGoals_Claim, трейды, ручные машины — см. Types.Quests в Studio.
	  Нормализация GoalGenerators + приоритетный список генераторов (Eggs, Zone, Machines, Transitions, FishingEvent, …): не резать minigame-хьюристикой; GUI-клики включены (questClickGuiTargets).
	  Квестный флаг при no_goal от GoalGenerators: questAutoPlaceFlagWithoutTrackedGoal + MapCmds.IsInDottedBox.
	  Зелья: questConsumePotionsPreferMaxTier — выбор стака с максимальным tier (иначе случайный порядок pairs()).
	  minigameAssistMode: skip | complete | off — диспетчер инстансов (обби/wave2), Minefield не автоматизируется, instanceIdsForceLeave, LeaveTeleport,
	  InstancingCmds.Leave для блок-листа, PetCmds.EquipBest.
	  hideEggHatching = прямой Invoke без HatchingCmds; после purchase — autoClickEggOpeningPrompt дергает Mouse.Button1Down (Egg Opening Frontend в Studio), не только GuiButton.

	Конфиг: getgenv().AutoRank = { ... }
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local GuiService = game:GetService("GuiService")

local LocalPlayer = Players.LocalPlayer

local DEFAULT = {
	enabled = true,
	--- Фарм
	farmNormalBreakables = true,
	--- BreakableFrontend.AllByZoneAndClass: несколько классов (ранговые квесты «подарки» часто не Normal).
	farmBreakableClasses = { "Normal", "Present", "Gift", "MiniChest", "Chest" },
	delayDamage = 0.125,
	farmRadius = 420,
	preferClosest = true,
	--- Не чаще 1 раз за интервал собирать кандидатов фарма (AllByZoneAndClass × классы — тяжело на каждом Heartbeat). 0 = каждый кадр.
	farmCandidateScanInterval = 0.12,
	--- Орбы
	collectOrbs = true,
	orbCollectInterval = 0.35,
	maxOrbBatch = 80,
	--- Если ключи орбов копятся без Clear — сброс (антиутечка)
	orbAccumulatorMaxKeys = 4000,
	--- Радиус подбора орбов на клиенте (Orb.CollectDistance / DefaultPickupDistance / CombineDistance)
	orbMagnetBoost = true,
	orbMagnetMinDistance = 800,
	--- Дополнительно слать Orbs: Collect по id из Fired (часто не нужно при orbMagnetBoost)
	orbRemoteCollectBatch = false,
	--- Клейм наград ранга
	autoClaimRankRewards = true,
	claimInterval = 0.35,
	claimDebounce = 0.28,
	--- После полного клейма — попытка rank up через GUI
	autoRankUpGui = true,
	rankUpGuiInterval = 1.2,
	--- Туториал: скрывает стрелки, завязанные на ActiveGoalArrow (см. Tutorial)
	tutorialHideGoalArrow = true,
	--- Не вызывать SetAttribute ActiveGoalArrow каждый кадр
	tutorialArrowInterval = 2,
	--- Следующая зона мира: Invoke Zones_RequestPurchase (как Gates / Zone Progress Bar)
	autoBuyZones = true,
	--- Если true — не ждать ZoneCmds.HasCompletedNextZoneQuests() (можно кинуть Invoke раньше клиентских квестов гейта)
	ignoreZoneGateQuests = false,
	zonePurchaseInterval = 0.55,
	--- Телепорт на макс. зону: только клиентский PivotTo к PERSISTENT/Teleport (без Teleports_RequestTeleport — без пушки и попапа «You're already here!»).
	teleportMaxZoneClientPivotOnly = true,
	--- Если уже в нужной зоне, но далеко от точки телепорта — только докрутить pivot, без Invoke
	teleportClientPivotWhenSameZone = true,
	--- Считать «уже на месте», если HRP в радиусе от GetTeleportPartLocation(зона)
	teleportClientPivotNearStuds = 32,
	--- Квест: телепорт к яйцу — тоже только pivot (без серверного Teleports_RequestTeleport)
	questEggTeleportClientPivotOnly = true,
	teleportInterval = 10,
	teleportPivotYOffset = 3,
	--- Несколько Pivot на RenderStepped после инвока (перебить cannon-VFX)
	teleportPivotRepeatCount = 5,
	teleportPivotRepeatDelayFrames = 1,
	--- Осторожно: на время повторных Pivot временно сбрасывает Variables.IsUsingCannon
	teleportCannonWorkaround = false,
	--- UI ребитха: только getconnections/firesignal на кнопке «Click for more» (без мыши экзекьютора)
	autoDismissRebirthUi = true,
	rebirthDismissInterval = 0.28,
	--- Хэтч: пауза после pivot перед Invoke (сервер видит позицию); флаг hatchBusy держит телепорт/фарм
	hatchAfterPivotDelay = 0.38,
	hatchBusyHoldSeconds = 2.6,
	--- Яйцо прогресса: если в тексте квеста нет конкретного яйца — брать лучшее яйцо физически в текущей зоне
	preferZoneEggWhenProgress = true,
	--- Если квест про конкретное яйцо и стенд в другой зоне — сначала Teleports_RequestTeleport на зону яйца
	questEggTeleportIfWrongZone = true,
	--- Продвинутый фарм: цели и урон по breakable якорю макс. зоны (персонаж может быть у квеста/яйца)
	advancedRemoteFarm = true,
	remoteFarmUseMaxZoneAnchor = true,
	remoteFarmRadiusMultiplier = 2.4,
	remoteFarmOrbMagnetMultiplier = 1.45,
	--- Если true — НЕ вызывать Teleports_RequestTeleport на макс. зону (остаёшься в текущей локации).
	remoteFarmSkipMaxZoneTeleport = false,
	--- Если true — не тянуть к BREAKABLE_SPAWNS.Main в макс. зоне (имеет смысл только вместе с телепортом в ту зону).
	remoteFarmSkipBreakablePull = false,
	--- Общая прогрессия: если curZone ~= maxOwnedZone — ВСЕГДА телепортить на maxOwned (перебивает remoteFarmSkipMaxZoneTeleport).
	forceTeleportWhenBehindMaxZone = true,
	--- Зелёная кнопка возврата в актуальную зону (когда разблокированы области выше спавна)
	autoClickReturnToAreaButton = true,
	returnToAreaClickInterval = 2,
	--- Другой Experience Place (Tech World и т.д.): клиент полностью новый — после телепорта снова выполнить скрипт (UNC queue_on_teleport). Нужен crossPlaceReloadUrl (raw) или crossPlaceReloadReadfile.
	crossPlaceAutoReload = true,
	crossPlaceReloadUrl = "https://raw.githubusercontent.com/topzurdo/DoNotTryfindmyreposssssalsooa/refs/heads/main/hello/.lua",
	crossPlaceReloadReadfile = "",
	crossPlaceReloadDelaySec = 3,
	--- В текущей макс. зоне подтягивать персонажа к BREAKABLE_SPAWNS.Main (ZonesUtil), центр поля брейкаблов
	teleportToBreakableFarmCenter = true,
	farmBreakablePullInterval = 1.15,
	farmBreakableMinDist = 20,
	farmBreakableYOffset = 5,
	--- Порядок имён Part в INTERACT/BREAKABLE_SPAWNS (как в Studio: Main, Easy, VIP…)
	farmBreakableSpawnPartPriority = { "Main", "Easy", "VIP" },
	--- Ассистент «целей» как у стрелки квеста (GoalCmds + приоритеты из клиента)
	questAssistEnabled = true,
	questAssistInterval = 0.65,
	--- Телепорт персонажа к первому мировому Target из Displays (яйцо, машина, зона…)
	questTeleportToTarget = true,
	questTeleportMinDist = 14,
	questTeleportYOffset = 6,
	--- Если у цели HUD есть мировой Target (Part/Model) — не звать телепорт на макс. зону
	questAssistSkipFarmTeleportWhenObjective = true,
	--- false: не блокировать квест при GUI.Transition() (частый «NO environment … GUITransition» без подхода к ракете)
	questBlockOnGuiTransition = false,
	questAutoUnlockEgg = true,
	--- HatchingCmds: Enable(AUTO) + SetupEgg/SetupCustomEgg + AttemptHatch (Invoke Eggs_RequestPurchase)
	questAutoHatch = true,
	--- Если false — крутить хэтч только когда генератор цели в имени содержит "Egg"
	questAutoHatchAnytime = false,
	questHatchAssistInterval = 1.1,
	--- Infinity Egg только если явно разрешено или текст цели содержит ключевые слова
	allowInfinityEggWithoutQuest = false,
	infinityEggQuestKeywords = { "infinity", "infinity egg", "infinityegg" },
	--- Сброс кулдаунов покупок по ключевым словам в тексте цели HUD
	questAssistObjectiveKeywords = true,
	--- Авто-зелья / фрукты / расходники (ConsumableItem). Всегда из Heartbeat при enabled (не требуют questAssist).
	autoConsumeBuffs = true,
	--- false: не жать баффы, пока игрок в инстансе (TNT/бусты в минииграх)
	autoConsumeBuffsInInstance = false,
	--- Раз в интервал — зелье (UID стака + кол-во, см. ActionMenu.Potion)
	questConsumePotions = true,
	questConsumePotionsInterval = 1.35,
	--- true: как раньше — если хоть одно зелье уже активно (Save.Potions), не пить новые
	questConsumePotionsOnlyWhenNoneActive = false,
	--- Крупные порции при перке Potions/BulkConsume (5/10/25/50/100)
	questConsumePotionBulk = true,
	--- true: среди стаков выбирать максимальный tier (pairs() по инвентарю даёт случайный порядок и часто сначала I–II уровень)
	questConsumePotionsPreferMaxTier = true,
	questConsumeFruits = true,
	questConsumeFruitsInterval = 1.5,
	--- За тик не больше N штук одного фрукта (очередь мастери)
	questConsumeFruitMaxAtOnce = 4,
	--- Consumables_Consume (токены, «Ultra Pet Token Boost», TNT в майнинге — в blocklist)
	autoConsumeConsumables = true,
	autoConsumeConsumablesInterval = 2.2,
	autoConsumeConsumableBlocklist = {
		"Mining Bomb",
		"Mining TNT",
		"Mining TNT Crate",
		"Mining Nuclear TNT Crate",
		"Mining Bejeweled TNT Crate",
		"TNT",
	},
	--- Цель HUD может указывать на GuiButton (ранг, машины, сайд-табы, plaza…)
	questClickGuiTargets = true,
	questGuiClickInterval = 0.38,
	--- Если true и имя генератора из списка questGoalGeneratorPrioritySubstrings — не применять minigame-хьюристику (но учитывать questBlockedObjectiveSubstrings).
	questPrioritizeListedGoalGenerators = true,
	--- Подстрочники имён генераторов GoalCmds.Modules.* (совпадает если string.find по нижнему регистру)
	questGoalGeneratorPrioritySubstrings = {
		"eggs",
		"zone",
		"unlock castle",
		"side buttons",
		"upgrades",
		"instances",
		"return to farm",
		"use enchant",
		"use potion",
		"keys",
		"trading plaza",
		"redeem rank reward",
		"machines",
		"rainbow machine",
		"rebirth shrines",
		"egg slots",
		"gold machine",
		"upgrade potions machine",
		"upgrade enchants machine",
		"pet slots",
		"travel to tech",
		"travel to void",
		"traverse void islands",
		"traverse from void spawn",
		"travel to fantasy",
		"fishingevent",
		"farmingworld",
		"halloweenworld",
		--- подмодули FarmingWorld (имена как ModuleScript: PlaceFarmingEgg, SpendFarmingToken, …)
		"placefarm",
		"claimfarm",
		"claimfarming",
		"spendfarm",
		"farmingtoken",
		--- подмодули HalloweenWorld (CamelCase → lower без пробелов: HalloweenTrickOrTreat и т.д.)
		"halloweentrick",
		"placehalloween",
		"newhalloween",
		"claimhalloween",
		"castfishing",
		"catchfish",
		"sellfish",
		"buyboat",
	},
	--- Экипировать первый свободный слот энчантом из инвентаря (Enchants_Equip)
	questEquipEnchants = true,
	questEquipEnchantInterval = 2.2,
	--- Квест «place / use a flag»: после входа в dotted box (IsInDottedBox) — FlexibleFlagCmds.Consume (см. Studio FlexibleFlagCmds)
	questAutoPlaceFlag = true,
	questPlaceFlagInterval = 2,
	--- Если GoalGenerators не отдают цель (в логе no_goal / valid=0), всё равно пробовать флаг в dotted box — иначе квест «Use a flag» никогда не триггерится.
	questAutoPlaceFlagWithoutTrackedGoal = true,
	--- Порядок перебора флагов, если в тексте квеста нет конкретного имени
	questFlagNameFallbackOrder = {
		"Strength Flag",
		"Magnet Flag",
		"Hasty Flag",
		"Shiny Flag",
		"Rainbow Flag",
	},
	--- При hideEggHatching: если true — не жать «Click to open!» (часто яйцо визуально не открывается; в Studio цепочка идёт через UI/HatchingCmds).
	skipEggGuiClickWhenHiddenHatch = false,
	--- Авто-покупка слотов яиц (Egg Slots Machine → EggHatchSlotsMachine_RequestPurchase)
	autoBuyEggSlots = true,
	eggSlotPurchaseInterval = 1,
	eggSlotMaxPurchasesPerPulse = 3,
	--- Если true — пробовать EggHatchSlotsMachine_RequestPurchase и для UNLOCKED (в UI кнопка не вешается; сервер может принять очередной бандл)
	eggSlotPurchaseTryUnlocked = true,
	--- Авто-покупка слотов питомцев (инвок как у GUI машины)
	autoBuyEquipSlots = true,
	equipSlotPurchaseInterval = 1,
	equipSlotMaxPurchasesPerPulse = 3,
	--- Авто-покупка ближайшего доступного апгрейда зоны (квест «купи апгрейд»)
	autoBuyCheapestUpgrade = true,
	upgradePurchaseInterval = 1.5,
	--- Авто садик (Daycare)
	autoDaycare = true,
	autoDaycareInterval = 5,
	--- Пропускать (игнорировать) квесты на миниигры (инстансы), чтобы бот в них не заходил
	questIgnoreMinigames = true,
	--- false: генератор Instances ведёт к порталу — телепорт/промпт к цели (ранг часто даёт вход в активности)
	questIgnoreInstancesGenerator = false,
	--- Если Callback вернул Displays, но Priority=nil (часто при пустом Goals.Priorities в билде) — считать приоритет 0
	questNormalizeNilGoalPriority = true,
	--- Подстроки в тексте цели (HUD), при совпадении не взаимодействовать с Target (рыбалка, ивенты)
	questMinigameObjectiveSubstrings = {
		"fishing",
		"digsite",
		"advanced digsite",
		"chest rush",
		"atlantis",
		"obby",
		"falling",
		"sled",
		"woodcutting",
		"diamond wheel",
		"flower garden",
		"ice obby",
		"jungle obby",
		"pyramid",
		"millionaire run",
		"easy obby",
		"hoverboard",
		"enchant empowering",
	},
	--- По умолчанию пусто: квесты на fuse/rainbow/gold machine и карты не блокируются (ранговая прокачка)
	questBlockedObjectiveSubstrings = {},
	--- Выйти из инстанса через InstancingCmds.Leave, если id в списке (имена как в GoalCmds.Modules.Instances)
	questAutoLeaveBlockedInstances = true,
	questBlockedInstanceIds = {
		"Fishing",
		"AdvancedFishing",
		"FishingEvent",
		"Digsite",
		"AdvancedDigsite",
		"Woodcutting",
		"FlowerGarden",
		"Atlantis",
		"ChestRush",
		"DiamondWheelInstance",
		"SpawnObby",
		"IceObby",
		"JungleObby",
		"PyramidObby",
		"HoverboardTechObby",
		"MillionaireRun",
		"LuckyBlocks",
		"EnchantEmpoweringInstance",
		"Minefield",
	},
	--- "off" — без движка миниигр. "skip" — квест-скип + Leave из списка.
	--- "complete" — квест ведёт в инстансы (см. minigameAllowQuestInstancesWhenComplete), автопрохождение для minigameAutoPlayInstanceIds.
	minigameAssistMode = "skip",
	--- Непустая таблица: только эти ID для принудительного Leave (иначе используется questBlockedInstanceIds).
	instanceIdsForceLeave = nil,
	--- Какие инстансы обрабатывать в режиме "complete" (обби-эвристика, wave2-хендлеры). Minefield — только Leave.
	minigameAutoPlayInstanceIds = {
		"SpawnObby",
		"IceObby",
		"JungleObby",
		"PyramidObby",
		"HoverboardTechObby",
		"MillionaireRun",
		"Fishing",
		"AdvancedFishing",
		"FishingEvent",
		"Digsite",
		"AdvancedDigsite",
		"ChestRush",
	},
	minigameAllowQuestInstancesWhenComplete = true,
	minigameAssistTickInterval = 0.16,
	minigameStuckLeaveSeconds = 90,
	minigameObbyFinishSearchDepth = 26,
	minigameObbyFinishPartNames = { "Finish", "Reward", "Win", "Goal", "End" },
	minigameObbyPreferCheckpointFallback = true,
	minigameObbyTouchNearbyParts = true,
	minigameObbyFireChildPrompts = true,
	minigameWave2SearchDepth = 14,
	minigameWave2MaxPromptsPerTick = 8,
	--- Хэтч лучшего/зонного яйца, если нет валидной стрелки / скип цели — иначе только через квест
	autoHatchProgressWithoutQuest = true,
	--- Хэтч без валидной стрелки: не чаще раз в N сек (иначе при no_goal бот залипает только на яйцах)
	autoHatchProgressCooldown = 18,
	--- Если hatchBusy не сбросился после hold+grace — сбросить (застревание телепорта/фарма)
	hatchBusyWatchdogExtra = 10,
	--- Периодически экипировать лучших петов (PetCmds.EquipBest → Pets_EquipBest)
	autoEquipBestPetsEnabled = true,
	autoEquipBestPetsInterval = 14,
	--- true: не вызывать HatchingCmds.SetupEgg/AttemptHatch, а сразу Eggs_RequestPurchase / CustomEggs_Hatch (сервер всё равно может показать оверлей яйца).
	hideEggHatching = true,
	--- Жать «Click to open!» на оверлее открытия (PlayerGui), пока виден текст
	autoClickEggOpeningPrompt = true,
	eggOpeningPromptClickInterval = 0.32,
	--- При hideEggHatching — чаще жать оверлей (меньше задержка после Eggs_RequestPurchase)
	eggOpeningPromptIntervalHiddenHatch = 0.14,
	--- После скрытого инвока — короткие повторы клика (обход throttling одного кадра)
	eggOpeningPostInvokeBurstCount = 8,
	eggOpeningPostInvokeBurstDelay = 0.09,
	--- Если у надписи нет GuiButton — кликнуть мышью внизу экрана (как в игре часто ловится оверлей)
	--- Устарело: центр экрана через мышь не используется
	eggOpeningPromptCenterFallback = false,
	--- Минимум между обходами PlayerGui для «Click to open» (GetDescendants очень дорогой)
	eggOpeningGuiScanInterval = 0.22,
	--- Перед инвоками телепорт на машину / яйцо (сервер режет дистанцию)
	pivotBeforeRemotePurchases = true,
	machineSearchRadius = 2500,
	machineTeleportYOffset = 6,
	hatchTeleportNearEgg = true,
	hatchEggProximity = 36,
	hatchEggPivotYOffset = 8,
	--- После успешной покупки слота: закрыть вкладку, если TabController.Get() совпадает с машиной
	autoCloseMachineTabs = true,
	autoCloseTabDelay = 0.22,
	--- Если nil — используется список по умолчанию (имена как в AddOpenListener машин)
	autoCloseMachineTabIds = nil,
	autoCloseTabUseForce = false,
	--- Executor: после Activated — getconnections + firesignal на MouseButton1/2 (без мыши)
	executorGuiClickFallbacks = true,
	--- Квест Target: fireclickdetector / firetouchinterest (агрессивнее, по умолчанию выкл.)
	questUseFireClickDetector = false,
	questUseFireTouchInterest = false,
	--- Квесты перехода между мирами: в клиенте Interact → Message.New(OK?) → Network.Fire. fireProximityPrompt модалку не жмёт — дублируем Fire.
	questTravelWorldDirectNetwork = true,
	questTravelWorldDirectNetworkInterval = 2.6,
	--- RequestTechRocket: при Rebirths < 4 клиент ставит только гейт (см. Tech Rocket.lua). Отключите проверку только если уверены в Save.
	questTravelTechRequireRebirth4 = true,
	--- После forceClickBreakable — попытка fireclickdetector на модели
	farmUseFireClickDetectorFallback = false,
	--- Лог всех Network.Invoke через hookfunction (отладка)
	debugLogInvokes = false,
	--- Сервер закрывает сокет клиентскому скриптом этого не отменить. Часть античитов вызывает LocalPlayer:Kick() с локалки — см. kickGuardTryBlockClientKick (+ __namecall).
	kickGuardTryBlockClientKick = false,
	kickGuardKickLog = true,
	--- Устарело: синтетическая мышь отключена навсегда в этом скрипте (ключ не читается).
	executorVirtualGuiClick = false,
	--- Редкие события (успешный телепорт, клейм, хэтч)
	log = false,
	--- Подробная трассировка в консоль (F9): pulse, фарм, квест, ошибки
	verboseLog = true,
	traceInterval = 4,
	--- После успешной загрузки модулей — не вызывать ensureModules каждый Heartbeat. 0 = каждый кадр.
	ensureModulesInterval = 0.35,
	--- warn при падении heartbeat / runQuestAssistPulse / ensureModules
	heartbeatErrorWarn = true,
}

local G = (getgenv and getgenv()) or _G
G.AutoRank = G.AutoRank or {}
for k, v in pairs(DEFAULT) do
	if G.AutoRank[k] == nil then
		G.AutoRank[k] = v
	end
end

local function cfg()
	return G.AutoRank
end

local lastVerbosePulseTick = 0
local traceThrottleAt = {}

local function log(...)
	if cfg().log then
		print("[AutoRank]", ...)
	end
end

local function trace(cat, ...)
	if cfg().verboseLog then
		print("[AutoRank][" .. tostring(cat) .. "]", ...)
	end
end

local function traceThrottled(key, intervalSec, cat, ...)
	if not cfg().verboseLog then
		return
	end
	local now = tick()
	local iv = intervalSec or cfg().traceInterval or 4
	if now - (traceThrottleAt[key] or 0) < iv then
		return
	end
	traceThrottleAt[key] = now
	trace(cat, ...)
end

local function warnErr(where, err)
	local msg = "[AutoRank][ERR] " .. tostring(where) .. ": " .. tostring(err)
	if cfg().heartbeatErrorWarn ~= false then
		warn(msg)
	end
	if cfg().verboseLog and debug and debug.traceback then
		warn(debug.traceback(nil, 2))
	end
end

--- UNC / executor: единые точки входа + безопасный pcall.
local Exec = {}

local function execResolve(...)
	local env = G
	for _, name in ipairs({ ... }) do
		if type(name) == "function" then
			return name
		end
		local f = env[name] or (typeof(_G) == "table" and _G[name])
		if type(f) == "function" then
			return f
		end
	end
	return nil
end

function Exec.getconnections(signal)
	local gc = execResolve("getconnections")
	if not gc or not signal then
		return {}
	end
	local ok, res = pcall(gc, signal)
	if ok and type(res) == "table" then
		return res
	end
	return {}
end

function Exec.fireProximityPrompt(prompt)
	local fn = execResolve("fireproximityprompt", "FireProximityPrompt")
	if fn and prompt then
		local ok, err = pcall(fn, prompt)
		if not ok and cfg().log then
			log("Exec.fireProximityPrompt err", err)
		end
	end
end

function Exec.fireClickDetector(detector, dist)
	local fn = execResolve("fireclickdetector", "FireClickDetector")
	if fn and detector then
		pcall(fn, detector, dist or 0)
	end
end

function Exec.fireTouchInterest(part, touchPart, toggle)
	local fn = execResolve("firetouchinterest", "FireTouchInterest")
	if fn and part and touchPart then
		pcall(fn, part, touchPart, toggle or 0)
	end
end

local function runRBXScriptConnections(signal)
	local fired = false
	for _, conn in ipairs(Exec.getconnections(signal)) do
		if conn.Function then
			pcall(conn.Function)
			fired = true
		end
	end
	return fired
end

--- firesignal / FireSignal (UNC) — без движения системной/игровой мыши.
local function execFireRBXScriptSignal(signal)
	if not signal then
		return false
	end
	local fs = execResolve("firesignal", "FireSignal")
	if not fs then
		return false
	end
	local ok = pcall(fs, signal)
	return ok
end

--- Activated → firesignal(Activated) → (опц.) MouseButton1/2 через getconnections + firesignal. Синтетическая мышь не используется.
local function clickGuiButtonRobust(btn)
	if not btn or not btn:IsA("GuiButton") then
		return false
	end
	if runRBXScriptConnections(btn.Activated) then
		return true
	end
	if execFireRBXScriptSignal(btn.Activated) then
		return true
	end
	if cfg().executorGuiClickFallbacks then
		if runRBXScriptConnections(btn.MouseButton1Click) then
			return true
		end
		if execFireRBXScriptSignal(btn.MouseButton1Click) then
			return true
		end
		if runRBXScriptConnections(btn.MouseButton2Click) then
			return true
		end
		if execFireRBXScriptSignal(btn.MouseButton2Click) then
			return true
		end
	end
	return false
end

--- PS99 Egg Opening Frontend: ожидание «Click to open!» висит на LocalPlayer.Mouse.Button1Down (+ геймпад), не на GuiButton.
local function tryFireEggOpenPrimaryInput()
	local mouse = LocalPlayer:GetMouse()
	if not mouse then
		return false
	end
	if runRBXScriptConnections(mouse.Button1Down) then
		return true
	end
	return execFireRBXScriptSignal(mouse.Button1Down) == true
end

local function eggOpeningTextScanRoots()
	local roots = {}
	local pg = LocalPlayer:FindFirstChild("PlayerGui")
	if pg then
		table.insert(roots, pg)
	end
	local cam = workspace.CurrentCamera
	if cam then
		table.insert(roots, cam)
	end
	return roots
end

local ClientFolder = ReplicatedStorage:WaitForChild("Library"):WaitForChild("Client", 30)

local Network, BreakableFrontend, Save, RankCmds, MapCmds, InstancingCmds, GUI, Directory, RanksUtil, FFlags
local ZoneCmds, TeleportMapCmds, CurrencyCmds, Balancing, RebirthCmds, InstanceZoneCmds
local GoalCmds, Functions, Variables, TabController, InventoryCmds
local HatchingCmds, EggCmds, HatchingTypes, PotionCmds, FruitCmds, EggsUtil
local EnchantCmds
local ZonesUtil
local PetEquipCmds, PetCmds, MachineCmds, UpgradeCmds
local Gamepasses, CustomEggsCmds
local DaycareCmds, DaycareLoot
local FlexibleFlagCmds
local MasteryCmds, ConsumableCmds

local function ensureModules()
	if not ClientFolder then
		return false
	end
	local ok, err = pcall(function()
		local Client = ClientFolder
		Network = Network or require(Client:WaitForChild("Network"))
		BreakableFrontend = BreakableFrontend or require(Client:WaitForChild("BreakableFrontend"))
		Save = Save or require(Client:WaitForChild("Save"))
		RankCmds = RankCmds or require(Client:WaitForChild("RankCmds"))
		MapCmds = MapCmds or require(Client:WaitForChild("MapCmds"))
		InstancingCmds = InstancingCmds or require(Client:WaitForChild("InstancingCmds"))
		GUI = GUI or require(Client:WaitForChild("GUI"))
		local Lib = ReplicatedStorage.Library
		Directory = Directory or require(Lib:WaitForChild("Directory"))
		RanksUtil = RanksUtil or require(Lib.Util:WaitForChild("RanksUtil"))
		FFlags = FFlags or require(Client:WaitForChild("FFlags"))
		ZoneCmds = ZoneCmds or require(Client:WaitForChild("ZoneCmds"))
		TeleportMapCmds = TeleportMapCmds or require(Client:WaitForChild("TeleportMapCmds"))
		CurrencyCmds = CurrencyCmds or require(Client:WaitForChild("CurrencyCmds"))
		Balancing = Balancing or require(ReplicatedStorage.Library:WaitForChild("Balancing"))
		RebirthCmds = RebirthCmds or require(Client:WaitForChild("RebirthCmds"))
		InstanceZoneCmds = InstanceZoneCmds or require(Client:WaitForChild("InstanceZoneCmds"))
		GoalCmds = GoalCmds or require(Client:WaitForChild("GoalCmds"))
		Functions = Functions or require(ReplicatedStorage.Library:WaitForChild("Functions"))
		Variables = Variables or require(ReplicatedStorage.Library:WaitForChild("Variables"))
		TabController = TabController or require(Client:WaitForChild("TabController"))
		InventoryCmds = InventoryCmds or require(Client:WaitForChild("InventoryCmds"))
		HatchingCmds = HatchingCmds or require(Client:WaitForChild("HatchingCmds"))
		EggCmds = EggCmds or require(Client:WaitForChild("EggCmds"))
		HatchingTypes = HatchingTypes or require(ReplicatedStorage.Library.Types:WaitForChild("Hatching"))
		PotionCmds = PotionCmds or require(Client:WaitForChild("PotionCmds"))
		FruitCmds = FruitCmds or require(Client:WaitForChild("FruitCmds"))
		EggsUtil = EggsUtil or require(ReplicatedStorage.Library.Util:WaitForChild("EggsUtil"))
		EnchantCmds = EnchantCmds or require(Client:WaitForChild("EnchantCmds"))
		ZonesUtil = ZonesUtil or require(ReplicatedStorage.Library.Util:WaitForChild("ZonesUtil"))
		PetEquipCmds = PetEquipCmds or require(Client:WaitForChild("PetEquipCmds"))
		PetCmds = PetCmds or require(Client:WaitForChild("PetCmds"))
		MachineCmds = MachineCmds or require(Client:WaitForChild("MachineCmds"))
		UpgradeCmds = UpgradeCmds or require(Client:WaitForChild("UpgradeCmds"))
		Gamepasses = Gamepasses or require(Client:WaitForChild("Gamepasses"))
		CustomEggsCmds = CustomEggsCmds or require(Client:WaitForChild("CustomEggsCmds"))
		DaycareCmds = DaycareCmds or require(Client:WaitForChild("DaycareCmds"))
		FlexibleFlagCmds = FlexibleFlagCmds or require(Client:WaitForChild("FlexibleFlagCmds"))
		MasteryCmds = MasteryCmds or require(Client:WaitForChild("MasteryCmds"))
		ConsumableCmds = ConsumableCmds or require(Client:WaitForChild("ConsumableCmds"))
	end)
	if not ok then
		warnErr("ensureModules", err)
	end
	return ok
end

local lastEnsureModulesHeartbeatTick = 0
local ensureModulesCachedOk = false

--- Полный require-модулей тяжёлый даже с or require; раз в интервал достаточно после первой загрузки.
local function ensureModulesOnHeartbeat()
	local iv = cfg().ensureModulesInterval
	if type(iv) ~= "number" or iv <= 0 then
		local ok = ensureModules()
		ensureModulesCachedOk = ok
		return ok
	end
	local now = tick()
	if ensureModulesCachedOk and (now - lastEnsureModulesHeartbeatTick) < iv then
		return true
	end
	lastEnsureModulesHeartbeatTick = now
	local ok = ensureModules()
	ensureModulesCachedOk = ok
	return ok
end

local lastDamageTick = 0
local currentFocusUid = nil
local orbAccumulator = {}
local lastOrbSend = 0
local lastOrbAccumPruneTick = 0
local orbNetHooked = false
local orbMagnetPatched = false
local networkInvokeHookInstalled = false
local networkInvokeOriginal = nil
local lastClaimTick = 0
local lastRankUpGuiTick = 0
local lastZonePurchaseTick = 0
local lastTeleportTick = 0
local lastTravelWorldDirectNetworkTick = 0
local lastTravelTechRebirthWarnTick = 0
local lastReturnAreaGuiTick = 0
local lastQuestPickTick = 0
local lastQuestHatchTick = 0
local lastProgressOnlyHatchTick = 0
local lastPotionConsumeTick = 0
local lastFruitConsumeTick = 0
local lastConsumableConsumeTick = 0
local lastQuestGuiClickTick = 0
local lastEnchantEquipTick = 0
local lastEggOpeningPromptTick = 0
local lastEggOpeningGuiScanTick = 0
local lastAutoEquipBestTick = 0
local lastMinigameAssistTick = 0
local minigameSessionInstanceId = nil
local minigameSessionStartTick = 0
local cachedTrackedObjective = nil
local lastFarmCenterTick = 0
local lastEquipSlotTick = 0
local lastEggSlotTick = 0
local lastUpgradePurchaseTick = 0
local lastDaycareTick = 0
local lastRebirthDismissTick = 0
local lastQuestFlagTick = 0
--- Пока true — не дергаем телепорт на макс. зону, не тянем в центр брейков и не шлём урон (HeartBeat может продолжаться во время task.wait хэтча).
local hatchBusy = false
local hatchBusyArmedAt = 0

local function armHatchBusyEnd(delaySec)
	hatchBusy = true
	hatchBusyArmedAt = tick()
	local d = delaySec or cfg().hatchBusyHoldSeconds or 2.6
	task.delay(d, function()
		hatchBusy = false
		hatchBusyArmedAt = 0
	end)
end

local function tryHatchBusyWatchdog()
	if not hatchBusy or hatchBusyArmedAt <= 0 then
		return
	end
	if cfg().hatchBusyWatchdogExtra == false then
		return
	end
	local grace = cfg().hatchBusyWatchdogExtra
	if type(grace) ~= "number" or grace < 0 then
		grace = 8
	end
	local limit = (cfg().hatchBusyHoldSeconds or 2.6) + grace
	if tick() - hatchBusyArmedAt <= limit then
		return
	end
	hatchBusy = false
	hatchBusyArmedAt = 0
	traceThrottled("hatchBusyWatchdog", 6, "pulse", "hatchBusy watchdog cleared after", limit, "s")
end

local AUTO_RANK_RUNTIME_VERSION = 3
local AutoRankRuntimeState = {
	version = AUTO_RANK_RUNTIME_VERSION,
	connections = {},
	heartbeatConn = nil,
	diagFarm = {},
	diagQuest = {},
	diagTeleport = {},
	diagGoalPick = {},
	--- Кэш фарма + туториал-троттлинг (в чанке отдельными local — упираемся в лимит 200 регистров Luau)
	farmCandidateCache = { list = nil, at = -1e9, diag = nil },
	lastTutorialArrowTick = 0,
}

local function autoRankDisconnectAll()
	for _, c in ipairs(AutoRankRuntimeState.connections) do
		pcall(function()
			if c and c.Disconnect then
				c:Disconnect()
			end
		end)
	end
	table.clear(AutoRankRuntimeState.connections)
	if AutoRankRuntimeState.heartbeatConn then
		pcall(function()
			AutoRankRuntimeState.heartbeatConn:Disconnect()
		end)
		AutoRankRuntimeState.heartbeatConn = nil
	end
	orbNetHooked = false
	hatchBusy = false
	hatchBusyArmedAt = 0
	ensureModulesCachedOk = false
	lastEnsureModulesHeartbeatTick = 0
	local fc = AutoRankRuntimeState.farmCandidateCache
	fc.list = nil
	fc.diag = nil
	fc.at = -1e9
end

local function autoRankRegisterConn(conn)
	if conn and conn.Disconnect then
		table.insert(AutoRankRuntimeState.connections, conn)
	end
	return conn
end

do
	local prev = G.AutoRankRuntime
	if prev and type(prev.disconnectAll) == "function" then
		pcall(prev.disconnectAll)
	end
	AutoRankRuntimeState.disconnectAll = autoRankDisconnectAll
	G.AutoRankRuntime = AutoRankRuntimeState
	G.AutoRankUnload = function()
		autoRankDisconnectAll()
	end
end

local DEFAULT_AUTOCLOSE_MACHINE_TAB_IDS = { "EggSlotsMachine", "EquipSlotsMachine", "InfinityEggMachine" }

local function tryCloseMachineTabIfConfigured()
	if not cfg().autoCloseMachineTabs then
		return
	end
	local delaySec = cfg().autoCloseTabDelay or 0
	task.delay(delaySec, function()
		pcall(function()
			if not TabController or not TabController.Get or not TabController.CloseTab then
				return
			end
			local cur = TabController.Get()
			local list = cfg().autoCloseMachineTabIds
			if type(list) ~= "table" then
				list = DEFAULT_AUTOCLOSE_MACHINE_TAB_IDS
			end
			for _, id in ipairs(list) do
				if cur == id then
					TabController.CloseTab(cfg().autoCloseTabUseForce == true and true or nil)
					break
				end
			end
		end)
	end)
end

local QUEST_TAB_BLOCKS = {
	ExclusiveShop = true,
	StarterpackDeal = true,
}

local function stabilizeCharacterPhysics(ch)
	if not ch then
		return
	end
	local hrp = ch:FindFirstChild("HumanoidRootPart")
	local hum = ch:FindFirstChildOfClass("Humanoid")
	if hrp and hrp:IsA("BasePart") then
		pcall(function()
			hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
			hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
		end)
	end
	if hum then
		pcall(function()
			hum.PlatformStand = false
		end)
	end
end

local function pivotCharacterToCFrame(targetCf)
	local ch = LocalPlayer.Character
	local pp = ch and ch.PrimaryPart
	if not ch or not pp or not targetCf then
		return false
	end
	pcall(function()
		ch:PivotTo(targetCf)
	end)
	stabilizeCharacterPhysics(ch)
	return true
end

local function pivotNearEquipSlotsMachine()
	if not cfg().pivotBeforeRemotePurchases or not MachineCmds then
		return false
	end
	local ch = LocalPlayer.Character
	local pp = ch and ch.PrimaryPart
	if not pp then
		return false
	end
	local radius = cfg().machineSearchRadius or 2500
	local yOff = cfg().machineTeleportYOffset or 6
	local entry = nil
	pcall(function()
		entry = MachineCmds.GetClosestMachine("EquipSlotsMachine", pp.Position, radius)
	end)
	if not entry or not entry.Model then
		return false
	end
	local m = entry.Model
	local pivotPart = m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart", true)
	if not pivotPart then
		return false
	end
	local prox = cfg().hatchEggProximity or 36
	if (pp.Position - pivotPart.Position).Magnitude <= prox + 12 then
		return true
	end
	local cf = pivotPart.CFrame * CFrame.new(0, yOff, 0)
	return pivotCharacterToCFrame(cf)
end

--- Клиент Infinity Egg останавливает автохэтч при > ~40 studs от Center — подтягиваем к ближайшему стенду.
local function pivotNearestInfinityEggStand()
	if not cfg().pivotBeforeRemotePurchases or not cfg().hatchTeleportNearEgg then
		return false
	end
	local ch = LocalPlayer.Character
	local pp = ch and ch.PrimaryPart
	if not pp then
		return false
	end
	local maxDist = cfg().hatchEggProximity or 36
	local yOff = cfg().hatchEggPivotYOffset or 8
	local best, bestMag = nil, math.huge
	for _, inst in ipairs(CollectionService:GetTagged("InfinityEgg")) do
		if inst:IsA("Model") then
			local center = inst:FindFirstChild("Center")
			if center and center:IsA("BasePart") then
				local d = (center.Position - pp.Position).Magnitude
				if d < bestMag then
					bestMag = d
					best = center
				end
			end
		end
	end
	if not best then
		return false
	end
	if bestMag <= maxDist then
		return true
	end
	return pivotCharacterToCFrame(best.CFrame * CFrame.new(0, yOff, 0))
end

local function fflagPetSlotsOk()
	if not FFlags then
		return true
	end
	local ok = true
	pcall(function()
		ok = FFlags.Get(FFlags.Keys.PetSlotsMachine) or FFlags.CanBypass()
	end)
	return ok
end

local function fflagUpgradesOk()
	if not FFlags then
		return true
	end
	local ok = true
	pcall(function()
		ok = FFlags.Get(FFlags.Keys.Upgrades) or FFlags.CanBypass()
	end)
	return ok
end

--- Зеркало Egg Slots Machine: generateBundles / GetStatus / стоимость бандла алмазами.
local EggSlots = {}

function EggSlots.generateBundles(rankEntry)
	if not rankEntry or not RankCmds then
		return {}
	end
	local before = 0
	pcall(function()
		before = RankCmds.GetEggSlotsBeforeRank(rankEntry.RankNumber) or 0
	end)
	local unlockable = tonumber(rankEntry.UnlockableEggSlots) or 0
	local bundles = {}
	for idx = 1, unlockable do
		local overallIdx = before + idx
		local bundleEnd, bundleSize, prevEnd = nil, nil, nil
		pcall(function()
			bundleEnd, bundleSize, prevEnd = RankCmds.GetEggBundle(overallIdx)
		end)
		if bundleEnd ~= nil then
			local dup = false
			for _, ex in ipairs(bundles) do
				if ex.BundleEnd == bundleEnd then
					dup = true
					break
				end
			end
			if not dup then
				table.insert(bundles, {
					BundleEnd = bundleEnd,
					BundleSize = bundleSize or 1,
					PreviousBundleEnd = prevEnd,
					OverallIdx = overallIdx,
				})
			end
		end
	end
	return bundles
end

function EggSlots.iterateRankEntriesSorted()
	local list = {}
	if not Directory or not Directory.Ranks then
		return list
	end
	for _, rankEntry in pairs(Directory.Ranks) do
		if rankEntry and type(rankEntry.RankNumber) == "number" then
			table.insert(list, rankEntry)
		end
	end
	table.sort(list, function(a, b)
		return (a.RankNumber or 0) < (b.RankNumber or 0)
	end)
	return list
end

function EggSlots.bundleStatus(bundleEnd)
	if not Save or not RankCmds or not RanksUtil then
		return "LOCKED"
	end
	local save = Save.Get()
	if not save then
		return "LOCKED"
	end
	local geBundle, _bundleSize, prevEnd = nil, nil, nil
	pcall(function()
		geBundle, _bundleSize, prevEnd = RankCmds.GetEggBundle(bundleEnd)
	end)
	if geBundle == nil then
		return "LOCKED"
	end
	pcall(function()
		if Gamepasses and Gamepasses.Owns then
			Gamepasses.Owns("15 Extra Eggs")
		end
	end)
	local maxPurch = 0
	pcall(function()
		maxPurch = RankCmds.GetMaxPurchasableEggSlots() or 0
	end)
	pcall(function()
		RanksUtil.GetMaxEggSlots()
	end)
	local purchased = save.EggSlotsPurchased or 0
	-- Как Egg Slots Machine v5_upvr (дистрибутив Studio): одинаковые приоритеты and/or
	return geBundle <= purchased and "PURCHASED"
		or (
			(geBundle == 1 or (purchased == prevEnd and geBundle <= maxPurch)) and "NEXT"
			or (geBundle <= maxPurch and "UNLOCKED" or "LOCKED")
		)
end

function EggSlots.bundleDiamondCost(bundle)
	if not bundle or not Balancing then
		return 0
	end
	local bundleEnd = bundle.BundleEnd
	local bundleSize = bundle.BundleSize or 1
	local startSlot = bundleEnd - bundleSize
	local total = 0
	for i = 1, bundleSize do
		local p = 0
		pcall(function()
			p = Balancing.CalcEggSlotPrice(startSlot + i) or 0
		end)
		total += p
	end
	return total
end

function EggSlots.findNextPurchasableBundle()
	if not Directory or not RankCmds then
		return nil
	end
	local candNext = {}
	local candUnlocked = {}
	local tryUnlocked = cfg().eggSlotPurchaseTryUnlocked ~= false
	for _, rankEntry in ipairs(EggSlots.iterateRankEntriesSorted()) do
		for _, b in ipairs(EggSlots.generateBundles(rankEntry)) do
			local st = EggSlots.bundleStatus(b.BundleEnd)
			if st == "NEXT" then
				table.insert(candNext, b)
			elseif tryUnlocked and st == "UNLOCKED" then
				table.insert(candUnlocked, b)
			end
		end
	end
	local function byEnd(a, b)
		return (a.BundleEnd or 0) < (b.BundleEnd or 0)
	end
	table.sort(candNext, byEnd)
	if candNext[1] then
		return candNext[1]
	end
	table.sort(candUnlocked, byEnd)
	return candUnlocked[1]
end

local function fflagEggSlotsOk()
	if not FFlags then
		return true
	end
	local ok = true
	pcall(function()
		ok = FFlags.Get(FFlags.Keys.EggSlotsMachine) or FFlags.CanBypass()
	end)
	return ok
end

local function pivotNearEggSlotsMachine()
	if not cfg().pivotBeforeRemotePurchases or not MachineCmds then
		return false
	end
	local ch = LocalPlayer.Character
	local pp = ch and ch.PrimaryPart
	if not pp then
		return false
	end
	local radius = cfg().machineSearchRadius or 2500
	local yOff = cfg().machineTeleportYOffset or 6
	local entry = nil
	pcall(function()
		entry = MachineCmds.GetClosestMachine("EggSlotsMachine", pp.Position, radius)
	end)
	if not entry or not entry.Model then
		return false
	end
	local m = entry.Model
	local pivotPart = m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart", true)
	if not pivotPart then
		return false
	end
	local prox = cfg().hatchEggProximity or 36
	if (pp.Position - pivotPart.Position).Magnitude <= prox + 12 then
		return true
	end
	local cf = pivotPart.CFrame * CFrame.new(0, yOff, 0)
	return pivotCharacterToCFrame(cf)
end

local function tryAutoBuyEggSlots()
	if not cfg().autoBuyEggSlots or not Network or not CurrencyCmds or not Directory or not RankCmds then
		return
	end
	local okIn, inInst = pcall(function()
		return InstancingCmds and InstancingCmds.IsInInstance and InstancingCmds.IsInInstance()
	end)
	if okIn and inInst then
		return
	end
	local now = tick()
	if now - lastEggSlotTick < (cfg().eggSlotPurchaseInterval or 1) then
		return
	end
	if not fflagEggSlotsOk() then
		return
	end
	local maxPulse = math.max(1, cfg().eggSlotMaxPurchasesPerPulse or 1)
	for _ = 1, maxPulse do
		local bundle = EggSlots.findNextPurchasableBundle()
		if not bundle then
			break
		end
		local totalCost = EggSlots.bundleDiamondCost(bundle)
		local afford = false
		pcall(function()
			afford = CurrencyCmds.CanAfford("Diamonds", totalCost)
		end)
		if not afford then
			break
		end
		lastEggSlotTick = now
		pivotNearEggSlotsMachine()
		local invOk = false
		local errMsg = nil
		pcall(function()
			local r, e = Network.Invoke("EggHatchSlotsMachine_RequestPurchase", bundle.BundleEnd)
			invOk = r ~= false and r ~= nil
			errMsg = e
		end)
		log("EggHatchSlotsMachine_RequestPurchase", bundle.BundleEnd, totalCost, invOk, errMsg)
		if invOk then
			tryCloseMachineTabIfConfigured()
		end
		if not invOk then
			break
		end
	end
end

local function tryAutoBuyEquipSlots()
	if not cfg().autoBuyEquipSlots or not Network or not PetEquipCmds or not RankCmds or not CurrencyCmds then
		return
	end
	local okIn, inInst = pcall(function()
		return InstancingCmds and InstancingCmds.IsInInstance and InstancingCmds.IsInInstance()
	end)
	if okIn and inInst then
		return
	end
	local now = tick()
	if now - lastEquipSlotTick < (cfg().equipSlotPurchaseInterval or 1) then
		return
	end
	if not fflagPetSlotsOk() then
		return
	end
	local maxBuy = 0
	pcall(function()
		maxBuy = RankCmds.GetMaxPurchasableEquipSlots() or 0
	end)
	if maxBuy <= 0 then
		return
	end
	local maxPulse = math.max(1, cfg().equipSlotMaxPurchasesPerPulse or 1)
	for _ = 1, maxPulse do
		local targetSlot = nil
		for slot = 1, maxBuy do
			local st = nil
			pcall(function()
				st = PetEquipCmds.GetStatus(slot)
			end)
			if st == "NEXT" then
				targetSlot = slot
				break
			end
		end
		if not targetSlot then
			break
		end
		local price = 0
		if Balancing and type(Balancing.CalcPetSlotPrice) == "function" then
			pcall(function()
				price = Balancing.CalcPetSlotPrice(targetSlot) or 0
			end)
		end
		if price > 0 then
			local afford = false
			pcall(function()
				afford = CurrencyCmds.CanAfford("Diamonds", price)
			end)
			if not afford then
				break
			end
		end
		lastEquipSlotTick = now
		pivotNearEquipSlotsMachine()
		local invOk = false
		local errMsg = nil
		pcall(function()
			local r, e = Network.Invoke("EquipSlotsMachine_RequestPurchase", targetSlot)
			invOk = r ~= false and r ~= nil
			errMsg = e
		end)
		log("EquipSlotsMachine_RequestPurchase", targetSlot, invOk, errMsg)
		if invOk then
			tryCloseMachineTabIfConfigured()
		else
			break
		end
	end
end

local function tryAutoBuyCheapestUpgrade()
	if not cfg().autoBuyCheapestUpgrade or not UpgradeCmds or not CurrencyCmds or not Directory then
		return
	end
	local okIn, inInst = pcall(function()
		return InstancingCmds and InstancingCmds.IsInInstance and InstancingCmds.IsInInstance()
	end)
	if okIn and inInst then
		return
	end
	local now = tick()
	if now - lastUpgradePurchaseTick < (cfg().upgradePurchaseInterval or 1.5) then
		return
	end
	if not fflagUpgradesOk() then
		return
	end
	local list = {}
	pcall(function()
		list = UpgradeCmds.All()
	end)
	if type(list) ~= "table" then
		return
	end
	local bestU, bestCost = nil, math.huge
	for _, u in ipairs(list) do
		if u and u.UpgradeID and u.ZoneID then
			local can = false
			pcall(function()
				can = UpgradeCmds.CanInteractWith(u.UpgradeID, u.ZoneID)
			end)
			if can then
				local def = Directory.Upgrades[u.UpgradeID]
				local tier = u.UpgradeTier
				if def and tier and def.TierCosts and def.TierCosts[tier] and def.TierCurrencies and def.TierCurrencies[tier] then
					local cost = def.TierCosts[tier]
					local cid = def.TierCurrencies[tier]._id
					local bal = 0
					pcall(function()
						bal = CurrencyCmds.Get(cid) or 0
					end)
					if bal >= cost and cost < bestCost then
						bestCost = cost
						bestU = u
					end
				end
			end
		end
	end
	if not bestU or not bestU.Model then
		return
	end
	lastUpgradePurchaseTick = now
	if cfg().pivotBeforeRemotePurchases then
		local m = bestU.Model
		local pivotPart = m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart", true)
		local ch = LocalPlayer.Character
		local pp = ch and ch.PrimaryPart
		if pivotPart and pp and (pp.Position - pivotPart.Position).Magnitude > (cfg().hatchEggProximity or 36) then
			local yOff = cfg().machineTeleportYOffset or 6
			pivotCharacterToCFrame(pivotPart.CFrame * CFrame.new(0, yOff, 0))
		end
	end
	local okPurch = false
	pcall(function()
		local r = UpgradeCmds.Purchase(bestU.UpgradeID, bestU.ZoneID)
		okPurch = r ~= false and r ~= nil
	end)
	log("UpgradeCmds.Purchase", bestU.UpgradeID, bestU.ZoneID, okPurch)
end

local function canEnrollPetData(data)
	if not data or not Directory or type(data.id) ~= "string" then return false end
	local def = Directory.Pets[data.id]
	if not def then return false end
	
	if def.huge or def.titanic or (def.exclusiveLevel and def.exclusiveLevel > 0) then
		return false
	end
	if def.ugc then
		return false
	end
	return true
end

local function tryAutoDaycare()
	if not cfg().autoDaycare or not DaycareCmds then return end
	local okIn, inInst = pcall(function() return InstancingCmds.IsInInstance() end)
	if okIn and inInst then return end
	
	local now = tick()
	if now - lastDaycareTick < (cfg().autoDaycareInterval or 5) then return end
	
	local active = nil
	pcall(function() active = DaycareCmds.GetActive() end)
	if type(active) == "table" then
		for uid, _ in pairs(active) do
			local remaining = math.huge
			pcall(function() remaining = DaycareCmds.ComputeRemainingTime(uid) end)
			if remaining <= 0 then
				lastDaycareTick = now
				pcall(function() DaycareCmds.Claim(uid) end)
				log("Daycare Claimed", uid)
			end
		end
	end
	
	local used, max = 0, 0
	pcall(function()
		used = DaycareCmds.GetUsedSlots()
		max = DaycareCmds.GetMaxSlots()
	end)
	
	local slotsLeft = max - used
	if slotsLeft > 0 then
		local s = Save and Save.Get and Save.Get()
		if s and s.Inventory and s.Inventory.Pet then
			local toEnroll = {}
			local count = 0
			
			for uid, data in pairs(s.Inventory.Pet) do
				if not data._lk then
					local isEquipped = false
					if s.EquippedPets and s.EquippedPets[uid] then
						isEquipped = true
					end
					if not isEquipped then
						if canEnrollPetData(data) then
							toEnroll[uid] = 1
							count = count + 1
							if count >= slotsLeft then break end
						end
					end
				end
			end
			if count > 0 then
				lastDaycareTick = now
				local ok = false
				pcall(function() 
					local res = DaycareCmds.Enroll(toEnroll) 
					ok = res ~= false and res ~= nil
				end)
				log("Daycare Enrolled", count, "pets", ok)
			end
		end
	end
end

local function harvestOrbIds()
	local ids = {}
	local n = 0
	local cap = cfg().maxOrbBatch or 80
	for k in pairs(orbAccumulator) do
		n += 1
		if n > cap then
			break
		end
		table.insert(ids, k)
	end
	return ids
end

local function tryCollectOrbs()
	if not cfg().orbRemoteCollectBatch or not cfg().collectOrbs or not Network then
		return
	end
	local now = tick()
	if now - lastOrbSend < (cfg().orbCollectInterval or 0.35) then
		return
	end
	local ids = harvestOrbIds()
	if #ids == 0 then
		return
	end
	lastOrbSend = now
	pcall(function()
		Network.Fire("Orbs: Collect", ids)
	end)
	for _, id in ipairs(ids) do
		orbAccumulator[id] = nil
	end
end

local function accumulateOrbBatch(batch)
	if type(batch) ~= "table" then
		return
	end
	if batch.id ~= nil then
		orbAccumulator[tostring(batch.id)] = true
		return
	end
	for _, item in ipairs(batch) do
		if type(item) == "table" and item.id ~= nil then
			orbAccumulator[tostring(item.id)] = true
		end
	end
	local cap = cfg().orbAccumulatorMaxKeys
	if type(cap) == "number" and cap > 0 then
		local now = tick()
		if now - lastOrbAccumPruneTick >= 1.25 then
			lastOrbAccumPruneTick = now
			local n = 0
			for _ in pairs(orbAccumulator) do
				n += 1
			end
			if n > cap then
				for k in pairs(orbAccumulator) do
					orbAccumulator[k] = nil
				end
			end
		end
	end
end

local function patchOrbMagnet()
	if orbMagnetPatched or not cfg().collectOrbs or cfg().orbMagnetBoost == false or not ClientFolder then
		return
	end
	local ok, orbMod = pcall(function()
		require(ClientFolder:WaitForChild("OrbCmds"))
		return require(ClientFolder:WaitForChild("OrbCmds"):WaitForChild("Orb"))
	end)
	if not ok or type(orbMod) ~= "table" then
		return
	end
	local minD = cfg().orbMagnetMinDistance or 800
	if cfg().advancedRemoteFarm then
		local om = tonumber(cfg().remoteFarmOrbMagnetMultiplier) or 1.45
		if om > 1 then
			minD = minD * om
		end
	end
	for _, key in ipairs({ "CollectDistance", "DefaultPickupDistance", "CombineDistance" }) do
		local cur = rawget(orbMod, key)
		if type(cur) == "number" then
			rawset(orbMod, key, math.max(cur, minD))
		else
			rawset(orbMod, key, minD)
		end
	end
	orbMagnetPatched = true
end

local function tryInstallNetworkInvokeDebugHook()
	if networkInvokeHookInstalled or not cfg().debugLogInvokes then
		return
	end
	if not Network or type(Network.Invoke) ~= "function" then
		return
	end
	local hf = execResolve("hookfunction", "replaceclosure")
	if not hf then
		return
	end
	local ok, err = pcall(function()
		networkInvokeOriginal = hf(Network.Invoke, function(...)
			local pack = { ... }
			log("[Invoke]", tostring(pack[1]))
			return networkInvokeOriginal(table.unpack(pack))
		end)
	end)
	if ok then
		networkInvokeHookInstalled = true
	elseif cfg().log then
		log("debugLogInvokes hook failed", err)
	end
end

--- Блок только клиентских путей (Kick / __namecall). Сервер закрыл соединение — скриптом не восстановить.
local kickGuardKickOrig = nil
local kickGuardKickProbeDone = false
local kickGuardNamecallProbeDone = false

local function tryInstallKickGuard()
	if cfg().kickGuardTryBlockClientKick ~= true then
		return
	end
	local lp = Players.LocalPlayer
	if not lp then
		return
	end
	local hf = execResolve("hookfunction", "replaceclosure")
	if hf and not kickGuardKickProbeDone then
		kickGuardKickProbeDone = true
		local fk = lp.Kick
		if type(fk) == "function" then
			local ok, err = pcall(function()
				local ncMaker = execResolve("newcclosure")
				local function replacement(self, ...)
					if cfg().kickGuardTryBlockClientKick ~= true then
						if type(kickGuardKickOrig) == "function" then
							return kickGuardKickOrig(self, ...)
						end
						return nil
					end
					if self ~= lp then
						if type(kickGuardKickOrig) == "function" then
							return kickGuardKickOrig(self, ...)
						end
						return nil
					end
					if cfg().kickGuardKickLog then
						traceThrottled("kick_guard_kick_fn", 2, "kick_guard", "blocked Kick()", ...)
					end
					return nil
				end
				local rep = replacement
				if ncMaker and type(ncMaker) == "function" then
					rep = ncMaker(replacement)
				end
				kickGuardKickOrig = hf(fk, rep)
			end)
			if not ok and cfg().verboseLog then
				trace("kick_guard", "Kick hf failed", err)
			end
		end
	end
	if kickGuardNamecallProbeDone then
		return
	end
	local gsm = execResolve("getnamecallmethod")
	local grm = execResolve("getrawmetatable")
	local sor = execResolve("setreadonly")
	local ncMaker = execResolve("newcclosure")
	if not (gsm and grm and sor and ncMaker) then
		kickGuardNamecallProbeDone = true
		return
	end
	kickGuardNamecallProbeDone = true
	local okNc, errNc = pcall(function()
		local mt = grm(game)
		if type(mt) ~= "table" or type(mt.__namecall) ~= "function" then
			return
		end
		sor(mt, false)
		local innerOk, innerErr = pcall(function()
			local old = mt.__namecall
			local function hooked(self, ...)
				if cfg().kickGuardTryBlockClientKick ~= true then
					return old(self, ...)
				end
				if gsm() == "Kick" and self == lp then
					if cfg().kickGuardKickLog then
						traceThrottled("kick_guard_nc", 2, "kick_guard", "blocked namecall Kick")
					end
					return nil
				end
				return old(self, ...)
			end
			mt.__namecall = ncMaker(hooked)
		end)
		sor(mt, true)
		if not innerOk and cfg().verboseLog then
			trace("kick_guard", "__namecall assign failed", innerErr)
		end
	end)
	if not okNc and cfg().verboseLog then
		trace("kick_guard", "__namecall hook failed", errNc)
	end
end

--- При переходе в другой Experience (TeleportService на другой PlaceId) память клиента новая — инжект не переносится. UNC queue_on_teleport запускает тот же .lua заново по URL/readfile.
local crossPlaceQueueRegistered = false

local function tryRegisterCrossPlaceScriptReload()
	if crossPlaceQueueRegistered or cfg().crossPlaceAutoReload ~= true then
		return
	end
	local q = execResolve("queue_on_teleport", "syn.queue_on_teleport", "queueonteleport", "QueueOnTeleport")
	if type(q) ~= "function" then
		traceThrottled("cross_place_no_queue", 45, "cross_place", "queue_on_teleport не найден (добавь UNC в экзекьютор)")
		return
	end
	local url = cfg().crossPlaceReloadUrl
	local path = cfg().crossPlaceReloadReadfile
	local delay = tonumber(cfg().crossPlaceReloadDelaySec) or 3
	if delay < 0 then
		delay = 0
	end
	local innerExec
	if type(url) == "string" and string.match(url, "^https?://") then
		innerExec = "loadstring(game:HttpGet(" .. string.format("%q", url) .. ", true))()"
	elseif type(path) == "string" and #path > 0 then
		if not execResolve("readfile") then
			trace("cross_place", "crossPlaceReloadReadfile задан, но readfile() недоступен")
			return
		end
		innerExec = "loadstring(readfile(" .. string.format("%q", path) .. "))()"
	else
		trace("cross_place", "crossPlaceAutoReload: укажи crossPlaceReloadUrl (https raw) или crossPlaceReloadReadfile")
		return
	end
	local snippet = string.format(
		"task.delay(%g, function()\n\tlocal _ok, _err = pcall(function()\n\t\t%s\n\tend)\n\tif not _ok and warn then warn('[AutoRank cross-place]', _err) end\nend)",
		delay,
		innerExec
	)
	local okReg, qerr = pcall(q, snippet)
	if okReg then
		crossPlaceQueueRegistered = true
		traceThrottled("cross_place_ok", 15, "cross_place", "queue_on_teleport: перезапуск скрипта после смены Place")
	else
		trace("cross_place", "queue_on_teleport", qerr)
	end
end

local function tryFarmFireClickDetectorFallback(entry)
	if not cfg().farmUseFireClickDetectorFallback or not entry or not entry.model then
		return
	end
	local cd = entry.model:FindFirstChildWhichIsA("ClickDetector", true)
	if cd then
		Exec.fireClickDetector(cd, 0)
	end
end

local function hookOrbNetwork()
	if orbNetHooked or not Network or not Network.Fired then
		return
	end
	local connCreate = Network.Fired("Orbs: Create")
	if not connCreate or not connCreate.Connect then
		return
	end
	orbNetHooked = true
	autoRankRegisterConn(connCreate:Connect(function(batch)
		accumulateOrbBatch(batch)
	end))
	local connClear = Network.Fired("Orbs: Clear")
	if connClear and connClear.Connect then
		autoRankRegisterConn(connClear:Connect(function()
			for k in pairs(orbAccumulator) do
				orbAccumulator[k] = nil
			end
		end))
	end
end

local function dealDamage(uid)
	if not Network then
		return
	end
	local now = tick()
	if now - lastDamageTick < (cfg().delayDamage or 0.125) then
		return
	end
	lastDamageTick = now
	pcall(function()
		Network.UnreliableFire("Breakables_PlayerDealDamage", uid)
	end)
end

local function focusBreakable(uid)
	if uid == currentFocusUid then
		return
	end
	currentFocusUid = uid
	if not BreakableFrontend or not uid then
		return
	end
	pcall(function()
		if BreakableFrontend.forceClickBreakable then
			BreakableFrontend.forceClickBreakable(uid, true)
		end
	end)
end

local function characterPrimaryPosition()
	local ch = LocalPlayer.Character
	local pp = ch and ch.PrimaryPart
	return pp and pp.Position or nil
end

--- Ключи наград текущего ранга: накопительная звезда ≤ RankStars и ещё не RedeemedRankRewards (как updateNotifications в GUIs.Ranks).
local function getClaimableRewardKeys()
	local save = Save and Save.Get and Save.Get()
	if not save or not Directory or not RanksUtil then
		return {}
	end
	local rankId = RanksUtil.RankIDFromNumber(save.Rank)
	if not rankId then
		return {}
	end
	local ranksDir = Directory.Ranks[rankId]
	if not ranksDir or not ranksDir.Rewards then
		return {}
	end
	local rankStars = save.RankStars or 0
	local redeemed = save.RedeemedRankRewards or {}
	local cumulative = 0
	local keys = {}
	for rewardKey, rewardDef in pairs(ranksDir.Rewards) do
		cumulative += (rewardDef and rewardDef.StarsRequired) or 0
		if cumulative <= rankStars and redeemed[tostring(rewardKey)] == nil then
			table.insert(keys, rewardKey)
		end
	end
	table.sort(keys, function(a, b)
		local na, nb = tonumber(a), tonumber(b)
		if na and nb then
			return na < nb
		end
		return tostring(a) < tostring(b)
	end)
	return keys
end

local function zoneUnlockFlagOk()
	if not FFlags then
		return true
	end
	local ok, allowed = pcall(function()
		return FFlags.Get(FFlags.Keys.ZoneUnlocking) or FFlags.CanBypass()
	end)
	return ok and allowed or false
end

local function teleportFlagOk()
	if not FFlags then
		return true
	end
	local ok, allowed = pcall(function()
		return FFlags.Get(FFlags.Keys.Teleporting) or FFlags.CanBypass()
	end)
	return ok and allowed or false
end

local function isEligibleToPurchaseZoneNumber(zoneNumber)
	if not zoneNumber or not FFlags or not RebirthCmds then
		return true
	end
	local ok, allowed = pcall(function()
		if FFlags.Get(FFlags.Keys.Zones_RequireRebirth) then
			local nr = RebirthCmds.GetNextRebirth()
			if nr and nr.ZoneNumberRequired < zoneNumber then
				return false
			end
		end
		return true
	end)
	return ok and allowed ~= false
end

local function tryAutoBuyInstanceZone()
	if not cfg().autoBuyZones or not Network then
		return
	end
	local okIn, inInst = pcall(function()
		return InstancingCmds and InstancingCmds.IsInInstance and InstancingCmds.IsInInstance()
	end)
	if not okIn or not inInst then
		return
	end
	local now = tick()
	if now - lastZonePurchaseTick < (cfg().zonePurchaseInterval or 0.55) then
		return
	end
	local inst = InstancingCmds.Get and InstancingCmds.Get()
	if not inst or not inst.instanceID or not inst.instanceZones then
		return
	end
	local nums = {}
	for k in pairs(inst.instanceZones) do
		local n = tonumber(k)
		if n then
			table.insert(nums, n)
		end
	end
	table.sort(nums)
	for _, zn in ipairs(nums) do
		local unlocked = false
		pcall(function()
			unlocked = InstanceZoneCmds and InstanceZoneCmds.IsUnlocked(zn)
		end)
		if not unlocked then
			local zdata = inst.instanceZones[zn]
			if zdata and zdata.CurrencyId and zdata.CurrencyCost and CurrencyCmds then
				local can = false
				pcall(function()
					can = CurrencyCmds.CanAfford(zdata.CurrencyId, zdata.CurrencyCost)
				end)
				if can then
					lastZonePurchaseTick = now
					local okR, success = pcall(function()
						return Network.Invoke("InstanceZones_RequestPurchase", inst.instanceID, zn)
					end)
					log("InstanceZones_RequestPurchase", inst.instanceID, zn, okR, success)
				end
			end
			break
		end
	end
end

local function tryAutoBuyMainZone()
	if not cfg().autoBuyZones or not Network or not zoneUnlockFlagOk() then
		return
	end
	local okIn, inInst = pcall(function()
		return InstancingCmds and InstancingCmds.IsInInstance and InstancingCmds.IsInInstance()
	end)
	if okIn and inInst then
		return
	end
	if not ZoneCmds or not Directory or not Balancing or not CurrencyCmds then
		return
	end
	local now = tick()
	if now - lastZonePurchaseTick < (cfg().zonePurchaseInterval or 0.55) then
		return
	end
	local nextId, nextTbl = ZoneCmds.GetNextZone()
	if not nextId then
		return
	end
	nextTbl = nextTbl or (Directory.Zones and Directory.Zones[nextId])
	if not nextTbl then
		return
	end
	if ZoneCmds.Owns(nextId) then
		return
	end
	if not cfg().ignoreZoneGateQuests then
		local questsOk = false
		pcall(function()
			questsOk = ZoneCmds.HasCompletedNextZoneQuests()
		end)
		if not questsOk then
			return
		end
	end
	local zn = nextTbl.ZoneNumber
	if zn and not isEligibleToPurchaseZoneNumber(zn) then
		return
	end
	local zoneDir = (Directory.Zones and Directory.Zones[nextId]) or nextTbl
	local price = Balancing.CalcGatePrice(zoneDir)
	local currency = zoneDir and zoneDir.Currency
	if not price or not currency then
		return
	end
	local bal = CurrencyCmds.Get(currency) or 0
	if bal < price then
		return
	end
	lastZonePurchaseTick = now
	local purchaseArg = nextTbl.ZoneName or nextId
	local okR, success, errMsg = pcall(function()
		return Network.Invoke("Zones_RequestPurchase", purchaseArg)
	end)
	log("Zones_RequestPurchase", purchaseArg, okR, success, errMsg)
end

local function questObjectiveEnvironmentBlockedDetail()
	if not Variables or not GUI or not InstancingCmds or not FFlags then
		return false, "variables_gui_fflags_missing"
	end
	local reasons = {}
	local ok, blocked = pcall(function()
		if Variables.IsUsingCannon then
			table.insert(reasons, "IsUsingCannon")
		end
		if Variables.IsRebirthing then
			table.insert(reasons, "IsRebirthing")
		end
		if Variables.IsTeleportingWorld2 then
			table.insert(reasons, "IsTeleportingWorld2")
		end
		if Variables.IsTeleportingWorld3 then
			table.insert(reasons, "IsTeleportingWorld3")
		end
		if Variables.IsTeleportingWorld4 then
			table.insert(reasons, "IsTeleportingWorld4")
		end
		if cfg().questBlockOnGuiTransition and GUI.Transition and GUI.Transition().Enabled then
			table.insert(reasons, "GUITransition")
		end
		if InstancingCmds.IsInInstance and InstancingCmds.IsInInstance("BasketballEvent") then
			table.insert(reasons, "BasketballEvent")
		end
		if FFlags.GetBoolean and FFlags.Keys and FFlags.Keys.MapVFX and FFlags.GetBoolean(FFlags.Keys.MapVFX) then
			table.insert(reasons, "MapVFX")
		end
		return #reasons > 0
	end)
	if not ok then
		return false, "env_check_pcall_failed"
	end
	local why = table.concat(reasons, ",")
	return blocked, (why ~= "" and why) or nil
end

local function questObjectiveEnvironmentBlocked()
	local b, _ = questObjectiveEnvironmentBlockedDetail()
	return b
end

local function descendantGuiButton(obj)
	local at = obj
	for _ = 1, 12 do
		if not at then
			return nil
		end
		if at:IsA("GuiButton") then
			return at
		end
		at = at.Parent
	end
	return nil
end

--- TextLabel/TextButton «Click to open!»: предок-GuiButton, соседняя кнопка или подъём по родителям.
local function resolveOverlayGuiButton(d)
	if not d then
		return nil
	end
	if d:IsA("GuiButton") then
		return d
	end
	if d.FindFirstAncestorWhichIsA then
		local anc = d:FindFirstAncestorWhichIsA("GuiButton")
		if anc then
			return anc
		end
	end
	local p = d.Parent
	if p then
		for _, c in ipairs(p:GetChildren()) do
			if c:IsA("GuiButton") then
				return c
			end
		end
	end
	return descendantGuiButton(d)
end

--- Ребитх: «Click for more» — только getconnections / firesignal (без мыши экзекьютора).
local function tryDismissRebirthUi()
	if not cfg().autoDismissRebirthUi then
		return
	end
	local rebirthing = false
	pcall(function()
		rebirthing = Variables and Variables.IsRebirthing == true
	end)
	if not rebirthing then
		return
	end
	local now = tick()
	if now - lastRebirthDismissTick < (cfg().rebirthDismissInterval or 0.28) then
		return
	end
	lastRebirthDismissTick = now

	local pg = LocalPlayer:FindFirstChild("PlayerGui")
	if pg then
		for _, d in ipairs(pg:GetDescendants()) do
			if d:IsA("TextLabel") or d:IsA("TextButton") then
				local t = string.lower(tostring(d.Text or ""))
				if string.find(t, "click for more", 1, true) or string.find(t, "click for more <", 1, true) then
					local btn = resolveOverlayGuiButton(d)
					if btn then
						if clickGuiButtonRobust(btn) then
							log("rebirth GUI click", btn:GetFullName())
							return
						end
					end
				end
			end
		end
	end
end

--- Оверлей открытия яйца (Egg Opening Frontend): промпт текстом + Variables.OpeningEgg; игра продолжается при LocalPlayer.Mouse.Button1Down / геймпад A/X (TapToOpen — Frame+TextLabel, не GuiButton).
--- opts.ignoreThrottles — для короткого бёрста после Eggs_RequestPurchase (см. eggOpeningPostInvokeBurst*).
local function tryClickEggOpeningPrompt(opts)
	opts = type(opts) == "table" and opts or {}
	if cfg().hideEggHatching and cfg().skipEggGuiClickWhenHiddenHatch ~= false then
		return
	end
	if cfg().autoClickEggOpeningPrompt == false then
		return
	end
	local now = tick()
	if not opts.ignoreThrottles then
		local scanIv = cfg().eggOpeningGuiScanInterval
		if type(scanIv) == "number" and scanIv > 0 and (now - lastEggOpeningGuiScanTick) < scanIv then
			return
		end
		lastEggOpeningGuiScanTick = now
	end

	local openingEgg = false
	pcall(function()
		openingEgg = Variables and type(Variables.OpeningEgg) == "number" and Variables.OpeningEgg > 0
	end)

	local matchLabel = nil
	if openingEgg then
		matchLabel = true
	else
		for _, root in ipairs(eggOpeningTextScanRoots()) do
			if root and root.Parent then
				for _, d in ipairs(root:GetDescendants()) do
					if d:IsA("TextLabel") or d:IsA("TextButton") then
						local t = string.lower(tostring(d.Text or ""))
						if string.find(t, "click to open", 1, true) or string.find(t, "tap to open", 1, true) or (string.find(t, "tap ", 1, true) and string.find(t, " to open", 1, true)) then
							matchLabel = d
							break
						end
					end
				end
			end
			if matchLabel then
				break
			end
		end
	end

	if matchLabel == nil then
		return
	end

	local clickIv = cfg().eggOpeningPromptClickInterval or 0.32
	if cfg().hideEggHatching then
		local ih = cfg().eggOpeningPromptIntervalHiddenHatch
		if type(ih) == "number" and ih > 0 then
			clickIv = ih
		end
	end
	if not opts.ignoreThrottles then
		if now - lastEggOpeningPromptTick < clickIv then
			return
		end
	end
	lastEggOpeningPromptTick = now

	if tryFireEggOpenPrimaryInput() then
		log("egg open primary (Mouse.Button1Down)")
		return
	end

	if type(matchLabel) == "userdata" and matchLabel.Parent then
		local btn = resolveOverlayGuiButton(matchLabel)
		if btn and clickGuiButtonRobust(btn) then
			log("egg Click-to-open GUI", btn:GetFullName())
		end
	end
end

--- Верхний HUD «Return to Area» — когда игрок на спавне/старой зоне при уже открытых высших зонах.
local function tryClickReturnToMaxAreaButton()
	if not cfg().autoClickReturnToAreaButton or hatchBusy then
		return
	end
	if not ZoneCmds or not MapCmds then
		return
	end
	local okIn, inInst = pcall(function()
		return InstancingCmds and InstancingCmds.IsInInstance and InstancingCmds.IsInInstance()
	end)
	if okIn and inInst then
		return
	end
	local maxId = select(1, ZoneCmds.GetMaxOwnedZone())
	local cur = MapCmds.GetCurrentZone()
	if not maxId or type(maxId) ~= "string" or not cur or cur == maxId then
		return
	end
	local now = tick()
	if now - lastReturnAreaGuiTick < (cfg().returnToAreaClickInterval or 2) then
		return
	end
	local pg = LocalPlayer:FindFirstChild("PlayerGui")
	if not pg then
		return
	end
	for _, d in ipairs(pg:GetDescendants()) do
		if d:IsA("TextLabel") or d:IsA("TextButton") then
			local t = string.lower(tostring(d.Text or ""))
			if string.find(t, "return", 1, true) and (string.find(t, "area", 1, true) or string.find(t, "zone", 1, true)) then
				local btn = d:IsA("GuiButton") and d or descendantGuiButton(d)
				if btn then
					local vis = true
					pcall(function()
						vis = btn.Visible == true
					end)
					if vis then
						lastReturnAreaGuiTick = now
						local fired = clickGuiButtonRobust(btn)
						log("Return-to-area GUI", fired, btn:GetFullName())
						return
					end
				end
			end
		end
	end
end

--- Колбэки GoalGenerators иногда возвращают Displays при Priority=nil (напр. пустой Goals.Priorities в декомпиле/билде).
local function normalizeGoalCallbackResult(res)
	if type(res) ~= "table" or cfg().questNormalizeNilGoalPriority == false then
		return res
	end
	local disp = res.Displays
	if disp == nil and type(res.displays) == "table" then
		res.Displays = res.displays
		disp = res.Displays
	end
	if res.Priority == nil and type(res.priority) == "number" then
		res.Priority = res.priority
	end
	if res.Priority == nil and type(disp) == "table" then
		res.Priority = 0
	end
	return res
end

local function pickTrackedObjective()
	local pickDiag = {
		generatorCount = 0,
		fflagOff = 0,
		callbackErr = 0,
		invalidShape = 0,
		validCallbacks = 0,
		hints = {},
	}
	local function hint(s)
		if #pickDiag.hints < 8 then
			table.insert(pickDiag.hints, s)
		end
	end

	if not GoalCmds or not FFlags or not Functions then
		pickDiag.missingModules = true
		hint("GoalCmds_or_FFlags_missing")
		AutoRankRuntimeState.diagGoalPick = pickDiag
		return nil
	end

	local tab = nil
	pcall(function()
		tab = TabController and TabController.Get and TabController.Get()
	end)
	if tab and QUEST_TAB_BLOCKS[tab] then
		pickDiag.blockedTab = tostring(tab)
		hint("TabController_blocked:" .. tostring(tab))
		AutoRankRuntimeState.diagGoalPick = pickDiag
		return nil
	end

	local gens = GoalCmds.GoalGenerators or {}
	pickDiag.generatorCount = #gens
	local best = nil
	for _, gen in ipairs(gens) do
		local clean = string.gsub(string.gsub(string.gsub(gen.Name, " ", ""), "%(", ""), "%)", "")
		local allow = true
		pcall(function()
			allow = FFlags.BulkGet("Goal", clean)
		end)
		if not allow then
			pickDiag.fflagOff += 1
			hint(gen.Name .. ":GoalFFlag_off")
		else
			local ok, res = pcall(gen.Callback)
			if ok and type(res) == "table" then
				res = normalizeGoalCallbackResult(res)
			end
			if not ok then
				pickDiag.callbackErr += 1
				hint(gen.Name .. ":cb_" .. tostring(res):sub(1, 48))
			elseif type(res) ~= "table" or not res.Priority or not res.Displays then
				pickDiag.invalidShape += 1
				hint(gen.Name .. ":no_Priority_or_Displays")
			else
				pickDiag.validCallbacks += 1
				if best and res.Priority <= best.Priority then
					res = best
				else
					res._generatorName = gen.Name
				end
				best = res
			end
		end
	end
	AutoRankRuntimeState.diagGoalPick = pickDiag
	return best
end

local function objectiveSnippetForDiag(tracked, maxLen)
	if not tracked then
		return ""
	end
	maxLen = maxLen or 96
	local parts = {}
	if tracked._generatorName then
		table.insert(parts, tostring(tracked._generatorName))
	end
	for _, disp in ipairs(tracked.Displays or {}) do
		if type(disp) == "table" then
			for _, key in ipairs({ "Text", "Title", "Description", "Subtitle", "GoalText", "Hint" }) do
				local v = disp[key]
				if type(v) == "string" then
					table.insert(parts, v)
				end
			end
		end
	end
	local s = table.concat(parts, " ")
	if #s > maxLen then
		return string.sub(s, 1, maxLen) .. "…"
	end
	return s
end

local function refreshTrackedObjective()
	local now = tick()
	if now - lastQuestPickTick < (cfg().questAssistInterval or 0.65) then
		return cachedTrackedObjective
	end
	lastQuestPickTick = now

	local blocked, envWhy = questObjectiveEnvironmentBlockedDetail()
	if blocked then
		cachedTrackedObjective = nil
		AutoRankRuntimeState.diagQuest = {
			ok = false,
			where = "environment",
			detail = envWhy or "blocked",
		}
		return nil
	end

	local tab = nil
	pcall(function()
		tab = TabController and TabController.Get and TabController.Get()
	end)
	if tab and QUEST_TAB_BLOCKS[tab] then
		cachedTrackedObjective = nil
		AutoRankRuntimeState.diagQuest = {
			ok = false,
			where = "tab_blocked",
			detail = tostring(tab),
		}
		return nil
	end

	cachedTrackedObjective = pickTrackedObjective()
	if cachedTrackedObjective then
		AutoRankRuntimeState.diagQuest = {
			ok = true,
			generator = cachedTrackedObjective._generatorName,
			snippet = objectiveSnippetForDiag(cachedTrackedObjective),
		}
	else
		local dg = AutoRankRuntimeState.diagGoalPick
		local detail = "generators_empty_or_fflag"
		if dg then
			detail = string.format(
				"gens=%d fflagOff=%d cbErr=%d badShape=%d valid=%d",
				dg.generatorCount or 0,
				dg.fflagOff or 0,
				dg.callbackErr or 0,
				dg.invalidShape or 0,
				dg.validCallbacks or 0
			)
			if dg.blockedTab then
				detail = detail .. " tab=" .. dg.blockedTab
			end
			if dg.missingModules then
				detail = "modules_missing"
			end
		end
		AutoRankRuntimeState.diagQuest = {
			ok = false,
			where = "no_goal",
			detail = detail,
		}
	end
	return cachedTrackedObjective
end

--- Цепочка «стрелки»: для каждого Display первый шаг — либо мир (Part), либо GUI (как Goals.ProcessClickSequence → GUITarget в Target).
local function tryClickGuiTargetTree(gui)
	if not gui or not cfg().questClickGuiTargets then
		return false
	end
	local now = tick()
	if now - lastQuestGuiClickTick < (cfg().questGuiClickInterval or 0.38) then
		return false
	end
	local targetBtn = nil
	if gui:IsA("GuiButton") then
		targetBtn = gui
	else
		targetBtn = gui:FindFirstChildWhichIsA("GuiButton", true)
	end
	if not targetBtn then
		return false
	end
	lastQuestGuiClickTick = now
	return clickGuiButtonRobust(targetBtn)
end

local QuestAssist = {}

function QuestAssist.flattenObjectiveText(tracked)
	if not tracked then
		return ""
	end
	local parts = {}
	if tracked._generatorName then
		table.insert(parts, tostring(tracked._generatorName))
	end
	for _, disp in ipairs(tracked.Displays or {}) do
		if type(disp) == "table" then
			for _, key in ipairs({ "Text", "Title", "Description", "Subtitle", "GoalText", "Hint" }) do
				local v = disp[key]
				if type(v) == "string" then
					table.insert(parts, v)
				elseif type(v) == "function" then
					local ok, r = pcall(v)
					if ok and type(r) == "string" then
						table.insert(parts, r)
					end
				end
			end
		end
	end
	return table.concat(parts, " ")
end

function QuestAssist.objectiveTextLower(tracked)
	return string.lower(QuestAssist.flattenObjectiveText(tracked))
end

function QuestAssist.blobMatchesList(blobLower, list)
	if type(list) ~= "table" or blobLower == "" then
		return false
	end
	for _, s in ipairs(list) do
		if type(s) == "string" and s ~= "" and string.find(blobLower, string.lower(s), 1, true) then
			return true
		end
	end
	return false
end

function QuestAssist.generatorMatchesPriorityList(tracked)
	if not tracked or cfg().questPrioritizeListedGoalGenerators == false then
		return false
	end
	local g = string.lower(tostring(tracked._generatorName or ""))
	if g == "" then
		return false
	end
	for _, pref in ipairs(cfg().questGoalGeneratorPrioritySubstrings or {}) do
		if type(pref) == "string" and pref ~= "" and string.find(g, string.lower(pref), 1, true) then
			return true
		end
	end
	return false
end

--- true = не трогать Displays (телепорт/промпты/GUI) для этой цели
function QuestAssist.shouldSkipObjectiveInteraction(tracked)
	if not tracked then
		return false
	end
	local blob = QuestAssist.objectiveTextLower(tracked)
	if QuestAssist.blobMatchesList(blob, cfg().questBlockedObjectiveSubstrings or {}) then
		return true
	end

	local prioritized = QuestAssist.generatorMatchesPriorityList(tracked)

	local mgMode = cfg().minigameAssistMode or "skip"
	if mgMode == "complete" and cfg().minigameAllowQuestInstancesWhenComplete ~= false then
		return false
	end

	if prioritized then
		return false
	end

	if not cfg().questIgnoreMinigames then
		return false
	end
	local gen = string.gsub(string.gsub(string.gsub(string.lower(tostring(tracked._generatorName or "")), " ", ""), "%(", ""), "%)", "")
	if cfg().questIgnoreInstancesGenerator and string.find(gen, "instances", 1, true) then
		return true
	end
	if QuestAssist.blobMatchesList(blob, cfg().questMinigameObjectiveSubstrings or {}) then
		return true
	end
	local isMinigame = string.find(gen, "minefield")
		or string.find(gen, "digsite")
		or string.find(gen, "fishing")
		or string.find(gen, "fishingevent")
		or string.find(gen, "chest rush")
		or string.find(gen, "pyramid")
		or string.find(gen, "atlantis")
		or string.find(gen, "obby")
		or string.find(gen, "falling")
		or string.find(gen, "sled")
		or string.find(gen, "castfishing")
		or string.find(gen, "catchfish")
		or string.find(gen, "sellfish")
		or string.find(gen, "buyboat")
	return isMinigame
end

function QuestAssist.tryKeywordCooldownReset(tracked)
	if not cfg().questAssistObjectiveKeywords or not tracked then
		return
	end
	local blob = string.lower(QuestAssist.flattenObjectiveText(tracked))
	local function has(s)
		return string.find(blob, s, 1, true) ~= nil
	end
	if has("egg slot") or has("hatch slot") or has("extra eggs") or has("more eggs") then
		lastEggSlotTick = 0
	end
	if has("equip slot") or has("pet slot") or has("equip pet") then
		lastEquipSlotTick = 0
	end
	if has("upgrade") or has("rebirth shrine") or has("enchant machine") or has("potion machine") then
		lastUpgradePurchaseTick = 0
	end
	if has("rank reward") or has("redeem reward") or has("claim reward") then
		lastClaimTick = 0
	end
	if has("rank up") then
		lastRankUpGuiTick = 0
	end
	if has("travel ") or has("traverse") or has("void island") or has("tech ") or has("fantasy ") then
		lastTeleportTick = 0
		lastTravelWorldDirectNetworkTick = 0
	end
	if has("farming") or has("farm token") or has("farming token") or has("halloween") or has("trick or treat") then
		lastQuestPickTick = 0
	end
end

--- Поиск ближайшего ProximityPrompt к игроку в workspace
local function getClosestProximityPrompt(maxDist)
	local ch = LocalPlayer.Character
	local pp = ch and ch.PrimaryPart
	if not pp then return nil end
	local best = nil
	local bestDist = maxDist or 40

	local function scan(inst)
		if inst:IsA("ProximityPrompt") and inst.Enabled then
			local p = inst.Parent
			if p and p:IsA("BasePart") then
				local d = (p.Position - pp.Position).Magnitude
				if d < bestDist then
					bestDist = d
					best = inst
				end
			elseif p and p:IsA("Model") and p.PrimaryPart then
				local d = (p.PrimaryPart.Position - pp.Position).Magnitude
				if d < bestDist then
					bestDist = d
					best = inst
				end
			end
		end
		for _, ch in ipairs(inst:GetChildren()) do
			scan(ch)
		end
	end

	-- Ищем в Interact-папке спавна или глобально в Map
	local folder = nil
	pcall(function() folder = ZonesUtil and ZonesUtil.GetInteractFolder and ZonesUtil.GetInteractFolder("Rainbow Road") end)
	if folder then scan(folder) end

	if not best then
		local map = workspace:FindFirstChild("Map")
		if map then scan(map) end
	end

	if not best then
		local things = workspace:FindFirstChild("__THINGS")
		if things then scan(things) end
	end

	return best
end

--- Имя генератора GoalCmds «Travel To Tech» (как в ReplicatedStorage...Transitions.Travel To Tech).
local function isTravelToTechGeneratorName(genName)
	local g = string.lower(genName or "")
	return string.find(g, "travel to tech", 1, true) ~= nil
		or string.find(g, "tech starter", 1, true) ~= nil
		or (string.find(g, "world 2", 1, true) and string.find(g, "tech", 1, true))
		or string.find(g, "tech world", 1, true) ~= nil
end

--- Поиск точки входа в Tech World (раньше была ракета, теперь портал). Ищем любой ProximityPrompt в Interact-папке Rainbow Road.
local function rainbowRoadRocketInteractPart()
	if not ZonesUtil or type(ZonesUtil.GetInteractFolder) ~= "function" then
		return nil
	end
	local folder = nil
	pcall(function()
		folder = ZonesUtil.GetInteractFolder("Rainbow Road")
	end)
	if not folder then
		return nil
	end
	-- Ищем сначала по старым путям (Rocket / Frame -> Rocket)
	local frame = folder:FindFirstChild("Frame")
	local rocket = frame and frame:FindFirstChild("Rocket") or folder:FindFirstChild("Rocket")
	local ri = rocket and rocket:FindFirstChild("RocketInteract")
	if ri and (ri:IsA("BasePart") or (ri:IsA("Model") and ri.PrimaryPart)) then
		return ri
	end
	-- Фолбэк: ищем первый попавшийся ProximityPrompt внутри папки интерактивов Rainbow Road
	local fallbackPart = nil
	local function searchPP(inst)
		if fallbackPart then return end
		if inst:IsA("ProximityPrompt") then
			local p = inst.Parent
			if p and (p:IsA("BasePart") or (p:IsA("Model") and p.PrimaryPart)) then
				fallbackPart = p
			end
		end
		for _, ch in ipairs(inst:GetChildren()) do
			searchPP(ch)
		end
	end
	searchPP(folder)
	return fallbackPart
end

--- Tech Rocket (World 1 → 2): Network.Fire("RequestTechRocket") — см. Scripts.Game.Misc "Tech Rocket" / SetupRocketInteract + Message.New.
local function tryTravelWorldDirectNetworkFire(genName)
	if cfg().questTravelWorldDirectNetwork == false then
		return false
	end
	if not Network or type(Network.Fire) ~= "function" then
		return false
	end
	local remoteName = isTravelToTechGeneratorName(genName) and "RequestTechRocket" or nil
	if not remoteName then
		return false
	end
	if remoteName == "RequestTechRocket" and cfg().questTravelTechRequireRebirth4 ~= false then
		local rb = nil
		pcall(function()
			local s = Save and Save.Get and Save.Get()
			rb = s and type(s.Rebirths) == "number" and s.Rebirths or nil
		end)
		if type(rb) == "number" and rb < 4 then
			local nowW = tick()
			if nowW - lastTravelTechRebirthWarnTick > 10 then
				lastTravelTechRebirthWarnTick = nowW
				trace(
					"pulse.quest",
					"Travel To Tech: Rebirth",
					rb,
					"/4 — сервер/UI не отправят ракету; повысьте Rebirth или questTravelTechRequireRebirth4 = false"
				)
			end
			return false
		end
	end
	local now = tick()
	local iv = tonumber(cfg().questTravelWorldDirectNetworkInterval) or 2.6
	if now - lastTravelWorldDirectNetworkTick < iv then
		return false
	end
	lastTravelWorldDirectNetworkTick = now
	local ok, err = pcall(function()
		Network.Fire(remoteName)
	end)
	if cfg().log then
		log("quest travel direct Network.Fire", remoteName, genName, ok and "ok" or err)
	end
	if cfg().verboseLog then
		traceThrottled("travelDirectNet:" .. remoteName, iv + 0.1, "pulse.quest", ok and "Network.Fire OK" or "Network.Fire FAIL", remoteName, genName)
	end
	return ok == true
end

local function tryQuestTargetExecutorExtras(inst, pp, genName)
	if not inst then
		return
	end
	if inst:IsA("ClickDetector") then
		if cfg().questUseFireClickDetector then
			Exec.fireClickDetector(inst, 0)
			log("quest Exec.fireClickDetector", genName)
		end
		tryTravelWorldDirectNetworkFire(genName)
		return
	end
	--- Travel To Tech / Void / Fantasy: в Studio Target = часть (RocketInteract), ProximityPrompt — потомок (клавиша E).
	local ppNested = inst:FindFirstChildWhichIsA("ProximityPrompt", true)
	if ppNested and ppNested:IsA("ProximityPrompt") then
		Exec.fireProximityPrompt(ppNested)
		log("quest ProximityPrompt∈Target", genName, ppNested:GetFullName())
	end
	if cfg().questUseFireClickDetector then
		local cd = inst:FindFirstChildWhichIsA("ClickDetector", true)
		if cd then
			Exec.fireClickDetector(cd, 0)
			log("quest Exec.fireClickDetector child", genName)
		end
	end
	if cfg().questUseFireTouchInterest and pp then
		local touchPart = nil
		if inst:IsA("BasePart") then
			touchPart = inst
		elseif inst:IsA("Model") and inst.PrimaryPart then
			touchPart = inst.PrimaryPart
		end
		if touchPart then
			Exec.fireTouchInterest(touchPart, pp, 0)
			log("quest Exec.fireTouchInterest", genName)
		end
	end
	tryTravelWorldDirectNetworkFire(genName)
end

local function tryQuestResolveDisplayTargets(tracked)
	if not tracked or type(tracked.Displays) ~= "table" then
		return
	end

	if QuestAssist.shouldSkipObjectiveInteraction(tracked) then
		return
	end

	local ch = LocalPlayer.Character
	local pp = ch and ch.PrimaryPart
	local minD = cfg().questTeleportMinDist or 14
	local yOff = cfg().questTeleportYOffset or 6
	local genName = tracked._generatorName
	local displays = tracked.Displays
	local handledPhysical = false

	for _, disp in ipairs(displays) do
		local t = disp and disp.Target
		if typeof(t) == "Instance" and t:IsA("ProximityPrompt") then
			Exec.fireProximityPrompt(t)
			log("quest ProximityPrompt", genName, t:GetFullName())
		end
	end

	for _, disp in ipairs(displays) do
		local t = disp and disp.Target
		if typeof(t) == "Instance" and t:IsA("ClickDetector") then
			handledPhysical = true
			tryQuestTargetExecutorExtras(t, pp, genName)
			return
		end
	end

	for _, disp in ipairs(displays) do
		local t = disp and disp.Target
		if typeof(t) == "Instance" and t:IsA("BasePart") then
			handledPhysical = true
			if cfg().questTeleportToTarget and pp then
				if (pp.Position - t.Position).Magnitude >= minD then
					pcall(function()
						pp.CFrame = CFrame.new(t.Position + Vector3.new(0, yOff, 0))
					end)
					log("quest teleport →", genName, t:GetFullName())
				end
			end
			tryQuestTargetExecutorExtras(t, pp, genName)
			return
		end
		if typeof(t) == "Instance" and t:IsA("Model") and t.PrimaryPart then
			handledPhysical = true
			local pos = t.PrimaryPart.Position
			if cfg().questTeleportToTarget and pp then
				if (pp.Position - pos).Magnitude >= minD then
					pcall(function()
						pp.CFrame = CFrame.new(pos + Vector3.new(0, yOff, 0))
					end)
					log("quest teleport →", genName, t:GetFullName())
				end
			end
			tryQuestTargetExecutorExtras(t, pp, genName)
			return
		end
	end

	for _, disp in ipairs(displays) do
		local t = disp and disp.Target
		if typeof(t) == "Instance" and t:IsA("GuiObject") then
			if tryClickGuiTargetTree(t) then
				log("quest GUI click →", genName, t:GetFullName())
				return
			end
		end
	end

	--- Travel To Tech: при дистанции >500 студов клиент не кладёт Target в Displays (см. Studio) — тянем к RocketInteract сами.
	if not handledPhysical and isTravelToTechGeneratorName(genName) then
		local bestPrompt = getClosestProximityPrompt(150)
		if bestPrompt and pp then
			local anchor = bestPrompt.Parent
			local pos = anchor:IsA("BasePart") and anchor.Position or (anchor:IsA("Model") and anchor.PrimaryPart and anchor.PrimaryPart.Position)
			if pos and cfg().questTeleportToTarget and (pp.Position - pos).Magnitude >= minD then
				pcall(function()
					pp.CFrame = CFrame.new(pos + Vector3.new(0, yOff, 0))
				end)
				log("quest teleport (Travel To Tech closest prompt) →", anchor:GetFullName())
			end
			Exec.fireProximityPrompt(bestPrompt)
			tryTravelWorldDirectNetworkFire(genName)
		end
	end
end

local function countEquippedEnchantSlots()
	local s = Save and Save.Get and Save.Get()
	if not s or type(s.EquippedEnchants) ~= "table" then
		return 0
	end
	local n = 0
	for _, _ in pairs(s.EquippedEnchants) do
		n += 1
	end
	return n
end

local function tryQuestEquipEnchantFromInventory()
	if not cfg().questEquipEnchants or not EnchantCmds or not InventoryCmds then
		return
	end
	local now = tick()
	if now - lastEnchantEquipTick < (cfg().questEquipEnchantInterval or 2.2) then
		return
	end
	local maxSlots = 0
	pcall(function()
		maxSlots = EnchantCmds.GetMaxEquippedEnchants() or 0
	end)
	if maxSlots <= 0 then
		return
	end
	if countEquippedEnchantSlots() >= maxSlots then
		return
	end
	local s = Save and Save.Get and Save.Get()
	if not s or not s.Inventory or not s.Inventory.Enchant then return end
	
	for uid, data in pairs(s.Inventory.Enchant) do
		local eid = data.id
		if type(eid) == "string" and type(uid) == "string" then
			local already = false
			pcall(function() already = EnchantCmds.IsEquipped(eid) == true end)
			if not already then
				lastEnchantEquipTick = now
				pcall(function() EnchantCmds.Equip(uid) end)
				log("Enchants_Equip", uid, eid)
				break
			end
		end
	end
end

local function buffConsumablesInstanceBlocked()
	if cfg().autoConsumeBuffsInInstance ~= false then
		return false
	end
	local ok, ins = pcall(function()
		return InstancingCmds and InstancingCmds.IsInInstance and InstancingCmds.IsInInstance()
	end)
	return ok and ins == true
end

local function idInConsumableBlocklist(id)
	if type(id) ~= "string" then
		return true
	end
	local list = cfg().autoConsumeConsumableBlocklist
	if type(list) ~= "table" then
		return false
	end
	for _, v in ipairs(list) do
		if v == id then
			return true
		end
	end
	return false
end

local function countActivePotionEntries()
	if not PotionCmds or not PotionCmds.GetActivePotions then
		return 0
	end
	local t = PotionCmds.GetActivePotions()
	if not t then
		return 0
	end
	local n = 0
	for _, tiers in pairs(t) do
		if type(tiers) == "table" then
			for _, _ in pairs(tiers) do
				n += 1
			end
		end
	end
	return n
end

local function potionTypeAlreadyActive(potionId)
	if type(potionId) ~= "string" or not PotionCmds or not PotionCmds.GetActivePotions then
		return false
	end
	local t = PotionCmds.GetActivePotions()
	if not t then
		return false
	end
	local sub = t[potionId]
	return type(sub) == "table" and next(sub) ~= nil
end

local function pickPotionConsumeAmount(item)
	local am = 1
	pcall(function()
		am = item:GetAmount()
	end)
	if am < 1 then
		return 0
	end
	if not cfg().questConsumePotionBulk then
		return 1
	end
	local bulk = false
	pcall(function()
		bulk = MasteryCmds and MasteryCmds.HasPerk and MasteryCmds.HasPerk("Potions", "BulkConsume") == true
	end)
	if not bulk then
		return 1
	end
	local tiers = { 100, 50, 25, 10, 5, 1 }
	for _, n in ipairs(tiers) do
		if n <= am then
			return n
		end
	end
	return 1
end

local function tryQuestConsumePotion()
	if not cfg().autoConsumeBuffs or cfg().questConsumePotions == false or buffConsumablesInstanceBlocked() then
		return
	end
	if not PotionCmds or not InventoryCmds then
		return
	end
	local now = tick()
	if now - lastPotionConsumeTick < (cfg().questConsumePotionsInterval or 1.35) then
		return
	end
	if cfg().questConsumePotionsOnlyWhenNoneActive and countActivePotionEntries() > 0 then
		return
	end
	local cont = nil
	pcall(function()
		cont = InventoryCmds.Container()
	end)
	if not cont then
		return
	end
	local PotionItem = nil
	pcall(function()
		PotionItem = require(ReplicatedStorage.Library.Items:WaitForChild("PotionItem"))
	end)
	if not PotionItem then
		return
	end
	local s = Save and Save.Get and Save.Get()
	if not s or not s.Inventory or not s.Inventory.Potion then
		return
	end

	local useTierSort = cfg().questConsumePotionsPreferMaxTier ~= false

	local function consumePotionCand(c)
		lastPotionConsumeTick = now
		pcall(function()
			PotionCmds.Consume(c.uid, c.n)
		end)
		log("Potions: Consume", c.uid, c.pid, c.n, "tier", c.tier)
	end

	if not useTierSort then
		for uid, data in pairs(s.Inventory.Potion) do
			local pid = data and data.id
			if type(uid) == "string" and type(pid) == "string" then
				if not potionTypeAlreadyActive(pid) then
					local item = cont:Get(uid, PotionItem)
					if item then
						local tier = nil
						pcall(function()
							tier = item.GetTier and item:GetTier()
						end)
						tier = tier or data.tn or 1
						local tierOk = true
						if MasteryCmds and MasteryCmds.CanUsePotion then
							pcall(function()
								tierOk = select(1, MasteryCmds.CanUsePotion(tier)) == true
							end)
						end
						if tierOk then
							local n = pickPotionConsumeAmount(item)
							if n >= 1 then
								consumePotionCand({ uid = uid, pid = pid, tier = tier, n = n })
								return
							end
						end
					end
				end
			end
		end
		return
	end

	local candidates = {}
	for uid, data in pairs(s.Inventory.Potion) do
		local pid = data and data.id
		if type(uid) == "string" and type(pid) == "string" and not potionTypeAlreadyActive(pid) then
			local item = cont:Get(uid, PotionItem)
			if item then
				local tier = nil
				pcall(function()
					tier = item.GetTier and item:GetTier()
				end)
				tier = tonumber(tier) or tonumber(data and data.tn) or 1
				local tierOk = true
				if MasteryCmds and MasteryCmds.CanUsePotion then
					pcall(function()
						tierOk = select(1, MasteryCmds.CanUsePotion(tier)) == true
					end)
				end
				if tierOk then
					local n = pickPotionConsumeAmount(item)
					if n >= 1 then
						table.insert(candidates, { uid = uid, pid = pid, tier = tier, n = n })
					end
				end
			end
		end
	end
	if #candidates == 0 then
		return
	end
	table.sort(candidates, function(a, b)
		if a.tier ~= b.tier then
			return a.tier > b.tier
		end
		if a.n ~= b.n then
			return a.n > b.n
		end
		return tostring(a.uid) < tostring(b.uid)
	end)
	consumePotionCand(candidates[1])
end

local function tryQuestConsumeFruit()
	if not cfg().autoConsumeBuffs or cfg().questConsumeFruits == false or buffConsumablesInstanceBlocked() then
		return
	end
	if not FruitCmds or not InventoryCmds then
		return
	end
	local now = tick()
	if now - lastFruitConsumeTick < (cfg().questConsumeFruitsInterval or 1.5) then
		return
	end
	local s = Save and Save.Get and Save.Get()
	if not s or not s.Inventory or not s.Inventory.Fruit then
		return
	end

	for uid, data in pairs(s.Inventory.Fruit) do
		if type(uid) == "string" then
			local maxC = 0
			pcall(function()
				maxC = FruitCmds.GetMaxConsume(uid) or 0
			end)
			if maxC >= 1 then
				local cap = tonumber(cfg().questConsumeFruitMaxAtOnce) or 4
				local take = math.min(maxC, math.max(1, cap))
				lastFruitConsumeTick = now
				pcall(function()
					FruitCmds.Consume(uid, take)
				end)
				log("Fruits: Consume", uid, data and data.id, take)
				break
			end
		end
	end
end

local function tryAutoConsumeConsumables()
	if not cfg().autoConsumeBuffs or cfg().autoConsumeConsumables == false or buffConsumablesInstanceBlocked() then
		return
	end
	if not ConsumableCmds or not InventoryCmds or type(ConsumableCmds.Consume) ~= "function" then
		return
	end
	local now = tick()
	if now - lastConsumableConsumeTick < (cfg().autoConsumeConsumablesInterval or 2.2) then
		return
	end
	local ConsumableItem = nil
	pcall(function()
		ConsumableItem = require(ReplicatedStorage.Library.Items:WaitForChild("ConsumableItem"))
	end)
	if not ConsumableItem then
		return
	end
	local cont = nil
	pcall(function()
		cont = InventoryCmds.Container()
	end)
	if not cont then
		return
	end
	local s = Save and Save.Get and Save.Get()
	if not s or not s.Inventory or not s.Inventory.Consumable then
		return
	end

	for uid, data in pairs(s.Inventory.Consumable) do
		local cid = data and data.id
		if type(uid) == "string" and type(cid) == "string" and not idInConsumableBlocklist(cid) then
			local item = cont:Get(uid, ConsumableItem)
			if item and item.GetAmount and item:GetAmount() > 0 then
				lastConsumableConsumeTick = now
				local okR = false
				local err = nil
				pcall(function()
					okR, err = ConsumableCmds.Consume(item, 1)
				end)
				log("Consumables_Consume", uid, cid, okR, err)
				break
			end
		end
	end
end

--- Пульс зелий / фруктов / ConsumableItem (см. Studio PotionCmds, FruitCmds, ConsumableCmds).
local function tryAutoBuffConsumablesPulse()
	pcall(function()
		tryQuestConsumePotion()
		tryQuestConsumeFruit()
		tryAutoConsumeConsumables()
	end)
end

--- Справочник флагов: НЕ через `require(Library.Directory).ZoneFlags` — у Directory LazyModuleLoader
--- и ключ `ZoneFlags` часто отсутствует (ошибка «Unknown entry \'ZoneFlags\'»). Как в FlexibleFlagCmds — прямой require модуля.
local zoneFlagsDirectoryCache = nil
local zoneFlagsDirectoryCachedBad = false
local function getZoneFlagsDirectoryTable()
	if zoneFlagsDirectoryCachedBad then
		return nil
	end
	if zoneFlagsDirectoryCache ~= nil then
		return zoneFlagsDirectoryCache
	end
	local ok, tbl = pcall(function()
		return require(ReplicatedStorage.Library.Directory:WaitForChild("ZoneFlags"))
	end)
	if ok and type(tbl) == "table" then
		zoneFlagsDirectoryCache = tbl
		return tbl
	end
	zoneFlagsDirectoryCachedBad = true
	return nil
end

--- Квест use/place flag: клиент MapCmds.IsInDottedBox + Network.Invoke через FlexibleFlagCmds.Consume (игра).
--- Без tracked (no_goal из GoalGenerators) — см. cfg().questAutoPlaceFlagWithoutTrackedGoal.
local function tryQuestPlaceFlexibleFlag(tracked)
	if not cfg().questAutoPlaceFlag then
		return
	end
	if tracked ~= nil then
		if QuestAssist.shouldSkipObjectiveInteraction(tracked) then
			return
		end
		local blobTracked = QuestAssist.objectiveTextLower(tracked)
		if not string.find(blobTracked, "flag", 1, true) then
			return
		end
	elseif cfg().questAutoPlaceFlagWithoutTrackedGoal ~= false then
		-- ставим по dotted box без текста цели от GoalCmds
	else
		return
	end
	if not FlexibleFlagCmds or not MapCmds or not InventoryCmds then
		return
	end
	local inBox = false
	pcall(function()
		inBox = MapCmds.IsInDottedBox and MapCmds.IsInDottedBox() == true
	end)
	if not inBox then
		return
	end
	local now = tick()
	if now - lastQuestFlagTick < (cfg().questPlaceFlagInterval or 2) then
		return
	end

	local blobHint = ""
	if tracked ~= nil then
		blobHint = QuestAssist.objectiveTextLower(tracked)
	end

	local function orderedFlagNames()
		local out = {}
		local seen = {}
		local hints = {
			{ "strength", "Strength Flag" },
			{ "magnet", "Magnet Flag" },
			{ "hasty", "Hasty Flag" },
			{ "shiny", "Shiny Flag" },
			{ "rainbow", "Rainbow Flag" },
		}
		for _, h in ipairs(hints) do
			if string.find(blobHint, h[1], 1, true) and not seen[h[2]] then
				table.insert(out, h[2])
				seen[h[2]] = true
			end
		end
		local fb = cfg().questFlagNameFallbackOrder
		if type(fb) == "table" then
			for _, n in ipairs(fb) do
				if type(n) == "string" and not seen[n] then
					table.insert(out, n)
					seen[n] = true
				end
			end
		end
		return out
	end

	local cont = nil
	pcall(function()
		cont = InventoryCmds.Container and InventoryCmds.Container()
	end)
	if not cont or type(cont.CollectAny) ~= "function" then
		return
	end

	local zoneDir = getZoneFlagsDirectoryTable()
	if not zoneDir then
		return
	end

	for _, flagNm in ipairs(orderedFlagNames()) do
		local dirEntry = zoneDir[flagNm]
		if dirEntry then
			local items = nil
			pcall(function()
				items = cont:CollectAny(dirEntry)
			end)
			if items and #items > 0 then
				local it = items[1]
				local uid = nil
				pcall(function()
					if type(it.GetUID) == "function" then
						uid = it:GetUID()
					end
				end)
				if type(uid) == "string" and uid ~= "" then
					lastQuestFlagTick = now
					local ok, res = pcall(function()
						return FlexibleFlagCmds.Consume(flagNm, uid)
					end)
					log("quest FlexibleFlagCmds.Consume", flagNm, ok, res)
					return
				end
			end
		end
	end
end

local function objectiveHasWorldTarget(tracked)
	if not tracked then
		return false
	end
	--- Travel To Tech: при дистанции >500 в Displays нет Target (см. Studio), но цель всё равно мировая.
	if isTravelToTechGeneratorName(tracked._generatorName) then
		return true
	end
	if type(tracked.Displays) ~= "table" then
		return false
	end
	for _, disp in ipairs(tracked.Displays) do
		local t = disp and disp.Target
		if typeof(t) == "Instance" then
			if t:IsA("ProximityPrompt") then
				return true
			end
			if t:IsA("BasePart") then
				return true
			end
			if t:IsA("Model") and t.PrimaryPart then
				return true
			end
		end
	end
	return false
end

local function getZoneIdAtWorldPosition(pos)
	if not pos then
		return nil
	end
	local z = nil
	pcall(function()
		if MapCmds and MapCmds.GetZoneAtPosition then
			z = MapCmds.GetZoneAtPosition(pos)
		elseif MapCmds and MapCmds.GetZoneFromPosition then
			z = MapCmds.GetZoneFromPosition(pos)
		elseif ZoneCmds and ZoneCmds.GetZoneAtPosition then
			z = ZoneCmds.GetZoneAtPosition(pos)
		elseif ZoneCmds and ZoneCmds.GetZoneFromWorldPosition then
			z = ZoneCmds.GetZoneFromWorldPosition(pos)
		end
	end)
	if type(z) == "string" and z ~= "" then
		return z
	end
	return nil
end

local function getEggZoneIdForNumber(n)
	if not EggsUtil then
		return nil
	end
	local part = nil
	pcall(function()
		part = EggsUtil.GetEggPart(n)
	end)
	if not part then
		return nil
	end
	return getZoneIdAtWorldPosition(part.Position)
end

--- Если в тексте цели явно фигурирует имя яйца — вернуть его номер (для телепорта на другую зону).
local function questSpecifiesEggNumber(tracked)
	if not tracked or not EggsUtil or not EggCmds then
		return nil
	end
	local blob = string.lower(QuestAssist.flattenObjectiveText(tracked))
	if not string.find(blob, "hatch", 1, true) and not string.find(blob, "egg", 1, true) then
		return nil
	end
	local hi = 0
	pcall(function()
		hi = EggCmds.GetHighestEggNumberAvailable() or 0
	end)
	if hi <= 0 then
		return nil
	end
	for i = hi, 1, -1 do
		local ed = EggsUtil.GetByNumber(i)
		if ed and ed._id then
			local idl = string.lower(tostring(ed._id))
			if string.find(blob, idl, 1, true) then
				return i
			end
			local bare = string.gsub(idl, " egg", "", 1)
			if #bare >= 4 and bare ~= idl and string.find(blob, bare, 1, true) then
				return i
			end
		end
	end
	return nil
end

local HatchAssist = {}

function HatchAssist.infinityAllowed(tracked)
	if cfg().allowInfinityEggWithoutQuest then
		return true
	end
	local blob = string.lower(
		QuestAssist.flattenObjectiveText(tracked) .. " " .. tostring(tracked and tracked._generatorName or "")
	)
	for _, kw in ipairs(cfg().infinityEggQuestKeywords or {}) do
		if type(kw) == "string" and kw ~= "" and string.find(blob, string.lower(kw), 1, true) then
			return true
		end
	end
	return false
end

function HatchAssist.pickEggNumber(tracked)
	if not EggsUtil or not EggCmds then
		return 0
	end
	local hi = 0
	pcall(function()
		hi = EggCmds.GetHighestEggNumberAvailable() or 0
	end)
	if hi <= 0 then
		return 0
	end
	if HatchAssist.infinityAllowed(tracked) then
		return hi
	end
	while hi > 0 do
		local dir = EggsUtil.GetByNumber(hi)
		if dir and dir._id and dir._id ~= "Infinity Egg" then
			return hi
		end
		hi -= 1
	end
	return 0
end

--- Наивысший доступный номер яйца, чей мировой стенд в зоне zoneId (по позиции GetEggPart).
function HatchAssist.pickHighestEggInPhysicalZone(zoneId, tracked)
	if not zoneId or not EggsUtil or not EggCmds then
		return 0
	end
	local hi = 0
	pcall(function()
		hi = EggCmds.GetHighestEggNumberAvailable() or 0
	end)
	if hi <= 0 then
		return 0
	end
	local allowInf = HatchAssist.infinityAllowed(tracked)
	for i = hi, 1, -1 do
		local dir = EggsUtil.GetByNumber(i)
		if dir and dir._id then
			if not (dir._id == "Infinity Egg" and not allowInf) then
				local ez = getEggZoneIdForNumber(i)
				if ez and ez == zoneId then
					return i
				end
			end
		end
	end
	return 0
end

--- Яйцо из текста квеста; иначе приоритет яйца текущей локации; иначе прежняя логика.
function HatchAssist.pickEggNumberForHatch(tracked)
	local explicit = questSpecifiesEggNumber(tracked)
	if explicit and explicit > 0 then
		return explicit, true
	end
	if cfg().preferZoneEggWhenProgress and MapCmds then
		local cur = MapCmds.GetCurrentZone()
		if cur then
			local zn = HatchAssist.pickHighestEggInPhysicalZone(cur, tracked)
			if zn > 0 then
				return zn, false
			end
		end
	end
	return HatchAssist.pickEggNumber(tracked), false
end

function HatchAssist.pivotForEgg(eggDir, tracked)
	if not eggDir or not cfg().pivotBeforeRemotePurchases or not cfg().hatchTeleportNearEgg then
		return
	end
	if eggDir._id == "Infinity Egg" then
		if HatchAssist.infinityAllowed(tracked) then
			pivotNearestInfinityEggStand()
		end
		return
	end
	local uid = nil
	if CustomEggsCmds and eggDir._id then
		pcall(function()
			uid = CustomEggsCmds.GetClosestById(eggDir._id)
		end)
	end
	
	local yOff = cfg().hatchEggPivotYOffset or 8
	local ch = LocalPlayer.Character
	
	if uid then
		local row = nil
		pcall(function()
			row = CustomEggsCmds.Get(uid)
		end)
		if row and row._model and ch then
			pcall(function()
				ch:PivotTo(row._model:GetPivot() * CFrame.new(0, yOff, 0))
			end)
			stabilizeCharacterPhysics(ch)
		end
		return
	end
	
	if eggDir.eggNumber and EggsUtil and EggsUtil.GetEggPart then
		local part = nil
		pcall(function()
			part = EggsUtil.GetEggPart(eggDir.eggNumber)
		end)
		if part and ch then
			pcall(function()
				ch:PivotTo(part.CFrame * CFrame.new(0, yOff, 0))
			end)
			stabilizeCharacterPhysics(ch)
			log("Pivot to physical egg", eggDir.eggNumber)
		else
			log("Failed to find physical egg part for", eggDir.eggNumber)
		end
	end
end

local zonesIdMatch, playerNearZoneTeleportPoint
do
	local function normZoneId(z)
		if type(z) ~= "string" then
			return nil
		end
		return (string.gsub(z, "^%s*(.-)%s*$", "%1"))
	end
	zonesIdMatch = function(a, b)
		local na = normZoneId(a)
		local nb = normZoneId(b)
		if not na or not nb then
			return false
		end
		return na == nb
	end
	--- HRP рядом с клиентской точкой PERSISTENT/Teleport для зоны (без серверного Teleports_RequestTeleport).
	playerNearZoneTeleportPoint = function(zoneId, maxDist)
		if not ZonesUtil or type(zoneId) ~= "string" then
			return false
		end
		local md = maxDist or cfg().teleportClientPivotNearStuds or 32
		local cf = nil
		pcall(function()
			cf = ZonesUtil.GetTeleportPartLocation(zoneId)
		end)
		if not cf then
			return false
		end
		local ch = LocalPlayer.Character
		local pp = ch and ch.PrimaryPart
		if not pp then
			return false
		end
		return (pp.Position - cf.Position).Magnitude <= md
	end
end

local Teleports = {}

function Teleports.schedulePivotRepeats(maxId)
	if not ZonesUtil then
		return
	end
	local yOff = cfg().teleportPivotYOffset or 3
	local reps = math.max(1, cfg().teleportPivotRepeatCount or 1)
	local delayFrames = math.max(0, cfg().teleportPivotRepeatDelayFrames or 0)
	local cannonFix = cfg().teleportCannonWorkaround == true
	task.spawn(function()
		task.wait(0.06)
		local prevCannon = nil
		if cannonFix and Variables then
			pcall(function()
				prevCannon = Variables.IsUsingCannon
				Variables.IsUsingCannon = false
			end)
		end
		for i = 1, reps do
			if i > 1 then
				local skips = delayFrames > 0 and delayFrames or 1
				for _ = 1, skips do
					RunService.RenderStepped:Wait()
				end
			end
			local cf = nil
			pcall(function()
				cf = ZonesUtil.GetTeleportPartLocation(maxId)
			end)
			local ch = LocalPlayer.Character
			if cf and ch and ch.PrimaryPart then
				pcall(function()
					ch:PivotTo(cf * CFrame.new(0, yOff, 0))
				end)
			end
		end
		if cannonFix and Variables and prevCannon ~= nil then
			pcall(function()
				Variables.IsUsingCannon = prevCannon
			end)
		end
	end)
end

local function tryQuestEggHatchAssist(tracked, opts)
	opts = opts or {}
	local progressOnly = opts.progressOnly == true
	if not cfg().questAutoHatch or not HatchingCmds or not EggCmds or not HatchingTypes or not EggsUtil then
		return
	end
	if hatchBusy then
		return
	end
	local gen = (tracked and tracked._generatorName) or ""
	if not cfg().questAutoHatchAnytime and not progressOnly then
		local blob = string.lower(QuestAssist.flattenObjectiveText(tracked))
		if not string.find(blob, "hatch", 1, true) and not string.find(blob, "egg", 1, true) then
			return
		end
	end
	local now = tick()
	if progressOnly then
		local pcd = cfg().autoHatchProgressCooldown
		if type(pcd) == "number" and pcd > 0 and (now - lastProgressOnlyHatchTick) < pcd then
			return
		end
	end
	if now - lastQuestHatchTick < (cfg().questHatchAssistInterval or 1.1) then
		return
	end
	local n, fromQuestText = HatchAssist.pickEggNumberForHatch(tracked)
	if n <= 0 then
		return
	end
	local eggDir = EggsUtil.GetByNumber(n)
	if not eggDir or not eggDir._id then
		return
	end

	if cfg().questEggTeleportIfWrongZone and fromQuestText and MapCmds and Network and TeleportMapCmds then
		local cur = MapCmds.GetCurrentZone()
		local eggZ = getEggZoneIdForNumber(n)
		if eggZ and cur and eggZ ~= cur then
			local can = false
			local reason = nil
			pcall(function()
				can, reason = TeleportMapCmds.CanTeleportTo(eggZ)
			end)
			if can then
				lastQuestHatchTick = now
				armHatchBusyEnd(cfg().hatchBusyHoldSeconds or 2.6)
				if progressOnly then
					lastProgressOnlyHatchTick = now
				end
				if cfg().questEggTeleportClientPivotOnly ~= false then
					log("quest egg client pivot → zone", eggZ, "for", eggDir._id, reason)
					Teleports.schedulePivotRepeats(eggZ)
				else
					pcall(function()
						Network.Invoke("Teleports_RequestTeleport", eggZ)
					end)
					log("quest egg TP → zone", eggZ, "for", eggDir._id, reason)
					Teleports.schedulePivotRepeats(eggZ)
				end
				return true
			end
		end
	end

	local locked = false
	pcall(function()
		locked = EggCmds.IsEggLocked(eggDir._id) == true
	end)
	if locked and cfg().questAutoUnlockEgg then
		lastQuestHatchTick = now
		pcall(function()
			EggCmds.RequestUnlock(eggDir._id)
		end)
		log("Eggs_RequestUnlock", eggDir._id)
		return
	end
	local hatchAmt = 1
	pcall(function()
		local mx = EggCmds.GetMaxHatch(eggDir)
		hatchAmt = math.clamp(mx or 1, 1, 12)
	end)
	lastQuestHatchTick = now

	local pivotDelay = cfg().hatchAfterPivotDelay or 0.38
	local busyHold = cfg().hatchBusyHoldSeconds or 2.6

	local function runPurchaseInvoke(customUid)
		if customUid then
			Network.Invoke("CustomEggs_Hatch", customUid, hatchAmt)
		elseif EggCmds and type(EggCmds.RequestPurchase) == "function" then
			EggCmds.RequestPurchase(eggDir._id, hatchAmt)
		else
			Network.Invoke("Eggs_RequestPurchase", eggDir._id, hatchAmt)
		end
	end

	if cfg().hideEggHatching then
		local customUid = nil
		if CustomEggsCmds and eggDir._id then
			pcall(function()
				customUid = CustomEggsCmds.GetClosestById(eggDir._id)
			end)
		end
		armHatchBusyEnd(busyHold)
		task.spawn(function()
			pcall(function()
				HatchAssist.pivotForEgg(eggDir, tracked)
				task.wait(pivotDelay)
				runPurchaseInvoke(customUid)
				local nBurst = tonumber(cfg().eggOpeningPostInvokeBurstCount)
				local dBurst = tonumber(cfg().eggOpeningPostInvokeBurstDelay)
				if type(nBurst) == "number" and nBurst > 0 and type(dBurst) == "number" and dBurst >= 0 then
					for _ = 1, nBurst do
						task.wait(dBurst)
						tryClickEggOpeningPrompt({ ignoreThrottles = true })
					end
				end
			end)
		end)
		if progressOnly then
			lastProgressOnlyHatchTick = now
		end
		log("quest hatch (hidden)", eggDir._id, hatchAmt, gen)
		return true
	end

	local autoOpt = HatchingTypes.Options and HatchingTypes.Options.AUTO
	if autoOpt then
		pcall(function()
			HatchingCmds.Enable(autoOpt)
		end)
	end
	local customUid = nil
	if CustomEggsCmds and eggDir._id then
		pcall(function()
			customUid = CustomEggsCmds.GetClosestById(eggDir._id)
		end)
	end
	armHatchBusyEnd(busyHold)
	task.spawn(function()
		pcall(function()
			HatchAssist.pivotForEgg(eggDir, tracked)
			task.wait(pivotDelay)
			if customUid then
				HatchingCmds.SetupCustomEgg(customUid, eggDir, hatchAmt)
			else
				HatchingCmds.SetupEgg(eggDir, hatchAmt)
			end
			HatchingCmds.AttemptHatch()
		end)
	end)
	if progressOnly then
		lastProgressOnlyHatchTick = now
	end
	log("quest hatch", eggDir._id, hatchAmt, gen)
	return true
end

--- Минигame: один IIFE → таблица (иначе корневой чанк превышает лимит ~200 локалей Luau).
local MinigameAssist = (function()
	local function forEachDescendantDepthLimited(root, maxDepth, callback)
		if not root or type(callback) ~= "function" then
			return
		end
		local function visit(inst, depth)
			callback(inst, depth)
			if depth >= maxDepth then
				return
			end
			for _, ch in ipairs(inst:GetChildren()) do
				visit(ch, depth + 1)
			end
		end
		visit(root, 0)
	end

	local function tryWave2Proximity(root, label)
		local maxD = cfg().minigameWave2SearchDepth or 14
		local maxP = cfg().minigameWave2MaxPromptsPerTick or 8
		local ch = LocalPlayer.Character
		local pp = ch and ch.PrimaryPart
		if not pp or not root then
			return
		end
		local fired = 0
		forEachDescendantDepthLimited(root, maxD, function(inst)
			if fired >= maxP then
				return
			end
			if inst:IsA("ProximityPrompt") and inst.Enabled then
				local parent = inst.Parent
				if parent and parent:IsA("BasePart") then
					local dist = (parent.Position - pp.Position).Magnitude
					if dist <= (inst.MaxActivationDistance or 10) + 10 then
						Exec.fireProximityPrompt(inst)
						fired = fired + 1
					end
				end
			end
		end)
		if fired > 0 and label then
			traceThrottled("minigame_wave2_" .. tostring(label), 2, "minigame", label, "prompts", fired)
		end
	end

	local function tryGenericObbyFinish(root, instanceId)
		if not root then
			return
		end
		local maxD = cfg().minigameObbyFinishSearchDepth or 26
		local names = cfg().minigameObbyFinishPartNames or {}
		local nameSet = {}
		for _, n in ipairs(names) do
			nameSet[string.lower(tostring(n))] = true
		end
		local best, bestY = nil, -1e9
		local bestCk, bestCkY = nil, -1e9
		local function considerPart(p)
			if not p or not p:IsA("BasePart") then
				return
			end
			local ln = string.lower(p.Name)
			if nameSet[ln] then
				local y = p.Position.Y
				if y > bestY then
					bestY = y
					best = p
				end
			elseif cfg().minigameObbyPreferCheckpointFallback ~= false and string.find(ln, "checkpoint", 1, true) then
				local y = p.Position.Y
				if y > bestCkY then
					bestCkY = y
					bestCk = p
				end
			end
		end
		forEachDescendantDepthLimited(root, maxD, function(inst)
			considerPart(inst)
		end)
		local target = best or bestCk
		if not target then
			return
		end
		local ch2 = LocalPlayer.Character
		local pp = ch2 and ch2.PrimaryPart
		if not pp then
			return
		end
		if (pp.Position - target.Position).Magnitude > 12 then
			pivotCharacterToCFrame(target.CFrame * CFrame.new(0, 4, 0))
			log("minigame obby pivot", instanceId, target.Name)
		end
		if cfg().minigameObbyTouchNearbyParts then
			for _, chChild in ipairs(target:GetChildren()) do
				if chChild:IsA("BasePart") then
					Exec.fireTouchInterest(chChild, pp, 0)
				end
			end
			Exec.fireTouchInterest(target, pp, 0)
		end
		if cfg().minigameObbyFireChildPrompts then
			local nPrompt = 0
			forEachDescendantDepthLimited(target, 4, function(inst)
				if nPrompt > 12 then
					return
				end
				if inst:IsA("ProximityPrompt") and inst.Enabled then
					Exec.fireProximityPrompt(inst)
					nPrompt = nPrompt + 1
				end
			end)
		end
	end

	local function wave2Combo(root, label)
		tryWave2Proximity(root, label)
		tryGenericObbyFinish(root, label)
	end

	local function instanceIdInMinigameList(id, list)
		if type(id) ~= "string" or id == "" or type(list) ~= "table" then
			return false
		end
		for _, v in ipairs(list) do
			if v == id then
				return true
			end
		end
		return false
	end

	local function shouldQuestAutoLeaveInstanceId(id)
		if type(id) ~= "string" or id == "" then
			return false
		end
		local mode = cfg().minigameAssistMode or "skip"
		local explicit = cfg().instanceIdsForceLeave
		if type(explicit) == "table" and #explicit > 0 then
			return instanceIdInMinigameList(id, explicit)
		end
		local list = cfg().questBlockedInstanceIds
		if type(list) ~= "table" or not instanceIdInMinigameList(id, list) then
			return false
		end
		if mode == "complete" and instanceIdInMinigameList(id, cfg().minigameAutoPlayInstanceIds or {}) then
			return false
		end
		return true
	end

	local function getMinigameInstanceRoot(instanceId)
		if type(instanceId) ~= "string" or instanceId == "" then
			return nil
		end
		local things = workspace:FindFirstChild("__THINGS")
		if not things then
			return nil
		end
		local instances = things:FindFirstChild("Instances")
		if not instances then
			return nil
		end
		local folder = instances:FindFirstChild(instanceId)
		if folder then
			return folder
		end
		if InstancingCmds then
			local m = nil
			pcall(function()
				m = InstancingCmds.Get and InstancingCmds.Get()
				if not m and InstancingCmds.GetModel then
					m = InstancingCmds.GetModel()
				end
			end)
			if m then
				return m
			end
		end
		return nil
	end

	local fishing = function(root)
		wave2Combo(root, "Fishing")
	end
	local digsite = function(root)
		wave2Combo(root, "Digsite")
	end
	local chestRush = function(root)
		wave2Combo(root, "ChestRush")
	end
	local wave2Handlers = {
		Fishing = fishing,
		AdvancedFishing = fishing,
		FishingEvent = fishing,
		Digsite = digsite,
		AdvancedDigsite = digsite,
		ChestRush = chestRush,
	}

	return {
		instanceIdInMinigameList = instanceIdInMinigameList,
		shouldQuestAutoLeaveInstanceId = shouldQuestAutoLeaveInstanceId,
		getMinigameInstanceRoot = getMinigameInstanceRoot,
		tryGenericObbyFinish = tryGenericObbyFinish,
		wave2Handlers = wave2Handlers,
	}
end)()

--- Ниже: методы AutoRankRuntimeState (локальные function — свой лимит регистров).
function AutoRankRuntimeState.tryTeleportToMaxFarmZone(trackedObjective, isHatching)
	if isHatching or hatchBusy then
		return
	end

	local cur = nil
	local maxId = nil
	pcall(function()
		cur = MapCmds and MapCmds.GetCurrentZone()
	end)
	pcall(function()
		maxId = ZoneCmds and select(1, ZoneCmds.GetMaxOwnedZone())
	end)
	local behindMax = cur and maxId and type(maxId) == "string" and not zonesIdMatch(cur, maxId)

	local skipRemoteTp = cfg().advancedRemoteFarm and cfg().remoteFarmSkipMaxZoneTeleport
	if cfg().forceTeleportWhenBehindMaxZone and behindMax then
		skipRemoteTp = false
		if cfg().advancedRemoteFarm and cfg().remoteFarmSkipMaxZoneTeleport then
			traceThrottled("teleport_force_max_zone", 10, "teleport", "forceTeleportWhenBehindMaxZone", cur, "->", maxId)
		end
	end
	if skipRemoteTp then
		return
	end

	if trackedObjective and cfg().questAssistSkipFarmTeleportWhenObjective and objectiveHasWorldTarget(trackedObjective) then
		return
	end
	if not cfg().teleportToMaxFarmZone or not teleportFlagOk() then
		return
	end
	local okIn, inInst = pcall(function()
		return InstancingCmds and InstancingCmds.IsInInstance and InstancingCmds.IsInInstance()
	end)
	if okIn and inInst then
		return
	end
	if not TeleportMapCmds or not ZoneCmds or not MapCmds or not Network or not ZonesUtil then
		return
	end
	local now = tick()
	if now - lastTeleportTick < (cfg().teleportInterval or 10) then
		return
	end
	local maxZoneId = select(1, ZoneCmds.GetMaxOwnedZone())
	if not maxZoneId or type(maxZoneId) ~= "string" then
		return
	end
	local curZone = MapCmds.GetCurrentZone()
	if zonesIdMatch(curZone, maxZoneId) then
		if cfg().teleportClientPivotWhenSameZone and not playerNearZoneTeleportPoint(maxZoneId) then
			lastTeleportTick = now
			log("teleport same zone client pivot", maxZoneId)
			Teleports.schedulePivotRepeats(maxZoneId)
		end
		return
	end
	local can, reason = TeleportMapCmds.CanTeleportTo(maxZoneId)
	if not can then
		log("teleport skip CanTeleportTo", maxZoneId, reason)
		return
	end
	lastTeleportTick = now
	if cfg().teleportMaxZoneClientPivotOnly ~= false then
		log("teleport client pivot max zone", maxZoneId, "from", curZone)
		Teleports.schedulePivotRepeats(maxZoneId)
		return
	end
	local invokeOk = false
	pcall(function()
		local r = Network.Invoke("Teleports_RequestTeleport", maxZoneId)
		invokeOk = r ~= false and r ~= nil
	end)
	if not invokeOk then
		log("Teleports_RequestTeleport failed", maxZoneId)
		return
	end
	log("Teleport pivot (server+client)", maxZoneId, "from", curZone)
	Teleports.schedulePivotRepeats(maxZoneId)
end

function AutoRankRuntimeState.getBreakableFarmCenterPosition(zoneId)
	if not ZonesUtil or type(zoneId) ~= "string" then
		return nil
	end
	local folder = nil
	pcall(function()
		folder = ZonesUtil.GetBreakableSpawns(zoneId)
	end)
	if not folder then
		return nil
	end
	local order = cfg().farmBreakableSpawnPartPriority
	if type(order) ~= "table" or #order == 0 then
		order = { "Main", "Easy", "VIP" }
	end
	for _, name in ipairs(order) do
		local p = folder:FindFirstChild(name)
		if p and p:IsA("BasePart") then
			return p.Position
		end
	end
	for _, ch in ipairs(folder:GetChildren()) do
		if ch:IsA("BasePart") then
			return ch.Position
		end
	end
	return nil
end

--- После телепорта игрок часто на точке «Teleport», а не над BREAKABLE_SPAWNS — тянем в центр Main.
function AutoRankRuntimeState.tryPivotToBreakableFarmCenter(isHatching)
	if isHatching or hatchBusy or not cfg().teleportToBreakableFarmCenter then
		return
	end
	if cfg().advancedRemoteFarm and cfg().remoteFarmSkipBreakablePull then
		return
	end
	local okIn, inInst = pcall(function()
		return InstancingCmds and InstancingCmds.IsInInstance and InstancingCmds.IsInInstance()
	end)
	if okIn and inInst then
		return
	end
	if not ZonesUtil or not ZoneCmds or not MapCmds then
		return
	end
	local maxId = select(1, ZoneCmds.GetMaxOwnedZone())
	if not maxId or type(maxId) ~= "string" then
		return
	end
	local cur = MapCmds.GetCurrentZone()
	if cur ~= maxId then
		return
	end
	local pos = AutoRankRuntimeState.getBreakableFarmCenterPosition(maxId)
	if not pos then
		return
	end
	local ch = LocalPlayer.Character
	local pp = ch and ch.PrimaryPart
	if not pp then
		return
	end
	if (pp.Position - pos).Magnitude < (cfg().farmBreakableMinDist or 20) then
		return
	end
	local now = tick()
	if now - lastFarmCenterTick < (cfg().farmBreakablePullInterval or 1.15) then
		return
	end
	lastFarmCenterTick = now
	local yOff = cfg().farmBreakableYOffset or 5
	pcall(function()
		pp.CFrame = CFrame.new(pos + Vector3.new(0, yOff, 0))
	end)
	log("BREAKABLE_SPAWNS pivot", maxId, pos)
end

function AutoRankRuntimeState.tryMinigameTouchLeaveTeleport(root)
	if not root then
		return
	end
	local leave = root:FindFirstChild("LeaveTeleport", true)
	if not leave or not leave:IsA("BasePart") then
		return
	end
	local ch = LocalPlayer.Character
	local pp = ch and ch.PrimaryPart
	if not pp then
		return
	end
	if (pp.Position - leave.Position).Magnitude < 22 then
		Exec.fireTouchInterest(leave, pp, 0)
	end
end

function AutoRankRuntimeState.tryMinigameAssistPulse()
	local now = tick()
	if now - lastMinigameAssistTick < (cfg().minigameAssistTickInterval or 0.16) then
		return
	end
	lastMinigameAssistTick = now
	if not InstancingCmds then
		return
	end
	local okIn, inInst = pcall(function()
		return InstancingCmds.IsInInstance()
	end)
	if not okIn or not inInst then
		minigameSessionInstanceId = nil
		return
	end
	local id = nil
	pcall(function()
		id = InstancingCmds.GetInstanceID and InstancingCmds.GetInstanceID()
	end)
	if type(id) ~= "string" or id == "" then
		return
	end
	if minigameSessionInstanceId ~= id then
		minigameSessionInstanceId = id
		minigameSessionStartTick = now
	end
	local mode = cfg().minigameAssistMode or "skip"
	local root = MinigameAssist.getMinigameInstanceRoot(id)

	if mode ~= "complete" then
		return
	end

	if not MinigameAssist.instanceIdInMinigameList(id, cfg().minigameAutoPlayInstanceIds or {}) then
		return
	end

	if now - minigameSessionStartTick > (cfg().minigameStuckLeaveSeconds or 90) then
		pcall(function()
			if type(InstancingCmds.Leave) == "function" then
				InstancingCmds.Leave()
			end
		end)
		log("minigame stuck timeout Leave", id)
		minigameSessionInstanceId = nil
		return
	end

	if not root then
		return
	end

	local w2 = MinigameAssist.wave2Handlers[id]
	if w2 then
		w2(root)
	else
		MinigameAssist.tryGenericObbyFinish(root, id)
	end

	AutoRankRuntimeState.tryMinigameTouchLeaveTeleport(root)
end

function AutoRankRuntimeState.tryQuestAutoLeaveBlockedInstance()
	if not cfg().questAutoLeaveBlockedInstances or not InstancingCmds then
		return
	end
	local okIn, inInst = pcall(function()
		return InstancingCmds.IsInInstance()
	end)
	if not okIn or not inInst then
		return
	end
	local id = nil
	pcall(function()
		id = InstancingCmds.GetInstanceID and InstancingCmds.GetInstanceID()
	end)
	if type(id) ~= "string" or id == "" then
		return
	end
	if not MinigameAssist.shouldQuestAutoLeaveInstanceId(id) then
		return
	end
	pcall(function()
		if type(InstancingCmds.Leave) == "function" then
			InstancingCmds.Leave()
		end
	end)
	log("InstancingCmds.Leave", id)
end

function AutoRankRuntimeState.runQuestAssistPulse()
	if not cfg().questAssistEnabled then
		cachedTrackedObjective = nil
		AutoRankRuntimeState.diagQuest = {
			ok = false,
			where = "config",
			detail = "questAssistEnabled_false",
		}
		return nil, false
	end
	tryHatchBusyWatchdog()
	AutoRankRuntimeState.tryQuestAutoLeaveBlockedInstance()
	local okIn, inInst = pcall(function()
		return InstancingCmds and InstancingCmds.IsInInstance and InstancingCmds.IsInInstance()
	end)
	if not okIn then
		cachedTrackedObjective = nil
		AutoRankRuntimeState.diagQuest = {
			ok = false,
			where = "instance",
			detail = "IsInInstance_pcall_failed",
		}
		return nil, false
	end
	if inInst then
		cachedTrackedObjective = nil
		AutoRankRuntimeState.diagQuest = {
			ok = false,
			where = "instance",
			detail = "quest_pulse_skipped_in_instance",
		}
		return nil, false
	end
	local tracked = refreshTrackedObjective()
	local isHatching = false
	if tracked then
		local qaOk, qaErr = pcall(function()
			QuestAssist.tryKeywordCooldownReset(tracked)
			tryQuestResolveDisplayTargets(tracked)
			if tracked and not QuestAssist.shouldSkipObjectiveInteraction(tracked) then
				tryTravelWorldDirectNetworkFire(tracked._generatorName)
			end
		end)
		if not qaOk then
			warnErr("quest_resolve_targets", qaErr)
		end
		local hhOk, hhErr = pcall(function()
			isHatching = tryQuestEggHatchAssist(tracked) == true or hatchBusy == true
		end)
		if not hhOk then
			warnErr("tryQuestEggHatchAssist", hhErr)
		end
	end
	local pfOk, pfErr = pcall(function()
		tryQuestPlaceFlexibleFlag(tracked)
	end)
	if not pfOk then
		warnErr("tryQuestPlaceFlexibleFlag", pfErr)
	end
	pcall(function()
		tryQuestEquipEnchantFromInventory()
	end)
	local dqEnd = AutoRankRuntimeState.diagQuest
	if cfg().autoHatchProgressWithoutQuest and cfg().questAutoHatch and not hatchBusy then
		local wantProgress = not tracked
			or (tracked and QuestAssist.shouldSkipObjectiveInteraction(tracked))
			or (dqEnd and (dqEnd.where == "no_goal" or dqEnd.where == "tab_blocked"))
		if wantProgress then
			local phOk, phErr = pcall(function()
				if tryQuestEggHatchAssist(nil, { progressOnly = true }) == true then
					isHatching = true
				end
			end)
			if not phOk then
				warnErr("tryQuestEggHatchAssist_progressOnly", phErr)
			end
		end
	end
	isHatching = isHatching or hatchBusy == true
	return tracked, isHatching
end

function AutoRankRuntimeState.tryAutoEquipBestPets()
	if not cfg().autoEquipBestPetsEnabled or not PetCmds or type(PetCmds.EquipBest) ~= "function" then
		return
	end
	local now = tick()
	if now - lastAutoEquipBestTick < (cfg().autoEquipBestPetsInterval or 14) then
		return
	end
	local okIn, inInst = pcall(function()
		return InstancingCmds and InstancingCmds.IsInInstance and InstancingCmds.IsInInstance()
	end)
	if okIn and inInst then
		return
	end
	lastAutoEquipBestTick = now
	pcall(function()
		PetCmds.EquipBest()
	end)
	log("PetCmds.EquipBest")
end

function AutoRankRuntimeState.tryClaimRankRewards()
	if not cfg().autoClaimRankRewards or not Network then
		return
	end
	local now = tick()
	if now - lastClaimTick < (cfg().claimInterval or 0.35) then
		return
	end
	do
		local allowed = true
		if FFlags then
			local ok, gate = pcall(function()
				return FFlags.Get(FFlags.Keys.RankRewards) or FFlags.CanBypass()
			end)
			allowed = ok and gate or false
		end
		if not allowed then
			return
		end
	end
	local keys = getClaimableRewardKeys()
	if #keys == 0 then
		return
	end
	lastClaimTick = now
	local spacing = cfg().claimDebounce or 0.28
	task.spawn(function()
		for i, key in ipairs(keys) do
			pcall(function()
				Network.Fire("Ranks_ClaimReward", key)
			end)
			log("claim Ranks_ClaimReward", key)
			if i < #keys then
				task.wait(spacing)
			end
		end
	end)
end

function AutoRankRuntimeState.tryRankUpViaGui()
	if not cfg().autoRankUpGui then
		return
	end
	local now = tick()
	if now - lastRankUpGuiTick < (cfg().rankUpGuiInterval or 1.2) then
		return
	end
	if not RankCmds or not GUI then
		return
	end
	if RankCmds.IsMaxRank() then
		return
	end
	local blockedZone = select(1, RankCmds.IsRankBlockedByZone())
	if blockedZone then
		return
	end
	if not RankCmds.AllRewardsRedeemed() then
		return
	end
	lastRankUpGuiTick = now
	local okR, rankGui = pcall(function()
		return GUI.Rank()
	end)
	if not okR or not rankGui then
		return
	end
	local side = rankGui.Frame and rankGui.Frame.Side
	local btn = side and side.MiddleRankUpReady
	if btn and btn.Visible then
		local fired = clickGuiButtonRobust(btn)
		log("rank up GUI MiddleRankUpReady", fired)
	end
end

function AutoRankRuntimeState.farmBreakableClassList()
	local t = cfg().farmBreakableClasses
	if type(t) ~= "table" or #t == 0 then
		return { "Normal" }
	end
	return t
end

--- Кэш тяжёлого AllByZoneAndClass × N классов между кадрами Heartbeat

function AutoRankRuntimeState.farmCandidateCacheStore(list, diag)
	local fc = AutoRankRuntimeState.farmCandidateCache
	fc.list = list
	fc.at = tick()
	fc.diag = diag
end

function AutoRankRuntimeState.farmDiagNew()
	return {
		rawTotal = 0,
		rawTapOk = 0,
		inRadius = 0,
		zoneId = nil,
		perClass = {},
		posSource = "character",
		inInstance = false,
		radius = 0,
		reasonEmpty = "",
	}
end

function AutoRankRuntimeState.farmGetInInstanceFlag()
	if not InstancingCmds or not InstancingCmds.IsInInstance then
		return false
	end
	local ok, res = pcall(function()
		return InstancingCmds.IsInInstance()
	end)
	return ok and res == true
end

--- Позиция скана, zoneId, множитель радиуса; при отсутствии pos — diag.reasonEmpty и nil.
function AutoRankRuntimeState.farmResolveScanOrigin(diag)
	local pos = characterPrimaryPosition()
	local zoneId = MapCmds.GetCurrentZone()
	diag.zoneId = zoneId
	local mult = 1
	local inInstance = AutoRankRuntimeState.farmGetInInstanceFlag()
	diag.inInstance = inInstance
	if cfg().advancedRemoteFarm and not inInstance and cfg().remoteFarmUseMaxZoneAnchor and ZoneCmds then
		local maxId = select(1, ZoneCmds.GetMaxOwnedZone())
		if maxId and type(maxId) == "string" then
			local anchor = AutoRankRuntimeState.getBreakableFarmCenterPosition(maxId)
			if anchor then
				pos = anchor
				zoneId = maxId
				diag.zoneId = zoneId
				diag.posSource = "max_zone_anchor"
				mult = tonumber(cfg().remoteFarmRadiusMultiplier) or 1
				if mult < 1 then
					mult = 1
				end
			end
		end
	end
	if not pos then
		diag.reasonEmpty = "no_character_position"
		return nil, nil, mult
	end
	return pos, zoneId, mult
end

function AutoRankRuntimeState.farmMergeBreakableChunks(zoneId, inInstance, classes, diag)
	local byUid = {}
	for _, cls in ipairs(classes) do
		local chunk = nil
		local ok, err = pcall(function()
			if inInstance then
				chunk = BreakableFrontend.AllByInstanceAndClass(cls)
			elseif zoneId then
				chunk = BreakableFrontend.AllByZoneAndClass(zoneId, cls)
			end
		end)
		if not ok then
			diag.perClass[cls] = "err:" .. tostring(err)
			traceThrottled("farmClassErr_" .. cls, cfg().traceInterval, "farm", "AllByZoneAndClass failed", cls, err)
		else
			local n = 0
			for uid, entry in pairs(chunk or {}) do
				byUid[uid] = entry
				n += 1
			end
			diag.perClass[cls] = n
		end
	end
	for _ in pairs(byUid) do
		diag.rawTotal += 1
	end
	return byUid
end

function AutoRankRuntimeState.farmListInRadius(byUid, pos, r, diag)
	local out = {}
	for uid, entry in pairs(byUid) do
		local model = entry.model
		local pp = model and model.PrimaryPart
		if pp and entry.dir and not entry.dir.NoTapping and not entry.disableDamage then
			diag.rawTapOk += 1
			local d = (pp.Position - pos).Magnitude
			if d <= r then
				table.insert(out, { uid = uid, entry = entry, d = d })
			end
		end
	end
	if cfg().preferClosest then
		table.sort(out, function(a, b)
			return a.d < b.d
		end)
	end
	diag.inRadius = #out
	return out
end

function AutoRankRuntimeState.farmFinalizeEmptyListDiag(diag, r, out)
	if #out ~= 0 then
		return
	end
	if diag.reasonEmpty == "" then
		if diag.rawTotal == 0 then
			diag.reasonEmpty = "zero_breakables_merged_classes"
		elseif diag.rawTapOk == 0 then
			diag.reasonEmpty = "all_NoTapping_or_disableDamage"
		else
			diag.reasonEmpty = string.format("none_in_radius (r=%.0f pos=%s zone=%s)", r, diag.posSource, tostring(diag.zoneId))
		end
	end
	traceThrottled("farmEmpty", cfg().traceInterval, "farm", diag.reasonEmpty, "perClass=", diag.perClass)
end

function AutoRankRuntimeState.collectFarmCandidates()
	local iv = cfg().farmCandidateScanInterval
	local now = tick()
	local fc = AutoRankRuntimeState.farmCandidateCache
	if type(iv) == "number" and iv > 0 and fc.list ~= nil and (now - fc.at) < iv then
		if fc.diag then
			AutoRankRuntimeState.diagFarm = fc.diag
		end
		return fc.list
	end

	local diag = AutoRankRuntimeState.farmDiagNew()
	AutoRankRuntimeState.diagFarm = diag

	if not BreakableFrontend or not MapCmds then
		diag.reasonEmpty = "BreakableFrontend_or_MapCmds_nil"
		AutoRankRuntimeState.farmCandidateCacheStore({}, diag)
		return {}
	end

	local pos, zoneId, mult = AutoRankRuntimeState.farmResolveScanOrigin(diag)
	if not pos then
		AutoRankRuntimeState.farmCandidateCacheStore({}, diag)
		return {}
	end

	local classes = AutoRankRuntimeState.farmBreakableClassList()
	local byUid = AutoRankRuntimeState.farmMergeBreakableChunks(zoneId, diag.inInstance, classes, diag)
	local r = (cfg().farmRadius or 420) * mult
	diag.radius = r
	local out = AutoRankRuntimeState.farmListInRadius(byUid, pos, r, diag)
	AutoRankRuntimeState.farmFinalizeEmptyListDiag(diag, r, out)
	AutoRankRuntimeState.farmCandidateCacheStore(out, diag)
	return out
end

function AutoRankRuntimeState.farmTick()
	if hatchBusy then
		return
	end
	if not cfg().farmNormalBreakables then
		return
	end
	local list = AutoRankRuntimeState.collectFarmCandidates()
	local top = list[1]
	if not top then
		currentFocusUid = nil
		return
	end
	focusBreakable(top.uid)
	dealDamage(top.uid)
	tryFarmFireClickDetectorFallback(top.entry)
end

function AutoRankRuntimeState.tutorialTick()
	if not cfg().tutorialHideGoalArrow then
		return
	end
	local now = tick()
	if now - AutoRankRuntimeState.lastTutorialArrowTick < (cfg().tutorialArrowInterval or 2) then
		return
	end
	AutoRankRuntimeState.lastTutorialArrowTick = now
	pcall(function()
		LocalPlayer:SetAttribute("ActiveGoalArrow", true)
	end)
end

function AutoRankRuntimeState.refreshTeleportDiagSnapshot(trackedObjective, isHatching)
	local d = {}
	pcall(function()
		d.cur = MapCmds and MapCmds.GetCurrentZone()
	end)
	pcall(function()
		d.maxOwned = select(1, ZoneCmds.GetMaxOwnedZone())
	end)
	local skip = nil
	local behindMax = d.cur and d.maxOwned and type(d.maxOwned) == "string" and not zonesIdMatch(d.cur, d.maxOwned)
	local skipRemoteTp = cfg().advancedRemoteFarm and cfg().remoteFarmSkipMaxZoneTeleport
	if cfg().forceTeleportWhenBehindMaxZone and behindMax then
		skipRemoteTp = false
	end
	if isHatching or hatchBusy then
		skip = "hatching_or_hatchBusy"
	elseif skipRemoteTp then
		skip = "remoteFarmSkipMaxZoneTeleport"
	elseif trackedObjective and cfg().questAssistSkipFarmTeleportWhenObjective and objectiveHasWorldTarget(trackedObjective) then
		skip = "quest_world_target_blocks_farm_teleport"
	elseif not cfg().teleportToMaxFarmZone then
		skip = "teleportToMaxFarmZone_disabled"
	elseif not teleportFlagOk() then
		skip = "teleport_fflag_blocked"
	else
		local okIn, inInst = pcall(function()
			return InstancingCmds and InstancingCmds.IsInInstance and InstancingCmds.IsInInstance()
		end)
		if okIn and inInst then
			skip = "player_in_instance"
		elseif not TeleportMapCmds or not ZoneCmds or not MapCmds or not Network or not ZonesUtil then
			skip = "teleport_modules_missing"
		else
			local nowT = tick()
			local interval = cfg().teleportInterval or 10
			local elapsed = nowT - lastTeleportTick
			if elapsed < interval then
				skip = string.format("teleport_interval %.1fs left", interval - elapsed)
			elseif not d.maxOwned or type(d.maxOwned) ~= "string" then
				skip = "no_max_owned_zone_id"
			elseif zonesIdMatch(d.cur, d.maxOwned) then
				if cfg().teleportMaxZoneClientPivotOnly ~= false then
					skip = "same_zone_client_pivot_if_far_from_marker"
				else
					skip = "already_at_max_owned_zone"
				end
			else
				local can, reason = TeleportMapCmds.CanTeleportTo(d.maxOwned)
				if not can then
					skip = "CanTeleportTo false: " .. tostring(reason)
				else
					skip = "ok_can_teleport (fires on interval tick)"
				end
			end
		end
	end
	d.skip = skip
	AutoRankRuntimeState.diagTeleport = d
end

function AutoRankRuntimeState.emitVerbosePulse(trackedQuest, isHatching)
	local df = AutoRankRuntimeState.diagFarm or {}
	local dq = AutoRankRuntimeState.diagQuest or {}
	local dt = AutoRankRuntimeState.diagTeleport or {}
	trace(
		"pulse",
		"zone_cur=",
		tostring(dt.cur),
		"maxOwned=",
		tostring(dt.maxOwned),
		"| teleport:",
		tostring(dt.skip)
	)
	trace(
		"pulse.farm",
		"raw=",
		df.rawTotal,
		"tapOk=",
		df.rawTapOk,
		"inRadius=",
		df.inRadius,
		"empty=",
		df.reasonEmpty or "-",
		"src=",
		df.posSource
	)
	if type(df.perClass) == "table" then
		trace("pulse.farm.perClass", df.perClass)
	end
	local ql = dq.ok and "OK" or "NO"
	trace(
		"pulse.quest",
		ql,
		tostring(dq.generator or dq.where or "-"),
		tostring(dq.snippet or dq.detail or "")
	)
	if not dq.ok then
		local dg = AutoRankRuntimeState.diagGoalPick
		if dg and type(dg.hints) == "table" and #dg.hints > 0 then
			trace("pulse.goalHints", table.concat(dg.hints, " | "))
		end
	end
	trace("pulse.flags", "hatchBusy=", hatchBusy, "isHatching=", isHatching)
	local rb = false
	pcall(function()
		rb = Variables and Variables.IsRebirthing == true
	end)
	if rb then
		trace("pulse", "Variables.IsRebirthing=true")
	end
end

--- Авто-клик "Yes" в диалогах (Message GUI) при перемещении
local function tryAutoClickMessageDialogYes()
	local pg = LocalPlayer:FindFirstChild("PlayerGui")
	if not pg then return end
	local msg = pg:FindFirstChild("Message")
	if not msg or not msg:IsA("ScreenGui") or not msg.Enabled then return end
	
	local clicked = false
	for _, d in ipairs(msg:GetDescendants()) do
		if d:IsA("GuiButton") and d.Visible then
			local t = string.lower(tostring(d.Name))
			local t2 = ""
			pcall(function()
				if d:IsA("TextLabel") or d:IsA("TextButton") then
					t2 = string.lower(tostring(d.Text))
				end
			end)
			if t == "yes" or string.find(t2, "yes", 1, true) then
				clicked = clickGuiButtonRobust(d) or clicked
				if clicked then
					log("Message dialog auto-clicked YES", d:GetFullName())
				end
			end
		end
	end
	return clicked
end

--- Вынесено из анонимного обработчика Heartbeat — меньше локальных регистров на замыкании (лимит Luau 200).
function AutoRankRuntimeState.autoRankHeartbeatWork()
	pcall(ensureModulesOnHeartbeat)
	tryDismissRebirthUi()
	tryAutoClickMessageDialogYes()
	tryInstallNetworkInvokeDebugHook()
	tryInstallKickGuard()
	patchOrbMagnet()
	hookOrbNetwork()
	AutoRankRuntimeState.tutorialTick()
	AutoRankRuntimeState.tryClaimRankRewards()
	AutoRankRuntimeState.tryRankUpViaGui()
	tryAutoBuyInstanceZone()
	tryAutoBuyMainZone()
	tryAutoBuyEggSlots()
	tryAutoBuyEquipSlots()
	tryAutoBuyCheapestUpgrade()
	tryAutoBuffConsumablesPulse()
	tryAutoDaycare()
	AutoRankRuntimeState.tryMinigameAssistPulse()
	local trackedQuest, isHatching = nil, false
	local qaOk, qaErr = pcall(function()
		trackedQuest, isHatching = AutoRankRuntimeState.runQuestAssistPulse()
	end)
	if not qaOk then
		warnErr("runQuestAssistPulse", qaErr)
	end
	tryClickEggOpeningPrompt()
	AutoRankRuntimeState.tryAutoEquipBestPets()
	tryClickReturnToMaxAreaButton()
	AutoRankRuntimeState.tryTeleportToMaxFarmZone(trackedQuest, isHatching)
	AutoRankRuntimeState.tryPivotToBreakableFarmCenter(isHatching)
	AutoRankRuntimeState.farmTick()
	tryCollectOrbs()
	return trackedQuest, isHatching
end

task.defer(function()
	pcall(tryRegisterCrossPlaceScriptReload)
end)

AutoRankRuntimeState.heartbeatConn = RunService.Heartbeat:Connect(function()
	if not cfg().enabled then
		return
	end
	local trackedQuest, isHatching = nil, false
	local hbOk, hbErr = pcall(function()
		trackedQuest, isHatching = AutoRankRuntimeState.autoRankHeartbeatWork()
	end)
	if not hbOk then
		warnErr("heartbeat", hbErr)
	end
	local now = tick()
	if cfg().verboseLog and now - lastVerbosePulseTick >= (cfg().traceInterval or 4) then
		lastVerbosePulseTick = now
		AutoRankRuntimeState.refreshTeleportDiagSnapshot(trackedQuest, isHatching)
		AutoRankRuntimeState.emitVerbosePulse(trackedQuest, isHatching)
	end
end)
