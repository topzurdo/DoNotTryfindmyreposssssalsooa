local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local GuiService = game:GetService("GuiService")

-- Config: getgenv().AutoRank = { ... } merged over defaults from auto_rank_defaults.lua via HttpGet (Git raw).
local LocalPlayer = Players.LocalPlayer
local autoRankLoadTick = tick()
-- Скрипт-версия (должна быть объявлена до AR.Log.resetFile).
local AUTO_RANK_RUNTIME_VERSION = 11

--[[ NAV: defaults HttpGet | autorank/worlds/* profiles | Net/log | ARQ | hatch | Farm | HB.tasks ]]

local AR = {
	Log = {},
	Exec = {},
	Modules = {},
	Net = {},
	AntiKick = {},
	UI = {},
	Pets = {},
	Reward = {},
	Lootbox = {},
	Cons = {},
	Farm = {},
	Quest = {},
	Buy = {},
	HB = {},
	CrossPlace = {},
}

-- Forward-declared: ARZone / tryTeleport reference ARQ before ARQ = {} assignment below.
local ARQ

-- World-specific overrides (autorank/worlds/*.lua), resolved via PlaceFile + registry.
local AutoRankWorld = {
	active = nil,
	_lastRefresh = 0,
}
AR.WorldProfile = AutoRankWorld

local function pcallWrap0(f) return pcall(f) end
local function pcallWrap1(f, a) return pcall(f, a) end
local function pcallWrap2(f, a, b) return pcall(f, a, b) end
local function pcallWrap3(f, a, b, c) return pcall(f, a, b, c) end
local function pcallWrap4(f, a, b, c, d) return pcall(f, a, b, c, d) end
AR.Log.pcallWrap0 = pcallWrap0
AR.Log.pcallWrap1 = pcallWrap1
AR.Log.pcallWrap2 = pcallWrap2
AR.Log.pcallWrap3 = pcallWrap3
AR.Log.pcallWrap4 = pcallWrap4

-- Defaults loader: remote only via HttpGet. Override URL with getgenv().AutoRankDefaultsUrl.
local AUTO_RANK_DEFAULTS_URL_FALLBACK = "https://raw.githubusercontent.com/topzurdo/DoNotTryfindmyreposssssalsooa/refs/heads/main/auto_rank_defaults.lua"

local function loadAutoRankInternalDefaults()
	local g0 = (getgenv and getgenv()) or _G
	local url = rawget(g0, "AutoRankDefaultsUrl")
	if type(url) ~= "string" or url == "" then
		url = AUTO_RANK_DEFAULTS_URL_FALLBACK
	end
	local ok, body = pcall(function()
		return game:HttpGet(url, true)
	end)
	if ok and type(body) == "string" and #body > 0 and loadstring then
		local f = loadstring(body, "@AutoRankDefaults")
		if f then
			local ok2, res = pcall(f)
			if ok2 and type(res) == "table" then
				return res
			end
		end
	end
	error("[AutoRank] Failed to load auto_rank_defaults.lua via HttpGet.")
end

local INTERNAL_DEFAULTS = loadAutoRankInternalDefaults()

local G = (getgenv and getgenv()) or _G
G.AutoRank = G.AutoRank or {}
for k, v in pairs(INTERNAL_DEFAULTS) do
	if G.AutoRank[k] == nil then
		G.AutoRank[k] = v
	end
end
if G.AutoRank.safeMode ~= false then
	G.AutoRank.netRateLimitPerSec = math.min(tonumber(G.AutoRank.netRateLimitPerSec) or 18, 18)
	G.AutoRank.delayDamage = math.max(tonumber(G.AutoRank.delayDamage) or 0.16, 0.16)
	G.AutoRank.farmMultiHitCount = 1
	G.AutoRank.farmSignalNearbyEnabled = false
	G.AutoRank.autoDaycareInterval = math.max(tonumber(G.AutoRank.autoDaycareInterval) or 20, 20)
	G.AutoRank.autoDaycareMaxClaimsPerTick = 1
	G.AutoRank.eggSlotMaxPurchasesPerPulse = math.min(tonumber(G.AutoRank.eggSlotMaxPurchasesPerPulse) or 3, 1)
	G.AutoRank.equipSlotMaxPurchasesPerPulse = math.min(tonumber(G.AutoRank.equipSlotMaxPurchasesPerPulse) or 3, 1)
	G.AutoRank.consumablesTickInterval = math.max(0.75, math.min(tonumber(G.AutoRank.consumablesTickInterval) or 2, 2))
	G.AutoRank.consumeFailureCooldown = math.max(4, math.min(tonumber(G.AutoRank.consumeFailureCooldown) or 8, 8))
	G.AutoRank.freeGiftsCheckInterval = math.max(1, math.min(tonumber(G.AutoRank.freeGiftsCheckInterval) or 2, 2))
	G.AutoRank.hbIntervalFreeRewards = math.max(1, math.min(tonumber(G.AutoRank.hbIntervalFreeRewards) or 2, 2))
	G.AutoRank.hbIntervalConsumables = math.max(0.75, math.min(tonumber(G.AutoRank.hbIntervalConsumables) or 2, 2))
	G.AutoRank.consumeDebugLog = false
	G.AutoRank.eggOpeningPromptClickInterval = math.max(tonumber(G.AutoRank.eggOpeningPromptClickInterval) or 0.65, 0.65)
	G.AutoRank.eggOpeningPostInvokeBurstCount = math.min(tonumber(G.AutoRank.eggOpeningPostInvokeBurstCount) or 1, 2)
	G.AutoRank.autoPickStarterPetsInterval = math.max(tonumber(G.AutoRank.autoPickStarterPetsInterval) or 1.5, 1.5)
	G.AutoRank.petsAlwaysFarmTickInterval = math.max(tonumber(G.AutoRank.petsAlwaysFarmTickInterval) or 8, 8)
	G.AutoRank.autoFarmEnableInterval = math.max(tonumber(G.AutoRank.autoFarmEnableInterval) or 15, 15)
	G.AutoRank.consumeTrustServerInventory = false
	G.AutoRank.hatchMaxBatchAllowed = math.min(tonumber(G.AutoRank.hatchMaxBatchAllowed) or 10, 3)
end

-- Одноразовые миграции старых getgenv().AutoRank
do
	local v = G.AutoRank._arNoQuestHatchMigrate or 0
	if v < 1 then
		G.AutoRank.autoHatchProgressWithoutQuest = true
		G.AutoRank._arNoQuestHatchMigrate = 1
	end
end
do
	local v = G.AutoRank._arNonEggProgressHatchMigrate or 0
	if v < 1 then
		G.AutoRank.autoHatchProgressWhenNonEggQuest = false
		G.AutoRank._arNonEggProgressHatchMigrate = 1
	end
end
do
	local v = G.AutoRank._arEconomyHatchBuffsV1 or 0
	if v < 1 then
		G.AutoRank.hatchReserveSkipForProgressOnly = false
		G.AutoRank.questConsumeScrapedPotionTierExactMatch = false
		G.AutoRank.questConsumeFruitsPreferMaxTier = true
		G.AutoRank._arEconomyHatchBuffsV1 = 1
	end
end
do
	local v = G.AutoRank._arEconomyHatchBuffsV2 or 0
	if v < 1 then
		G.AutoRank.hatchProgressTryCheaperEggWhenReserveBlocks = true
		G.AutoRank.hatchProgressFallbackEggMaxOwnedZoneOnly = true
		G.AutoRank.hatchAsyncGuardClearWithHatchBusyEarlyRelease = true
		G.AutoRank.miscGiftBagAssertionFailureCooldownSec = 300
		G.AutoRank._arEconomyHatchBuffsV2 = 1
	end
end
do
	local v = G.AutoRank._arEggOpeningUiMigrate or 0
	if v < 1 then
		-- Глобальный Mouse.Button1Down по всем коннекшенам ломал чужой UI; бандлы во время hatch давали GiftBag assertion.
		G.AutoRank.skipEggGuiClickWhenHiddenHatch = true
		G.AutoRank.eggOpeningPreferGuiButtonOverSyntheticMouse = true
		if G.AutoRank.safeMode ~= false then
			G.AutoRank.eggOpeningPostInvokeBurstCount = math.min(tonumber(G.AutoRank.eggOpeningPostInvokeBurstCount) or 1, 2)
		end
		G.AutoRank._arEggOpeningUiMigrate = 1
	end
end

local function cfg()
	return G.AutoRank
end

-- World/registry Lua — только HttpGet (база репозитория на GitHub raw).
local AUTO_RANK_REPO_BASE = "https://raw.githubusercontent.com/topzurdo/DoNotTryfindmyreposssssalsooa/refs/heads/main/"

local function loadAutoRankOptionalScript(relativePath)
	local rel = string.gsub(relativePath, "^%./", "")
	local url = AUTO_RANK_REPO_BASE .. rel
	local ok, body = pcall(function()
		return game:HttpGet(url, true)
	end)
	if ok and type(body) == "string" and #body > 0 then
		return body
	end
	local g0 = (getgenv and getgenv()) or _G
	local alt = rawget(g0, "AutoRankRepoBaseUrl")
	if type(alt) == "string" and alt ~= "" then
		local u2 = alt .. rel
		local ok2, b2 = pcall(function()
			return game:HttpGet(u2, true)
		end)
		if ok2 and type(b2) == "string" and #b2 > 0 then
			return b2
		end
	end
	return nil
end

local function loadAutoRankOptionalModule(relativePath)
	local s = loadAutoRankOptionalScript(relativePath)
	if not s or not loadstring then
		return nil
	end
	local chunkName = "@" .. relativePath
	local f = loadstring(s, chunkName)
	if not f then
		return nil
	end
	local ok, res = pcall(f)
	if ok and type(res) == "table" then
		return res
	end
	return nil
end

local Ticks = {}
Ticks.lastVerbosePulseTick = 0
local traceThrottleAt = {}
local warnThrottleAt = {}

function AR.Log.stringify(...)
	local out = {}
	for i = 1, select("#", ...) do
		local v = select(i, ...)
		if typeof and typeof(v) == "Instance" then
			out[#out + 1] = v:GetFullName()
		elseif type(v) == "table" then
			out[#out + 1] = "<table:" .. tostring(v) .. ">"
		else
			out[#out + 1] = tostring(v)
		end
	end
	return table.concat(out, " ")
end

function AR.Log.write(kind, ...)
	if not cfg().fileLogEnabled then
		return
	end
	local ap = appendfile
	if type(ap) ~= "function" then
		return
	end
	local path = cfg().fileLogPath or "AutoRank_debug.log"
	local msg = string.format("[%.3f][%s] %s\n", tick() - autoRankLoadTick, tostring(kind), AR.Log.stringify(...))
	pcall(ap, path, msg)
end

function AR.Log.resetFile()
	if not cfg().fileLogEnabled or cfg().fileLogResetOnStart == false then
		return
	end
	if type(writefile) ~= "function" then
		return
	end
	local path = cfg().fileLogPath or "AutoRank_debug.log"
	pcall(writefile, path, string.format("[0.000][boot] AutoRank file log reset version=%s\n", tostring(AUTO_RANK_RUNTIME_VERSION or "?")))
end

AR.Log.resetFile()

local function log(...)
	if cfg().log then
		print("[AutoRank]", ...)
	end
	AR.Log.write("log", ...)
end

local function trace(cat, ...)
	if cfg().verboseLog then
		print("[AutoRank][" .. tostring(cat) .. "]", ...)
	end
	if cfg().fileLogVerbose ~= false then
		AR.Log.write(cat, ...)
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

local function logThrottled(key, intervalSec, ...)
	local now = tick()
	local iv = intervalSec or 10
	if now - (traceThrottleAt[key] or 0) < iv then
		return
	end
	traceThrottleAt[key] = now
	log(...)
end

local function warnErr(where, err)
	local now = tick()
	local key = tostring(where) .. ":" .. tostring(err)
	if now - (warnThrottleAt[key] or 0) < 5 then
		return
	end
	warnThrottleAt[key] = now
	local msg = "[AutoRank][ERR] " .. tostring(where) .. ": " .. tostring(err)
	if cfg().heartbeatErrorWarn ~= false then
		warn(msg)
	end
	AR.Log.write("ERR", where, err)
	if cfg().verboseLog and debug and debug.traceback then
		warn(debug.traceback(nil, 2))
		AR.Log.write("traceback", debug.traceback(nil, 2))
	end
end

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
local GoalCmds, Variables, TabController, InventoryCmds
local HatchingCmds, EggCmds, HatchingTypes, PotionCmds, FruitCmds, EggsUtil
local EnchantCmds
local ZonesUtil
local PetEquipCmds, PetCmds, MachineCmds, UpgradeCmds
local PetNetworking
local Gamepasses, CustomEggsCmds
local DaycareCmds, DaycareLoot
local FlexibleFlagCmds
local MasteryCmds, ConsumableCmds
local AutoFarmCmds, Signal
local RandomEventCmds

local function safeIsInInstance(instanceId)
	if not InstancingCmds or type(InstancingCmds.IsInInstance) ~= "function" then
		return false, true
	end
	local ok, res = pcall(InstancingCmds.IsInInstance, instanceId)
	return ok and res == true, ok
end

local function safeCurrentZone()
	if not MapCmds or type(MapCmds.GetCurrentZone) ~= "function" then
		return nil
	end
	local ok, res = pcall(MapCmds.GetCurrentZone)
	if ok then
		return res
	end
	return nil
end

local function safeInDottedBox()
	if not MapCmds or type(MapCmds.IsInDottedBox) ~= "function" then
		return false
	end
	local ok, res = pcall(MapCmds.IsInDottedBox)
	return ok and res == true
end

do
local netRecentTimestamps = {}
local netRecentSize = 0

local function netPriorityFor(name)
	if not name then
		return tonumber(cfg().netRateLimitDefaultPriority) or 5
	end
	local n = string.lower(tostring(name))
	if string.find(n, "purchase", 1, true)
		or string.find(n, "teleport", 1, true)
		or string.find(n, "claim", 1, true)
		or string.find(n, "rebirth", 1, true)
		or string.find(n, "ranks_", 1, true)
		or string.find(n, "redeem free gift", 1, true)
		or string.find(n, "lootbox: open", 1, true)
		or string.find(n, "pick starter pets", 1, true)
	then
		return tonumber(cfg().netRateLimitPurchasePriority) or 10
	end
	if string.find(n, "blockworlds", 1, true)
		or string.find(n, "fishingevent_", 1, true)
		or string.find(n, "playerdealdamage", 1, true)
		or string.find(n, "orbs:", 1, true)
		or string.find(n, "tnt", 1, true)
		or string.find(n, "_consume", 1, true)
		or string.find(n, "comet_spawn", 1, true)
		or string.find(n, "coinjar_spawn", 1, true)
		or string.find(n, "itemjar_spawn", 1, true)
		or string.find(n, "minipinata_consume", 1, true)
		or string.find(n, "miniluckyblock_consume", 1, true)
		or string.find(n, "giftbag_open", 1, true)
	then
		return tonumber(cfg().netRateLimitFarmPriority) or 1
	end
	return tonumber(cfg().netRateLimitDefaultPriority) or 5
end

local function netWithinRate()
	if cfg().netRateLimitEnabled == false then
		return true
	end
	local maxN = tonumber(cfg().netRateLimitPerSec) or 30
	local window = tonumber(cfg().netRateLimitWindow) or 1.0
	local cutoff = tick() - window
	local i = 1
	while i <= netRecentSize and netRecentTimestamps[i] < cutoff do
		i = i + 1
	end
	if i > 1 then
		local j = 1
		for k = i, netRecentSize do
			netRecentTimestamps[j] = netRecentTimestamps[k]
			j = j + 1
		end
		for k = j, netRecentSize do
			netRecentTimestamps[k] = nil
		end
		netRecentSize = j - 1
	end
	return netRecentSize < maxN
end

local function netRecord()
	netRecentSize = netRecentSize + 1
	netRecentTimestamps[netRecentSize] = tick()
end

local function arNetDoInvoke(name, ...)
	if not Network or type(Network.Invoke) ~= "function" then
		return nil
	end
	return Network.Invoke(name, ...)
end

local function arNetDoFire(name, ...)
	if not Network or type(Network.Fire) ~= "function" then
		return
	end
	Network.Fire(name, ...)
end

local function arNetDoUnreliable(name, ...)
	if not Network or type(Network.UnreliableFire) ~= "function" then
		return
	end
	Network.UnreliableFire(name, ...)
end

function AR.Net.invoke(name, ...)
	if not Network or type(Network.Invoke) ~= "function" then
		return nil, "network_missing"
	end
	local prio = netPriorityFor(name)
	if prio < 10 and not netWithinRate() then
		traceThrottled("net_drop_invoke_" .. tostring(name), 5, "net", "rate-limit drop invoke", name, "prio=", prio)
		return nil, "rate_limited"
	end
	netRecord()
	local ok, a, b, c, d = pcall(arNetDoInvoke, name, ...)
	if not ok then
		traceThrottled("net_err_invoke_" .. tostring(name), 5, "net", "invoke err", name, a)
		return nil, a
	end
	return a, b, c, d
end

function AR.Net.fire(name, ...)
	if not Network or type(Network.Fire) ~= "function" then
		return
	end
	local prio = netPriorityFor(name)
	if prio < 10 and not netWithinRate() then
		traceThrottled("net_drop_fire_" .. tostring(name), 5, "net", "rate-limit drop fire", name, "prio=", prio)
		return
	end
	netRecord()
	local ok, err = pcall(arNetDoFire, name, ...)
	if not ok then
		traceThrottled("net_err_fire_" .. tostring(name), 5, "net", "fire err", name, err)
	end
end

function AR.Net.unreliable(name, ...)
	if not Network or type(Network.UnreliableFire) ~= "function" then
		return
	end
	if cfg().netRateLimitEnabled and not netWithinRate() then
		traceThrottled("net_drop_unreliable_" .. tostring(name), 5, "net", "rate-limit drop unreliable", name)
		return
	end
	netRecord()
	local ok, err = pcall(arNetDoUnreliable, name, ...)
	if not ok then
		traceThrottled("net_err_unreliable_" .. tostring(name), 5, "net", "unreliable err", name, err)
	end
end

function AR.Net.fired(name)
	if not Network or type(Network.Fired) ~= "function" then
		return nil
	end
	local ok, sig = pcall(Network.Fired, name)
	if ok and sig then
		return sig
	end
	return nil
end

function AR.Net.stats()
	return {
		recent = netRecentSize,
		rateLimitPerSec = tonumber(cfg().netRateLimitPerSec) or 30,
		window = tonumber(cfg().netRateLimitWindow) or 1.0,
		enabled = cfg().netRateLimitEnabled,
	}
end
end

local function safeRequire(mod)
	if not mod then
		return nil
	end
	local genv = (getgenv and getgenv()) or _G
	if type(genv.getrequire) == "function" then
		local ok, res = pcall(genv.getrequire, mod)
		if ok and res ~= nil then
			return res
		end
	end
	local getID = genv.getthreadidentity or genv.getidentity or genv.getthreadcontext
	local setID = genv.setthreadidentity or genv.setidentity or genv.setthreadcontext
	local oldId = 8
	local changed = false
	if type(getID) == "function" and type(setID) == "function" then
		pcall(function()
			oldId = getID()
			setID(2)
			changed = true
		end)
	end
	local ok, res = pcall(require, mod)
	if changed then
		pcall(function()
			setID(oldId)
		end)
	end
	if ok and res ~= nil then
		return res
	end
	return nil
end

local function cacheReq(mod)
	if not mod then
		return nil
	end
	local genv = (getgenv and getgenv()) or _G
	if type(genv.getrequire) == "function" then
		local ok, res = pcall(genv.getrequire, mod)
		if ok and res ~= nil then
			return res
		end
		return nil
	end
	return safeRequire(mod)
end

local function ensureModules()
	if not ClientFolder then
		return false
	end
	local ok, err = pcall(function()
		local Client = ClientFolder
		Network = Network or cacheReq(Client:WaitForChild("Network"))
		BreakableFrontend = BreakableFrontend or cacheReq(Client:WaitForChild("BreakableFrontend"))
		Save = Save or cacheReq(Client:WaitForChild("Save"))
		pcall(function() RankCmds = RankCmds or cacheReq(Client:WaitForChild("RankCmds")) end)
		MapCmds = MapCmds or cacheReq(Client:WaitForChild("MapCmds"))
		InstancingCmds = InstancingCmds or cacheReq(Client:WaitForChild("InstancingCmds"))
		GUI = GUI or cacheReq(Client:WaitForChild("GUI"))
		local Lib = ReplicatedStorage.Library
		Directory = Directory or cacheReq(Lib:WaitForChild("Directory"))
		pcall(function() RanksUtil = RanksUtil or cacheReq(Lib.Util:WaitForChild("RanksUtil")) end)
		FFlags = FFlags or cacheReq(Client:WaitForChild("FFlags"))
		ZoneCmds = ZoneCmds or cacheReq(Client:WaitForChild("ZoneCmds"))
		TeleportMapCmds = TeleportMapCmds or cacheReq(Client:WaitForChild("TeleportMapCmds"))
		CurrencyCmds = CurrencyCmds or cacheReq(Client:WaitForChild("CurrencyCmds"))
		Balancing = Balancing or cacheReq(ReplicatedStorage.Library:WaitForChild("Balancing"))
		RebirthCmds = RebirthCmds or cacheReq(Client:WaitForChild("RebirthCmds"))
		InstanceZoneCmds = InstanceZoneCmds or cacheReq(Client:WaitForChild("InstanceZoneCmds"))
		GoalCmds = GoalCmds or cacheReq(Client:WaitForChild("GoalCmds"))
		Variables = Variables or cacheReq(ReplicatedStorage.Library:WaitForChild("Variables"))
		TabController = TabController or cacheReq(Client:WaitForChild("TabController"))
		InventoryCmds = InventoryCmds or cacheReq(Client:WaitForChild("InventoryCmds"))
		HatchingCmds = HatchingCmds or cacheReq(Client:WaitForChild("HatchingCmds"))
		EggCmds = EggCmds or cacheReq(Client:WaitForChild("EggCmds"))
		HatchingTypes = HatchingTypes or cacheReq(ReplicatedStorage.Library.Types:WaitForChild("Hatching"))
		PotionCmds = PotionCmds or cacheReq(Client:WaitForChild("PotionCmds"))
		FruitCmds = FruitCmds or cacheReq(Client:WaitForChild("FruitCmds"))
		EggsUtil = EggsUtil or cacheReq(ReplicatedStorage.Library.Util:WaitForChild("EggsUtil"))
		EnchantCmds = EnchantCmds or cacheReq(Client:WaitForChild("EnchantCmds"))
		ZonesUtil = ZonesUtil or cacheReq(ReplicatedStorage.Library.Util:WaitForChild("ZonesUtil"))
		PetEquipCmds = PetEquipCmds or cacheReq(Client:WaitForChild("PetEquipCmds"))
		PetCmds = PetCmds or cacheReq(Client:WaitForChild("PetCmds"))
		pcall(function()
			PetNetworking = PetNetworking or cacheReq(Client:WaitForChild("PetNetworking"))
		end)
		MachineCmds = MachineCmds or cacheReq(Client:WaitForChild("MachineCmds"))
		UpgradeCmds = UpgradeCmds or cacheReq(Client:WaitForChild("UpgradeCmds"))
		Gamepasses = Gamepasses or cacheReq(Client:WaitForChild("Gamepasses"))
		CustomEggsCmds = CustomEggsCmds or cacheReq(Client:WaitForChild("CustomEggsCmds"))
		DaycareCmds = DaycareCmds or cacheReq(Client:WaitForChild("DaycareCmds"))
		FlexibleFlagCmds = FlexibleFlagCmds or cacheReq(Client:WaitForChild("FlexibleFlagCmds"))
		MasteryCmds = MasteryCmds or cacheReq(Client:WaitForChild("MasteryCmds"))
		ConsumableCmds = ConsumableCmds or cacheReq(Client:WaitForChild("ConsumableCmds"))
		AutoFarmCmds = AutoFarmCmds or cacheReq(Client:WaitForChild("AutoFarmCmds"))
		RandomEventCmds = RandomEventCmds or cacheReq(Client:WaitForChild("RandomEventCmds"))
		Signal = Signal or cacheReq(ReplicatedStorage.Library:WaitForChild("Signal"))
	end)
	if not ok then
		warnErr("ensureModules", err)
	end
	return ok
end

Ticks.lastEnsureModulesHeartbeatTick = 0
local ensureModulesCachedOk = false

local function ensureModulesOnHeartbeat()
	local waitSec = tonumber(cfg().ensureModulesInitialDelaySec) or 0
	if waitSec > 0 and (tick() - autoRankLoadTick) < waitSec then
		return false
	end
	local iv = cfg().ensureModulesInterval
	if type(iv) ~= "number" or iv <= 0 then
		local ok = ensureModules()
		ensureModulesCachedOk = ok
		return ok
	end
	local now = tick()
	if ensureModulesCachedOk and (now - Ticks.lastEnsureModulesHeartbeatTick) < iv then
		return true
	end
	Ticks.lastEnsureModulesHeartbeatTick = now
	local ok = ensureModules()
	ensureModulesCachedOk = ok
	return ok
end

Ticks.lastDamageTick = 0
local currentFocusUid = nil
local orbAccumulator = {}
local lastOrbSend = 0
Ticks.lastOrbAccumPruneTick = 0
local orbNetHooked = false
local orbMagnetPatched = false
local networkInvokeHookInstalled = false
local networkInvokeOriginal = nil
local orbMagnetOriginal = nil
local orbMagnetModule = nil
local kickGuardKickOrig = nil
local kickGuardKickProbeDone = false
local kickGuardNamecallProbeDone = false
local kickGuardNamecallOrig = nil
local restoreRuntimeHooks = nil
Ticks.lastClaimTick = 0
Ticks.lastRankUpGuiTick = 0
Ticks.lastZonePurchaseTick = 0
Ticks.lastTeleportTick = 0
Ticks.lastTravelWorldDirectNetworkTick = 0
Ticks.lastTravelTechRebirthWarnTick = 0
Ticks.lastRequestTechRocketTick = 0
Ticks.travelTechStuck_anchorGen = nil
Ticks.travelTechStuck_anchorStartTick = nil
Ticks.lastTravelTechRetryTick = 0
Ticks.travelTechRetryCountSession = 0
Ticks.lastTravelTechNoGoalAssistTick = 0
Ticks.lastReturnAreaGuiTick = 0
Ticks.lastQuestPickTick = 0
Ticks.lastQuestHatchTick = 0
Ticks.lastProgressOnlyHatchTick = 0
Ticks.lastPotionConsumeTick = 0
Ticks.lastFruitConsumeTick = 0
Ticks.lastConsumableConsumeTick = 0
Ticks.lastFarmExplosiveTick = 0
local farmExplosiveInvokeBusy = false
Ticks.lastQuestGuiClickTick = 0
Ticks.lastEnchantEquipTick = 0
Ticks.lastEnchantLoadoutTick = 0
Ticks.lastEggOpeningPromptTick = 0
Ticks.lastEggOpeningGuiScanTick = 0
Ticks.lastAutoEquipBestTick = 0
Ticks.lastMinigameAssistTick = 0
local minigameSessionInstanceId = nil
local minigameSessionStartTick = 0
local cachedTrackedObjective = nil
local cachedTrackedObjectiveZone = nil
local questMachineGuiStuckState = { snippet = "", clicks = 0, firstAt = 0 }
local freeGiftClaimedLocal = {}
local potionQuestGuiBlobCache = ""
local potionQuestGuiBlobCacheTick = -1e9
local rankGoalsGuiBlobCache = ""
local rankGoalsGuiBlobCacheTick = -1e9
local rankGuiSynthProtectedInstanceId = nil
local rankGuiSynthProtectedUntilTick = 0

local function clearRankGuiSynthProtection()
	rankGuiSynthProtectedInstanceId = nil
	rankGuiSynthProtectedUntilTick = 0
end

local function bumpRankGuiSynthProtectionFromTracked(tr)
	if cfg().questSynthRankProtectInstanceFromAutoLeave == false then
		clearRankGuiSynthProtection()
		return
	end
	if not tr or tr._rankGuiSynth ~= true or type(tr._synthInstanceId) ~= "string" or tr._synthInstanceId == "" then
		return
	end
	local ttl = tonumber(cfg().questSynthRankProtectTtlSeconds) or 180
	rankGuiSynthProtectedInstanceId = tr._synthInstanceId
	rankGuiSynthProtectedUntilTick = tick() + ttl
end

local function rankGuiSynthProtectionAllowsStay(instanceId)
	if cfg().questSynthRankProtectInstanceFromAutoLeave == false then
		return false
	end
	if type(instanceId) ~= "string" or instanceId == "" then
		return false
	end
	if rankGuiSynthProtectedInstanceId ~= instanceId then
		return false
	end
	return tick() < rankGuiSynthProtectedUntilTick
end

local lastEggUnlockAt = {}
local machinePurchaseRetryAfter = {
	EggSlots = 0,
	EquipSlots = 0,
}
Ticks.lastFarmCenterTick = 0
Ticks.lastEquipSlotTick = 0
Ticks.lastEggSlotTick = 0
Ticks.lastUpgradePurchaseTick = 0
Ticks.lastDaycareTick = 0
Ticks.lastRebirthDismissTick = 0
Ticks.lastRankUpDismissTick = 0
Ticks.lastMasteryPerkDismissTick = 0
Ticks.lastAutoFarmEnableTick = 0
local autoFarmEnabledZone = nil
Ticks.lastQuestFlagTick = 0
Ticks.lastQuestSpawnInventoryBreakTick = 0
Ticks.lastBuiltInAutoTapperTick = 0
Ticks.lastFreeGiftsTick = 0
Ticks.lastLootboxTick = 0
Ticks.lastMiscGiftBagOpenTick = 0
Ticks.miscGiftBagGlobalQuietUntil = 0
Ticks.eggPhysicalPartMissUntil = {}
Ticks.lastConsTick = 0
Ticks.lastConsFailPruneTick = 0
Ticks.progressOnlyHatchDisabledAt = 0
Ticks.hatchAsyncGuardUntil = 0
Ticks.hb = {}
local hatchBusy = false
local hatchBusyArmedAt = 0
local hatchBusyArmedForSec = 2.6
local hatchBusyToken = 0
-- Заполняется после объявления AutoRankRuntimeState.runQuestAssistPulse — отложенный пульс после снятия hatchBusy.
local scheduleQuestAssistPulseAfterHatchBusy = nil

local function tryHatchBusyReleaseIfIdle(reason, armedToken)
	if cfg().hatchBusyEarlyRelease == false then
		return
	end
	if armedToken ~= nil and armedToken ~= hatchBusyToken then
		return
	end
	if not hatchBusy then
		return
	end
	local opening = false
	pcall(function()
		opening = Variables and (
			Variables.OpeningEgg == true
			or (type(Variables.OpeningEgg) == "number" and Variables.OpeningEgg > 0)
		)
	end)
	local hci = false
	if HatchingCmds and type(HatchingCmds.IsHatching) == "function" then
		pcall(function()
			hci = HatchingCmds.IsHatching() == true
		end)
	end
	if opening or hci then
		return
	end
	hatchBusy = false
	hatchBusyArmedAt = 0
	traceThrottled("hatch_busy_early_release", 10, "hatch", "hatchBusy cleared (idle OpeningEgg/HatchingCmds)", reason)
	if cfg().hatchAsyncGuardClearWithHatchBusyEarlyRelease ~= false then
		local g = Ticks.hatchAsyncGuardUntil
		if type(g) == "number" and tick() < g then
			Ticks.hatchAsyncGuardUntil = 0
		end
	end
	if type(scheduleQuestAssistPulseAfterHatchBusy) == "function" then
		scheduleQuestAssistPulseAfterHatchBusy()
	end
end

local function armHatchBusyEnd(delaySec)
	hatchBusy = true
	hatchBusyArmedAt = tick()
	hatchBusyToken += 1
	local token = hatchBusyToken
	local d = delaySec or cfg().hatchBusyHoldSeconds or 2.6
	hatchBusyArmedForSec = d
	task.delay(d, function()
		if token ~= hatchBusyToken then
			return
		end
		hatchBusy = false
		hatchBusyArmedAt = 0
	end)
end

--- Сбросить «длинный» hatchBusy до истечения holdPipeline, если клиент уже не в состоянии открытия яйца.
local function scheduleHatchBusyEarlyRelease(armedToken)
	if cfg().hatchBusyEarlyRelease == false then
		return
	end
	local minDelay = tonumber(cfg().hatchBusyEarlyReleaseMinDelay) or 0.55
	local maxWait = tonumber(cfg().hatchBusyEarlyReleaseMaxWait) or 24
	local poll = tonumber(cfg().hatchBusyEarlyReleasePoll) or 0.22
	task.spawn(function()
		task.wait(minDelay)
		local deadline = tick() + maxWait
		while tick() < deadline do
			if armedToken ~= hatchBusyToken then
				return
			end
			tryHatchBusyReleaseIfIdle("early_poll", armedToken)
			if armedToken ~= hatchBusyToken or not hatchBusy then
				return
			end
			task.wait(poll)
		end
	end)
end

local function hatchAsyncPipelineActive()
	return hatchBusy or (type(Ticks.hatchAsyncGuardUntil) == "number" and tick() < Ticks.hatchAsyncGuardUntil)
end

local function hatchSequenceBlocksWorldTeleport()
	if hatchAsyncPipelineActive() then
		return true
	end
	local oe = false
	pcall(function()
		oe = Variables and (
			Variables.OpeningEgg == true
			or (type(Variables.OpeningEgg) == "number" and Variables.OpeningEgg > 0)
		)
	end)
	return oe == true
end

local function tryHatchBusyWatchdog()
	if not hatchBusy or hatchBusyArmedAt <= 0 then
		return
	end
	if cfg().hatchBusyWatchdogExtra == false then
		return
	end
	local extra = cfg().hatchBusyWatchdogExtra
	if type(extra) ~= "number" or extra < 0 then
		extra = 8
	end
	local hidden = tonumber(cfg().hatchBusyHoldSecondsHidden) or 14
	local limit = hidden + extra
	if tick() - hatchBusyArmedAt <= limit then
		return
	end
	hatchBusy = false
	hatchBusyArmedAt = 0
	traceThrottled("hatchBusyWatchdog", 6, "pulse", "hatchBusy watchdog cleared after", limit, "s")
	if cfg().hatchAsyncGuardClearWithHatchBusyEarlyRelease ~= false then
		local g = Ticks.hatchAsyncGuardUntil
		if type(g) == "number" and tick() < g then
			Ticks.hatchAsyncGuardUntil = 0
		end
	end
	if type(scheduleQuestAssistPulseAfterHatchBusy) == "function" then
		scheduleQuestAssistPulseAfterHatchBusy()
	end
end

local AutoRankRuntimeState = {
	version = AUTO_RANK_RUNTIME_VERSION,
	connections = {},
	heartbeatConn = nil,
	diagFarm = {},
	diagQuest = {},
	diagTeleport = {},
	diagGoalPick = {},
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
	hatchBusyToken += 1
	cachedTrackedObjective = nil
	cachedTrackedObjectiveZone = nil
	ensureModulesCachedOk = false
	Ticks.lastEnsureModulesHeartbeatTick = 0
	Ticks.hatchAsyncGuardUntil = 0
	if type(restoreRuntimeHooks) == "function" then
		pcall(restoreRuntimeHooks)
	end
	if AR.Cons and type(AR.Cons.failUntil) == "table" then
		table.clear(AR.Cons.failUntil)
	end
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

local taggedConnections = {}
local function autoRankRegisterTaggedConn(tag, conn)
	if not (tag and conn and conn.Disconnect) then
		return conn
	end
	local prev = taggedConnections[tag]
	if prev then
		pcall(function() prev:Disconnect() end)
	end
	taggedConnections[tag] = conn
	table.insert(AutoRankRuntimeState.connections, conn)
	return conn
end
AR.registerConn = autoRankRegisterConn
AR.registerTaggedConn = autoRankRegisterTaggedConn
AR.taggedConnections = taggedConnections

do
	local prev = G.AutoRankRuntime
	if prev and type(prev.disconnectAll) == "function" then
		pcall(prev.disconnectAll)
	end
	AutoRankRuntimeState.disconnectAll = autoRankDisconnectAll
	AutoRankRuntimeState.AR = AR
	AR.runtime = AutoRankRuntimeState
	AR.connections = AutoRankRuntimeState.connections
	G.AutoRankRuntime = AutoRankRuntimeState
	G.AutoRankAR = AR
	G.AutoRankUnload = function()
		for k, c in pairs(taggedConnections) do
			pcall(function() c:Disconnect() end)
			taggedConnections[k] = nil
		end
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
					TabController.CloseTab(cfg().autoCloseTabUseForce == true or nil)
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

local EggSlots = {}

function EggSlots.generateBundles(rankEntry)
	if not rankEntry then
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
	if not Save or not RanksUtil then
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

local function machinePurchaseFailureCooldown(errMsg)
	local msg = string.lower(tostring(errMsg or ""))
	if string.find(msg, "don't own this machine", 1, true) then
		return tonumber(cfg().machineNotOwnedCooldown) or 30
	end
	return tonumber(cfg().machinePurchaseFailureCooldown) or 6
end

local function tryAutoBuyEggSlots()
	if not cfg().autoBuyEggSlots or not Network or not CurrencyCmds or not Directory then
		return
	end
	local inInst = safeIsInInstance()
	if inInst then
		return
	end
	local now = tick()
	if now < (machinePurchaseRetryAfter.EggSlots or 0) then
		return
	end
	if now - Ticks.lastEggSlotTick < (cfg().eggSlotPurchaseInterval or 1) then
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
		Ticks.lastEggSlotTick = now
		pivotNearEggSlotsMachine()
		local invOk = false
		local errMsg = nil
		local r, e = AR.Net.invoke("EggHatchSlotsMachine_RequestPurchase", bundle.BundleEnd)
		invOk = r ~= false and r ~= nil
		errMsg = e
		log("EggHatchSlotsMachine_RequestPurchase", bundle.BundleEnd, totalCost, invOk, errMsg)
		if invOk then
			tryCloseMachineTabIfConfigured()
		end
		if not invOk then
			machinePurchaseRetryAfter.EggSlots = now + machinePurchaseFailureCooldown(errMsg)
			break
		end
	end
end

local function tryAutoBuyEquipSlots()
	if not cfg().autoBuyEquipSlots or not Network or not PetEquipCmds or not CurrencyCmds then
		return
	end
	local inInst = safeIsInInstance()
	if inInst then
		return
	end
	local now = tick()
	if now < (machinePurchaseRetryAfter.EquipSlots or 0) then
		return
	end
	if now - Ticks.lastEquipSlotTick < (cfg().equipSlotPurchaseInterval or 1) then
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
		Ticks.lastEquipSlotTick = now
		pivotNearEquipSlotsMachine()
		local invOk = false
		local errMsg = nil
		local r, e = AR.Net.invoke("EquipSlotsMachine_RequestPurchase", targetSlot)
		invOk = r ~= false and r ~= nil
		errMsg = e
		log("EquipSlotsMachine_RequestPurchase", targetSlot, invOk, errMsg)
		if invOk then
			tryCloseMachineTabIfConfigured()
		else
			machinePurchaseRetryAfter.EquipSlots = now + machinePurchaseFailureCooldown(errMsg)
			break
		end
	end
end

local function tryAutoBuyCheapestUpgrade()
	if not cfg().autoBuyCheapestUpgrade or not UpgradeCmds or not CurrencyCmds or not Directory then
		return
	end
	local inInst = safeIsInInstance()
	if inInst then
		return
	end
	local now = tick()
	if now - Ticks.lastUpgradePurchaseTick < (cfg().upgradePurchaseInterval or 1.5) then
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
	Ticks.lastUpgradePurchaseTick = now
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

-- Save.EquippedPets is slot/euid -> row (not petUid -> true). Old check EquippedPets[uid] was always nil → daycare ate equipped pets.
local function saveTableMentionsPetUid(tbl, uid)
	if type(tbl) ~= "table" or type(uid) ~= "string" or uid == "" then
		return false
	end
	for k, v in pairs(tbl) do
		if v == uid or k == uid then
			return true
		end
		if type(v) == "table" and (v.uid == uid or v.UID == uid) then
			return true
		end
	end
	return false
end

local function petUidIsEquippedFromSave(s, uid)
	if type(s) ~= "table" or type(uid) ~= "string" or uid == "" then
		return false
	end
	if s.EquippedPets and s.EquippedPets[uid] == true then
		return true
	end
	if saveTableMentionsPetUid(s.EquippedPets or {}, uid) then
		return true
	end
	if saveTableMentionsPetUid(s.EquippedPetsTitanic or {}, uid) then
		return true
	end
	if saveTableMentionsPetUid(s.EquippedPetsGargantuan or {}, uid) then
		return true
	end
	return false
end

local function petUidIsEquippedFromNetworking(uid)
	if type(PetNetworking) ~= "table" or type(PetNetworking.EquippedPets) ~= "function" then
		return false
	end
	if type(uid) ~= "string" or uid == "" then
		return false
	end
	local ok, t = pcall(function()
		return PetNetworking.EquippedPets()
	end)
	if not ok or type(t) ~= "table" then
		return false
	end
	for _, row in pairs(t) do
		if type(row) == "table" and row.uid == uid then
			return true
		end
	end
	return false
end

local function petUidIsCurrentlyEquipped(s, uid)
	return petUidIsEquippedFromSave(s, uid) or petUidIsEquippedFromNetworking(uid)
end

local function tryAutoDaycare()
	if not cfg().autoDaycare or not DaycareCmds then return end
	if safeIsInInstance() then return end
	
	local now = tick()
	if now - Ticks.lastDaycareTick < (cfg().autoDaycareInterval or 5) then return end
	
	local active = nil
	pcall(function() active = DaycareCmds.GetActive() end)
	if type(active) == "table" then
		local claimed = 0
		local maxClaims = tonumber(cfg().autoDaycareMaxClaimsPerTick) or 1
		for uid, _ in pairs(active) do
			local remaining = math.huge
			pcall(function() remaining = DaycareCmds.ComputeRemainingTime(uid) end)
			if remaining <= 0 then
				Ticks.lastDaycareTick = now
				pcall(function() DaycareCmds.Claim(uid) end)
				log("Daycare Claimed", uid)
				claimed += 1
				if claimed >= maxClaims then
					return
				end
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
					local isEquipped = petUidIsCurrentlyEquipped(s, uid)
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
				Ticks.lastDaycareTick = now
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
	AR.Net.fire("Orbs: Collect", ids)
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
		if now - Ticks.lastOrbAccumPruneTick >= 1.25 then
			Ticks.lastOrbAccumPruneTick = now
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
		cacheReq(ClientFolder:WaitForChild("OrbCmds"))
		return cacheReq(ClientFolder:WaitForChild("OrbCmds"):WaitForChild("Orb"))
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
	orbMagnetModule = orbMod
	orbMagnetOriginal = orbMagnetOriginal or {}
	for _, key in ipairs({ "CollectDistance", "DefaultPickupDistance", "CombineDistance" }) do
		local cur = rawget(orbMod, key)
		if orbMagnetOriginal[key] == nil then
			orbMagnetOriginal[key] = cur == nil and false or cur
		end
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

local TeleportService = game:GetService("TeleportService")
local kickGuardTeleportLogAt = {}

local function antiKickAnyEnabled()
	return cfg().kickGuardTryBlockClientKick == true
		or cfg().kickGuardBlockTeleportToLobby == true
end

local function antiKickIsBlockedPlaceId(placeId)
	if type(placeId) ~= "number" then
		return false
	end
	local list = cfg().kickGuardBlockTeleportToPlaceIds
	if type(list) ~= "table" then
		return false
	end
	for _, v in ipairs(list) do
		if tonumber(v) == placeId then
			return true
		end
	end
	return false
end

local function antiKickLogTeleportDestination(method, placeId, jobId)
	if type(placeId) ~= "number" then
		return
	end
	local key = tostring(method) .. ":" .. tostring(placeId)
	local now = tick()
	if now - (kickGuardTeleportLogAt[key] or 0) < 60 then
		return
	end
	kickGuardTeleportLogAt[key] = now
	trace(
		"kick_guard",
		"TeleportService:" .. method .. "(",
		tostring(placeId),
		") seen — добавь в kickGuardBlockTeleportToPlaceIds чтобы блокировать",
		jobId and ("jobId=" .. tostring(jobId)) or ""
	)
end

local function tryInstallKickGuard()
	if not antiKickAnyEnabled() then
		return
	end
	local lp = Players.LocalPlayer
	if not lp then
		return
	end
	local hf = execResolve("hookfunction", "replaceclosure")
	if hf and not kickGuardKickProbeDone and cfg().kickGuardTryBlockClientKick == true then
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
			kickGuardNamecallOrig = old
			local function hooked(self, ...)
				if not antiKickAnyEnabled() then
					return old(self, ...)
				end
				local method = gsm()
				if cfg().kickGuardTryBlockClientKick == true and method == "Kick" and self == lp then
					if cfg().kickGuardKickLog then
						traceThrottled("kick_guard_nc", 2, "kick_guard", "blocked namecall Kick")
					end
					return nil
				end
				if cfg().kickGuardBlockTeleportToLobby == true
					and self == TeleportService
					and (method == "Teleport"
						or method == "TeleportAsync"
						or method == "TeleportToPlaceInstance"
						or method == "TeleportToPrivateServer"
						or method == "TeleportPartyAsync")
				then
					local args = { ... }
					local placeId = args[1]
					antiKickLogTeleportDestination(method, placeId, args[2])
					if antiKickIsBlockedPlaceId(placeId) then
						if cfg().kickGuardKickLog then
							traceThrottled("kick_guard_tp_" .. tostring(placeId), 2, "kick_guard",
								"blocked TeleportService:" .. method .. "(" .. tostring(placeId) .. ")")
						end
						return nil
					end
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
AR.AntiKick.tryInstall = tryInstallKickGuard
AR.AntiKick.isBlockedPlaceId = antiKickIsBlockedPlaceId

restoreRuntimeHooks = function()
	local hf = execResolve("hookfunction", "replaceclosure")
	if hf and Network and networkInvokeHookInstalled and type(networkInvokeOriginal) == "function" and type(Network.Invoke) == "function" then
		pcall(hf, Network.Invoke, networkInvokeOriginal)
	end
	networkInvokeHookInstalled = false
	networkInvokeOriginal = nil

	local lp = Players.LocalPlayer
	if hf and lp and kickGuardKickProbeDone and type(kickGuardKickOrig) == "function" and type(lp.Kick) == "function" then
		pcall(hf, lp.Kick, kickGuardKickOrig)
	end
	kickGuardKickOrig = nil
	kickGuardKickProbeDone = false

	if kickGuardNamecallProbeDone and type(kickGuardNamecallOrig) == "function" then
		local grm = execResolve("getrawmetatable")
		local sor = execResolve("setreadonly")
		if grm and sor then
			pcall(function()
				local mt = grm(game)
				if type(mt) == "table" then
					sor(mt, false)
					mt.__namecall = kickGuardNamecallOrig
					sor(mt, true)
				end
			end)
		end
	end
	kickGuardNamecallOrig = nil
	kickGuardNamecallProbeDone = false

	if orbMagnetModule and orbMagnetOriginal then
		for key, value in pairs(orbMagnetOriginal) do
			pcall(function()
				rawset(orbMagnetModule, key, value == false and nil or value)
			end)
		end
	end
	orbMagnetPatched = false
	orbMagnetModule = nil
	orbMagnetOriginal = nil
end

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
	local delay = tonumber(cfg().crossPlaceReloadDelaySec) or 3
	if delay < 0 then
		delay = 0
	end
	local innerExec
	if type(url) == "string" and string.match(url, "^https?://") then
		innerExec = "loadstring(game:HttpGet(" .. string.format("%q", url) .. ", true))()"
	else
		trace("cross_place", "crossPlaceAutoReload: укажи crossPlaceReloadUrl (https:// raw, без readfile)")
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

local function orbsCreateHandler(batch)
	accumulateOrbBatch(batch)
end

local function orbsClearHandler()
	table.clear(orbAccumulator)
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
	autoRankRegisterTaggedConn("orbs_create", connCreate:Connect(orbsCreateHandler))
	local connClear = Network.Fired("Orbs: Clear")
	if connClear and connClear.Connect then
		autoRankRegisterTaggedConn("orbs_clear", connClear:Connect(orbsClearHandler))
	end
end

local function dealDamage(uid)
	if not Network then
		return false
	end
	local now = tick()
	if now - Ticks.lastDamageTick < (cfg().delayDamage or 0.125) then
		return false
	end
	Ticks.lastDamageTick = now
	AR.Net.unreliable("Breakables_PlayerDealDamage", uid)
	return true
end

local placeFileModuleCache = nil
local function getPlaceFileModule()
	if placeFileModuleCache ~= nil then
		return placeFileModuleCache
	end
	local pf = ReplicatedStorage.Library.Modules:FindFirstChild("PlaceFile")
	local m = pf and cacheReq(pf) or nil
	if type(m) == "table" then
		placeFileModuleCache = m
		return m
	end
	return nil
end

local function refreshAutoRankWorldSelection()
	local env = {
		getPlaceFileModule = getPlaceFileModule,
		cfg = cfg,
		game = game,
		LocalPlayer = LocalPlayer,
		Players = Players,
		log = log,
		traceThrottled = traceThrottled,
	}
	local reg = loadAutoRankOptionalModule("autorank/world_registry.lua")
	local paths = (reg and reg.modulePaths) or {
		"autorank/worlds/w4_future.lua",
		"autorank/worlds/w3_void.lua",
		"autorank/worlds/w2_tech.lua",
		"autorank/worlds/w1.lua",
	}
	local mods = {}
	for _, p in ipairs(paths) do
		local m = loadAutoRankOptionalModule(p)
		if type(m) == "table" and type(m.detect) == "function" then
			table.insert(mods, m)
		end
	end
	table.sort(mods, function(a, b)
		return (a.priority or 0) > (b.priority or 0)
	end)
	local prevId = AutoRankWorld.active and AutoRankWorld.active.id
	for _, mod in ipairs(mods) do
		local ok, hit = pcall(mod.detect, env)
		if ok and hit then
			AutoRankWorld.active = mod
			if prevId ~= mod.id and cfg().log then
				log("AutoRank world profile:", mod.id or "?")
			end
			return
		end
	end
	AutoRankWorld.active = nil
end

local function ensureAutoRankWorldSelection()
	local now = tick()
	local iv = 6
	if AutoRankWorld.active == nil then
		iv = 0.45
	end
	if now - AutoRankWorld._lastRefresh < iv then
		return
	end
	AutoRankWorld._lastRefresh = now
	refreshAutoRankWorldSelection()
end

refreshAutoRankWorldSelection()

local function placeFileAllowsFarmExplosive(pf)
	if cfg().farmExplosiveAssistRequireWorld2 == false then
		return true
	end
	if not pf or type(pf) ~= "table" then
		return false
	end
	if pf.IsWorld2 == true or pf.IsWorld3 == true or pf.IsWorld4 == true then
		return true
	end
	local wn = pf.WorldNumber or pf.worldNumber or pf.World or pf.world
	if type(wn) == "number" and wn >= 2 then
		return true
	end
	return false
end

local function farmExplosiveMiscCountsForIds(idList)
	local s = Save and Save.Get and Save.Get()
	if not s or not s.Inventory or not s.Inventory.Misc then
		return nil
	end
	local amounts = {}
	for _, id in ipairs(idList) do
		amounts[id] = 0
	end
	for _, data in pairs(s.Inventory.Misc) do
		if type(data) == "table" and type(data.id) == "string" and amounts[data.id] ~= nil then
			local n = tonumber(data._am or data.amt or data.amount or data.n or data.Amount or data.qty)
			if not n or n < 1 then
				n = 1
			end
			amounts[data.id] += n
		end
	end
	return amounts
end

local function tryFarmExplosiveAssist(top)
	if cfg().farmExplosiveBreakableAssist ~= true or not top or not top.entry then
		return
	end
	if not top.entry.disableDamage and cfg().farmExplosiveAssistWhenDealingDamage ~= true then
		return
	end
	if not Network or type(Network.Invoke) ~= "function" then
		return
	end
	if not safeCurrentZone() then
		return
	end
	if safeIsInInstance() then
		return
	end
	if not safeInDottedBox() then
		if cfg().farmExplosiveAssistPullToFarmBox and AutoRankRuntimeState.tryPivotToBreakableFarmCenter then
			pcall(function()
				AutoRankRuntimeState.tryPivotToBreakableFarmCenter(false)
			end)
		end
		return
	end
	if cfg().farmExplosiveAssistRequireWorld2 ~= false then
		local pf = getPlaceFileModule()
		if not placeFileAllowsFarmExplosive(pf) then
			return
		end
	end
	local now = tick()
	if now - Ticks.lastFarmExplosiveTick < (cfg().farmExplosiveAssistInterval or 2.8) then
		return
	end
	if farmExplosiveInvokeBusy then
		return
	end
	local order = cfg().farmExplosiveAssistPreferOrder
	if type(order) ~= "table" or #order == 0 then
		order = { "TNT Crate", "TNT" }
	end
	local amounts = farmExplosiveMiscCountsForIds(order)
	if not amounts then
		return
	end
	local invokeName = nil
	local chosenId = nil
	for _, id in ipairs(order) do
		if (amounts[id] or 0) >= 1 then
			chosenId = id
			if id == "TNT Crate" then
				invokeName = "TNT_Crate_Consume"
			elseif id == "TNT" then
				invokeName = "TNT_Consume"
			end
			break
		end
	end
	if not invokeName then
		return
	end
	farmExplosiveInvokeBusy = true
	Ticks.lastFarmExplosiveTick = now
	local ok, errMsg = AR.Net.invoke(invokeName)
	log("farm explosive", invokeName, chosenId, ok, errMsg)
	task.delay(0.55, function()
		farmExplosiveInvokeBusy = false
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

-- Chunk-local namespaces (Luau ≤200 locals per prototype): fewer top-level locals than many `local function`.
local ARZone = {}

function ARZone.zoneUnlockFlagOk()
	if not FFlags then
		return true
	end
	local ok, allowed = pcall(function()
		return FFlags.Get(FFlags.Keys.ZoneUnlocking) or FFlags.CanBypass()
	end)
	return ok and allowed or false
end

function ARZone.teleportFlagOk()
	if not FFlags then
		return true
	end
	local ok, allowed = pcall(function()
		return FFlags.Get(FFlags.Keys.Teleporting) or FFlags.CanBypass()
	end)
	return ok and allowed or false
end

function ARZone.isEligibleToPurchaseZoneNumber(zoneNumber)
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

function ARZone.tryAutoBuyInstanceZone()
	if not cfg().autoBuyZones or not Network then
		return
	end
	if not safeIsInInstance() then
		return
	end
	if ARQ.hasActiveRandomEventBlockingInstanceProgress() then
		return
	end
	local now = tick()
	if now - Ticks.lastZonePurchaseTick < (cfg().zonePurchaseInterval or 0.55) then
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
					Ticks.lastZonePurchaseTick = now
					local success = AR.Net.invoke("InstanceZones_RequestPurchase", inst.instanceID, zn)
					log("InstanceZones_RequestPurchase", inst.instanceID, zn, success)
				end
			end
			break
		end
	end
end

function ARZone.safeDirectoryZonesGet(zoneId)
	local row = nil
	if not zoneId or type(zoneId) ~= "string" then
		return nil
	end
	pcall(function()
		if Directory and type(Directory.Zones) == "table" then
			row = Directory.Zones[zoneId]
		end
	end)
	return row
end

function ARZone.getNextMainZonePurchaseInfo(opts)
	opts = type(opts) == "table" and opts or {}
	if not ZoneCmds or not Directory or not Balancing or not CurrencyCmds then
		return nil
	end
	local nextId, nextTbl = ZoneCmds.GetNextZone()
	if not nextId then
		return nil
	end
	nextTbl = nextTbl or ARZone.safeDirectoryZonesGet(nextId)
	if not nextTbl then
		return nil
	end
	if ZoneCmds.Owns(nextId) then
		return nil
	end
	if not opts.ignoreQuestCompletion and not cfg().ignoreZoneGateQuests then
		local questsOk = false
		pcall(function()
			questsOk = ZoneCmds.HasCompletedNextZoneQuests()
		end)
		if not questsOk then
			return nil
		end
	end
	local zn = nextTbl.ZoneNumber
	if zn and not ARZone.isEligibleToPurchaseZoneNumber(zn) then
		return nil
	end
	local zoneDir = ARZone.safeDirectoryZonesGet(nextId) or nextTbl
	local price = Balancing.CalcGatePrice(zoneDir)
	local currency = zoneDir and zoneDir.Currency
	if type(price) ~= "number" or type(currency) ~= "string" then
		return nil
	end
	local bal = CurrencyCmds.Get(currency) or 0
	return {
		id = nextId,
		dir = zoneDir,
		tbl = nextTbl,
		price = price,
		currency = currency,
		balance = bal,
		purchaseArg = nextTbl.ZoneName or nextId,
	}
end

function ARZone.tryAutoBuyMainZone()
	if not cfg().autoBuyZones or not Network or not ARZone.zoneUnlockFlagOk() then
		return
	end
	if safeIsInInstance() then
		return
	end
	if ARQ.hasActiveRandomEventBlockingZoneProgress() then
		return
	end
	local now = tick()
	if now - Ticks.lastZonePurchaseTick < (cfg().zonePurchaseInterval or 0.55) then
		return
	end
	local info = ARZone.getNextMainZonePurchaseInfo()
	if not info then
		return
	end
	local bal = info.balance or 0
	local price = info.price
	if bal < price then
		return
	end
	Ticks.lastZonePurchaseTick = now
	local purchaseArg = info.purchaseArg
	local success, errMsg = AR.Net.invoke("Zones_RequestPurchase", purchaseArg)
	log("Zones_RequestPurchase", purchaseArg, success, errMsg)
end

function ARZone.questObjectiveEnvironmentBlockedDetail()
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
		if safeIsInInstance("BasketballEvent") then
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

function ARZone.questObjectiveEnvironmentBlocked()
	local b, _ = ARZone.questObjectiveEnvironmentBlockedDetail()
	return b
end

local ARUI = {}

function ARUI.descendantGuiButton(obj)
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

function ARUI.resolveOverlayGuiButton(d)
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
	return ARUI.descendantGuiButton(d)
end

function ARUI.tryDismissRebirthUi()
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
	if now - Ticks.lastRebirthDismissTick < (cfg().rebirthDismissInterval or 0.28) then
		return
	end
	Ticks.lastRebirthDismissTick = now

	local pg = LocalPlayer:FindFirstChild("PlayerGui")
	if pg then
		for _, d in ipairs(pg:GetDescendants()) do
			if d:IsA("TextLabel") or d:IsA("TextButton") then
				local t = string.lower(tostring(d.Text or ""))
				if string.find(t, "click for more", 1, true) or string.find(t, "click for more <", 1, true) then
					local btn = ARUI.resolveOverlayGuiButton(d)
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

function ARUI.advanceSlideUiByUpvalue()
	local UIS = game:GetService("UserInputService")
	local conns = nil
	conns = Exec.getconnections(UIS.InputBegan)
	if type(conns) ~= "table" then
		return false
	end
	for _, conn in ipairs(conns) do
		local fn = conn.Function
		if type(fn) ~= "function" then
			continue
		end
		local ok, ups = pcall(debug.getupvalues, fn)
		if not ok or type(ups) ~= "table" then
			continue
		end
		local kbTable = type(ups[1]) == "table" and ups[1]
		if not kbTable or not kbTable.NextSlideKeybinds then
			continue
		end
		local isInProcess = ups[2] == true
		if not isInProcess then
			continue
		end
		local clickable = ups[3] == true
		if not clickable then
			continue
		end
		local advanceFlag = ups[6]
		if advanceFlag == true then
			continue
		end
		local setOk = pcall(debug.setupvalue, fn, 6, true)
		if setOk then
			return true
		end
	end
	return false
end

function ARUI.tryDismissRankUpUi()
	if not cfg().autoDismissRankUpUi then
		return
	end
	local isRanking = false
	pcall(function()
		isRanking = Variables and Variables.IsRankingUp == true
	end)
	if not isRanking then
		return
	end
	local now = tick()
	if now - Ticks.lastRankUpDismissTick < (cfg().rankUpDismissInterval or 0.32) then
		return
	end
	Ticks.lastRankUpDismissTick = now
	local fired = ARUI.advanceSlideUiByUpvalue()
	if fired then
		log("rank up dismiss via upvalue v5=true")
		return
	end
	traceThrottled("rank_up_dismiss_no_upvalue", 3, "ui", "rank up dismiss skipped: slide upvalue not found")
end

function ARUI.tryDismissMasteryPerkUi()
	if not cfg().autoDismissMasteryPerkUi then
		return
	end
	local pg = LocalPlayer:FindFirstChild("PlayerGui")
	if not pg then
		return
	end
	local masteryGui = nil
	for _, v in ipairs(pg:GetChildren()) do
		if v.Name == "MasteryPerk" and v:IsA("ScreenGui") and v.Enabled then
			masteryGui = v
			break
		end
	end
	if not masteryGui then
		return
	end
	local now = tick()
	if now - Ticks.lastMasteryPerkDismissTick < (cfg().masteryPerkDismissInterval or 0.32) then
		return
	end
	Ticks.lastMasteryPerkDismissTick = now
	local fired = ARUI.advanceSlideUiByUpvalue()
	if fired then
		log("mastery perk dismiss via upvalue v5=true")
		return
	end
	pcall(function()
		masteryGui.Enabled = false
		log("mastery perk dismiss forced Enabled=false")
	end)
end

local function eggOpeningCollectScanRoots()
	ensureAutoRankWorldSelection()
	local roots = eggOpeningTextScanRoots()
	local mod = AutoRankWorld.active
	if mod and type(mod.augmentEggOpeningScanRoots) == "function" then
		local env = {
			LocalPlayer = LocalPlayer,
			game = game,
			Players = Players,
			cfg = cfg,
		}
		pcall(mod.augmentEggOpeningScanRoots, roots, env)
	end
	return roots
end

function ARUI.tryClickEggOpeningPrompt(opts)
	opts = type(opts) == "table" and opts or {}
	ensureAutoRankWorldSelection()
	local modWorld = AutoRankWorld.active
	if cfg().hideEggHatching and cfg().skipEggGuiClickWhenHiddenHatch ~= false and not opts.ignoreThrottles then
		if not (modWorld and modWorld.allowEggPromptDuringHiddenHatchHeartbeat == true) then
			return
		end
	end
	if cfg().autoClickEggOpeningPrompt == false then
		return
	end
	local now = tick()
	if not opts.ignoreThrottles then
		local scanIv = cfg().eggOpeningGuiScanInterval
		if type(scanIv) == "number" and scanIv > 0 and (now - Ticks.lastEggOpeningGuiScanTick) < scanIv then
			return
		end
		Ticks.lastEggOpeningGuiScanTick = now
	end

	local openingEgg = false
	pcall(function()
		openingEgg = Variables and (
			Variables.OpeningEgg == true
			or (type(Variables.OpeningEgg) == "number" and Variables.OpeningEgg > 0)
		)
	end)
	if cfg().eggOpeningOnlyWhenOpening ~= false and not openingEgg and not opts.ignoreThrottles then
		return
	end

	local matchLabel = nil
	if openingEgg then
		matchLabel = true
	else
		for _, root in ipairs(eggOpeningCollectScanRoots()) do
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
		if now - Ticks.lastEggOpeningPromptTick < clickIv then
			return
		end
	end
	Ticks.lastEggOpeningPromptTick = now

	local preferGui = cfg().eggOpeningPreferGuiButtonOverSyntheticMouse ~= false
	if preferGui and type(matchLabel) == "userdata" and matchLabel.Parent then
		local btn = ARUI.resolveOverlayGuiButton(matchLabel)
		if btn and clickGuiButtonRobust(btn) then
			log("egg Click-to-open GUI", btn:GetFullName())
			return
		end
	end

	if tryFireEggOpenPrimaryInput() then
		log("egg open primary (Mouse.Button1Down)")
		return
	end

	if not preferGui and type(matchLabel) == "userdata" and matchLabel.Parent then
		local btn = ARUI.resolveOverlayGuiButton(matchLabel)
		if btn and clickGuiButtonRobust(btn) then
			log("egg Click-to-open GUI", btn:GetFullName())
		end
	end
end

function ARUI.tryClickReturnToMaxAreaButton()
	if not cfg().autoClickReturnToAreaButton or hatchSequenceBlocksWorldTeleport() then
		return
	end
	if cfg().questSynthRankSuppressReturnToArea ~= false then
		local tq = AR.HB and AR.HB.state and AR.HB.state.trackedQuest
		if tq and tq._rankGuiSynth == true then
			return
		end
		local gen = tq and tq._generatorName
		if type(gen) == "string" and string.sub(gen, 1, 14) == "RankGuiSynth_" then
			return
		end
	end
	if not ZoneCmds or not MapCmds then
		return
	end
	if safeIsInInstance() then
		return
	end
	local maxId = select(1, ZoneCmds.GetMaxOwnedZone())
	local cur = safeCurrentZone()
	if not maxId or type(maxId) ~= "string" or not cur or cur == maxId then
		return
	end
	local now = tick()
	if now - Ticks.lastReturnAreaGuiTick < (cfg().returnToAreaClickInterval or 2) then
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
				local btn = d:IsA("GuiButton") and d or ARUI.descendantGuiButton(d)
				if btn then
					local vis = true
					pcall(function()
						vis = btn.Visible == true
					end)
					if vis then
						Ticks.lastReturnAreaGuiTick = now
						local fired = clickGuiButtonRobust(btn)
						log("Return-to-area GUI", fired, btn:GetFullName())
						return
					end
				end
			end
		end
	end
end

local ARG = {}

function ARG.normalizeGoalCallbackResult(res)
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

function ARG.pickTrackedObjective()
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

	if not GoalCmds or not FFlags then
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
				res = ARG.normalizeGoalCallbackResult(res)
			end
			if not ok then
				pickDiag.callbackErr += 1
				hint(gen.Name .. ":cb_" .. tostring(res):sub(1, 48))
			elseif type(res) ~= "table" or not res.Priority or not res.Displays then
				pickDiag.invalidShape += 1
				hint(gen.Name .. ":no_Priority_or_Displays")
			else
				pickDiag.validCallbacks += 1
				if not best or res.Priority > best.Priority then
					res._generatorName = gen.Name
					best = res
				end
			end
		end
	end
	AutoRankRuntimeState.diagGoalPick = pickDiag
	return best
end

function ARG.objectiveSnippetForDiag(tracked, maxLen)
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

function ARG.tryClickGuiTargetTree(gui)
	if not gui or not cfg().questClickGuiTargets then
		return false
	end
	local now = tick()
	if now - Ticks.lastQuestGuiClickTick < (cfg().questGuiClickInterval or 0.38) then
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
	Ticks.lastQuestGuiClickTick = now
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

function QuestAssist.blobMentionsPotionUse(blob)
	if type(blob) ~= "string" or blob == "" then
		return false
	end
	if not string.find(blob, "potion", 1, true) then
		return false
	end
	if string.find(blob, "consume", 1, true) or string.find(blob, "drink", 1, true) then
		return true
	end
	if string.find(blob, "use ", 1, true) or string.find(blob, " use ", 1, true) then
		return true
	end
	if string.find(blob, "use", 1, true) and string.find(blob, "tier", 1, true) then
		return true
	end
	if string.find(blob, "tier", 1, true) and string.find(blob, "/", 1, true) then
		return true
	end
	-- Прогресс "0 / 4" и "0/4"
	if string.match(blob, "%d+%s*/%s*%d+") and string.find(blob, "use", 1, true) then
		return true
	end
	return false
end

function QuestAssist.potionTierRomanFromBlob(blob)
	local romanOrdered = {
		{ "tier viii", 8 },
		{ "tier vii", 7 },
		{ "tier ix", 9 },
		{ "tier iii", 3 },
		{ "tier x", 10 },
		{ "tier iv", 4 },
		{ "tier ii", 2 },
		{ "tier vi", 6 },
		{ "tier v", 5 },
		{ "tier i", 1 },
	}
	table.sort(romanOrdered, function(a, b)
		return #a[1] > #b[1]
	end)
	for _, pair in ipairs(romanOrdered) do
		if string.find(blob, pair[1], 1, true) then
			return pair[2]
		end
	end
	local numStr = string.match(blob, "tier%s*(%d+)")
	local nDigit = tonumber(numStr)
	if nDigit and nDigit >= 1 and nDigit <= 15 then
		return nDigit
	end
	return nil
end

function QuestAssist.potionTierHintFromObjectiveBlob(blob)
	if cfg().questConsumeHonorObjectivePotionTier == false then
		return nil
	end
	if not QuestAssist.blobMentionsPotionUse(blob) then
		return nil
	end
	return QuestAssist.potionTierRomanFromBlob(blob)
end

function QuestAssist.scrapePlayerGuiPotionQuestBlob()
	if cfg().questConsumeScrapeGuiForPotionTier == false then
		return ""
	end
	local iv = tonumber(cfg().questConsumeGuiScrapeInterval) or 2
	local now = tick()
	if now - potionQuestGuiBlobCacheTick < iv then
		return potionQuestGuiBlobCache
	end
	local maxLbl = math.clamp(tonumber(cfg().questConsumeGuiScrapeMaxLabels) or 400, 50, 2000)
	local prio, rest = {}, {}
	local np, nr = 0, 0
	local pg = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
	if not pg then
		potionQuestGuiBlobCacheTick = now
		return ""
	end
	local lower = string.lower
	local function ancestryQuestHint(inst)
		local cur, steps = inst, 0
		while cur and steps < 12 do
			local nm = lower(cur.Name)
			if string.find(nm, "goal", 1, true) or string.find(nm, "rank", 1, true) or string.find(nm, "quest", 1, true)
				or string.find(nm, "challenge", 1, true) then
				return true
			end
			cur = cur.Parent
			steps += 1
		end
		return false
	end
	local function pushText(raw, inst)
		local tl = lower(tostring(raw or ""))
		if tl == "" or not (string.find(tl, "potion", 1, true) or string.find(tl, "tier", 1, true)) then
			return
		end
		if ancestryQuestHint(inst) then
			if np < maxLbl then
				np += 1
				table.insert(prio, tl)
			end
		else
			if nr < maxLbl then
				nr += 1
				table.insert(rest, tl)
			end
		end
	end
	for _, d in ipairs(pg:GetDescendants()) do
		if np + nr >= maxLbl then
			break
		end
		if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
			pcall(function()
				pushText(d.Text or "", d)
			end)
		elseif d:IsA("StringValue") then
			local v = ""
			pcall(function()
				v = d.Value or ""
			end)
			pushText(v, d)
		end
	end
	local parts = {}
	for i = 1, #prio do
		table.insert(parts, prio[i])
	end
	for i = 1, #rest do
		table.insert(parts, rest[i])
	end
	local blob = table.concat(parts, " | ")
	potionQuestGuiBlobCache = blob
	potionQuestGuiBlobCacheTick = now
	return blob
end

-- Тексты ранговых целей (Goals справа, Rank UI) — клиентские GoalCmds часто возвращают no_goal из executor.
function QuestAssist.scrapeRankGoalsGuiBlobForMiscSpawn()
	if cfg().questScrapeRankGoalsForMiscSpawn == false then
		return ""
	end
	local iv = tonumber(cfg().questRankGoalsGuiScrapeInterval) or 2
	local now = tick()
	if now - rankGoalsGuiBlobCacheTick < iv then
		return rankGoalsGuiBlobCache
	end
	rankGoalsGuiBlobCacheTick = now
	local maxLbl = math.clamp(tonumber(cfg().questRankGoalsGuiScrapeMaxLabels) or 320, 40, 1200)
	local parts = {}
	local n = 0
	local lower = string.lower

	local function consumeRoot(root)
		if not root then
			return
		end
		local list = nil
		local okD = pcall(function()
			list = root:GetDescendants()
		end)
		if not okD or type(list) ~= "table" then
			return
		end
		for _, d in ipairs(list) do
			if n >= maxLbl then
				break
			end
			local raw = ""
			if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
				pcall(function()
					raw = lower(tostring(d.Text or ""))
				end)
			elseif d:IsA("StringValue") then
				pcall(function()
					raw = lower(tostring(d.Value or ""))
				end)
			end
			if raw ~= "" then
				if #raw > 360 then
					raw = string.sub(raw, 1, 360)
				end
				n += 1
				table.insert(parts, raw)
			end
		end
	end

	local goalsFromRankUI = nil
	pcall(function()
		if GUI and type(GUI.Rank) == "function" then
			local rk = GUI.Rank()
			local fr = rk and rk.Frame
			local side = fr and fr.Side
			local mid = side and side.Middle
			goalsFromRankUI = mid and mid.Goals or nil
		end
	end)
	if goalsFromRankUI then
		consumeRoot(goalsFromRankUI)
	end

	pcall(function()
		if GUI and type(GUI.GoalsSide) == "function" then
			local gs = GUI.GoalsSide()
			local frm = gs and gs.Frame
			if frm then
				local q = frm:FindFirstChild("Quests", true)
				if q then
					consumeRoot(q)
				end
			end
		end
	end)

	if #parts == 0 and n < math.min(maxLbl, 80) then
		local pg = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
		if pg then
			for _, sg in ipairs(pg:GetChildren()) do
				if sg:IsA("ScreenGui") and sg.Enabled ~= false then
					local ln = lower(sg.Name)
					if string.find(ln, "rank", 1, true) then
						consumeRoot(sg)
						break
					end
				end
			end
		end
	end

	local blob = table.concat(parts, " | ")
	rankGoalsGuiBlobCache = blob
	return blob
end

function QuestAssist.rankGuiBlobSuggestInstanceIds(blobLow)
	local ids = {}
	local function append(id)
		for _, e in ipairs(ids) do
			if e == id then
				return
			end
		end
		table.insert(ids, id)
	end
	if string.find(blobLow, "advanced fishing", 1, true) then
		append("AdvancedFishing")
	end
	if string.find(blobLow, "fishing event", 1, true) or string.find(blobLow, "fishingevent", 1, true) then
		append("FishingEvent")
	end
	local fishingWord = string.find(blobLow, "fishing", 1, true) ~= nil
	local mini = string.find(blobLow, "minigame", 1, true) ~= nil
	local catch = string.find(blobLow, "catch", 1, true) ~= nil
	local fish = string.find(blobLow, "fish", 1, true) ~= nil
	if fishingWord and mini then
		append("Fishing")
	elseif fish and catch and (mini or fishingWord) then
		append("Fishing")
	end
	return ids
end

--[[ Восстановление Instances-цели (как GoalCmds.Modules.Instances): Target = GetEnterPart. ]]
function QuestAssist.pickSynthTrackedObjectiveFromRankGui()
	if cfg().questSynthRankTrackedFromGui == false then
		return nil
	end
	if InstancingCmds == nil or type(InstancingCmds.GetEnterPart) ~= "function" then
		return nil
	end
	local inInstOk, inside = pcall(function()
		return InstancingCmds.IsInInstance()
	end)
	if inInstOk and inside then
		return nil
	end
	local rawAll = QuestAssist.scrapeRankGoalsGuiBlobForMiscSpawn()
	if type(rawAll) ~= "string" or rawAll == "" then
		return nil
	end
	local blobLow = string.lower(rawAll)
	local cand = QuestAssist.rankGuiBlobSuggestInstanceIds(blobLow)
	if #cand == 0 then
		return nil
	end
	for _, cid in ipairs(cand) do
		local enterPart = nil
		local gpOk = pcall(function()
			enterPart = InstancingCmds.GetEnterPart(cid)
		end)
		if gpOk and enterPart ~= nil then
			local snippet = rawAll
			if #snippet > 280 then
				snippet = string.sub(snippet, 1, 280) .. "…"
			end
			return {
				Priority = 100000,
				_generatorName = "RankGuiSynth_" .. cid,
				_rankGuiSynth = true,
				_synthInstanceId = cid,
				Displays = {
					{ Description = snippet },
					{ Target = enterPart },
				},
			}
		end
	end
	return nil
end

function ARG.refreshTrackedObjective()
	local now = tick()
	local curZone = safeCurrentZone()
	if curZone ~= cachedTrackedObjectiveZone then
		cachedTrackedObjective = nil
		cachedTrackedObjectiveZone = curZone
		Ticks.lastQuestPickTick = 0
		clearRankGuiSynthProtection()
	end
	if now - Ticks.lastQuestPickTick < (cfg().questAssistInterval or 0.65) then
		return cachedTrackedObjective
	end
	Ticks.lastQuestPickTick = now

	local blocked, envWhy = ARZone.questObjectiveEnvironmentBlockedDetail()
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

	cachedTrackedObjective = ARG.pickTrackedObjective()
	if cachedTrackedObjective and cachedTrackedObjective._rankGuiSynth ~= true then
		clearRankGuiSynthProtection()
	end
	if not cachedTrackedObjective and cfg().questSynthRankTrackedFromGui ~= false then
		local syn = QuestAssist.pickSynthTrackedObjectiveFromRankGui()
		if syn then
			cachedTrackedObjective = syn
			bumpRankGuiSynthProtectionFromTracked(syn)
			AutoRankRuntimeState.diagQuest = {
				ok = true,
				generator = syn._generatorName,
				snippet = ARG.objectiveSnippetForDiag(syn),
				synthRankGui = true,
			}
			return cachedTrackedObjective
		end
	end
	if cachedTrackedObjective then
		if cachedTrackedObjective._rankGuiSynth == true then
			bumpRankGuiSynthProtectionFromTracked(cachedTrackedObjective)
		end
		AutoRankRuntimeState.diagQuest = {
			ok = true,
			generator = cachedTrackedObjective._generatorName,
			snippet = ARG.objectiveSnippetForDiag(cachedTrackedObjective),
			synthRankGui = cachedTrackedObjective._rankGuiSynth == true,
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

function QuestAssist.potionTierRequiredByObjective(tracked)
	if not tracked then
		return nil
	end
	return QuestAssist.potionTierHintFromObjectiveBlob(QuestAssist.objectiveTextLower(tracked))
end

function QuestAssist.resolvePotionQuestTargetTier(tracked)
	local fromTr = QuestAssist.potionTierRequiredByObjective(tracked)
	if type(fromTr) == "number" then
		return fromTr
	end
	if cfg().questConsumeScrapeGuiForPotionTier == false then
		return nil
	end
	local scraped = QuestAssist.scrapePlayerGuiPotionQuestBlob()
	if scraped ~= "" then
		local fromScrape = QuestAssist.potionTierHintFromObjectiveBlob(scraped)
		if type(fromScrape) == "number" and cfg().questConsumeScrapedPotionTierExactMatch ~= false then
			return fromScrape
		end
	end
	return nil
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

function QuestAssist.objectiveMentionsDigsiteMinigame(tracked)
	if not tracked then
		return false
	end
	local blob = QuestAssist.objectiveTextLower(tracked)
	local gen = string.lower(tostring(tracked._generatorName or ""))
	return string.find(gen, "digsite", 1, true) ~= nil or string.find(blob, "digsite", 1, true) ~= nil
end

function QuestAssist.objectiveTargetsAdvancedDigsite(tracked)
	if not tracked then
		return false
	end
	local blob = QuestAssist.objectiveTextLower(tracked)
	local gen = string.gsub(string.gsub(string.gsub(string.lower(tostring(tracked._generatorName or "")), " ", ""), "%(", ""), "%)", "")
	if string.find(blob, "advanced digsite", 1, true) then
		return true
	end
	if string.find(gen, "advanceddigsite", 1, true) then
		return true
	end
	return false
end

function QuestAssist.shouldSkipObjectiveInteraction(tracked)
	if not tracked then
		return false
	end
	-- Synth из Rank GUI: имя содержит "…_Fishing", blob — "fishing" → иначе срабатывает questIgnoreMinigames и не вызывается tryQuestResolveDisplayTargets (нет тепорта к GetEnterPart).
	if tracked._rankGuiSynth == true then
		return false
	end
	local blob = QuestAssist.objectiveTextLower(tracked)
	if cfg().questBlockDigsiteEntryWithoutShovel ~= false then
		local blockAdvOnly = cfg().questBlockAdvancedDigsiteOnlyWithoutShovel ~= false
		local shouldBlockDig = blockAdvOnly and QuestAssist.objectiveTargetsAdvancedDigsite(tracked)
			or not blockAdvOnly and QuestAssist.objectiveMentionsDigsiteMinigame(tracked)
		if shouldBlockDig then
			local s = Save and Save.Get and Save.Get()
			local hasOk = AR.QuestWorldHelpers
				and type(AR.QuestWorldHelpers.saveInventoryHasUsableShovelForAdvancedDigsite) == "function"
				and AR.QuestWorldHelpers.saveInventoryHasUsableShovelForAdvancedDigsite(s)
			if s and not hasOk then
				return true
			end
		end
	end
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

function QuestAssist.objectiveMentionsEggOrHatch(tracked)
	if not tracked then
		return false
	end
	local blob = string.lower(QuestAssist.flattenObjectiveText(tracked))
	return string.find(blob, "hatch", 1, true) ~= nil or string.find(blob, "egg", 1, true) ~= nil
end

function QuestAssist.generatorLooksMachineStarter(genName)
	if type(genName) ~= "string" or genName == "" then
		return false
	end
	local g = string.lower(genName)
	if string.find(g, "machine", 1, true) then
		if string.find(g, "upgrade", 1, true) or string.find(g, "potions", 1, true) or string.find(g, "enchants", 1, true) then
			return true
		end
	end
	local subs = cfg().questMachineGuiStuckGeneratorSubstrings
	if type(subs) == "table" then
		for _, s in ipairs(subs) do
			if type(s) == "string" and s ~= "" and string.find(g, string.lower(s), 1, true) then
				return true
			end
		end
	end
	return false
end

function QuestAssist.onQuestGuiClickForStuck(genName, tracked)
	local maxC = tonumber(cfg().questMachineGuiStuckMaxClicks)
	if not maxC or maxC <= 0 then
		return
	end
	if not QuestAssist.generatorLooksMachineStarter(genName) then
		questMachineGuiStuckState.snippet = ""
		questMachineGuiStuckState.clicks = 0
		questMachineGuiStuckState.firstAt = 0
		return
	end
	local snip = ARG.objectiveSnippetForDiag(tracked, 120)
	local now = tick()
	if snip ~= questMachineGuiStuckState.snippet then
		questMachineGuiStuckState.snippet = snip
		questMachineGuiStuckState.clicks = 1
		questMachineGuiStuckState.firstAt = now
		return
	end
	questMachineGuiStuckState.clicks += 1
	maxC = math.max(3, maxC)
	local win = math.max(12, tonumber(cfg().questMachineGuiStuckWindowSec) or 45)
	if questMachineGuiStuckState.clicks < maxC then
		return
	end
	if now - questMachineGuiStuckState.firstAt > win then
		questMachineGuiStuckState.clicks = 1
		questMachineGuiStuckState.firstAt = now
		return
	end
	questMachineGuiStuckState.clicks = 0
	questMachineGuiStuckState.snippet = ""
	traceThrottled("quest_machine_gui_stuck", 15, "quest", "machine GUI stuck — CloseTab", genName)
	pcall(function()
		if TabController and type(TabController.CloseTab) == "function" then
			TabController.CloseTab(cfg().autoCloseTabUseForce == true or nil)
		end
	end)
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
		Ticks.lastEggSlotTick = 0
	end
	if has("equip slot") or has("pet slot") or has("equip pet") then
		Ticks.lastEquipSlotTick = 0
	end
	if has("upgrade") or has("rebirth shrine") or has("enchant machine") or has("potion machine") then
		Ticks.lastUpgradePurchaseTick = 0
	end
	if has("rank reward") or has("redeem reward") or has("claim reward") then
		Ticks.lastClaimTick = 0
	end
	if has("rank up") then
		Ticks.lastRankUpGuiTick = 0
	end
	if has("travel ") or has("traverse") or has("void island") or has("tech ") or has("fantasy ") then
		Ticks.lastTeleportTick = 0
		Ticks.lastTravelWorldDirectNetworkTick = 0
	end
	if has("farming") or has("farm token") or has("farming token") or has("halloween") or has("trick or treat") then
		Ticks.lastQuestPickTick = 0
	end
end

ARQ = {}
ARQ.giftBagAssertBackoff = ARQ.giftBagAssertBackoff or {}
ARQ.giftBagSessionAbandoned = ARQ.giftBagSessionAbandoned or {}
ARQ.giftBagRateLimit = ARQ.giftBagRateLimit or {}
-- GoalCmds no_goal: всё равно матчится isTravelToTech… + RequestTechRocket (синт имя без GUI).
ARQ.SYNTH_GENERATOR_TRAVEL_TECH_NOGOAL = "##AutoRank_TravelTech_NoGoal##"

-- RandomEvents.ParentType (см. ReplicatedStorage.Library.Types.RandomEvents)
local ARQ_RANDOM_EVENT_PARENT_ZONE = 1
local ARQ_RANDOM_EVENT_PARENT_INSTANCE = 2

function ARQ.randomEventIdBlocksZoneProgress(evId)
	if type(evId) ~= "string" then
		return false
	end
	local list = cfg().blockZoneProgressRandomEventIds
	if type(list) ~= "table" then
		return false
	end
	for _, id in ipairs(list) do
		if id == evId then
			return true
		end
	end
	return false
end

function ARQ.hasActiveRandomEventBlockingZoneProgress()
	if cfg().blockZoneProgressWhileRandomEventActive == false then
		return false
	end
	if safeIsInInstance() then
		return false
	end
	if not RandomEventCmds or type(RandomEventCmds.GetActive) ~= "function" or type(RandomEventCmds.GetTimeRemaining) ~= "function" then
		return false
	end
	local cur = safeCurrentZone()
	if type(cur) ~= "string" or cur == "" then
		return false
	end
	local act = RandomEventCmds.GetActive()
	if type(act) ~= "table" then
		return false
	end
	for _, ev in pairs(act) do
		if type(ev) == "table" and ARQ.randomEventIdBlocksZoneProgress(ev.id) then
			if ev.parentType == ARQ_RANDOM_EVENT_PARENT_ZONE and type(ev.parentID) == "string" and AR.zonesIdMatch(ev.parentID, cur) then
				local tr = 0
				pcall(function()
					tr = RandomEventCmds.GetTimeRemaining(ev)
				end)
				if type(tr) == "number" and tr > 0 then
					return true
				end
			end
		end
	end
	return false
end

function ARQ.hasActiveRandomEventBlockingInstanceProgress()
	if cfg().blockZoneProgressWhileRandomEventActive == false then
		return false
	end
	local inInst, okIn = safeIsInInstance()
	if not okIn or not inInst then
		return false
	end
	if not RandomEventCmds or type(RandomEventCmds.GetActive) ~= "function" or type(RandomEventCmds.GetTimeRemaining) ~= "function" then
		return false
	end
	local inst = InstancingCmds and InstancingCmds.Get and InstancingCmds.Get()
	local iid = inst and inst.instanceID
	if type(iid) ~= "string" or iid == "" then
		return false
	end
	local act = RandomEventCmds.GetActive()
	if type(act) ~= "table" then
		return false
	end
	for _, ev in pairs(act) do
		if type(ev) == "table" and ARQ.randomEventIdBlocksZoneProgress(ev.id) then
			if ev.parentType == ARQ_RANDOM_EVENT_PARENT_INSTANCE and type(ev.parentID) == "string" and ev.parentID == iid then
				local tr = 0
				pcall(function()
					tr = RandomEventCmds.GetTimeRemaining(ev)
				end)
				if type(tr) == "number" and tr > 0 then
					return true
				end
			end
		end
	end
	return false
end

function ARQ.miscSpawnFailureShouldCooldown(errMsg)
	local errLow = string.lower(tostring(errMsg or ""))
	if errLow == "" then
		return false
	end
	-- Сервер часто отвечает вариациями «уже что-то в зоне» — без cooldown спамятся все *_Spawn.
	if string.find(errLow, "already something", 1, true) then
		return true
	end
	if string.find(errLow, "there is already", 1, true) then
		return true
	end
	if string.find(errLow, "already in this area", 1, true) then
		return true
	end
	if string.find(errLow, "something in this area", 1, true) then
		return true
	end
	if string.find(errLow, "not enough room", 1, true) or string.find(errLow, "no room", 1, true) then
		return true
	end
	return false
end

function ARQ.tryQuestSpawnInventoryBreakablesFromBlob(blob)
	if cfg().questSpawnInventoryBreakables == false then
		return
	end
	if type(blob) ~= "string" or blob == "" then
		return
	end
	local now = tick()
	if now - Ticks.lastQuestSpawnInventoryBreakTick < (cfg().questSpawnInventoryBreakablesInterval or 2.75) then
		return
	end
	if safeIsInInstance() then
		return
	end
	local z = safeCurrentZone()
	if z == nil or z == false or z == "" then
		return
	end
	if not safeInDottedBox() then
		return
	end
	if cfg().questSpawnInventorySkipWorldSpawnObjectives ~= false then
		local invJarCue = string.find(blob, "coin jar", 1, true)
			or string.find(blob, "item jar", 1, true)
		if string.find(blob, "randomly spawned", 1, true) and not invJarCue then
			return
		end
		-- «in best area» относится к мировым спавнам; цели вида «coin jars in best area» как раз требуют CoinJar из инвентаря здесь.
		if string.find(blob, "in best area", 1, true) and not invJarCue then
			return
		end
	end
	local s = Save and Save.Get and Save.Get()
	if not s or type(s.Inventory) ~= "table" or type(s.Inventory.Misc) ~= "table" then
		return
	end

	local function miscStackN(data)
		return tonumber(data._am or data.amt or data.amount or data.n or data.Amount or data.qty) or 1
	end
	-- Для нескольких id порядок выбора = порядок первого совпадения при обходе pairs(Misc) (нестабилен).
	-- Несколько tier'ов одной механики — только через miscUidForPreferredIds / явный ipairs по id.
	local function miscUidForIds(ids)
		local want = {}
		for _, id in ipairs(ids) do
			want[id] = true
		end
		for uid, data in pairs(s.Inventory.Misc) do
			if type(uid) == "string" and type(data) == "table" and want[data.id] and miscStackN(data) >= 1 then
				return uid
			end
		end
		return nil
	end
	-- Явный порядок tier'ов (pairs по инвентарю иначе даёт случайный выбор — часто Giant Coin Jar).
	local function miscUidForPreferredIds(preferredOrder)
		for _, wantId in ipairs(preferredOrder) do
			for uid, data in pairs(s.Inventory.Misc) do
				if type(uid) == "string" and type(data) == "table" and data.id == wantId and miscStackN(data) >= 1 then
					return uid
				end
			end
		end
		return nil
	end

	local function try(remote, detail, ...)
		local a, b = AR.Net.invoke(remote, ...)
		if a ~= nil and a ~= false then
			Ticks.lastQuestSpawnInventoryBreakTick = now
			log("quest_misc_spawn", remote, detail, ...)
			traceThrottled(
				"misc_spawn_" .. tostring(remote),
				8,
				"pulse.quest",
				"inventory spawn",
				remote,
				detail,
				...
			)
			return true
		end
		if ARQ.miscSpawnFailureShouldCooldown(b) then
			Ticks.lastQuestSpawnInventoryBreakTick = now
			traceThrottled("misc_spawn_area_busy_" .. tostring(remote), 12, "pulse.quest", remote, "area busy, backoff", b)
			return false
		end
		if cfg().verboseLog then
			traceThrottled("misc_spawn_fail_" .. tostring(remote), 10, "pulse.quest", remote, "fail", a, b, detail)
		end
		return false
	end

	if string.find(blob, "rainbow", 1, true) and string.find(blob, "mini", 1, true) and string.find(blob, "chest", 1, true) then
		if miscUidForIds({ "Rainbow Mini Chest" }) and try("GiftBag_Open", "Rainbow Mini Chest", "Rainbow Mini Chest") then
			return
		end
	elseif string.find(blob, "mini", 1, true) and string.find(blob, "chest", 1, true) then
		if miscUidForIds({ "Mini Chest" }) and try("GiftBag_Open", "Mini Chest", "Mini Chest") then
			return
		end
	end
	if string.find(blob, "coin jar", 1, true) then
		local uid = miscUidForPreferredIds({ "Basic Coin Jar", "Magic Coin Jar", "Giant Coin Jar" })
		if uid and try("CoinJar_Spawn", "coin jar", uid) then
			return
		end
	end
	if string.find(blob, "item jar", 1, true) then
		local uid = miscUidForIds({ "Basic Item Jar" })
		if uid and try("ItemJar_Spawn", "item jar", uid) then
			return
		end
	end
	if string.find(blob, "comet", 1, true) then
		local uid = miscUidForIds({ "Comet" })
		if uid and try("Comet_Spawn", "comet", uid) then
			return
		end
	end
	if string.find(blob, "pinata", 1, true) then
		local uid = miscUidForIds({ "Mini Pinata" })
		if uid and try("MiniPinata_Consume", "mini pinata", uid) then
			return
		end
	end
	if string.find(blob, "lucky block", 1, true) or string.find(blob, "luckyblock", 1, true) then
		local uid = miscUidForIds({ "Mini Lucky Block" })
		if uid and try("MiniLuckyBlock_Consume", "mini lucky block", uid) then
			return
		end
	end
end

-- Клиент ActionMenu: часть предметов — GiftBag_Open(name), часть — GiftBag_Open(name, uid), бандлы часто сначала name-only, затем name+uid.
ARQ._giftBagOpenNameOnly = {
	["Mini Chest"] = true,
	["Rainbow Mini Chest"] = true,
	["Global Event Gift"] = true,
	["Diamond Gift Bag"] = true,
	["Charm Stone"] = true,
	["Seed Bag"] = true,
}
-- Studio: Large Gift Bag / Gift Bag — второй аргумент uid.
ARQ._giftBagOpenNameAndUid = {
	["Large Gift Bag"] = true,
	["Gift Bag"] = true,
}

ARQ._giftBagMiscStackN = function(data)
	if type(data) ~= "table" then
		return 0
	end
	return tonumber(data._am or data.amt or data.amount or data.n or data.Amount or data.qty) or 1
end

ARQ._giftBagErrIsAssertion = function(err)
	return string.find(tostring(err or ""), "assertion", 1, true) ~= nil
end

ARQ._giftBagErrIsTooFast = function(err)
	return string.find(string.lower(tostring(err or "")), "too fast", 1, true) ~= nil
end

function ARQ.giftBagTryOpenOne(pickId, pickUid, beforeAmt)
	local attempts = {}
	if ARQ._giftBagOpenNameOnly[pickId] then
		attempts[1] = function()
			return AR.Net.invoke("GiftBag_Open", pickId)
		end
	elseif ARQ._giftBagOpenNameAndUid[pickId] then
		attempts[1] = function()
			return AR.Net.invoke("GiftBag_Open", pickId, pickUid)
		end
	else
		attempts[1] = function()
			return AR.Net.invoke("GiftBag_Open", pickId)
		end
		attempts[2] = function()
			return AR.Net.invoke("GiftBag_Open", pickId, pickUid)
		end
	end
	local lastR, lastE = nil, nil
	for i = 1, #attempts do
		local fn = attempts[i]
		if fn then
			lastR, lastE = fn()
			local s2 = Save and Save.Get and Save.Get()
			local row = s2 and s2.Inventory and s2.Inventory.Misc and s2.Inventory.Misc[pickUid]
			local afterAmt = row and ARQ._giftBagMiscStackN(row) or 0
			if beforeAmt > afterAmt or (beforeAmt >= 1 and row == nil) then
				return true, lastR, lastE, i
			end
			if lastR ~= nil and lastR ~= false then
				return true, lastR, lastE, i
			end
		end
	end
	return false, lastR, lastE, 0
end

function ARQ.tryAutoOpenMiscGiftBags()
	if cfg().autoOpenMiscGiftBags ~= true or not Network or not Save or not Save.Get then
		return
	end
	if hatchSequenceBlocksWorldTeleport() then
		return
	end
	local now = tick()
	if now < (Ticks.miscGiftBagGlobalQuietUntil or 0) then
		return
	end
	local iv = math.max(0.35, tonumber(cfg().autoOpenMiscGiftBagsInterval) or 4)
	if now - (Ticks.lastMiscGiftBagOpenTick or 0) < iv then
		return
	end
	local ids = cfg().autoOpenMiscGiftBagIds
	if type(ids) ~= "table" then
		Ticks.lastMiscGiftBagOpenTick = now
		return
	end
	local want = {}
	for _, id in ipairs(ids) do
		if type(id) == "string" then
			want[id] = true
		end
	end
	if next(want) == nil then
		Ticks.lastMiscGiftBagOpenTick = now
		return
	end
	local maxN = math.max(1, math.floor(tonumber(cfg().autoOpenMiscGiftBagsMaxPerTick) or 2))
	for _ = 1, maxN do
		local s = Save.Get()
		if not s or type(s.Inventory) ~= "table" or type(s.Inventory.Misc) ~= "table" then
			Ticks.lastMiscGiftBagOpenTick = now
			return
		end
		local pickUid, pickId, beforeAmt = nil, nil, 0
		for uid, data in pairs(s.Inventory.Misc) do
			if type(uid) == "string" and type(data) == "table" and type(data.id) == "string" and want[data.id] then
				local skipUid = false
				if ARQ.giftBagSessionAbandoned[uid] then
					skipUid = true
				end
				local ab = ARQ.giftBagAssertBackoff[uid]
				if not skipUid and type(ab) == "table" and type(ab.untilT) == "number" and ab.untilT > now then
					skipUid = true
				end
				local rl = ARQ.giftBagRateLimit[uid]
				if not skipUid and type(rl) == "table" and type(rl.untilT) == "number" and rl.untilT > now then
					skipUid = true
				end
				if not skipUid then
					local n = ARQ._giftBagMiscStackN(data)
					if n >= 1 then
						pickUid, pickId, beforeAmt = uid, data.id, n
						break
					end
				end
			end
		end
		if not pickUid or not pickId then
			Ticks.lastMiscGiftBagOpenTick = now
			return
		end
		local opened, lastR, lastE, stage = ARQ.giftBagTryOpenOne(pickId, pickUid, beforeAmt)
		Ticks.lastMiscGiftBagOpenTick = now
		log("GiftBag_Open auto", pickId, pickUid, "opened=", opened, "stage=", stage, "r=", lastR, "err=", lastE, "amt=", beforeAmt)
		if opened then
			ARQ.giftBagAssertBackoff[pickUid] = nil
			ARQ.giftBagSessionAbandoned[pickUid] = nil
			local rl = ARQ.giftBagRateLimit[pickUid]
			if type(rl) == "table" then
				local baseIv = math.max(0.35, tonumber(cfg().autoOpenMiscGiftBagsInterval) or 4)
				local decay = tonumber(cfg().giftBagTooFastSuccessDecay) or 0.85
				local baseD = tonumber(cfg().giftBagTooFastBaseDelaySec) or 1.5
				rl.delay = math.max(baseIv * 0.35, (rl.delay or baseD) * decay)
				if rl.delay <= baseIv * 0.95 then
					ARQ.giftBagRateLimit[pickUid] = nil
				else
					rl.untilT = nil
				end
			end
		else
			if ARQ._giftBagErrIsAssertion(lastE) then
				local steps = cfg().giftBagAssertionBackoffSeconds
				if type(steps) ~= "table" or #steps == 0 then
					steps = { 30, 60, 120, 300 }
				end
				local maxR = math.max(1, math.floor(tonumber(cfg().giftBagAssertionMaxRetriesPerSession) or 5))
				local st = ARQ.giftBagAssertBackoff[pickUid] or { fails = 0 }
				st.fails = (tonumber(st.fails) or 0) + 1
				if st.fails >= maxR then
					ARQ.giftBagSessionAbandoned[pickUid] = true
					ARQ.giftBagAssertBackoff[pickUid] = nil
					traceThrottled("gift_bag_abandon", 20, "log", "GiftBag_Open abandon uid after assertions", pickUid, pickId, "fails", st.fails)
				else
					local idx = math.min(st.fails, #steps)
					local sec = tonumber(steps[idx]) or 30
					st.untilT = now + sec
					ARQ.giftBagAssertBackoff[pickUid] = st
					traceThrottled("gift_bag_assert_backoff", 18, "log", "GiftBag_Open assert backoff", pickUid, pickId, "in", sec, "s", "fail", st.fails)
				end
				local g = tonumber(cfg().miscGiftBagAssertionFailureCooldownSec) or 300
				Ticks.miscGiftBagGlobalQuietUntil = now + g
			elseif ARQ._giftBagErrIsTooFast(lastE) then
				local rl = ARQ.giftBagRateLimit[pickUid] or {}
				local mul = tonumber(cfg().giftBagTooFastBackoffMultiplier) or 1.5
				local cap = tonumber(cfg().giftBagTooFastMaxDelaySec) or 8
				local baseD = tonumber(cfg().giftBagTooFastBaseDelaySec) or 1.5
				rl.delay = math.min(cap, math.max(baseD, (rl.delay or baseD) * mul))
				rl.untilT = now + rl.delay
				ARQ.giftBagRateLimit[pickUid] = rl
				traceThrottled("gift_bag_too_fast", 14, "log", "GiftBag_Open rate backoff", pickUid, pickId, "delay", rl.delay)
			end
			return
		end
	end
end

function ARQ.tryQuestSpawnInventoryBreakables(tracked)
	local chunks = {}
	if type(tracked) == "table" then
		local flat = QuestAssist.flattenObjectiveText(tracked)
		if type(flat) == "string" and flat ~= "" then
			table.insert(chunks, string.lower(flat))
		end
	end
	local rg = QuestAssist.scrapeRankGoalsGuiBlobForMiscSpawn()
	if type(rg) == "string" and rg ~= "" then
		table.insert(chunks, rg)
	end
	if #chunks == 0 then
		return
	end
	ARQ.tryQuestSpawnInventoryBreakablesFromBlob(table.concat(chunks, " | "))
end

function ARQ.getClosestProximityPrompt(maxDist)
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

function ARQ.isTravelToTechGeneratorName(genName)
	if genName == ARQ.SYNTH_GENERATOR_TRAVEL_TECH_NOGOAL then
		return true
	end
	local g = string.lower(genName or "")
	return string.find(g, "travel to tech", 1, true) ~= nil
		or string.find(g, "tech starter", 1, true) ~= nil
		or (string.find(g, "world 2", 1, true) and string.find(g, "tech", 1, true))
		or string.find(g, "tech world", 1, true) ~= nil
end

function ARQ.rainbowRoadRocketInteractPart()
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
	local frame = folder:FindFirstChild("Frame")
	local rocket = frame and frame:FindFirstChild("Rocket") or folder:FindFirstChild("Rocket")
	local ri = rocket and rocket:FindFirstChild("RocketInteract")
	if ri and (ri:IsA("BasePart") or (ri:IsA("Model") and ri.PrimaryPart)) then
		return ri
	end
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

function ARQ.tryTravelWorldDirectNetworkFire(genName, opts)
	opts = opts and type(opts) == "table" and opts or {}
	if cfg().questTravelWorldDirectNetwork == false then
		return false
	end
	if not Network or type(Network.Fire) ~= "function" then
		return false
	end
	local remoteName = ARQ.isTravelToTechGeneratorName(genName) and "RequestTechRocket" or nil
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
			if nowW - Ticks.lastTravelTechRebirthWarnTick > 10 then
				Ticks.lastTravelTechRebirthWarnTick = nowW
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
	local gStable = genName and tostring(genName) or ""
	if remoteName == "RequestTechRocket" then
		if Ticks.travelTechStuck_anchorGen ~= gStable then
			Ticks.travelTechStuck_anchorGen = gStable
			Ticks.travelTechStuck_anchorStartTick = now
			Ticks.travelTechRetryCountSession = 0
		elseif (Ticks.travelTechStuck_anchorStartTick or 0) <= 0 then
			Ticks.travelTechStuck_anchorStartTick = now
		end
	end
	local iv = tonumber(cfg().questTravelWorldDirectNetworkInterval) or 2.6
	if opts.forceThrottle ~= true and now - Ticks.lastTravelWorldDirectNetworkTick < iv then
		return false
	end
	Ticks.lastTravelWorldDirectNetworkTick = now
	AR.Net.fire(remoteName)
	if remoteName == "RequestTechRocket" then
		Ticks.lastRequestTechRocketTick = now
	end
	if cfg().log then
		log(
			"quest travel direct Network.Fire",
			remoteName,
			genName,
			opts.forceThrottle and "(retry burst)" or "via AR.Net.fire"
		)
	end
	if cfg().verboseLog then
		local traceKey = "travelDirectNet:" .. remoteName .. (opts.forceThrottle == true and ":retry" or "")
		local traceIv = (opts.forceThrottle == true) and 3.2 or (iv + 0.12)
		traceThrottled(traceKey, traceIv, "pulse.quest", "Network.Fire", remoteName, genName)
	end
	return true
end

function ARQ.placeFileIsPastMainWorldForTech()
	local pf = getPlaceFileModule()
	if not pf or type(pf) ~= "table" then
		return nil
	end
	if pf.IsWorld2 == true or pf.IsWorld3 == true or pf.IsWorld4 == true then
		return true
	end
	local wn = pf.WorldNumber or pf.worldNumber or pf.World or pf.world
	if type(wn) == "number" and wn >= 2 then
		return true
	end
	return false
end

function ARQ.tryTravelToTechRocketPhysicalEngage(genName)
	if not ARQ.isTravelToTechGeneratorName(genName) then
		return false
	end
	local ch = LocalPlayer.Character
	local pp = ch and ch.PrimaryPart
	if not pp then
		return false
	end
	local minD = cfg().questTeleportMinDist or 14
	local yOff = cfg().questTeleportYOffset or 6
	local ri = ARQ.rainbowRoadRocketInteractPart()
	if ri then
		local pos = ri:IsA("BasePart") and ri.Position
			or (ri:IsA("Model") and ri.PrimaryPart and ri.PrimaryPart.Position)
		if pos and cfg().questTeleportToTarget and (pp.Position - pos).Magnitude >= minD then
			pcall(function()
				pp.CFrame = CFrame.new(pos + Vector3.new(0, yOff, 0))
			end)
			log("TravelToTech retry pivot →", ri:GetFullName())
		end
		ARQ.tryQuestTargetExecutorExtras(ri, pp, genName)
		return true
	end
	local bestPrompt = ARQ.getClosestProximityPrompt(150)
	if bestPrompt then
		local anchor = bestPrompt.Parent
		local pos = anchor
			and (
				(anchor:IsA("BasePart") and anchor.Position)
				or (anchor:IsA("Model") and anchor.PrimaryPart and anchor.PrimaryPart.Position)
			)
		if pos and cfg().questTeleportToTarget and (pp.Position - pos).Magnitude >= minD then
			pcall(function()
				pp.CFrame = CFrame.new(pos + Vector3.new(0, yOff, 0))
			end)
			log("TravelToTech retry pivoted to closest prompt →", anchor:GetFullName())
		end
		Exec.fireProximityPrompt(bestPrompt)
		ARQ.tryTravelWorldDirectNetworkFire(genName, { forceThrottle = true })
		return true
	end
	return false
end

function ARQ.tryTravelToTechStuckRetry(tracked)
	if cfg().questTravelTechRetryEnabled ~= true then
		return
	end
	if not tracked then
		Ticks.travelTechStuck_anchorGen = nil
		Ticks.travelTechStuck_anchorStartTick = nil
		Ticks.travelTechRetryCountSession = 0
		return
	end
	local genName = tracked._generatorName
	if not ARQ.isTravelToTechGeneratorName(genName) then
		Ticks.travelTechStuck_anchorGen = nil
		Ticks.travelTechStuck_anchorStartTick = nil
		Ticks.travelTechRetryCountSession = 0
		return
	end
	if QuestAssist.shouldSkipObjectiveInteraction(tracked) then
		return
	end
	local pastMain = ARQ.placeFileIsPastMainWorldForTech()
	if pastMain == true then
		Ticks.travelTechStuck_anchorGen = nil
		Ticks.travelTechStuck_anchorStartTick = nil
		Ticks.travelTechRetryCountSession = 0
		return
	end
	local envBlocked, envDetail = ARZone.questObjectiveEnvironmentBlockedDetail()
	if envBlocked and type(envDetail) == "string" then
		if string.find(envDetail, "IsTeleportingWorld2", 1, true)
			or string.find(envDetail, "IsRebirthing", 1, true)
			or string.find(envDetail, "IsUsingCannon", 1, true)
		then
			return
		end
	end
	local anchorStart = Ticks.travelTechStuck_anchorStartTick or 0
	local maxA = tonumber(cfg().questTravelTechRetryMaxAttempts) or 12
	if (Ticks.travelTechRetryCountSession or 0) >= maxA then
		traceThrottled(
			"travel_tech_retry_max",
			26,
			"quest",
			"Travel Tech: лимит повторов",
			maxA,
			"(cfg questTravelTechRetryMaxAttempts)"
		)
		return
	end
	local now = tick()
	local stuckAfter = tonumber(cfg().questTravelTechRetryStuckAfterSec) or 7
	if anchorStart <= 0 or now - anchorStart < stuckAfter then
		return
	end
	local retryEvery = tonumber(cfg().questTravelTechRetryEverySec) or 4.5
	if now - (Ticks.lastTravelTechRetryTick or 0) < retryEvery then
		return
	end
	Ticks.lastTravelTechRetryTick = now
	Ticks.travelTechRetryCountSession = (Ticks.travelTechRetryCountSession or 0) + 1
	traceThrottled(
		"travel_tech_stuck_retry",
		4.5,
		"quest",
		"Travel To Tech: повтор",
		Ticks.travelTechRetryCountSession,
		"/",
		maxA,
		"(RequestTechRocket + ракета)"
	)
	pcall(function()
		ARQ.tryTravelWorldDirectNetworkFire(genName, { forceThrottle = true })
	end)
	pcall(function()
		ARQ.tryTravelToTechRocketPhysicalEngage(genName)
	end)
end

function ARQ.maybeAutoTravelToTechWhenNoGoal(tracked)
	if cfg().questTravelTechWhenNoGoalEnabled ~= true then
		return nil
	end
	if tracked ~= nil then
		return nil
	end
	local dq = AutoRankRuntimeState.diagQuest or {}
	if dq.where ~= "no_goal" then
		return nil
	end
	local pastMain = ARQ.placeFileIsPastMainWorldForTech()
	if pastMain == true then
		return nil
	end
	local envBlocked, envDetail = ARZone.questObjectiveEnvironmentBlockedDetail()
	if envBlocked and type(envDetail) == "string" then
		if string.find(envDetail, "IsTeleportingWorld2", 1, true)
			or string.find(envDetail, "IsRebirthing", 1, true)
			or string.find(envDetail, "IsUsingCannon", 1, true)
		then
			return nil
		end
	end
	local cur = safeCurrentZone()
	local maxOw = nil
	if ZoneCmds and type(ZoneCmds.GetMaxOwnedZone) == "function" then
		pcall(function()
			maxOw = select(1, ZoneCmds.GetMaxOwnedZone())
		end)
	end
	if type(cur) ~= "string" or type(maxOw) ~= "string" or not AR.zonesIdMatch(cur, maxOw) then
		return nil
	end
	if cfg().questTravelTechWhenNoGoalRequireRainbowRoad ~= false then
		local lz = string.lower(cur)
		if string.find(lz, "rainbow", 1, true) == nil then
			return nil
		end
	end
	local phantom = { _generatorName = ARQ.SYNTH_GENERATOR_TRAVEL_TECH_NOGOAL }
	if QuestAssist.shouldSkipObjectiveInteraction(phantom) then
		return nil
	end
	local now = tick()
	local iv = tonumber(cfg().questTravelTechWhenNoGoalInterval) or 10
	if iv < 3 then
		iv = 3
	end
	if now - (Ticks.lastTravelTechNoGoalAssistTick or 0) >= iv then
		Ticks.lastTravelTechNoGoalAssistTick = now
		traceThrottled(
			"travel_tech_nogoal_pulse",
			iv * 0.85,
			"quest",
			"no_goal: Travel To Tech (max зона, PlaceFile≠W2+)",
			cur
		)
		if cfg().log then
			log("Travel To Tech assist (GoalCmds no_goal)", cur, "interval", iv)
		end
		pcall(function()
			ARQ.tryTravelWorldDirectNetworkFire(phantom._generatorName, { forceThrottle = true })
		end)
		pcall(function()
			ARQ.tryTravelToTechRocketPhysicalEngage(phantom._generatorName)
		end)
	end
	return phantom
end

function ARQ.tryQuestTargetExecutorExtras(inst, pp, genName)
	if not inst then
		return
	end
	if inst:IsA("ClickDetector") then
		if cfg().questUseFireClickDetector then
			Exec.fireClickDetector(inst, 0)
			log("quest Exec.fireClickDetector", genName)
		end
		ARQ.tryTravelWorldDirectNetworkFire(genName)
		return
	end
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
	ARQ.tryTravelWorldDirectNetworkFire(genName)
end

function ARQ.tryQuestResolveDisplayTargets(tracked)
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
			ARQ.tryQuestTargetExecutorExtras(t, pp, genName)
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
			ARQ.tryQuestTargetExecutorExtras(t, pp, genName)
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
			ARQ.tryQuestTargetExecutorExtras(t, pp, genName)
			return
		end
	end

	for _, disp in ipairs(displays) do
		local t = disp and disp.Target
		if typeof(t) == "Instance" and t:IsA("GuiObject") then
			if ARG.tryClickGuiTargetTree(t) then
				log("quest GUI click →", genName, t:GetFullName())
				QuestAssist.onQuestGuiClickForStuck(genName, tracked)
				return
			end
		end
	end

	if not handledPhysical and ARQ.isTravelToTechGeneratorName(genName) then
		local bestPrompt = ARQ.getClosestProximityPrompt(150)
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
			ARQ.tryTravelWorldDirectNetworkFire(genName)
		end
	end
end
function ARQ.countEquippedEnchantSlots()
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

local lazyDirCaches = {
	Enchants = { cache = nil, bad = false },
	ZoneFlags = { cache = nil, bad = false },
}

function ARQ.getEnchantsDirectoryTable()
	local b = lazyDirCaches.Enchants
	if b.bad then
		return nil
	end
	if b.cache ~= nil then
		return b.cache
	end
	local enf = ReplicatedStorage.Library.Directory:FindFirstChild("Enchants")
	local tbl = enf and cacheReq(enf) or nil
	if type(tbl) == "table" then
		b.cache = tbl
		return tbl
	end
	b.bad = true
	return nil
end

function ARQ.enchantPowerAtTier(def, tier)
	if not def or type(tier) ~= "number" or tier < 1 then
		return nil
	end
	local fn = def.Power
	if type(fn) ~= "function" then
		return nil
	end
	local ok, p = pcall(fn, tier)
	if ok and type(p) == "number" and p > 0 then
		return p
	end
	return nil
end

function ARQ.enchantMaxCopiesSameTier(enchantId, tier)
	local dir = ARQ.getEnchantsDirectoryTable()
	local def = dir and dir[enchantId]
	if not def then
		return 4
	end
	local thr = def.DiminishPowerThreshold
	if type(thr) ~= "number" or thr <= 0 then
		return 6
	end
	local p = ARQ.enchantPowerAtTier(def, tier)
	if not p then
		return 3
	end
	return math.max(1, math.floor(thr / p))
end

function ARQ.inventoryMaxTierByEnchantId(s)
	local t = {}
	if not s or not s.Inventory or not s.Inventory.Enchant then
		return t
	end
	for _, data in pairs(s.Inventory.Enchant) do
		local id = data and data.id
		if type(id) == "string" then
			local tn = tonumber(data.tn or data.tier or data.Tier) or 1
			if not t[id] or tn > t[id] then
				t[id] = tn
			end
		end
	end
	return t
end

function ARQ.enchantPriorityIdSet(priorityList)
	local st = {}
	if type(priorityList) == "table" then
		for _, id in ipairs(priorityList) do
			if type(id) == "string" then
				st[id] = true
			end
		end
	end
	return st
end

function ARQ.buildTargetEnchantPlan(maxSlots, priorityList, tierById)
	local plan = {}
	local counts = {}
	if type(priorityList) ~= "table" or maxSlots <= 0 then
		return plan
	end
	for _ = 1, maxSlots do
		local placed = false
		for _, eid in ipairs(priorityList) do
			local tier = tierById[eid]
			if type(tier) == "number" and tier >= 1 then
				local cap = ARQ.enchantMaxCopiesSameTier(eid, tier)
				local c = counts[eid] or 0
				if c < cap then
					table.insert(plan, eid)
					counts[eid] = c + 1
					placed = true
					break
				end
			end
		end
		if not placed then
			break
		end
	end
	return plan
end

function ARQ.enchantMultisetFromPlan(plan)
	local c = {}
	for _, id in ipairs(plan) do
		c[id] = (c[id] or 0) + 1
	end
	return c
end

function ARQ.getEquippedEnchantRows(s)
	local rows = {}
	if not s or type(s.EquippedEnchants) ~= "table" then
		return rows
	end
	for slot, uid in pairs(s.EquippedEnchants) do
		if type(uid) == "string" then
			local data = s.Inventory and s.Inventory.Enchant and s.Inventory.Enchant[uid]
			local id = data and data.id
			if type(id) == "string" then
				local tn = tonumber(data.tn or data.tier or data.Tier) or 1
				table.insert(rows, {
					slot = slot,
					uid = uid,
					id = id,
					tier = tn,
				})
			end
		end
	end
	return rows
end

function ARQ.tryQuestEquipEnchantSimpleFill()
	local now = tick()
	if now - Ticks.lastEnchantEquipTick < (cfg().questEquipEnchantInterval or 2.2) then
		return
	end
	local maxSlots = 0
	pcall(function()
		maxSlots = EnchantCmds.GetMaxEquippedEnchants() or 0
	end)
	if maxSlots <= 0 or ARQ.countEquippedEnchantSlots() >= maxSlots then
		return
	end
	local s = Save and Save.Get and Save.Get()
	if not s or not s.Inventory or not s.Inventory.Enchant then
		return
	end
	for uid, data in pairs(s.Inventory.Enchant) do
		local eid = data.id
		if type(eid) == "string" and type(uid) == "string" then
			local already = false
			pcall(function()
				already = EnchantCmds.IsEquipped(eid) == true
			end)
			if not already then
				Ticks.lastEnchantEquipTick = now
				pcall(function()
					EnchantCmds.Equip(uid)
				end)
				log("Enchants_Equip", uid, eid)
				break
			end
		end
	end
end

function ARQ.tryQuestEquipEnchantFromInventory(eggMode)
	if not cfg().questEquipEnchants or not EnchantCmds then
		return
	end
	if cfg().dynamicEnchantLoadout == false then
		ARQ.tryQuestEquipEnchantSimpleFill()
		return
	end
	local now = tick()
	if now - Ticks.lastEnchantLoadoutTick < (cfg().questEquipEnchantInterval or 2.2) then
		return
	end
	local maxSlots = 0
	pcall(function()
		maxSlots = EnchantCmds.GetMaxEquippedEnchants() or 0
	end)
	if maxSlots <= 0 then
		return
	end
	local priority = eggMode and cfg().enchantHatchPriority or cfg().enchantFarmPriority
	if type(priority) ~= "table" or #priority == 0 then
		return
	end
	local s = Save and Save.Get and Save.Get()
	if not s then
		return
	end
	local tierById = ARQ.inventoryMaxTierByEnchantId(s)
	local rowsTierUp = ARQ.getEquippedEnchantRows(s)
	for _, row in ipairs(rowsTierUp) do
		local invMax = tierById[row.id]
		if type(invMax) == "number" and invMax > row.tier then
			pcall(function()
				EnchantCmds.Unequip(tonumber(row.slot) or row.slot)
			end)
			log("Enchants_Unequip", row.slot, row.id, "tier_upgrade", row.tier, invMax)
		end
	end
	s = Save and Save.Get and Save.Get()
	if not s then
		return
	end
	local plan = ARQ.buildTargetEnchantPlan(maxSlots, priority, tierById)
	if #plan == 0 then
		Ticks.lastEnchantLoadoutTick = now
		return
	end
	Ticks.lastEnchantLoadoutTick = now
	Ticks.lastEnchantEquipTick = now

	local wanted = ARQ.enchantMultisetFromPlan(plan)
	local allowed = ARQ.enchantPriorityIdSet(priority)

	local rows = ARQ.getEquippedEnchantRows(s)
	for _, row in ipairs(rows) do
		if not allowed[row.id] then
			pcall(function()
				EnchantCmds.Unequip(tonumber(row.slot) or row.slot)
			end)
			log("Enchants_ClearSlot", row.slot, row.id, "wrong_mode")
		end
	end

	s = Save and Save.Get and Save.Get()
	if not s then
		return
	end
	rows = ARQ.getEquippedEnchantRows(s)

	for eid, need in pairs(wanted) do
		s = Save and Save.Get and Save.Get()
		rows = ARQ.getEquippedEnchantRows(s or {})
		local cands = {}
		for _, row in ipairs(rows) do
			if row.id == eid then
				table.insert(cands, row)
			end
		end
		if #cands > need then
			table.sort(cands, function(a, b)
				return a.tier < b.tier
			end)
			for i = need + 1, #cands do
				pcall(function()
					EnchantCmds.Unequip(tonumber(cands[i].slot) or cands[i].slot)
				end)
				log("Enchants_ClearSlot", cands[i].slot, eid, "stack_cap")
			end
			s = Save and Save.Get and Save.Get()
			rows = ARQ.getEquippedEnchantRows(s or {})
		end
	end

	s = Save and Save.Get and Save.Get()
	rows = ARQ.getEquippedEnchantRows(s or {})

	for _, row in ipairs(rows) do
		if wanted[row.id] == nil then
			pcall(function()
				EnchantCmds.Unequip(tonumber(row.slot) or row.slot)
			end)
			log("Enchants_ClearSlot", row.slot, row.id, "not_in_plan")
		end
	end

	s = Save and Save.Get and Save.Get()
	if not s or not s.Inventory or not s.Inventory.Enchant then
		return
	end

	local equippedUids = {}
	for _, row in ipairs(ARQ.getEquippedEnchantRows(s)) do
		equippedUids[row.uid] = true
	end
	local curHave = {}
	for _, row in ipairs(ARQ.getEquippedEnchantRows(s)) do
		curHave[row.id] = (curHave[row.id] or 0) + 1
	end

	for _, eid in ipairs(plan) do
		while (curHave[eid] or 0) < (wanted[eid] or 0) do
			local bestUid, bestTier = nil, -1
			for uid, data in pairs(s.Inventory.Enchant) do
				if type(uid) == "string" and data and data.id == eid and not equippedUids[uid] then
					local tn = tonumber(data.tn or data.tier or data.Tier) or 1
					if tn > bestTier then
						bestTier = tn
						bestUid = uid
					end
				end
			end
			if not bestUid then
				break
			end
			pcall(function()
				EnchantCmds.Equip(bestUid)
			end)
			log("Enchants_Equip", bestUid, eid, eggMode and "hatch" or "farm")
			equippedUids[bestUid] = true
			curHave[eid] = (curHave[eid] or 0) + 1
			s = Save and Save.Get and Save.Get()
			if not s or not s.Inventory or not s.Inventory.Enchant then
				return
			end
		end
	end
end

function ARQ.buffConsumablesInstanceBlocked()
	if cfg().autoConsumeBuffsInInstance ~= false then
		return false
	end
	return safeIsInInstance()
end

function ARQ.idInConsumableBlocklist(id)
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

function ARQ.countActivePotionEntries()
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

function ARQ.potionTypeAlreadyActive(potionId)
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

function ARQ.pickPotionConsumeAmount(item)
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
	local tiers = { 500, 200, 100, 50, 25, 10, 5, 1 }
	for _, n in ipairs(tiers) do
		if n <= am then
			return n
		end
	end
	return 1
end
function AR.Cons.getPotionItemClass()
	local PotionItem = nil
	pcall(function()
		local ms = ReplicatedStorage.Library.Items:FindFirstChild("PotionItem")
		if ms then
			PotionItem = cacheReq(ms)
		end
	end)
	return PotionItem
end

function AR.Cons.getFruitItemClass()
	local FruitItem = nil
	pcall(function()
		local ms = ReplicatedStorage.Library.Items:FindFirstChild("FruitItem")
		if ms then
			FruitItem = cacheReq(ms)
		end
	end)
	return FruitItem
end

function AR.Cons.canUsePotionTier(tier)
	local tierOk = true
	if MasteryCmds and MasteryCmds.CanUsePotion then
		pcall(function()
			tierOk = select(1, MasteryCmds.CanUsePotion(tier)) == true
		end)
	end
	return tierOk
end

function AR.Cons.makePotionConsumeCandidate(cont, PotionItem, uid, data, requiredTier)
	local pid = data and data.id
	if type(uid) ~= "string" or type(pid) ~= "string" then
		return nil
	end
	local bypassActiveBuff = type(requiredTier) == "number" and cfg().questConsumeBypassActiveBuffForTierForced ~= false
	if not bypassActiveBuff and ARQ.potionTypeAlreadyActive(pid) then
		return nil
	end
	local item = cont:Get(uid, PotionItem)
	if not item then
		return nil
	end
	local tier = nil
	pcall(function()
		tier = item.GetTier and item:GetTier()
	end)
	tier = tonumber(tier) or tonumber(data and data.tn) or 1
	if type(requiredTier) == "number" and requiredTier >= 1 and tier ~= requiredTier then
		return nil
	end
	if not AR.Cons.canUsePotionTier(tier) then
		return nil
	end
	local n = ARQ.pickPotionConsumeAmount(item)
	if n < 1 then
		return nil
	end
	return { uid = uid, pid = pid, tier = tier, n = n }
end

function AR.Cons.consumePotionCand(now, c)
	Ticks.lastPotionConsumeTick = now
	pcall(function()
		PotionCmds.Consume(c.uid, c.n)
	end)
	log("Potions: Consume", c.uid, c.pid, c.n, "tier", c.tier)
end

function AR.Cons.consumeFirstPotionCandidate(now, inventory, cont, PotionItem, requiredTier)
	for uid, data in pairs(inventory) do
		local c = AR.Cons.makePotionConsumeCandidate(cont, PotionItem, uid, data, requiredTier)
		if c then
			AR.Cons.consumePotionCand(now, c)
			return true
		end
	end
	return false
end

function AR.Cons.consumeBestPotionCandidate(now, inventory, cont, PotionItem, requiredTier)
	local candidates = {}
	for uid, data in pairs(inventory) do
		local c = AR.Cons.makePotionConsumeCandidate(cont, PotionItem, uid, data, requiredTier)
		if c then
			table.insert(candidates, c)
		end
	end
	if #candidates == 0 then
		return false
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
	AR.Cons.consumePotionCand(now, candidates[1])
	return true
end

function AR.Cons.tryQuestConsumePotionLegacy()
	if not cfg().autoConsumeBuffs or cfg().questConsumePotions == false or ARQ.buffConsumablesInstanceBlocked() then
		return
	end
	if not PotionCmds or not InventoryCmds then
		return
	end
	local now = tick()
	if now - Ticks.lastPotionConsumeTick < (cfg().questConsumePotionsInterval or 1.35) then
		return
	end
	local reqTier = QuestAssist.resolvePotionQuestTargetTier(cachedTrackedObjective)
	if cfg().questConsumePotionsOnlyWhenNoneActive and ARQ.countActivePotionEntries() > 0 then
		if type(reqTier) ~= "number" or cfg().questConsumeIgnoreOnlyWhenNoneWhenTierForced == false then
			return
		end
	end
	local cont = nil
	pcall(function()
		cont = InventoryCmds.Container()
	end)
	if not cont then
		return
	end
	local PotionItem = AR.Cons.getPotionItemClass()
	if not PotionItem then
		return
	end
	local s = Save and Save.Get and Save.Get()
	if not s or not s.Inventory or not s.Inventory.Potion then
		return
	end

	local inventory = s.Inventory.Potion
	if type(reqTier) == "number" then
		if cfg().verboseLog or cfg().log then
			traceThrottled(
				"potion_quest_target_tier",
				8,
				"quest",
				"potion tier",
				reqTier,
				QuestAssist.potionTierRequiredByObjective(cachedTrackedObjective) and "tracked" or "scraped_gui"
			)
		end
		local okPick = AR.Cons.consumeBestPotionCandidate(now, inventory, cont, PotionItem, reqTier)
		if not okPick then
			traceThrottled("potion_quest_tier_no_match", 10, "quest", "нет зелья тира", reqTier, "- инвентарь или уже активный баф")
		end
		return
	end
	if cfg().questConsumePotionsPreferMaxTier == false then
		AR.Cons.consumeFirstPotionCandidate(now, inventory, cont, PotionItem)
		return
	end
	AR.Cons.consumeBestPotionCandidate(now, inventory, cont, PotionItem)
end

function AR.Cons.tryQuestConsumeFruitLegacy()
	if not cfg().autoConsumeBuffs or cfg().questConsumeFruits == false or ARQ.buffConsumablesInstanceBlocked() then
		return
	end
	if not FruitCmds or not InventoryCmds then
		return
	end
	local now = tick()
	if now - Ticks.lastFruitConsumeTick < (cfg().questConsumeFruitsInterval or 1.5) then
		return
	end
	local s = Save and Save.Get and Save.Get()
	if not s or not s.Inventory or not s.Inventory.Fruit then
		return
	end
	local cont = nil
	pcall(function()
		cont = InventoryCmds.Container()
	end)
	local FruitItem = AR.Cons.getFruitItemClass()
	local cap = tonumber(cfg().questConsumeFruitMaxAtOnce) or 4
	local candidates = {}
	for uid, data in pairs(s.Inventory.Fruit) do
		if type(uid) == "string" then
			local maxC = 0
			pcall(function()
				maxC = FruitCmds.GetMaxConsume(uid) or 0
			end)
			if maxC >= 1 then
				local tier = tonumber(data and data.tn) or 1
				local shiny = false
				if cont and FruitItem then
					local item = cont:Get(uid, FruitItem)
					if item then
						if item.GetTier then
							pcall(function()
								local t = item:GetTier()
								if type(t) == "number" then
									tier = t
								end
							end)
						end
						if item.IsShiny then
							pcall(function()
								shiny = item:IsShiny() == true
							end)
						end
					end
				end
				table.insert(candidates, {
					uid = uid,
					id = data and data.id,
					maxC = maxC,
					tier = tier,
					shiny = shiny,
				})
			end
		end
	end
	if #candidates == 0 then
		return
	end
	if cfg().questConsumeFruitsPreferMaxTier ~= false then
		table.sort(candidates, function(a, b)
			if a.tier ~= b.tier then
				return a.tier > b.tier
			end
			if a.shiny ~= b.shiny then
				return a.shiny
			end
			if a.maxC ~= b.maxC then
				return a.maxC > b.maxC
			end
			return tostring(a.uid) < tostring(b.uid)
		end)
	else
		table.sort(candidates, function(a, b)
			return tostring(a.uid) < tostring(b.uid)
		end)
	end
	local pick = candidates[1]
	local take = math.min(pick.maxC, math.max(1, cap))
	Ticks.lastFruitConsumeTick = now
	pcall(function()
		FruitCmds.Consume(pick.uid, take)
	end)
	log("Fruits: Consume", pick.uid, pick.id, take)
end

function AR.Cons.tryAutoConsumeConsumablesLegacy()
	if not cfg().autoConsumeBuffs or cfg().autoConsumeConsumables == false or ARQ.buffConsumablesInstanceBlocked() then
		return
	end
	if not ConsumableCmds or not InventoryCmds or type(ConsumableCmds.Consume) ~= "function" then
		return
	end
	local now = tick()
	if now - Ticks.lastConsumableConsumeTick < (cfg().autoConsumeConsumablesInterval or 2.2) then
		return
	end
	local ConsumableItem = nil
	pcall(function()
		local ms = ReplicatedStorage.Library.Items:FindFirstChild("ConsumableItem")
		if ms then
			ConsumableItem = cacheReq(ms)
		end
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
		if type(uid) == "string" and type(cid) == "string" and not ARQ.idInConsumableBlocklist(cid) then
			local item = cont:Get(uid, ConsumableItem)
			if item and item.GetAmount and item:GetAmount() > 0 then
				Ticks.lastConsumableConsumeTick = now
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

function AR.Cons.tryAutoBuffConsumablesPulseLegacy()
	pcall(function()
		ARG.refreshTrackedObjective()
	end)
	pcall(function()
		AR.Cons.tryQuestConsumePotionLegacy()
		AR.Cons.tryQuestConsumeFruitLegacy()
		AR.Cons.tryAutoConsumeConsumablesLegacy()
	end)
end

AR.QuestWorldHelpers = AR.QuestWorldHelpers or {}
do
	-- PS99 egg stands / props use names like "Center", "Pad"; Directory.Zones.__index errors on unknown keys.
	local ZONE_FALSE_POSITIVE_NAMES = {
		Center = true,
		Pad = true,
		Capsule = true,
		Egg = true,
		Root = true,
		Hitbox = true,
		HitBox = true,
		Prompt = true,
		ProximityPrompt = true,
		Attachment = true,
		Handle = true,
		Mesh = true,
		Union = true,
		Collider = true,
		Model = true,
		Base = true,
		Primary = true,
		["Egg Capsule"] = true,
		Main = true,
	}

	local function zoneNameLooksLikeAuxiliaryPart(name)
		return type(name) == "string" and ZONE_FALSE_POSITIVE_NAMES[name] == true
	end

	function AR.QuestWorldHelpers.getZoneFlagsDirectoryTable()
		local b = lazyDirCaches.ZoneFlags
		if b.bad then
			return nil
		end
		if b.cache ~= nil then
			return b.cache
		end
		local zf = ReplicatedStorage.Library.Directory:FindFirstChild("ZoneFlags")
		local tbl = zf and cacheReq(zf) or nil
		if type(tbl) == "table" then
			b.cache = tbl
			return tbl
		end
		b.bad = true
		return nil
	end

	function AR.QuestWorldHelpers.normalizeZoneIdCandidate(z)
		if type(z) ~= "string" or z == "" then
			return nil
		end
		z = string.gsub(z, "^%s*(.-)%s*$", "%1")
		if z == "" then
			return nil
		end
		local zones = Directory and type(Directory.Zones) == "table" and Directory.Zones or nil
		if zones then
			local okDirect, direct = pcall(function()
				return zones[z]
			end)
			if okDirect and direct then
				return z
			end
			for id, row in pairs(zones) do
				if id == z then
					return id
				end
				if type(row) == "table" and (row._id == z or row.ZoneName == z or row.Name == z or row.DisplayName == z) then
					return id
				end
			end
			return nil
		end
		if zoneNameLooksLikeAuxiliaryPart(z) then
			return nil
		end
		return z
	end

	function AR.QuestWorldHelpers.getZoneIdFromInstance(inst)
		if typeof(inst) ~= "Instance" then
			return nil
		end
		local attrNames = { "ParentID", "ParentId", "ZoneID", "ZoneId", "zoneId", "Zone", "AreaId" }
		local at = inst
		for _ = 1, 16 do
			if not at then
				break
			end
			for _, attr in ipairs(attrNames) do
				local ok, v = pcall(function()
					return at:GetAttribute(attr)
				end)
				local z = ok and AR.QuestWorldHelpers.normalizeZoneIdCandidate(v) or nil
				if z then
					return z
				end
			end
			if not zoneNameLooksLikeAuxiliaryPart(at.Name) then
				local byName = AR.QuestWorldHelpers.normalizeZoneIdCandidate(at.Name)
				if byName then
					return byName
				end
			end
			at = at.Parent
		end
		return nil
	end

	function AR.QuestWorldHelpers.getZoneIdAtWorldPosition(pos)
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
		return AR.QuestWorldHelpers.normalizeZoneIdCandidate(z)
	end

	function AR.QuestWorldHelpers.getEggZoneIdForNumber(n)
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
		return AR.QuestWorldHelpers.getZoneIdFromInstance(part) or AR.QuestWorldHelpers.getZoneIdAtWorldPosition(part.Position)
	end

	function AR.QuestWorldHelpers.questSpecifiesEggNumber(tracked)
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
			local ed = nil
			pcall(function()
				ed = EggsUtil.GetByNumber(i)
			end)
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

	function AR.QuestWorldHelpers.saveInventoryHasAnyShovel(s)
		if not s or type(s.Inventory) ~= "table" or type(s.Inventory.Misc) ~= "table" then
			return false
		end
		for _, data in pairs(s.Inventory.Misc) do
			if type(data) == "table" and type(data.id) == "string" then
				if string.find(string.lower(data.id), "shovel", 1, true) then
					return true
				end
			end
		end
		return false
	end

	function AR.QuestWorldHelpers.saveInventoryHasUsableShovelForAdvancedDigsite(s)
		if not s or type(s.Inventory) ~= "table" or type(s.Inventory.Misc) ~= "table" then
			return false
		end
		local badFlimsy = cfg().questAdvancedDigsiteFlimsyShovelIsInsufficient ~= false
		for _, data in pairs(s.Inventory.Misc) do
			if type(data) == "table" and type(data.id) == "string" then
				local idl = string.lower(data.id)
				if string.find(idl, "shovel", 1, true) then
					if not (badFlimsy and string.find(idl, "flimsy", 1, true)) then
						return true
					end
				end
			end
		end
		return false
	end

	function AR.QuestWorldHelpers.objectiveHasWorldTarget(tracked)
		if not tracked then
			return false
		end
		if ARQ.isTravelToTechGeneratorName(tracked._generatorName) then
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

	function AR.QuestWorldHelpers.tryQuestPlaceFlexibleFlag(tracked)
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
		else
			return
		end
		if not FlexibleFlagCmds or not MapCmds or not InventoryCmds then
			return
		end
		if not safeInDottedBox() then
			return
		end
		local now = tick()
		if now - Ticks.lastQuestFlagTick < (cfg().questPlaceFlagInterval or 2) then
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

		local zoneDir = AR.QuestWorldHelpers.getZoneFlagsDirectoryTable()
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
						Ticks.lastQuestFlagTick = now
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
end
do
	function AR.normZoneId(z)
		if type(z) ~= "string" then
			return nil
		end
		return (string.gsub(z, "^%s*(.-)%s*$", "%1"))
	end
	AR.zonesIdMatch = function(a, b)
		local na = AR.normZoneId(a)
		local nb = AR.normZoneId(b)
		if not na or not nb then
			return false
		end
		return na == nb
	end
	AR.playerNearZoneTeleportPoint = function(zoneId, maxDist)
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

AR.Teleports = AR.Teleports or {}

function AR.Teleports.schedulePivotRepeats(maxId)
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

AR.ARC = (function()
	local badEggDirNumbers = {}

	local function safeEggByNumber(n)
		if badEggDirNumbers[n] then
			return nil
		end
		local dir = nil
		local ok, err = pcall(function()
			dir = EggsUtil.GetByNumber(n)
		end)
		if not ok then
			badEggDirNumbers[n] = true
			traceThrottled("egg_dir_bad_" .. tostring(n), 30, "hatch", "skip egg", n, err)
			return nil
		end
		return dir
	end

	local function eggZoneIdsEqual(zoneA, zoneB)
		if not zoneA or not zoneB then
			return false
		end
		if zoneA == zoneB then
			return true
		end
		local a = string.gsub(zoneA, "^%s*(.-)%s*$", "%1")
		local b = string.gsub(zoneB, "^%s*(.-)%s*$", "%1")
		return a == b
	end

	local function eggHatchUnitPriceAndCurrency(eggDir)
		if not eggDir then
			return nil, nil
		end
		local cid = eggDir.Currency or eggDir.CurrencyId or eggDir.CurrencyID or eggDir.currency
		local unit = eggDir.Cost or eggDir.Price or eggDir.CurrencyCost or eggDir.OpenPrice or eggDir.HatchCost
		if type(cid) == "string" and type(unit) == "number" and unit > 0 then
			return cid, unit
		end
		if type(unit) == "number" and unit > 0 and type(cid) ~= "string" then
			pcall(function()
				if Directory and Directory.Eggs and eggDir._id then
					local row = Directory.Eggs[eggDir._id]
					if row then
						cid = row.Currency or row.CurrencyId or cid
					end
				end
			end)
			if type(cid) == "string" then
				return cid, unit
			end
		end
		pcall(function()
			if EggCmds and eggDir._id and type(EggCmds.GetCost) == "function" then
				local c, u = EggCmds.GetCost(eggDir._id, 1)
				if type(u) == "number" and u > 0 then
					cid, unit = c or cid, u
				end
			end
			if (not unit or unit <= 0) and EggCmds and type(EggCmds.GetEggCost) == "function" then
				local u = EggCmds.GetEggCost(eggDir)
				if type(u) == "number" and u > 0 then
					unit = u
				end
			end
			if (not unit or unit <= 0) and EggCmds and type(EggCmds.GetPrice) == "function" then
				local u = EggCmds.GetPrice(eggDir)
				if type(u) == "number" and u > 0 then
					unit = u
				end
			end
			if (not unit or unit <= 0) and Balancing and type(Balancing.CalcEggOpenPrice) == "function" then
				local u = Balancing.CalcEggOpenPrice(eggDir)
				if type(u) == "number" and u > 0 then
					unit = u
				end
			end
			if (not unit or unit <= 0) and Balancing and type(Balancing.CalcEggPrice) == "function" then
				local u = Balancing.CalcEggPrice(eggDir, 1)
				if type(u) == "number" and u > 0 then
					unit = u
				end
			end
		end)
		if type(cid) == "string" and type(unit) == "number" and unit > 0 then
			return cid, unit
		end
		return nil, nil
	end

	local function hatchBatchUpperBound()
		local cap = math.clamp(math.floor(tonumber(cfg().hatchMaxBatchAllowed) or 10), 1, 12)
		if cfg().safeMode ~= false then
			cap = math.min(cap, 3)
		end
		return cap
	end

	local function eggMaxAffordableHatchCount(eggDir, maxWanted)
		local capB = hatchBatchUpperBound()
		maxWanted = math.clamp(maxWanted or capB, 1, capB)
		if cfg().hatchClampToAffordableAmount == false then
			return maxWanted
		end
		if not CurrencyCmds or not eggDir then
			return maxWanted
		end
		local cid, unit = eggHatchUnitPriceAndCurrency(eggDir)
		if not cid or not unit or unit <= 0 then
			if cfg().hatchClampToAffordableAmount ~= false then
				return 1
			end
			return maxWanted
		end
		local bal = 0
		pcall(function()
			bal = CurrencyCmds.Get(cid) or 0
		end)
		return math.clamp(math.floor(bal / unit), 0, maxWanted)
	end

	local function suppressHatchDirectoryZoneError(stage, err, now, progressOnly)
		local es = tostring(err)
		if not string.find(es, "Directory.Zones", 1, true) and not string.find(es, "Unknown Directory Zones", 1, true) then
			return false
		end
		traceThrottled(
			"quest_hatch_zone_dir_" .. tostring(stage),
			30,
			"hatch",
			"skip hatch assist (Directory.Zones); progressOnly=",
			progressOnly,
			err
		)
		return true
	end

	local function nextZoneCurrencyReserveForEgg(eggDir, progressOnly, fromQuestText)
		if progressOnly and cfg().hatchReserveSkipForProgressOnly ~= false then
			return 0, nil
		end
		if cfg().hatchReserveCurrencyForNextZone ~= true or not progressOnly or fromQuestText then
			return 0, nil
		end
		local cid = eggHatchUnitPriceAndCurrency(eggDir)
		if type(cid) ~= "string" then
			return 0, nil
		end
		local ignoreQuestCompletion = cfg().hatchReserveForNextZoneEvenWhenQuestIncomplete ~= false
		local info = ARZone.getNextMainZonePurchaseInfo({ ignoreQuestCompletion = ignoreQuestCompletion })
		if not info or info.currency ~= cid or type(info.price) ~= "number" or info.price <= 0 then
			return 0, info
		end
		local mult = tonumber(cfg().hatchNextZoneReserveMultiplier) or 1
		if mult < 1 then
			mult = 1
		end
		return math.ceil(info.price * mult), info
	end

	local function shouldFilterEggByAfford(useGlobalList)
		if useGlobalList then
			return cfg().hatchPreferAffordableEggGlobally ~= false
		end
		return cfg().hatchPreferAffordableEggInZone ~= false
	end

	local function eggPassesAffordFilter(eggDir, useGlobalList)
		if not shouldFilterEggByAfford(useGlobalList) then
			return true
		end
		if not eggDir then
			return false
		end
		if eggDir._id == "Infinity Egg" then
			return true
		end
		local cid, unit = eggHatchUnitPriceAndCurrency(eggDir)
		if not cid or not unit or unit <= 0 then
			return true
		end
		return eggMaxAffordableHatchCount(eggDir, 1) >= 1
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
			local dirTop = safeEggByNumber(hi)
			if dirTop and eggPassesAffordFilter(dirTop, true) then
				return hi
			end
		end
		while hi > 0 do
			local dir = safeEggByNumber(hi)
			if dir and dir._id and dir._id ~= "Infinity Egg" and eggPassesAffordFilter(dir, true) then
				return hi
			end
			if dir and dir._id == "Infinity Egg" and HatchAssist.infinityAllowed(tracked) and eggPassesAffordFilter(dir, true) then
				return hi
			end
			hi -= 1
		end
		return 0
	end

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
			local dir = safeEggByNumber(i)
			if dir and dir._id then
				if not (dir._id == "Infinity Egg" and not allowInf) then
					local ez = AR.QuestWorldHelpers.getEggZoneIdForNumber(i)
					if ez and eggZoneIdsEqual(ez, zoneId) and eggPassesAffordFilter(dir, false) then
						return i
					end
				end
			end
		end
		return 0
	end

	function HatchAssist.pickEggNumberForHatch(tracked)
		local explicit = AR.QuestWorldHelpers.questSpecifiesEggNumber(tracked)
		if explicit and explicit > 0 then
			return explicit, true
		end
		-- Без активной цели GoalCmds (progress-only): не брать яйцо по спавну/старой зоне — только глобальный pickEggNumber.
		if cfg().preferZoneEggWhenProgress and MapCmds and tracked ~= nil then
			local ordered = {}
			local seen = {}
			local function pushZone(z)
				if type(z) ~= "string" or z == "" then
					return
				end
				if seen[z] then
					return
				end
				seen[z] = true
				table.insert(ordered, z)
			end
			local ch = LocalPlayer.Character
			local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
			if hrp then
				pushZone(AR.QuestWorldHelpers.getZoneIdAtWorldPosition(hrp.Position))
			end
			pushZone(safeCurrentZone())
			if tracked == nil and ZoneCmds and type(ZoneCmds.GetMaxOwnedZone) == "function" then
				local okz, mz = pcall(function()
					return select(1, ZoneCmds.GetMaxOwnedZone())
				end)
				if okz then
					pushZone(mz)
				end
			end
			for _, zoneId in ipairs(ordered) do
				local zn = HatchAssist.pickHighestEggInPhysicalZone(zoneId, tracked)
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
		if eggDir.eggNumber then
			local untilT = Ticks.eggPhysicalPartMissUntil[eggDir.eggNumber]
			if type(untilT) == "number" and untilT > tick() then
				return
			end
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
				Ticks.eggPhysicalPartMissUntil[eggDir.eggNumber] = nil
				log("Pivot to physical egg", eggDir.eggNumber)
			else
				local cd = tonumber(cfg().eggPhysicalPartMissingCooldown) or 10
				Ticks.eggPhysicalPartMissUntil[eggDir.eggNumber] = tick() + math.max(2, cd)
				logThrottled(
					"egg_part_missing_" .. tostring(eggDir.eggNumber),
					math.max(3, cd * 0.5),
					"Failed to find physical egg part for",
					eggDir.eggNumber
				)
			end
		end
	end

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
			if rankGuiSynthProtectionAllowsStay(id) then
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

		local function minigameNoFishDigAssist(_root, _id)
		end
		local chestRush = function(root)
			wave2Combo(root, "ChestRush")
		end
		local wave2Handlers = {
			Fishing = minigameNoFishDigAssist,
			AdvancedFishing = minigameNoFishDigAssist,
			FishingEvent = minigameNoFishDigAssist,
			Digsite = minigameNoFishDigAssist,
			AdvancedDigsite = minigameNoFishDigAssist,
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

	local function tryQuestEggHatchAssist(tracked, opts)
	opts = opts or {}
	local progressOnly = opts.progressOnly == true
	local function hatchSkipDiag(tag, extra)
		if not cfg().log and not cfg().verboseLog then
			return
		end
		traceThrottled("hatch_skip_" .. tostring(tag), 12, "hatch", tag, "progressOnly=", progressOnly, extra)
	end
	if not cfg().questAutoHatch or not HatchingCmds or not EggCmds or not HatchingTypes or not EggsUtil then
		hatchSkipDiag("modules_missing")
		return
	end
	if hatchSequenceBlocksWorldTeleport() then
		hatchSkipDiag("hatch_busy")
		return
	end
	local gen = (tracked and tracked._generatorName) or ""
	if not cfg().questAutoHatchAnytime and not progressOnly then
		local blob = string.lower(QuestAssist.flattenObjectiveText(tracked))
		if not string.find(blob, "hatch", 1, true) and not string.find(blob, "egg", 1, true) then
			hatchSkipDiag("objective_not_egg_hatch", gen)
			return
		end
	end
	local now = tick()
	if progressOnly then
		local pcd = cfg().autoHatchProgressCooldown
		if type(pcd) == "number" and pcd > 0 and (now - Ticks.lastProgressOnlyHatchTick) < pcd then
			hatchSkipDiag("progress_cooldown", pcd)
			return
		end
	end
	if now - Ticks.lastQuestHatchTick < (cfg().questHatchAssistInterval or 1.1) then
		hatchSkipDiag("assist_interval")
		return
	end
	local n, fromQuestText = 0, false
	local pickOk, pickErr = pcall(function()
		n, fromQuestText = HatchAssist.pickEggNumberForHatch(tracked)
	end)
	if not pickOk then
		if suppressHatchDirectoryZoneError("pick", pickErr, now, progressOnly) then
			return
		end
		error(pickErr)
	end
	if n <= 0 then
		hatchSkipDiag("no_egg_number")
		return
	end
	local eggDir = safeEggByNumber(n)
	if not eggDir or not eggDir._id then
		hatchSkipDiag("egg_dir_missing", n)
		return
	end

	if cfg().questEggTeleportIfWrongZone and (fromQuestText or progressOnly) and MapCmds and Network and TeleportMapCmds then
		local cur = safeCurrentZone()
		local eggZ = AR.QuestWorldHelpers.getEggZoneIdForNumber(n)
		if eggZ and cur and not eggZoneIdsEqual(eggZ, cur) then
			local can = false
			local reason = nil
			pcall(function()
				can, reason = TeleportMapCmds.CanTeleportTo(eggZ)
			end)
			if can then
				Ticks.lastQuestHatchTick = now
				armHatchBusyEnd(math.max(cfg().hatchBusyHoldSeconds or 2.6, tonumber(cfg().hatchBusyHoldSecondsHidden) or 14))
				scheduleHatchBusyEarlyRelease(hatchBusyToken)
				if progressOnly then
					Ticks.lastProgressOnlyHatchTick = now
				end
				if cfg().questEggTeleportClientPivotOnly ~= false then
					log("quest egg client pivot → zone", eggZ, "for", eggDir._id, reason)
					AR.Teleports.schedulePivotRepeats(eggZ)
				else
					AR.Net.invoke("Teleports_RequestTeleport", eggZ)
					log("quest egg TP → zone", eggZ, "for", eggDir._id, reason)
					AR.Teleports.schedulePivotRepeats(eggZ)
				end
				return true
			end
		end
	end

	local locked = false
	pcall(function()
		locked = EggCmds.IsEggLocked(eggDir._id) == true
	end)
	if locked then
		if cfg().questAutoUnlockEgg then
			local unlockCd = tonumber(cfg().questEggUnlockCooldown) or 8
			if now - (lastEggUnlockAt[eggDir._id] or 0) >= unlockCd then
				lastEggUnlockAt[eggDir._id] = now
				Ticks.lastQuestHatchTick = now
				pcall(function()
					EggCmds.RequestUnlock(eggDir._id)
				end)
				log("Eggs_RequestUnlock", eggDir._id)
			else
				hatchSkipDiag("unlock_request_throttled", eggDir._id)
			end
		end
		pcall(function()
			locked = EggCmds.IsEggLocked(eggDir._id) == true
		end)
		if locked then
			hatchSkipDiag("egg_still_locked", eggDir._id)
			return
		end
	end
	local capFromGame = 1
	pcall(function()
		local mx = EggCmds.GetMaxHatch(eggDir)
		local capB = hatchBatchUpperBound()
		capFromGame = math.clamp(mx or 1, 1, capB)
	end)
	local hatchAmt = 0
	local affordOk, affordErr = pcall(function()
		hatchAmt = eggMaxAffordableHatchCount(eggDir, capFromGame)
	end)
	if not affordOk then
		if suppressHatchDirectoryZoneError("afford", affordErr, now, progressOnly) then
			return
		end
		error(affordErr)
	end
	local reservedForZone, reservedZone = 0, nil
	local reserveOk, reserveErr = pcall(function()
		reservedForZone, reservedZone = nextZoneCurrencyReserveForEgg(eggDir, progressOnly, fromQuestText)
	end)
	if not reserveOk then
		if suppressHatchDirectoryZoneError("reserve", reserveErr, now, progressOnly) then
			return
		end
		error(reserveErr)
	end
	if reservedForZone > 0 then
		local cid, unit = eggHatchUnitPriceAndCurrency(eggDir)
		local bal = 0
		pcall(function()
			bal = CurrencyCmds.Get(cid) or 0
		end)
		local spendable = math.max(0, bal - reservedForZone)
		if type(unit) == "number" and unit > 0 then
			hatchAmt = math.min(hatchAmt, math.clamp(math.floor(spendable / unit), 0, capFromGame))
		end
	end

	if hatchAmt < 1 and progressOnly and not fromQuestText and cfg().hatchProgressTryCheaperEggWhenReserveBlocks ~= false then
		local mz = nil
		if cfg().hatchProgressFallbackEggMaxOwnedZoneOnly ~= false and ZoneCmds and type(ZoneCmds.GetMaxOwnedZone) == "function" then
			pcall(function()
				mz = select(1, ZoneCmds.GetMaxOwnedZone())
			end)
		end
		local hi = 0
		pcall(function()
			hi = EggCmds.GetHighestEggNumberAvailable() or 0
		end)
		for cand = hi, 1, -1 do
			if cand ~= n then
				local ed = safeEggByNumber(cand)
				if ed and ed._id then
					local allow = true
					if ed._id == "Infinity Egg" and not HatchAssist.infinityAllowed(tracked) then
						allow = false
					elseif ed._id ~= "Infinity Egg" and not eggPassesAffordFilter(ed, true) then
						allow = false
					end
					if allow then
						local loc = false
						pcall(function()
							loc = EggCmds.IsEggLocked(ed._id) == true
						end)
						if loc then
							allow = false
						end
					end
					if allow and mz then
						local ez = AR.QuestWorldHelpers.getEggZoneIdForNumber(cand)
						if not ez or not eggZoneIdsEqual(ez, mz) then
							allow = false
						end
					end
					if allow and cfg().questEggTeleportIfWrongZone and MapCmds and Network and TeleportMapCmds then
						local cur = safeCurrentZone()
						local eggZ = AR.QuestWorldHelpers.getEggZoneIdForNumber(cand)
						if eggZ and cur and not eggZoneIdsEqual(eggZ, cur) then
							local can, reason = false, nil
							pcall(function()
								can, reason = TeleportMapCmds.CanTeleportTo(eggZ)
							end)
							if can then
								Ticks.lastQuestHatchTick = now
								armHatchBusyEnd(math.max(cfg().hatchBusyHoldSeconds or 2.6, tonumber(cfg().hatchBusyHoldSecondsHidden) or 14))
								scheduleHatchBusyEarlyRelease(hatchBusyToken)
								Ticks.lastProgressOnlyHatchTick = now
								if cfg().questEggTeleportClientPivotOnly ~= false then
									log("progress hatch cheaper egg pivot → zone", eggZ, "for", ed._id, reason)
									AR.Teleports.schedulePivotRepeats(eggZ)
								else
									AR.Net.invoke("Teleports_RequestTeleport", eggZ)
									log("progress hatch TP → zone", eggZ, "for", ed._id)
									AR.Teleports.schedulePivotRepeats(eggZ)
								end
								return true
							end
							allow = false
						end
					end
					if allow then
						local cap = 1
						pcall(function()
							local capB = hatchBatchUpperBound()
							cap = math.clamp(EggCmds.GetMaxHatch(ed) or 1, 1, capB)
						end)
						local ha = eggMaxAffordableHatchCount(ed, cap)
						local resZ = 0
						pcall(function()
							resZ = select(1, nextZoneCurrencyReserveForEgg(ed, progressOnly, fromQuestText))
						end)
						if resZ > 0 then
							local cid2, unit2 = eggHatchUnitPriceAndCurrency(ed)
							local bal2 = 0
							pcall(function()
								bal2 = CurrencyCmds.Get(cid2) or 0
							end)
							local spendable2 = math.max(0, bal2 - resZ)
							if type(unit2) == "number" and unit2 > 0 then
								ha = math.min(ha, math.clamp(math.floor(spendable2 / unit2), 0, cap))
							end
						end
						if ha >= 1 then
							n = cand
							eggDir = ed
							capFromGame = cap
							hatchAmt = ha
							break
						end
					end
				end
			end
		end
	end

	if hatchAmt < 1 then
		if cfg().log or cfg().verboseLog then
			traceThrottled(
				"hatch_no_currency_detail",
				14,
				"hatch",
				"quest hatch skip: no currency for",
				eggDir and eggDir._id,
				"cap",
				capFromGame,
				"progressOnly",
				progressOnly,
				"reserve_next",
				reservedZone and reservedZone.id
			)
		end
		hatchSkipDiag("no_currency", eggDir and eggDir._id)
		return
	end
	Ticks.lastQuestHatchTick = now

	local pivotDelay = cfg().hatchAfterPivotDelay or 0.38
	local busyHold = cfg().hatchBusyHoldSeconds or 2.6
	local guardSec = math.max(tonumber(cfg().hatchAsyncTeleportBlockSeconds) or 18, pivotDelay + 1)
	local holdPipeline = math.max(busyHold, tonumber(cfg().hatchBusyHoldSecondsHidden) or guardSec, guardSec)

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
	armHatchBusyEnd(holdPipeline)
	scheduleHatchBusyEarlyRelease(hatchBusyToken)
	task.spawn(function()
		Ticks.hatchAsyncGuardUntil = tick() + guardSec
		pcall(function()
			HatchAssist.pivotForEgg(eggDir, tracked)
			task.wait(pivotDelay)
			if customUid then
				HatchingCmds.SetupCustomEgg(customUid, eggDir, hatchAmt)
			else
				HatchingCmds.SetupEgg(eggDir, hatchAmt)
			end
			HatchingCmds.AttemptHatch()
			if cfg().hideEggHatching then
				ensureAutoRankWorldSelection()
				local nBurst = tonumber(cfg().eggOpeningPostInvokeBurstCount)
				local modWorld = AutoRankWorld.active
				if modWorld and type(modWorld.adjustEggOpeningBurstCount) == "function" then
					local okAdj, nb = pcall(modWorld.adjustEggOpeningBurstCount, nBurst)
					if okAdj and type(nb) == "number" and nb >= 0 then
						nBurst = nb
					end
				end
				local dBurst = tonumber(cfg().eggOpeningPostInvokeBurstDelay)
				if type(nBurst) == "number" and nBurst > 0 and type(dBurst) == "number" and dBurst >= 0 then
					for _ = 1, nBurst do
						task.wait(dBurst)
						ARUI.tryClickEggOpeningPrompt({ ignoreThrottles = true })
					end
				end
			end
		end)
		Ticks.hatchAsyncGuardUntil = tick() + (tonumber(cfg().hatchAsyncPostPipelineGrace) or 3)
	end)
	if progressOnly then
		Ticks.lastProgressOnlyHatchTick = now
	end
	if cfg().hideEggHatching then
		log("quest hatch (hidden)", eggDir._id, hatchAmt, gen)
	else
		log("quest hatch", eggDir._id, hatchAmt, gen)
	end
	return true
end

	return {
		HatchAssist = HatchAssist,
		MinigameAssist = MinigameAssist,
		eggZoneIdsEqual = eggZoneIdsEqual,
		eggMaxAffordableHatchCount = eggMaxAffordableHatchCount,
		tryQuestEggHatchAssist = tryQuestEggHatchAssist,
	}
end)()

function AutoRankRuntimeState.tryTeleportToMaxFarmZone(trackedObjective, isHatching)
	if isHatching or hatchSequenceBlocksWorldTeleport() then
		return
	end

	local cur = safeCurrentZone()
	local maxId = nil
	pcall(function()
		maxId = ZoneCmds and select(1, ZoneCmds.GetMaxOwnedZone())
	end)
	local behindMax = cur and maxId and type(maxId) == "string" and not AR.zonesIdMatch(cur, maxId)

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

	if trackedObjective and cfg().questAssistSkipFarmTeleportWhenObjective and AR.QuestWorldHelpers.objectiveHasWorldTarget(trackedObjective) then
		return
	end
	if not cfg().teleportToMaxFarmZone or not ARZone.teleportFlagOk() then
		return
	end
	if safeIsInInstance() then
		return
	end
	if not TeleportMapCmds or not ZoneCmds or not MapCmds or not Network or not ZonesUtil then
		return
	end
	local now = tick()
	if now - Ticks.lastTeleportTick < (cfg().teleportInterval or 10) then
		return
	end
	local maxZoneId = select(1, ZoneCmds.GetMaxOwnedZone())
	if not maxZoneId or type(maxZoneId) ~= "string" then
		return
	end
	cur = safeCurrentZone()
	local bypassRandomEventForBehindMax = cfg().blockZoneProgressAllowTeleportWhenBehindMax ~= false and behindMax
	if ARQ.hasActiveRandomEventBlockingZoneProgress()
		and cur
		and not AR.zonesIdMatch(cur, maxZoneId)
		and not bypassRandomEventForBehindMax
	then
		traceThrottled(
			"teleport_block_random_event",
			8,
			"teleport",
			"skip max zone: active RandomEvent in",
			tostring(cur)
		)
		return
	end
	if AR.zonesIdMatch(cur, maxZoneId) then
		if cfg().teleportClientPivotWhenSameZone and not AR.playerNearZoneTeleportPoint(maxZoneId) then
			Ticks.lastTeleportTick = now
			log("teleport same zone client pivot", maxZoneId)
			AR.Teleports.schedulePivotRepeats(maxZoneId)
		end
		return
	end
	local can, reason = false, nil
	pcall(function()
		can, reason = TeleportMapCmds.CanTeleportTo(maxZoneId)
	end)
	if not can then
		logThrottled(
			"teleport_cant_now",
			tonumber(cfg().questTeleportCanTeleportLogThrottleSeconds) or 15,
			"teleport skip CanTeleportTo",
			maxZoneId,
			reason
		)
		return
	end
	Ticks.lastTeleportTick = now
	if cfg().teleportMaxZoneClientPivotOnly ~= false then
		log("teleport client pivot max zone", maxZoneId, "from", cur)
		AR.Teleports.schedulePivotRepeats(maxZoneId)
		return
	end
	local r = AR.Net.invoke("Teleports_RequestTeleport", maxZoneId)
	local invokeOk = r ~= false and r ~= nil
	if not invokeOk then
		log("Teleports_RequestTeleport failed", maxZoneId)
		return
	end
	log("Teleport pivot (server+client)", maxZoneId, "from", cur)
	AR.Teleports.schedulePivotRepeats(maxZoneId)
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

function AutoRankRuntimeState.tryPivotToBreakableFarmCenter(isHatching)
	if isHatching or hatchSequenceBlocksWorldTeleport() or not cfg().teleportToBreakableFarmCenter then
		return
	end
	if cfg().advancedRemoteFarm and cfg().remoteFarmSkipBreakablePull then
		return
	end
	if safeIsInInstance() then
		return
	end
	if not ZonesUtil or not ZoneCmds or not MapCmds then
		return
	end
	local maxId = select(1, ZoneCmds.GetMaxOwnedZone())
	if not maxId or type(maxId) ~= "string" then
		return
	end
	local cur = safeCurrentZone()
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
	if now - Ticks.lastFarmCenterTick < (cfg().farmBreakablePullInterval or 1.15) then
		return
	end
	Ticks.lastFarmCenterTick = now
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
	if now - Ticks.lastMinigameAssistTick < (cfg().minigameAssistTickInterval or 0.16) then
		return
	end
	Ticks.lastMinigameAssistTick = now
	if not InstancingCmds then
		return
	end
	if not safeIsInInstance() then
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
	local root = AR.ARC.MinigameAssist.getMinigameInstanceRoot(id)
	local inPlayList =
		AR.ARC.MinigameAssist.instanceIdInMinigameList(id, cfg().minigameAutoPlayInstanceIds or {})
	local assistComplete = mode == "complete" and inPlayList

	if not assistComplete then
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

	local w2 = AR.ARC.MinigameAssist.wave2Handlers[id]
	if w2 then
		w2(root)
	else
		AR.ARC.MinigameAssist.tryGenericObbyFinish(root, id)
	end

	AutoRankRuntimeState.tryMinigameTouchLeaveTeleport(root)
end

function AutoRankRuntimeState.tryQuestAutoLeaveBlockedInstance()
	if not cfg().questAutoLeaveBlockedInstances or not InstancingCmds then
		return
	end
	if not safeIsInInstance() then
		return
	end
	local id = nil
	pcall(function()
		id = InstancingCmds.GetInstanceID and InstancingCmds.GetInstanceID()
	end)
	if type(id) ~= "string" or id == "" then
		return
	end
	if not AR.ARC.MinigameAssist.shouldQuestAutoLeaveInstanceId(id) then
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
	local inInst, okIn = safeIsInInstance()
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
	local tracked = ARG.refreshTrackedObjective()
	local isHatching = false
	pcall(function()
		ARQ.tryQuestSpawnInventoryBreakables(tracked)
	end)
	if tracked then
		local qaOk, qaErr = pcall(function()
			QuestAssist.tryKeywordCooldownReset(tracked)
			ARQ.tryQuestResolveDisplayTargets(tracked)
		end)
		if not qaOk then
			warnErr("quest_resolve_targets", qaErr)
		end
		pcall(function()
			ARQ.tryTravelToTechStuckRetry(tracked)
		end)
		local hhOk, hhErr = pcall(function()
			isHatching = AR.ARC.tryQuestEggHatchAssist(tracked) == true or hatchAsyncPipelineActive()
		end)
		if not hhOk then
			warnErr("tryQuestEggHatchAssist", hhErr)
		end
	end
	local pfOk, pfErr = pcall(function()
		AR.QuestWorldHelpers.tryQuestPlaceFlexibleFlag(tracked)
	end)
	if not pfOk then
		warnErr("tryQuestPlaceFlexibleFlag", pfErr)
	end
	local dqEnd = AutoRankRuntimeState.diagQuest
	if cfg().autoHatchProgressWithoutQuest and cfg().questAutoHatch and not hatchAsyncPipelineActive() then
		local eggRelated = tracked and QuestAssist.objectiveMentionsEggOrHatch(tracked)
		local allowNonEggProgress = tracked
			and cfg().autoHatchProgressWhenNonEggQuest ~= false
			and not eggRelated
		local dgPick = AutoRankRuntimeState.diagGoalPick
		local goalGeneratorsDead = type(dgPick) == "table"
			and (dgPick.generatorCount or 0) > 0
			and (dgPick.validCallbacks or 0) == 0
		local progressHatchBlocked = dqEnd
			and dqEnd.where == "no_goal"
			and (
				dqEnd.detail == "modules_missing"
				or goalGeneratorsDead
			)
		local suppressBlindEgg = cfg().autoHatchProgressWhenGoalModulesMissing == false and progressHatchBlocked
		local wantProgress = false
		if not tracked then
			wantProgress = not suppressBlindEgg
		else
			wantProgress = (tracked and QuestAssist.shouldSkipObjectiveInteraction(tracked))
				or (dqEnd and (dqEnd.where == "no_goal" or dqEnd.where == "tab_blocked"))
				or allowNonEggProgress
			if wantProgress and suppressBlindEgg then
				wantProgress = false
			end
		end
		if wantProgress then
			local phOk, phErr = pcall(function()
				if AR.ARC.tryQuestEggHatchAssist(nil, { progressOnly = true }) == true then
					isHatching = true
				end
			end)
			if not phOk then
				local phe = tostring(phErr)
				if string.find(phe, "Directory.Zones", 1, true) or string.find(phe, "Unknown Directory Zones", 1, true) then
					traceThrottled("progress_hatch_dir_zone_outer", 30, "hatch", "Directory.Zones during progress hatch (non-fatal):", phErr)
				else
					warnErr("tryQuestEggHatchAssist_progressOnly", phErr)
				end
			end
		end
	end
	pcall(function()
		local ph = ARQ.maybeAutoTravelToTechWhenNoGoal(tracked)
		if ph then
			ARQ.tryTravelToTechStuckRetry(ph)
		end
	end)
	isHatching = isHatching or hatchAsyncPipelineActive()
	return tracked, isHatching
end

scheduleQuestAssistPulseAfterHatchBusy = function()
	task.defer(function()
		pcall(function()
			AutoRankRuntimeState.runQuestAssistPulse()
		end)
	end)
end

function AutoRankRuntimeState.tryAutoEquipBestPets()
	if not cfg().autoEquipBestPetsEnabled or not PetCmds or type(PetCmds.EquipBest) ~= "function" then
		return
	end
	local now = tick()
	if now - Ticks.lastAutoEquipBestTick < (cfg().autoEquipBestPetsInterval or 14) then
		return
	end
	if safeIsInInstance() then
		return
	end
	Ticks.lastAutoEquipBestTick = now
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
	if now - Ticks.lastClaimTick < (cfg().claimInterval or 0.35) then
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
	Ticks.lastClaimTick = now
	local spacing = cfg().claimDebounce or 0.28
	task.spawn(function()
		for i, key in ipairs(keys) do
			AR.Net.fire("Ranks_ClaimReward", key)
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
	if now - Ticks.lastRankUpGuiTick < (cfg().rankUpGuiInterval or 1.2) then
		return
	end
	if not RankCmds or not GUI then
		return
	end
	
	local ok, isMax, blocked, allRedeemed = pcall(function()
		return RankCmds.IsMaxRank(), select(1, RankCmds.IsRankBlockedByZone()), RankCmds.AllRewardsRedeemed()
	end)
	
	if not ok then
		return
	end
	
	if isMax then
		return
	end
	if blocked then
		return
	end
	if not allRedeemed then
		return
	end
	Ticks.lastRankUpGuiTick = now
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
	return safeIsInInstance()
end

function AutoRankRuntimeState.farmResolveScanOrigin(diag)
	local pos = characterPrimaryPosition()
	local zoneId = safeCurrentZone()
	diag.zoneId = zoneId
	local mult = 1
	local inInstance = AutoRankRuntimeState.farmGetInInstanceFlag()
	diag.inInstance = inInstance
	if cfg().advancedRemoteFarm and not inInstance and cfg().remoteFarmUseMaxZoneAnchor and ZoneCmds then
		local maxId = select(1, ZoneCmds.GetMaxOwnedZone())
		if maxId and type(maxId) == "string" then
			local farmZoneId = maxId
			local anchor = AutoRankRuntimeState.getBreakableFarmCenterPosition(maxId)
			if zoneId and type(zoneId) == "string" and not AR.zonesIdMatch(zoneId, maxId) and cfg().remoteFarmAnchorCurrentZoneWhenCantTeleportMax ~= false and TeleportMapCmds then
				local can = false
				pcall(function()
					can = TeleportMapCmds.CanTeleportTo(maxId) == true
				end)
				if not can then
					local a2 = AutoRankRuntimeState.getBreakableFarmCenterPosition(zoneId)
					if a2 then
						anchor = a2
						farmZoneId = zoneId
					end
				end
			end
			if zoneId and type(zoneId) == "string" and not AR.zonesIdMatch(zoneId, maxId) and hatchAsyncPipelineActive() then
				local a3 = AutoRankRuntimeState.getBreakableFarmCenterPosition(zoneId)
				if a3 then
					anchor = a3
					farmZoneId = zoneId
				end
			end
			if anchor then
				pos = anchor
				zoneId = farmZoneId
				diag.zoneId = zoneId
				diag.posSource = (farmZoneId == maxId) and "max_zone_anchor" or "current_zone_anchor_fallback"
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

function AutoRankRuntimeState.farmMergeRandomEventBreakableUids(zoneId, inInstance, pos, r, byUid, diag)
	if cfg().farmMergeRandomEventBreakableParts == false then
		return 0
	end
	if inInstance or not BreakableFrontend or type(BreakableFrontend.Get) ~= "function" then
		return 0
	end
	if not pos or not r or type(zoneId) ~= "string" or zoneId == "" then
		return 0
	end
	local things = workspace:FindFirstChild("__THINGS")
	local folder = things and things:FindFirstChild("RandomEvents")
	if not folder then
		return 0
	end
	local added = 0
	local allowShielded = cfg().farmExplosiveBreakableAssist == true
	for _, inst in ipairs(folder:GetDescendants()) do
		if inst:IsA("BasePart") then
			local uid = inst:GetAttribute("BreakableUID")
			if type(uid) == "string" and uid ~= "" and not byUid[uid] then
				local entry = nil
				pcall(function()
					entry = BreakableFrontend.Get(uid)
				end)
				if entry and entry.model and entry.dir and not entry.dir.NoTapping and (not entry.disableDamage or allowShielded) then
					local pp = entry.model.PrimaryPart
					if pp and (pp.Position - pos).Magnitude <= r then
						byUid[uid] = entry
						added += 1
					end
				end
			end
		end
	end
	if added > 0 then
		diag.randomEventBreakablesMerged = added
	end
	return added
end

function AutoRankRuntimeState.farmListInRadius(byUid, pos, r, diag)
	local out = {}
	for uid, entry in pairs(byUid) do
		local model = entry.model
		local pp = model and model.PrimaryPart
		local allowShielded = cfg().farmExplosiveBreakableAssist == true
		if pp and entry.dir and not entry.dir.NoTapping and (not entry.disableDamage or allowShielded) then
			diag.rawTapOk += 1
			local d = (pp.Position - pos).Magnitude
			if d <= r then
				table.insert(out, { uid = uid, entry = entry, d = d })
			end
		end
	end
	local reFolder = nil
	if cfg().farmPrioritizeRandomEventBreakables ~= false then
		local things = workspace:FindFirstChild("__THINGS")
		reFolder = things and things:FindFirstChild("RandomEvents")
	end
	table.sort(out, function(a, b)
		if reFolder then
			local ma = a.entry.model and a.entry.model:IsDescendantOf(reFolder)
			local mb = b.entry.model and b.entry.model:IsDescendantOf(reFolder)
			if ma ~= mb then
				return ma
			end
		end
		if cfg().preferClosest then
			return a.d < b.d
		end
		return false
	end)
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
	local nRe = AutoRankRuntimeState.farmMergeRandomEventBreakableUids(zoneId, diag.inInstance, pos, r, byUid, diag)
	if nRe > 0 then
		diag.rawTotal += nRe
	end
	local out = AutoRankRuntimeState.farmListInRadius(byUid, pos, r, diag)
	AutoRankRuntimeState.farmFinalizeEmptyListDiag(diag, r, out)
	AutoRankRuntimeState.farmCandidateCacheStore(out, diag)
	return out
end

function AutoRankRuntimeState.tryAutoEnableAutoFarm()
	if not cfg().autoEnableAutoFarm then
		return
	end
	if not AutoFarmCmds or type(AutoFarmCmds.Enable) ~= "function" then
		return
	end
	if not safeInDottedBox() then
		return
	end
	local curZone = safeCurrentZone()
	local now = tick()
	local interval = cfg().autoFarmEnableInterval or 9
	local zoneChanged = cfg().autoFarmReenableOnZoneChange and curZone ~= autoFarmEnabledZone
	if not zoneChanged and now - Ticks.lastAutoFarmEnableTick < interval then
		return
	end
	Ticks.lastAutoFarmEnableTick = now
	pcall(function()
		if AutoFarmCmds.IsEnabled and AutoFarmCmds.IsEnabled() and not zoneChanged then
			return
		end
		AutoFarmCmds.Enable()
		autoFarmEnabledZone = curZone
		log("AutoFarm_Enable fired zone=", tostring(curZone))
	end)
end

function AutoRankRuntimeState.signalFireAutoClickerNearby(uid)
	Signal.Fire("AutoClicker_Nearby", uid)
end

function AutoRankRuntimeState.dealDamageSignal(uid)
	if not Signal or type(Signal.Fire) ~= "function" then
		return
	end
	pcallWrap1(AutoRankRuntimeState.signalFireAutoClickerNearby, uid)
end

function AutoRankRuntimeState.farmTick()
	if hatchAsyncPipelineActive() then
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
	tryFarmExplosiveAssist(top)
	local damaged = dealDamage(top.uid)
	if cfg().farmSignalNearbyEnabled then
		AutoRankRuntimeState.dealDamageSignal(top.uid)
	end
	tryFarmFireClickDetectorFallback(top.entry)
	local multiN = tonumber(cfg().farmMultiHitCount) or 1
	if damaged and multiN > 1 then
		for i = 2, math.min(multiN, #list) do
			local extra = list[i]
			if extra and extra.uid then
				AR.Net.unreliable("Breakables_PlayerDealDamage", extra.uid)
				if cfg().farmSignalNearbyEnabled then
					AutoRankRuntimeState.dealDamageSignal(extra.uid)
				end
			end
		end
	end
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
	d.cur = safeCurrentZone()
	pcall(function()
		d.maxOwned = select(1, ZoneCmds.GetMaxOwnedZone())
	end)
	local skip = nil
	local behindMax = d.cur and d.maxOwned and type(d.maxOwned) == "string" and not AR.zonesIdMatch(d.cur, d.maxOwned)
	local skipRemoteTp = cfg().advancedRemoteFarm and cfg().remoteFarmSkipMaxZoneTeleport
	if cfg().forceTeleportWhenBehindMaxZone and behindMax then
		skipRemoteTp = false
	end
	if isHatching or hatchSequenceBlocksWorldTeleport() then
		skip = "hatching_or_hatchBusy"
	elseif skipRemoteTp then
		skip = "remoteFarmSkipMaxZoneTeleport"
	elseif trackedObjective and cfg().questAssistSkipFarmTeleportWhenObjective and AR.QuestWorldHelpers.objectiveHasWorldTarget(trackedObjective) then
		skip = "quest_world_target_blocks_farm_teleport"
	elseif not cfg().teleportToMaxFarmZone then
		skip = "teleportToMaxFarmZone_disabled"
	elseif not ARZone.teleportFlagOk() then
		skip = "teleport_fflag_blocked"
	else
		if safeIsInInstance() then
			skip = "player_in_instance"
		elseif not TeleportMapCmds or not ZoneCmds or not MapCmds or not Network or not ZonesUtil then
			skip = "teleport_modules_missing"
		else
			local nowT = tick()
			local interval = cfg().teleportInterval or 10
			local elapsed = nowT - Ticks.lastTeleportTick
			if elapsed < interval then
				skip = string.format("teleport_interval %.1fs left", interval - elapsed)
			elseif not d.maxOwned or type(d.maxOwned) ~= "string" then
				skip = "no_max_owned_zone_id"
			elseif AR.zonesIdMatch(d.cur, d.maxOwned) then
				if cfg().teleportClientPivotWhenSameZone and cfg().teleportMaxZoneClientPivotOnly ~= false then
					skip = "same_zone_client_pivot_if_far_from_marker"
				else
					skip = "already_at_max_owned_zone"
				end
			else
				local bypassRe = cfg().blockZoneProgressAllowTeleportWhenBehindMax ~= false and behindMax
				if ARQ.hasActiveRandomEventBlockingZoneProgress() and d.cur and not bypassRe then
					skip = "random_event_blocks_teleport in " .. tostring(d.cur)
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
	local qSnippet = dq.snippet or dq.detail or ""
	if dq.synthRankGui then
		qSnippet = tostring(qSnippet) .. " [rankGuiSynth]"
	end
	trace(
		"pulse.quest",
		ql,
		tostring(dq.generator or dq.where or "-"),
		tostring(qSnippet)
	)
	if not dq.ok then
		local dg = AutoRankRuntimeState.diagGoalPick
		if dg and type(dg.hints) == "table" and #dg.hints > 0 then
			trace("pulse.goalHints", table.concat(dg.hints, " | "))
		end
	end
	local guardLeft = 0
	if type(Ticks.hatchAsyncGuardUntil) == "number" then
		guardLeft = math.max(0, Ticks.hatchAsyncGuardUntil - tick())
	end
	trace(
		"pulse.flags",
		"hatchBusy=",
		hatchBusy,
		"hatchGuardLeft=",
		string.format("%.2f", guardLeft),
		"isHatching=",
		isHatching
	)
	local rb = false
	pcall(function()
		rb = Variables and Variables.IsRebirthing == true
	end)
	if rb then
		trace("pulse", "Variables.IsRebirthing=true")
	end
end

function AutoRankRuntimeState.tryAutoClickMessageDialogYes()
	local pg = LocalPlayer:FindFirstChild("PlayerGui")
	if not pg then return end
	local msg = pg:FindFirstChild("Message")
	if not msg or not msg:IsA("ScreenGui") or not msg.Enabled then return end
	
	local clicked = false
	for _, d in ipairs(msg:GetDescendants()) do
		if d:IsA("GuiButton") and d.Visible then
			local t = string.lower(tostring(d.Name))
			local t2 = d:IsA("TextButton") and string.lower(string.gsub(tostring(d.Text), "[%c]", "")) or ""
			local isYes = t == "yes" or string.find(t2, "yes", 1, true)
			local isOk = t == "ok"
				or t2 == "ok"
				or t2 == "ok!"
				or string.find(t2, "ok!", 1, true) == 1
			if isYes or isOk then
				clicked = clickGuiButtonRobust(d) or clicked
				if clicked then
					log("Message dialog auto-clicked", isYes and "YES" or "OK", d:GetFullName())
				end
			end
		end
	end
	return clicked
end

do
function AR.UI.tryDisableBuiltInAutoTapper()
	if cfg().disableBuiltInAutoTapper ~= true then
		return
	end
	if not Save or type(Save.Get) ~= "function" then
		return
	end
	if not Gamepasses or type(Gamepasses.Owns) ~= "function" then
		return
	end
	local now = tick()
	local iv = tonumber(cfg().disableBuiltInAutoTapperInterval) or 2.0
	if now - (Ticks.lastBuiltInAutoTapperTick or 0) < iv then
		return
	end
	Ticks.lastBuiltInAutoTapperTick = now
	local s = Save.Get()
	if not s or s.AutoTapper ~= true then
		return
	end
	local owns = false
	pcall(function() owns = Gamepasses.Owns("Auto Tapper") == true end)
	if not owns then
		return
	end
	local newVal = AR.Net.invoke("AutoTapper_Toggle")
	traceThrottled("disableBuiltInAutoTapper", 5, "tapper",
		"toggled built-in Auto Tapper off (newVal=" .. tostring(newVal) .. ")")
end

AR.Pets.forceDisableListenerInstalled = false
AR.Pets.targetZone = nil
AR.Pets.lastEnableTry = 0
AR.Pets.lastStarterPickTry = 0
AR.Pets.pendingReenable = false
AR.Pets.pendingEnableSpawn = false

function AR.Pets.pickStarterPetIds()
	local pet1 = cfg().autoPickStarterPet1
	local pet2 = cfg().autoPickStarterPet2
	if type(pet1) ~= "string" or pet1 == "" then
		pet1 = "Axolotl"
	end
	if type(pet2) ~= "string" or pet2 == "" or pet2 == pet1 then
		pet2 = "Cat"
	end
	if pet2 == pet1 then
		pet2 = "Dog"
	end
	if Directory and Directory.Pets then
		if not Directory.Pets[pet1] then
			pet1 = "Axolotl"
		end
		if not Directory.Pets[pet2] or pet2 == pet1 then
			pet2 = "Cat"
		end
		if pet2 == pet1 then
			pet2 = Directory.Pets.Axolotl and "Axolotl" or "Dog"
		end
	end
	return pet1, pet2
end

function AR.Pets.tryPickStarterPets()
	if cfg().autoPickStarterPetsEnabled ~= true then
		return false
	end
	if not (Save and type(Save.Get) == "function") then
		return false
	end
	local now = tick()
	local iv = tonumber(cfg().autoPickStarterPetsInterval) or 1.5
	if now - (AR.Pets.lastStarterPickTry or 0) < iv then
		return false
	end
	local s = Save.Get()
	if not s or s.PickedStarterPet then
		return false
	end
	if not Network or type(Network.Invoke) ~= "function" then
		return false
	end
	AR.Pets.lastStarterPickTry = now
	local pet1, pet2 = AR.Pets.pickStarterPetIds()
	local res, err = AR.Net.invoke("Pick Starter Pets", pet1, pet2)
	log("Pick Starter Pets", pet1, pet2, "res=", res, "err=", err)
	if res ~= false and res ~= nil then
		pcall(function()
			if TabController and type(TabController.CloseTab) == "function" then
				TabController.CloseTab()
			end
		end)
		return true
	end
	return false
end

function AR.Pets.installForceDisableListener()
	if AR.Pets.forceDisableListenerInstalled then
		return
	end
	if not Network or type(Network.Fired) ~= "function" then
		return
	end
	if cfg().petsAlwaysFarmListenForceDisable == false then
		return
	end
	local sig = AR.Net.fired("AutoFarm_ForceDisable")
	if not sig or not sig.Connect then
		return
	end
	local conn = sig:Connect(function()
		AR.Pets.pendingReenable = true
		traceThrottled("pets_force_disable_recv", 4, "pets", "AutoFarm_ForceDisable получен — пометил pendingReenable")
	end)
	autoRankRegisterTaggedConn("pets_autofarm_force_disable", conn)
	AR.Pets.forceDisableListenerInstalled = true
end

function AR.Pets.requestPivotToFarm()
	if AutoRankRuntimeState and type(AutoRankRuntimeState.tryPivotToBreakableFarmCenter) == "function" then
		pcall(AutoRankRuntimeState.tryPivotToBreakableFarmCenter, false)
	end
end

function AR.Pets.tryEnableAutoFarmIfInBox()
	if not (AutoFarmCmds and type(AutoFarmCmds.Enable) == "function") then
		return
	end
	if not safeInDottedBox() then
		return false
	end
	pcall(function() AutoFarmCmds.Enable() end)
	AR.Pets.pendingReenable = false
	traceThrottled("pets_autofarm_enabled", 4, "pets", "AutoFarmCmds.Enable() — петы заякорены")
	return true
end

function AR.Pets.tick()
	if cfg().petsAlwaysFarmEnabled ~= true then
		return
	end
	if not AutoFarmCmds or type(AutoFarmCmds.Enable) ~= "function" then
		return
	end
	if not ZoneCmds or type(ZoneCmds.GetMaxOwnedZone) ~= "function" then
		return
	end
	AR.Pets.installForceDisableListener()
	local now = tick()
	local iv = tonumber(cfg().petsAlwaysFarmTickInterval) or 1.0
	if now - (AR.Pets.lastEnableTry or 0) < iv and not AR.Pets.pendingReenable then
		return
	end
	AR.Pets.lastEnableTry = now
	local maxOwnedId = nil
	pcall(function() maxOwnedId = select(1, ZoneCmds.GetMaxOwnedZone()) end)
	if type(maxOwnedId) ~= "string" then
		return
	end
	AR.Pets.targetZone = maxOwnedId
	local enabled = false
	pcall(function() enabled = AutoFarmCmds.IsEnabled() == true end)
	local curParentId = nil
	if enabled and type(AutoFarmCmds.GetTargetParentId) == "function" then
		pcall(function() curParentId = AutoFarmCmds.GetTargetParentId() end)
	end
	if enabled and curParentId == maxOwnedId and not AR.Pets.pendingReenable then
		return
	end
	AR.Pets.requestPivotToFarm()
	if AR.Pets.tryEnableAutoFarmIfInBox() then
		return
	end
	if AR.Pets.pendingEnableSpawn then
		return
	end
	AR.Pets.pendingEnableSpawn = true
	task.spawn(function()
		local deadline = tick() + 1.5
		while tick() < deadline do
			task.wait(0.1)
			if safeInDottedBox() then
				AR.Pets.tryEnableAutoFarmIfInBox()
				break
			end
		end
		AR.Pets.pendingEnableSpawn = false
	end)
end

function AR.Reward.hasAccess()
	if not Save or type(Save.Get) ~= "function" then
		return false
	end
	local s = Save.Get()
	if not s then
		return false
	end
	if (tonumber(s.Rebirths) or 0) >= 1 then
		return true
	end
	if not (ZoneCmds and ZoneCmds.GetMaxOwnedZone and Balancing and Balancing.Constants) then
		return false
	end
	local minZone = tonumber(Balancing.Constants.MinimumZoneFreeGifts) or 9
	local _, zoneData = nil, nil
	pcall(function() _, zoneData = ZoneCmds.GetMaxOwnedZone() end)
	if zoneData and tonumber(zoneData.ZoneNumber) and tonumber(zoneData.ZoneNumber) >= minZone then
		return true
	end
	return false
end

function AR.Reward.fflagAllows()
	if not FFlags then
		return true
	end
	local ok = false
	pcall(function()
		if type(FFlags.CanBypass) == "function" and FFlags.CanBypass() then
			ok = true
			return
		end
		if type(FFlags.Get) == "function" and FFlags.Keys and FFlags.Keys.FreeGifts then
			ok = FFlags.Get(FFlags.Keys.FreeGifts) == true
		else
			ok = true
		end
	end)
	return ok
end

function AR.Reward.searchArray(arr, val)
	if type(arr) ~= "table" then
		return false
	end
	for _, v in ipairs(arr) do
		if v == val then
			return true
		end
	end
	return false
end

function AR.Reward.claimFreeGift(id)
	local res, err = AR.Net.invoke("Redeem Free Gift", id)
	log("Redeem Free Gift id=", id, "res=", res, "err=", err)
	return res ~= false and res ~= nil
end

function AR.Reward.tick()
	if cfg().autoRedeemFreeGifts ~= true then
		return
	end
	if not Save or not Directory then
		return
	end
	local now = tick()
	local iv = tonumber(cfg().freeGiftsCheckInterval) or 30
	if now - (Ticks.lastFreeGiftsTick or 0) < iv then
		return
	end
	Ticks.lastFreeGiftsTick = now
	if not AR.Reward.hasAccess() then
		return
	end
	if not AR.Reward.fflagAllows() then
		traceThrottled("reward_fflag_blocked", 60, "reward", "FFlags.FreeGifts выключен — skip")
		return
	end
	local s = Save.Get()
	local dir = Directory.FreeGifts
	if not s or type(dir) ~= "table" then
		return
	end
	local redeemed = s.FreeGiftsRedeemed or {}
	local timeAcc = tonumber(s.FreeGiftsTime) or 0
	local claimed = 0
	local maxClaims = math.max(1, tonumber(cfg().freeGiftsMaxClaimsPerTick) or 12)
	for idx, entry in ipairs(dir) do
		if type(entry) == "table" then
			local waitTime = tonumber(entry.WaitTime) or math.huge
			local giftId = entry.Id or idx
			if
				timeAcc >= waitTime
				and not AR.Reward.searchArray(redeemed, idx)
				and not AR.Reward.searchArray(redeemed, giftId)
				and not freeGiftClaimedLocal[giftId]
				and not freeGiftClaimedLocal[idx]
			then
				if AR.Reward.claimFreeGift(giftId) then
					claimed += 1
					freeGiftClaimedLocal[giftId] = true
					freeGiftClaimedLocal[idx] = true
				end
				if claimed >= maxClaims then
					return
				end
			end
		end
	end
end

function AR.Lootbox.itemAmount(data)
	if type(data) ~= "table" then
		return 0
	end
	return tonumber(data._am or data.amt or data.amount or data.n or data.Amount or data.qty) or 1
end

function AR.Lootbox.tick()
	if cfg().autoOpenInstantLootboxes ~= true and cfg().autoOpenNonInstantLootboxes ~= true then
		return
	end
	if not Save or not Directory then
		return
	end
	local now = tick()
	local iv = tonumber(cfg().lootboxOpenInterval) or 1.5
	if now - (Ticks.lastLootboxTick or 0) < iv then
		return
	end
	Ticks.lastLootboxTick = now
	local s = Save.Get()
	local dir = Directory.Lootboxes
	if not s or type(s.Inventory) ~= "table" or type(s.Inventory.Lootbox) ~= "table" or type(dir) ~= "table" then
		return
	end
	local batch = math.max(1, tonumber(cfg().lootboxBatchAmount) or 25)
	for uid, data in pairs(s.Inventory.Lootbox) do
		if type(uid) == "string" and type(data) == "table" then
			local id = data.id
			local d = id and dir[id]
			if type(d) == "table" then
				local amt = AR.Lootbox.itemAmount(data)
				if amt >= 1 then
					local takeAmt = math.min(batch, amt)
					if d.Instant == true and not d.IsCardPack and cfg().autoOpenInstantLootboxes == true then
						local res, err = AR.Net.invoke("Lootbox: Open", uid, takeAmt, nil)
						log("Lootbox: Open instant uid=", uid, "id=", id, "amt=", takeAmt, "res=", res, "err=", err)
						return
					elseif (not d.Instant) and cfg().autoOpenNonInstantLootboxes == true then
						local res, err = AR.Net.invoke("Lootbox: Open", uid, 1, nil)
						if res == false then
							traceThrottled("lootbox_noplace_" .. tostring(id), 30, "lootbox",
								"non-Instant lootbox требует место в мире — silent skip", id)
						else
							log("Lootbox: Open placed uid=", uid, "id=", id, "res=", res, "err=", err)
						end
						return
					end
				end
			end
		end
	end
end

function AR.Cons.inventoryAmountByDirId(invField, dirId)
	if not (Save and type(Save.Get) == "function") then
		return 0
	end
	local s = Save.Get()
	if not s or type(s.Inventory) ~= "table" then
		return 0
	end
	local inv = s.Inventory[invField]
	if type(inv) ~= "table" then
		return 0
	end
	local total = 0
	for _, data in pairs(inv) do
		if type(data) == "table" and data.id == dirId then
			total = total + (tonumber(data._am or data.amt or data.amount or data.n or data.Amount or data.qty) or 1)
		end
	end
	return total
end

function AR.Cons.debug(...)
	if cfg().consumeDebugLog ~= false then
		traceThrottled("cons_dbg_" .. tostring(select(1, ...)) .. "_" .. tostring(select(2, ...)), 2, "cons", ...)
	end
end

function AR.Cons.idCandidates(id)
	local out = {}
	local seen = {}
	local function add(v)
		if type(v) == "string" and v ~= "" and not seen[v] then
			out[#out + 1] = v
			seen[v] = true
		end
	end
	add(id)
	if type(id) == "string" then
		add((string.gsub(id, "%s+", "")))
		add((string.gsub(id, "Flag$", " Flag")))
		if id == "Basic Sprinkler" then
			add("Breakable Sprinkler")
			add("SprinklerBasic")
			add("BasicSprinkler")
		elseif id == "SprinklerBasic" or id == "BasicSprinkler" or id == "Breakable Sprinkler" then
			add("Breakable Sprinkler")
			add("Basic Sprinkler")
		end
	end
	return out
end

function AR.Cons.inventoryAmountAny(invFields, ids)
	local best = 0
	for _, field in ipairs(invFields) do
		for _, id in ipairs(ids) do
			best = math.max(best, AR.Cons.inventoryAmountByDirId(field, id))
		end
	end
	return best
end

function AR.Cons.inventoryCandidatesAny(invFields, ids)
	local out = {}
	if not (Save and type(Save.Get) == "function") then
		return out
	end
	local s = Save.Get()
	if not s or type(s.Inventory) ~= "table" then
		return out
	end
	for _, field in ipairs(invFields) do
		local inv = s.Inventory[field]
		if type(inv) == "table" then
			for uid, data in pairs(inv) do
				if type(uid) == "string" and type(data) == "table" then
					for _, id in ipairs(ids) do
						if data.id == id then
							local amount = tonumber(data._am or data.amt or data.amount or data.n or data.Amount or data.qty) or 1
							table.insert(out, { uid = uid, id = id, amount = amount, field = field })
							break
						end
					end
				end
			end
		end
	end
	table.sort(out, function(a, b)
		if a.amount ~= b.amount then
			return a.amount > b.amount
		end
		return tostring(a.uid) < tostring(b.uid)
	end)
	return out
end

function AR.Cons.getCurrentZoneId()
	return safeCurrentZone()
end

function AR.Cons.conditionMet(cond)
	if cond == "alwaysOn" then
		return true
	end
	if cond == "inDottedBox" then
		return safeInDottedBox()
	end
	if cond == "hatchSession" then
		local dq = AutoRankRuntimeState and AutoRankRuntimeState.diagQuest
		if dq and type(dq.snippet) == "string" and string.find(string.lower(dq.snippet), "hatch", 1, true) then
			return true
		end
		return hatchBusy == true or hatchAsyncPipelineActive()
	end
	if cond == "eggHatch" then
		if Variables and Variables.OpeningEgg == true then
			return true
		end
		return hatchBusy == true or hatchAsyncPipelineActive()
	end
	return false
end

function AR.Cons.tryConsumeFlag(name, flagId, reserve)
	if not (FlexibleFlagCmds and type(FlexibleFlagCmds.Consume) == "function") then
		AR.Cons.debug("flag", name, "skip: FlexibleFlagCmds missing")
		return false
	end
	if cfg().consumeSkipMagnetFlagWhenOrbMagnet ~= false then
		if name == "Magnet" or (type(flagId) == "string" and string.find(flagId, "Magnet", 1, true)) then
			if cfg().collectOrbs and cfg().orbMagnetBoost then
				AR.Cons.debug("flag", name, "skip: collectOrbs+orbMagnetBoost")
				return false
			end
		end
	end
	local ids = AR.Cons.idCandidates(flagId)
	for _, cid in ipairs(ids) do
		local failKey = "flag:" .. tostring(cid)
		if (AR.Cons.failUntil[failKey] or 0) > tick() then
			AR.Cons.debug("flag", name, "skip: failure cooldown", cid)
			continue
		end
		local active = false
		if type(FlexibleFlagCmds.PlayerHasActiveFlag) == "function" then
			pcall(function() active = FlexibleFlagCmds.PlayerHasActiveFlag(cid) == true end)
		end
		if active then
			AR.Cons.debug("flag", name, "skip: already active", cid)
			continue
		end
		local maxPlace = 1
		if type(FlexibleFlagCmds.GetMaxPlaceAutomaticContext) == "function" then
			pcall(function()
				maxPlace = tonumber(FlexibleFlagCmds.GetMaxPlaceAutomaticContext(cid)) or 0
			end)
		end
		if maxPlace <= 0 then
			AR.Cons.debug("flag", name, "skip: no place slots", cid)
			continue
		end
		local candidates = AR.Cons.inventoryCandidatesAny({ "Flag", "ZoneFlag", "FlexibleFlag", "Misc" }, { cid })
		local stack = 0
		for _, c in ipairs(candidates) do
			stack += c.amount
		end
		if stack > 0 and stack <= (tonumber(reserve) or 0) then
			AR.Cons.debug("flag", name, "skip: reserve", cid, "stack=", stack, "reserve=", reserve)
			continue
		end
		local best = candidates[1]
		if not best then
			AR.Cons.debug("flag", name, "skip: no local stack", cid)
			continue
		end
		local take = 1
		local res, err = pcall(function()
			return FlexibleFlagCmds.Consume(cid, best.uid, take)
		end)
		local okRes = res and err ~= false and err ~= nil
		log("Cons flag", name, cid, "uid=", best.uid, "take=", take, "stack=", stack, "res=", err, "pcall=", res)
		AR.Cons.debug("flag", name, "consume", cid, "uid=", best.uid, "take=", take, "stack=", stack, "res=", err)
		if not okRes then
			AR.Cons.failUntil[failKey] = tick() + (tonumber(cfg().consumeFailureCooldown) or 8)
		end
		return true
	end
	return false
end

function AR.Cons.tryConsumeSprinkler(name, sprinklerId, reserve)
	if not (AR.Cons.SprinklerCmds and type(AR.Cons.SprinklerCmds.Consume) == "function") then
		AR.Cons.debug("sprinkler", name, "skip: SprinklerCmds missing")
		return false
	end
	local zid = AR.Cons.getCurrentZoneId()
	if not zid then
		AR.Cons.debug("sprinkler", name, "skip: no current zone")
		return false
	end
	do
		local sparseBelow = tonumber(cfg().consumeSprinklerOnlyWhenInRadiusBelow) or 0
		if sparseBelow > 0 then
			local df = AutoRankRuntimeState.diagFarm or {}
			local ir = tonumber(df.inRadius)
			local rt = tonumber(df.rawTapOk)
			local minTap = tonumber(cfg().consumeSprinklerSparseMinRawTapOk) or 10
			if type(ir) ~= "number" or ir > sparseBelow then
				AR.Cons.debug("sprinkler", name, "skip: sparse gate inRadius", tostring(ir), sparseBelow)
				return false
			end
			if type(rt) ~= "number" or rt < minTap then
				AR.Cons.debug("sprinkler", name, "skip: sparse gate rawTapOk", tostring(rt), minTap)
				return false
			end
		end
	end
	local ids = AR.Cons.idCandidates(sprinklerId)
	for _, sid in ipairs(ids) do
		local failKey = "sprinkler:" .. tostring(sid) .. ":" .. tostring(zid)
		if (AR.Cons.failUntil[failKey] or 0) > tick() then
			AR.Cons.debug("sprinkler", name, "skip: failure cooldown", sid, "zone=", zid)
			continue
		end
		local active = false
		if type(AR.Cons.SprinklerCmds.PlayerHasActiveSprinkler) == "function" then
			pcall(function() active = AR.Cons.SprinklerCmds.PlayerHasActiveSprinkler(sid) == true end)
		end
		if active then
			AR.Cons.debug("sprinkler", name, "skip: already active", sid, "zone=", zid)
			continue
		end
		local maxPlace = 1
		if type(AR.Cons.SprinklerCmds.GetMaxPlace) == "function" then
			pcall(function()
				maxPlace = tonumber(AR.Cons.SprinklerCmds.GetMaxPlace(sid, zid)) or 0
			end)
		end
		if maxPlace <= 0 then
			AR.Cons.debug("sprinkler", name, "skip: no place slots", sid, "zone=", zid)
			continue
		end
		local candidates = AR.Cons.inventoryCandidatesAny({ "Sprinkler", "Misc", "Consumable" }, { sid })
		local stack = 0
		for _, c in ipairs(candidates) do
			stack += c.amount
		end
		if stack > 0 and stack <= (tonumber(reserve) or 0) then
			AR.Cons.debug("sprinkler", name, "skip: reserve", sid, "stack=", stack, "reserve=", reserve)
			continue
		end
		local best = candidates[1]
		if not best then
			AR.Cons.debug("sprinkler", name, "skip: no local stack", sid)
			continue
		end
		local cap = math.max(1, math.floor(tonumber(cfg().consumeSprinklerMaxPerInvoke) or 1))
		local take = math.min(best.amount, math.max(1, maxPlace), math.max(1, stack - (tonumber(reserve) or 0)), cap)
		local res, err = pcall(function()
			return AR.Cons.SprinklerCmds.Consume(sid, best.uid, take)
		end)
		local okRes = res and err ~= false and err ~= nil
		log("Cons sprinkler", name, sid, "uid=", best.uid, "take=", take, "zone=", zid, "stack=", stack, "res=", err, "pcall=", res)
		AR.Cons.debug("sprinkler", name, "consume", sid, "uid=", best.uid, "take=", take, "zone=", zid, "stack=", stack, "res=", err)
		if not okRes then
			AR.Cons.failUntil[failKey] = tick() + (tonumber(cfg().consumeFailureCooldown) or 8)
		end
		return true
	end
	return false
end

function AR.Cons.tryConsumePotion(name, potionId, reserve)
	if not (PotionCmds and type(PotionCmds.Consume) == "function") then
		return false
	end
	if not Save then
		return false
	end
	local s = Save.Get()
	if not s or not s.Inventory or not s.Inventory.Potion then
		return false
	end
	local candidates = {}
	for uid, data in pairs(s.Inventory.Potion) do
		if type(uid) == "string" and type(data) == "table" and data.id == potionId then
			local tier = tonumber(data.tn) or 1
			local tierOk = true
			if MasteryCmds and MasteryCmds.CanUsePotion then
				pcall(function()
					tierOk = select(1, MasteryCmds.CanUsePotion(tier)) == true
				end)
			end
			if tierOk then
				table.insert(candidates, { uid = uid, tier = tier })
			end
		end
	end
	if #candidates == 0 then
		return false
	end
	local stack = AR.Cons.inventoryAmountByDirId("Potion", potionId)
	if stack <= (tonumber(reserve) or 0) then
		return false
	end
	table.sort(candidates, function(a, b)
		if a.tier ~= b.tier then
			return a.tier > b.tier
		end
		return tostring(a.uid) < tostring(b.uid)
	end)
	local best = candidates[1]
	local ok, err = pcall(function()
		PotionCmds.Consume(best.uid, 1)
	end)
	log("Cons potion", name, potionId, "uid=", best.uid, "stack=", stack, "tier=", best.tier, ok, err)
	return ok
end

AR.Cons.SprinklerCmds = nil
AR.Cons.failUntil = AR.Cons.failUntil or {}
function AR.Cons.ensureSprinklerCmds()
	if AR.Cons.SprinklerCmds ~= nil then
		return AR.Cons.SprinklerCmds
	end
	local Client = ClientFolder
	if not Client then
		return nil
	end
	pcall(function()
		local m = Client:FindFirstChild("SprinklerCmds")
		if m then
			AR.Cons.SprinklerCmds = cacheReq(m)
		end
	end)
	return AR.Cons.SprinklerCmds
end

local AR_CONS_TICK_PRIO = {
	{ fn="flag",      name="Hasty",       prio=10, cond="inDottedBox",
		toggleCfgKey="consumeFlagsHasty",      reserveCfgKey="consumeReserveHasty",      idCfgKey="consumeFlagIdHasty" },
	{ fn="flag",      name="Strength",    prio=10, cond="inDottedBox",
		toggleCfgKey="consumeFlagsStrength",   reserveCfgKey="consumeReserveStrength",   idCfgKey="consumeFlagIdStrength" },
	{ fn="flag",      name="Magnet",      prio=8,  cond="inDottedBox",
		toggleCfgKey="consumeFlagsMagnet",     reserveCfgKey="consumeReserveMagnet",     idCfgKey="consumeFlagIdMagnet" },
	{ fn="sprinkler", name="Sprinkler",   prio=7,  cond="inDottedBox",
		toggleCfgKey="consumeSprinklers",      reserveCfgKey="consumeReserveSprinkler",  idCfgKey="consumeSprinklerId" },
	{ fn="potion",    name="DamagePotion",prio=6,  cond="alwaysOn",
		toggleCfgKey="consumeDamagePotion",    reserveCfgKey="consumeReserveDamagePotion", idCfgKey="consumePotionIdDamage" },
	{ fn="potion",    name="Rainbow",     prio=4,  cond="hatchSession",
		toggleCfgKey="consumeRainbow",         reserveCfgKey="consumeReserveRainbow",    idCfgKey="consumePotionIdRainbow" },
	{ fn="potion",    name="Shiny",       prio=4,  cond="hatchSession",
		toggleCfgKey="consumeShiny",           reserveCfgKey="consumeReserveShiny",      idCfgKey="consumePotionIdShiny" },
	{ fn="potion",    name="HugeHunter",  prio=3,  cond="eggHatch",
		toggleCfgKey="consumeHugeHunter",      reserveCfgKey="consumeReserveHugeHunter", idCfgKey="consumePotionIdHugeHunter" },
}

function AR.Cons.tick()
	if cfg().autoConsumeEnabled ~= true then
		return
	end
	if ARQ.buffConsumablesInstanceBlocked() then
		return
	end
	local now = tick()
	local iv = tonumber(cfg().consumablesTickInterval) or 4
	if now - (Ticks.lastConsTick or 0) < iv then
		return
	end
	Ticks.lastConsTick = now
	if now - (Ticks.lastConsFailPruneTick or 0) > math.max(30, (tonumber(cfg().consumeFailureCooldown) or 8) * 4) then
		Ticks.lastConsFailPruneTick = now
		for key, untilAt in pairs(AR.Cons.failUntil or {}) do
			if type(untilAt) ~= "number" or untilAt <= now then
				AR.Cons.failUntil[key] = nil
			end
		end
	end
	AR.Cons.ensureSprinklerCmds()
	for _, e in ipairs(AR_CONS_TICK_PRIO) do
		local cfg_t = cfg()
		if cfg_t[e.toggleCfgKey] == true and AR.Cons.conditionMet(e.cond) then
			local id = cfg_t[e.idCfgKey]
			local reserve = cfg_t[e.reserveCfgKey] or 0
			if type(id) == "string" then
				local consumed = false
				if e.fn == "flag" then
					consumed = AR.Cons.tryConsumeFlag(e.name, id, reserve)
				elseif e.fn == "sprinkler" then
					consumed = AR.Cons.tryConsumeSprinkler(e.name, id, reserve)
				elseif e.fn == "potion" then
					consumed = AR.Cons.tryConsumePotion(e.name, id, reserve)
				end
				if consumed then
					return
				end
			end
		end
	end
end

function AR.HB.dispatch()
	if cfg().hbSchedulerEnabled == false then
		return AutoRankRuntimeState.autoRankHeartbeatWorkLegacy()
	end
	local cfg_t = cfg()
	local now = tick()
	local hbTicks = Ticks.hb
	local tasks = AR.HB.tasks
	if not tasks then
		return
	end
	for i = 1, #tasks do
		local t = tasks[i]
		local lastT = hbTicks[t.tag] or 0
		local iv = t.interval or 0
		if type(iv) == "string" then
			iv = tonumber(cfg_t[iv]) or 0
		elseif type(iv) == "function" then
			iv = tonumber(iv(cfg_t)) or 0
		end
		if iv == 0 or now - lastT >= iv then
			if t.gate and not t.gate() then
			else
				hbTicks[t.tag] = now
				local ok, err = pcall(t.fn, cfg_t)
				if not ok then
					traceThrottled("hb_err_" .. t.tag, 5, "hb", "task", t.tag, "err", err)
				end
			end
		end
	end
end

-- Тот же порядок/набор, что AR.HB.tasks; без интервалов (каждый Heartbeat). При hbSchedulerEnabled=false.
function AR.HB.runLegacyFrame()
	local cfg_t = cfg()
	local tasks = AR.HB.tasks
	if not tasks then
		return
	end
	for i = 1, #tasks do
		local t = tasks[i]
		if t.gate and not t.gate() then
		else
			local ok, err = pcall(t.fn, cfg_t)
			if not ok then
				traceThrottled("hb_legacy_err_" .. t.tag, 5, "hb", "legacy task", t.tag, "err", err)
			end
		end
	end
end

function AutoRankRuntimeState.autoRankHeartbeatWorkLegacy()
	AR.HB.runLegacyFrame()
	return AR.HB.state.trackedQuest, AR.HB.state.isHatching
end

AR.HB.state = { trackedQuest = nil, isHatching = false }

AR.HB.tasks = {
	{ tag = "ensureModules", interval = "hbIntervalEnsureModules", fn = function() pcall(ensureModulesOnHeartbeat) end },
	{ tag = "dismissRebirth", interval = "hbIntervalDismissUI", fn = function() ARUI.tryDismissRebirthUi() end,
		gate = function() return Variables and Variables.IsRebirthing == true end },
	{ tag = "dismissRankUp", interval = "hbIntervalDismissUI", fn = function() ARUI.tryDismissRankUpUi() end,
		gate = function() return Variables and Variables.IsRankingUp == true end },
	{ tag = "dismissMasteryPerk", interval = "hbIntervalDismissUI", fn = function() ARUI.tryDismissMasteryPerkUi() end },
	{ tag = "msgDialogYes", interval = 0.5, fn = function() AutoRankRuntimeState.tryAutoClickMessageDialogYes() end },
	{ tag = "netDebugHook", interval = 1.0, fn = function() tryInstallNetworkInvokeDebugHook() end },
	{ tag = "kickGuard", interval = 1.0, fn = function() tryInstallKickGuard() end },
	{ tag = "orbMagnet", interval = 0.5, fn = function() patchOrbMagnet() end },
	{ tag = "orbNetHook", interval = 0.5, fn = function() hookOrbNetwork() end },
	{ tag = "tutorial", interval = 1.0, fn = function() AutoRankRuntimeState.tutorialTick() end },
	{ tag = "starterPets", interval = "autoPickStarterPetsInterval", fn = function() AR.Pets.tryPickStarterPets() end },
	{ tag = "claimRanks", interval = 0.35, fn = function() AutoRankRuntimeState.tryClaimRankRewards() end },
	{ tag = "rankUpGui", interval = 0.5, fn = function() AutoRankRuntimeState.tryRankUpViaGui() end },
	{ tag = "buyEggSlots", interval = "hbIntervalAutoBuy", fn = function() tryAutoBuyEggSlots() end },
	{ tag = "buyEquipSlots", interval = "hbIntervalAutoBuy", fn = function() tryAutoBuyEquipSlots() end },
	{ tag = "buyUpgrade", interval = "hbIntervalAutoBuy", fn = function() tryAutoBuyCheapestUpgrade() end },
	{ tag = "minigame", interval = "hbIntervalQuestAssist", fn = function() AutoRankRuntimeState.tryMinigameAssistPulse() end },
	{ tag = "questAssist", interval = "hbIntervalQuestAssist", fn = function()
		local qaOk, qaErr = pcall(function()
			AR.HB.state.trackedQuest, AR.HB.state.isHatching = AutoRankRuntimeState.runQuestAssistPulse()
		end)
		if not qaOk then
			warnErr("runQuestAssistPulse", qaErr)
		end
	end },
	{ tag = "buyInstanceZone", interval = "hbIntervalAutoBuy", fn = function() ARZone.tryAutoBuyInstanceZone() end },
	{ tag = "buyMainZone", interval = "hbIntervalAutoBuy", fn = function() ARZone.tryAutoBuyMainZone() end },
	{ tag = "consumablesLegacy", interval = "hbIntervalConsumables", fn = function() AR.Cons.tryAutoBuffConsumablesPulseLegacy() end },
	{ tag = "daycare", interval = 1.0, fn = function() tryAutoDaycare() end },
	{ tag = "questEnchant", interval = "hbIntervalEquipPets", fn = function()
		pcall(function()
			ARQ.tryQuestEquipEnchantFromInventory(AR.HB.state.isHatching == true or hatchAsyncPipelineActive())
		end)
	end },
	{ tag = "eggOpeningPrompt", interval = 0.32, fn = function() ARUI.tryClickEggOpeningPrompt() end },
	{ tag = "equipPets", interval = "hbIntervalEquipPets", fn = function() AutoRankRuntimeState.tryAutoEquipBestPets() end },
	{ tag = "returnToArea", interval = 1.0, fn = function() ARUI.tryClickReturnToMaxAreaButton() end },
	{ tag = "teleportMaxFarm", interval = 0.5, fn = function()
		AutoRankRuntimeState.tryTeleportToMaxFarmZone(AR.HB.state.trackedQuest, AR.HB.state.isHatching)
	end },
	{ tag = "pivotFarmCenter", interval = 0.5, fn = function()
		AutoRankRuntimeState.tryPivotToBreakableFarmCenter(AR.HB.state.isHatching)
	end },
	{ tag = "autoFarmEnable", interval = "hbIntervalAutoFarmEnable", fn = function() AutoRankRuntimeState.tryAutoEnableAutoFarm() end },
	{ tag = "petsAlwaysFarm", interval = 0, fn = function() AR.Pets.tick() end },
	{ tag = "farmTick", interval = "hbIntervalDealDamage", fn = function() AutoRankRuntimeState.farmTick() end },
	{ tag = "orbCollect", interval = 0.35, fn = function() tryCollectOrbs() end },
	{ tag = "tapperOff", interval = 2.0, fn = function() AR.UI.tryDisableBuiltInAutoTapper() end },
	{ tag = "freeGifts", interval = "hbIntervalFreeRewards", fn = function() AR.Reward.tick() end },
	{ tag = "lootbox", interval = "hbIntervalLootbox", fn = function() AR.Lootbox.tick() end },
	{ tag = "cons", interval = "hbIntervalConsumables", fn = function() AR.Cons.tick() end },
	{ tag = "miscGiftBags", interval = "autoOpenMiscGiftBagsInterval", fn = function()
		pcall(ARQ.tryAutoOpenMiscGiftBags)
	end },
}

function AutoRankRuntimeState.autoRankHeartbeatWork()
	AR.HB.dispatch()
	return AR.HB.state.trackedQuest, AR.HB.state.isHatching
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
	if cfg().verboseLog and now - Ticks.lastVerbosePulseTick >= (cfg().traceInterval or 4) then
		Ticks.lastVerbosePulseTick = now
		AutoRankRuntimeState.refreshTeleportDiagSnapshot(trackedQuest, isHatching)
		AutoRankRuntimeState.emitVerbosePulse(trackedQuest, isHatching)
	end
end)

end
