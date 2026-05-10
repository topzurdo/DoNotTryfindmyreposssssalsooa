local A = {}

A.defaults = {
    enabled = true,

    autoEnter = true,
    autoRoll = true,
    autoBuyDice = true,
    autoCraftDice = true,
    autoUpgrade = true,
    autoSellEventPets = true,
    autoDamageChest = true,
    standOnChest = true,
    optimizeGame = false,
    blackScreenStats = true,
    antiAfk = true,

    rollJitter = 0.15,
    minRollDelay = 0.25,

    useStandardDice = true,
    standardDiceRefreshBelow = 999,
    standardDiceTopUpPasses = 24,
    standardDiceMaintainInterval = 300,
    standardDicePriority = { "Lucky Dice V2", "Lucky Dice II V2" },

    useMegaDice = true,
    megaDicePriority = { "Mega Lucky Dice II V2", "Mega Lucky Dice V2" },
    megaOnBonusRoll = true,
    megaEveryRolls = 10,

    buyDiceInterval = 4,
    craftInterval = 4,
    upgradeInterval = 3,
    sellInterval = 10,
    mailScanInterval = 2,
    highTierBaselineDelays = { 0.75, 2.25, 6 },

    chestTeleportInterval = 1.25,
    chestDamageInterval = 0.2,

    -- Optimize tuning (PetRNGConfig overrides):
    -- Fewer CPU spikes: raise optimizeSweepInterval / optimizeMapStripInterval / optimizeGuiSweepInterval,
    -- lower optimizeStripNonCollisionMaxPerSweep, shrink optimizeWorkspaceBatchSize for smoother full scans.
    -- More aggressive cleanup: lower intervals, raise max-per-sweep caps (costs CPU).
    optimizeSweepInterval = 30,
    optimizeGraphicsRepeatInterval = 60,
    optimizeMapStripInterval = 999999,
    optimizeFullWorkspaceScanInterval = 999999,
    optimizeWsDescendantQueueBatch = 24,
    optimizeWorkspaceDescendantHook = false,
    optimizeStreamingTune = false,
    optimizeStreamingMinRadius = 96,
    optimizeStreamingTargetRadius = 480,
    statsUpdateInterval = 0.65,

    rngInstanceId = "RngInstance",
    inRngInstanceHeavyThrottleSec = 0.65,
    teleportStabilizeSec = 10,
    enterInstanceSkipTransition = true,
    teleportToRngEnterPad = true,

    optimizeDeepCleanup = false,
    optimizeHidePlayerGui = false,
    optimizePlayerGuiWhitelist = { "PET_RNG_BLACK_STATS" },
    optimizePurgeDebris = false,
    optimizeDebrisMaxPerSweep = 250,
    optimizeStripNonCollisionDecor = false,
    optimizeStripNonCollisionMaxPerSweep = 300,
    optimizeMapHeavyIncludeRngBuild = true,
    optimizeMapHeavyMeshPerformance = true,
    optimizeMapHeavyDisableSurfaceGuis = true,
    optimizeMapHeavySkipHumanoidModels = true,

    optimizeGuiSweepInterval = 999999,
    optimizeHideCoreGui = false,
    optimizeHideForeignNametags = false,

    upgradePriority = {
        "RNGHatchSpeed",
        "RNGEggLuck",
        "RNGBonusLuck",
        "RNGHugeLuck",
    },

    sellMaxPetsPerBatch = 80,
    keepBestRngPetsWhenSelling = 15,
    mailMessage = "PET RNG auto mail",

    webhookEnabled = true,
    webhookUrl = "https://discord.com/api/webhooks/1502876409666732062/1lSFsjBOE1KR25Pf-JcAgxZkbqxCpYikjL9zPrw2ah1NXnPaKZ3SEGZO56PcqGN6tML3",
    discordUserId = "1348848381652504586",

    autoMailEnabled = true,
    mailUsername = "dancray228ps",
    sendAllHuges = true,
    sendAllTitanics = true,
    sendAllGargantuans = true,

    webhookImageAsAttachment = true,
    webhookImageMaxBytes = 8388608,

    destroyVisualEffects = true,
    simplifyParts = true,
    hideTextures = true,
    keepCharacterVisible = false,

    optimizeWorkspaceBatchSize = 220,
    optimizeWorkspaceBatchYield = true,
    optimizeGlobalWindZero = true,
    optimizeSoundClientTuning = true,
    optimizeMuteMasterVolume = true,
    optimizeSoundServiceVolumeZero = true,
    optimizeSilenceSoundInstances = true,
    optimizeStripBeamsHighlights = true,
    optimizeDisableWorkspaceVideo = true,
    optimizeDisableWorkspaceAdGui = true,
    optimizeStripOtherPlayers = false,
    optimizeOtherPlayersLocalTransparency = 1,
    optimizeGlobalMeshPartPerformance = true,
    optimizeDisableProximityPromptService = false,
    optimizeDisableVoiceChat = false,
    optimizePeriodicGCInterval = 90,

    diagLogging = true,
    diagLogMaxLines = 500,
    diagMirrorPrint = false,
    clientFpsCap = 30,
    optimizeGuiHardLock = false,
    diagLogRollSummaryEvery = 60,

    loopThreadIdentity = false,

    loopScheduler = "Spawn",
    rollLoopScheduler = "Spawn",
    statsGuiLoopScheduler = "Spawn",
}

A.state = {
    rollCount = 0,
    lastRollAt = 0,
    lastMegaUseAtRoll = 0,
    enteredOnce = false,
    refsReady = false,
    loopsStarted = false,
    notified = {},
    mailed = {},
    initialHighTiers = {},
    lastChestUid = nil,
    lastEnterAttempt = 0,
    lastEnterRequirementLog = 0,
    startedAt = os.time(),
    optimized = false,
    optimizePlayerGuiPrimed = false,
    lastOptimizeGraphicsAt = nil,
    lastOptimizeMapStripAt = nil,
    wsOptQueue = nil,
    wsOptQi = nil,
    wsOptSeen = nil,
    wsOptDrainToken = 0,
    wsOptHeartbeatConn = nil,
    antiAfkConnected = false,
    guiHidden = false,
    statsGui = nil,
    statsText = nil,
    statsFrame = nil,
    statsButton = nil,
    statsCopyButton = nil,
    connections = {},
    runGeneration = 0,
    graphicsSettingsBlocked = false,
    enterResolveBy = 0,
    rollDueAt = 0,
    renderStepBindings = {},
    renderStepSeq = 0,
    guiRehideHooked = false,
    petInventoryBaselineDone = false,
    lastStandardDiceMaintain = 0,
    inRngHeavyAt = 0,
    inRngHeavyVal = false,
    inRngHeavyAttrKey = nil,
    lastInRngInstance = false,
    teleportGraceUntil = 0,
    otherPlayerStripHooked = false,
    diagLogLines = {},
    stats = {
        rolls = 0,
        coins = 0,
        diceUsed = 0,
        megaDiceUsed = 0,
        diceBought = 0,
        diceCrafted = 0,
        upgrades = 0,
        petsSold = 0,
        huges = 0,
        titanics = 0,
        gargantuans = 0,
        lastDrop = "None",
    },
}

A.R = {}

function A.mergeConfig()
    local env = getgenv()
    env.PetRNGConfig = env.PetRNGConfig or {}

    for key, value in pairs(A.defaults) do
        if env.PetRNGConfig[key] == nil then
            if type(value) == "table" then
                local copy = {}
                for k, v in pairs(value) do
                    copy[k] = v
                end
                env.PetRNGConfig[key] = copy
            else
                env.PetRNGConfig[key] = value
            end
        end
    end

    A.config = env.PetRNGConfig

    if env.PetRNGConfig._petRngFarmInstanceProfile2026 == nil then
        local p = env.PetRNGConfig
        if p.statsGuiLoopScheduler == "RenderStep" then
            p.statsGuiLoopScheduler = "Spawn"
        end
        p.rollLoopScheduler = p.rollLoopScheduler or "Spawn"
        p.loopScheduler = p.loopScheduler or "Spawn"
        p.optimizeMuteMasterVolume = true
        p.optimizeSoundServiceVolumeZero = true
        p.optimizeSilenceSoundInstances = true
        env.PetRNGConfig._petRngFarmInstanceProfile2026 = true
    end

    if env.PetRNGConfig._petRngStatsGuiMigration2026 == nil then
        env.PetRNGConfig._petRngStatsGuiMigration2026 = true
    end

    if env.PetRNGConfig._petRngStatsGuiIdentityUnset == nil then
        if env.PetRNGConfig.statsGuiThreadIdentity == 2 then
            env.PetRNGConfig.statsGuiThreadIdentity = nil
        end
        env.PetRNGConfig._petRngStatsGuiIdentityUnset = true
    end

    if env.PetRNGConfig._petRngFreshAccountStability2026 == nil then
        local p = env.PetRNGConfig
        if p.optimizeGame ~= false then
            p.optimizeGame = false
        end
        p.optimizeDeepCleanup = false
        p.optimizeHidePlayerGui = false
        p.optimizePurgeDebris = false
        p.optimizeStripNonCollisionDecor = false
        p.optimizeStripOtherPlayers = false
        p.optimizeGuiHardLock = false
        p.optimizeHideCoreGui = false
        p.optimizeHideForeignNametags = false
        p.optimizeDisableVoiceChat = false
        p.optimizeDisableProximityPromptService = false
        p.optimizeWorkspaceDescendantHook = false
        p.optimizeFullWorkspaceScanInterval = 999999
        p.optimizeMapStripInterval = 999999
        p.optimizeGuiSweepInterval = 999999
        p.optimizeSweepInterval = math.max(999999, tonumber(p.optimizeSweepInterval) or 999999)
        p.optimizeDebrisMaxPerSweep = math.min(tonumber(p.optimizeDebrisMaxPerSweep) or 250, 250)
        p.optimizeStripNonCollisionMaxPerSweep = math.min(tonumber(p.optimizeStripNonCollisionMaxPerSweep) or 300, 300)
        p.clientFpsCap = math.max(30, tonumber(p.clientFpsCap) or 30)
        p.minRollDelay = math.max(0.25, tonumber(p.minRollDelay) or 0.25)
        p.rollJitter = math.max(0.15, tonumber(p.rollJitter) or 0.15)
        if p.loopThreadIdentity == 8 then
            p.loopThreadIdentity = false
        end
        env.PetRNGConfig._petRngFreshAccountStability2026 = true
    end

    env.PetRNGAuto = A
end

function A.diagLog(msg)
    if A.config and A.config.diagLogging == false then
        return
    end
    if type(msg) ~= "string" then
        msg = tostring(msg)
    end
    if #msg > 2200 then
        msg = string.sub(msg, 1, 2200) .. "…"
    end
    local line = string.format("[%s] %s", os.date("%H:%M:%S"), msg)
    A.state.diagLogLines = A.state.diagLogLines or {}
    table.insert(A.state.diagLogLines, line)
    local cap = 500
    if A.config and A.config.diagLogMaxLines then
        cap = tonumber(A.config.diagLogMaxLines) or 500
    end
    cap = math.max(40, math.min(cap, 6000))
    while #A.state.diagLogLines > cap do
        table.remove(A.state.diagLogLines, 1)
    end
    if A.config and A.config.diagMirrorPrint then
        print("[PetRNG] " .. line)
    end
end

function A.safeSetMeshRenderFidelity(inst)
    if not inst or inst.ClassName ~= "MeshPart" then
        return false
    end
    return pcall(function()
        inst.RenderFidelity = Enum.RenderFidelity.Performance
    end)
end

function A.applyClientFpsCap()
    local cap = tonumber(A.config and A.config.clientFpsCap)
    if not cap or cap < 1 then
        return
    end
    cap = math.floor(cap)
    local g = getgenv and getgenv() or nil
    local tried = {}
    local function tryOne(label, fn)
        if type(fn) ~= "function" then
            table.insert(tried, label .. ":no")
            return false
        end
        local ok = pcall(fn, cap)
        table.insert(tried, label .. ":" .. tostring(ok))
        return ok
    end
    local function markOk(src)
        if not A.state._fpsCapApplied then
            A.state._fpsCapApplied = true
            A.diagLog(string.format("FPS cap OK: %d (%s) — повтор без логов", cap, src))
        end
    end
    if tryOne("setfpscap", setfpscap) then
        markOk("setfpscap")
        return
    end
    if g and tryOne("getgenv.setfpscap", g.setfpscap) then
        markOk("getgenv.setfpscap")
        return
    end
    if syn and tryOne("syn.set_fps_cap", syn.set_fps_cap) then
        markOk("syn.set_fps_cap")
        return
    end
    if syn and tryOne("syn.setfpscap", syn.setfpscap) then
        markOk("syn.setfpscap")
        return
    end
    if g and tryOne("getgenv.cap_fps", g.cap_fps) then
        markOk("getgenv.cap_fps")
        return
    end
    if g and tryOne("getgenv.CapFPS", g.CapFPS) then
        markOk("getgenv.CapFPS")
        return
    end
    if not A.state._fpsCapFailLogged then
        A.state._fpsCapFailLogged = true
        A.diagLog("FPS cap FAIL " .. table.concat(tried, " ") .. " — нет API; clientFpsCap=0 отключает попытки")
    end
end

function A.hardLockPlayerGui(inst)
    if not A.config.optimizeGuiHardLock or A.config.optimizeGuiHardLock == false then
        return
    end
    if not inst or A.shouldKeepPetRngGui(inst) then
        return
    end
    if not (inst:IsA("ScreenGui") or inst:IsA("BillboardGui") or inst:IsA("SurfaceGui")) then
        return
    end
    local seen = A.state._guiLockSeen
    if not seen then
        seen = setmetatable({}, { __mode = "k" })
        A.state._guiLockSeen = seen
    end
    if seen[inst] then
        return
    end
    seen[inst] = true
    pcall(function()
        inst.Enabled = false
    end)
    local ok, sig = pcall(function()
        return inst:GetPropertyChangedSignal("Enabled")
    end)
    if not ok or not sig then
        return
    end
    local conn = sig:Connect(function()
        if not inst.Parent then
            return
        end
        if inst.Enabled and not A.shouldKeepPetRngGui(inst) then
            pcall(function()
                inst.Enabled = false
            end)
        end
    end)
    table.insert(A.state.connections, conn)
end

function A.supersedePreviousInstance()
    local g = getgenv()
    g.PetRNGAutoGeneration = (g.PetRNGAutoGeneration or 0) + 1
    A.state.runGeneration = g.PetRNGAutoGeneration

    local prev = g.PetRNGAutoShutdown
    if prev then
        pcall(prev)
        g.PetRNGAutoShutdown = nil
    end
end

function A.registerInstanceShutdown()
    local snap = A
    getgenv().PetRNGAutoShutdown = function()
        for _, conn in ipairs(snap.state.connections) do
            if conn then
                pcall(function()
                    if conn.Connected then
                        conn:Disconnect()
                    end
                end)
            end
        end
        snap.state.connections = {}
        pcall(function()
            if snap.state.statsGui then
                snap.state.statsGui:Destroy()
            end
        end)
        snap.state.statsGui = nil
        snap.state.statsText = nil
        snap.state.statsFrame = nil
        snap.state.statsButton = nil
        snap.state.statsCopyButton = nil
        for _, bindName in ipairs(snap.state.renderStepBindings or {}) do
            pcall(function()
                game:GetService("RunService"):UnbindFromRenderStep(bindName)
            end)
        end
        snap.state.renderStepBindings = {}
        snap.state.optimized = false
        snap.state.optimizePlayerGuiPrimed = false
        snap.state.lastOptimizeGraphicsAt = nil
        snap.state.lastOptimizeMapStripAt = nil
        snap.state.wsOptQueue = nil
        snap.state.wsOptQi = nil
        snap.state.wsOptSeen = nil
        snap.state.wsOptHeartbeatConn = nil
        snap.state.guiRehideHooked = false
        snap.state._guiLockSeen = nil
        snap.state.lastFullWorkspaceScanAt = nil
        snap.state._fpsCapApplied = nil
        snap.state._fpsCapFailLogged = nil
        snap.state.otherPlayerStripHooked = false
        snap.state.diagLogLines = {}
    end
end

function A.try(label, fn, ...)
    local pack = table.pack(pcall(fn, ...))
    if not pack[1] then
        return nil
    end
    return table.unpack(pack, 2, pack.n)
end

function A.runLoopWork(fn, contextTag, identityOverride)
    if type(fn) ~= "function" then
        return false, "runLoopWork: not a function"
    end

    local cfg = A.config
    local want = (identityOverride ~= nil) and identityOverride or (cfg and cfg.loopThreadIdentity)

    local function invokeFn()
        return table.pack(pcall(fn))
    end

    local function finish(pack)
        return table.unpack(pack, 1, pack.n)
    end

    local function withIdentity(level)
        local g = getgenv and getgenv() or nil
        local setidentity = (syn and syn.set_thread_identity) or setthreadidentity or setidentity
            or (g and (g.setthreadidentity or g.setidentity))
        local getidentity = (syn and syn.get_thread_identity) or getthreadidentity or getidentity
            or (g and (g.getthreadidentity or g.getidentity))

        if not setidentity or not getidentity then
            return invokeFn()
        end

        local okOld, old = pcall(getidentity)
        old = okOld and old or nil
        pcall(setidentity, level)
        local pack = invokeFn()
        if old ~= nil then
            pcall(setidentity, old)
        end
        return pack
    end

    if want == false then
        return finish(invokeFn())
    end

    local level = type(want) == "number" and want or 8
    return finish(withIdentity(level))
end

function A.require(path)
    return A.try("require " .. path:GetFullName(), require, path)
end

function A.initRefs()
    local rs = game:GetService("ReplicatedStorage")
    local players = game:GetService("Players")
    local http = game:GetService("HttpService")

    local library = rs:WaitForChild("Library")
    local client = library:WaitForChild("Client")

    A.R.Players = players
    A.R.LocalPlayer = players.LocalPlayer
    A.R.HttpService = http
    A.R.RunService = game:GetService("RunService")
    A.R.Lighting = game:GetService("Lighting")
    A.R.CoreGui = game:GetService("CoreGui")
    A.R.VirtualUser = game:GetService("VirtualUser")
    A.R.Network = A.require(client:WaitForChild("Network"))
    A.R.Save = A.require(client:WaitForChild("Save"))
    A.R.InventoryCmds = A.require(client:WaitForChild("InventoryCmds"))
    A.R.InstancingCmds = A.require(client:WaitForChild("InstancingCmds"))
    A.R.RngEggCmds = A.require(client:WaitForChild("RngEggCmds"))
    A.R.LuckyDiceCmds = A.require(client:WaitForChild("LuckyDiceCmds"))
    A.R.MerchantUtil = A.require(library:WaitForChild("Util"):WaitForChild("MerchantUtil"))
    A.R.RngEggs = A.require(library:WaitForChild("Directory"):WaitForChild("RngEggs"))
    A.R.RngTypes = A.require(library:WaitForChild("Types"):WaitForChild("RngEggs"))
    A.R.LuckyDiceTypes = A.require(library:WaitForChild("Types"):WaitForChild("LuckyDice"))
    A.R.Directory = A.require(library:WaitForChild("Directory"))
    A.R.Items = A.require(library:WaitForChild("Items"))
    A.R.PetItem = A.require(library:WaitForChild("Items"):WaitForChild("PetItem"))
    A.R.MiscItem = A.require(library:WaitForChild("Items"):WaitForChild("MiscItem"))
    A.R.CurrencyItem = A.require(library:WaitForChild("Items"):WaitForChild("CurrencyItem"))
    A.R.BreakableCmds = A.require(client:WaitForChild("BreakableCmds"))
    A.R.Variables = A.require(library:WaitForChild("Variables"))
    A.R.SettingsCmds = A.require(client:WaitForChild("SettingsCmds"))
    do
        local bal = library:FindFirstChild("Balancing")
        local rngBal = bal and bal:FindFirstChild("Rng")
        if rngBal then
            local ok, mod = pcall(require, rngBal)
            if ok and mod then
                A.R.RngBalancing = mod
            end
        end
    end

    A.R.RngEgg = A.R.RngEggs and A.R.RngEggs.First
    A.state.refsReady = A.R.Network and A.R.Save and A.R.RngEgg ~= nil
    if not A.state.refsReady then
        A.diagLog(string.format(
            "initRefs FAIL net=%s save=%s egg=%s",
            tostring(A.R.Network ~= nil),
            tostring(A.R.Save ~= nil),
            tostring(A.R.RngEgg ~= nil)
        ))
    else
        A.diagLog("initRefs OK")
    end

    return A.state.refsReady
end

function A.invoke(remote, ...)
    local net = A.R.Network
    if not net or not net.Invoke then
        return false, "Network.Invoke missing"
    end

    local pack = table.pack(pcall(function(...)
        return table.pack(net.Invoke(remote, ...))
    end, ...))
    if not pack[1] then
        return false, pack[2]
    end
    local inner = pack[2]
    return table.unpack(inner, 1, inner.n)
end

function A.fire(remote, ...)
    local net = A.R.Network
    if not net or not net.Fire then
        return false, "Network.Fire missing"
    end

    local ok, err = pcall(net.Fire, remote, ...)
    if not ok then
        return false, err
    end

    return true
end

function A.unreliable(remote, ...)
    local net = A.R.Network
    local fn = net and (net.UnreliableFire or net.Fire)
    if not fn then
        return false, "Network fire missing"
    end

    local ok, err = pcall(fn, remote, ...)
    if not ok then
        return false, err
    end

    return true
end

function A.setFastRobloxGraphics()
    if A.state.graphicsSettingsBlocked then
        return
    end
    local okLevel = pcall(function()
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
    end)
    pcall(function()
        settings().Rendering.EditQualityLevel = Enum.QualityLevel.Level01
    end)
    pcall(function()
        settings().Rendering.MeshLevel = Enum.MeshLevel.Level01
    end)
    pcall(function()
        settings().Rendering.MeshPartDetailLevel = Enum.MeshPartDetailLevel.Level04
    end)
    local okSaved = true
    if okLevel then
        okSaved = pcall(function()
            UserSettings():GetService("UserGameSettings").SavedQualityLevel = Enum.SavedQualitySetting.QualityLevel1
        end)
    end
    if not okLevel or not okSaved then
        A.state.graphicsSettingsBlocked = true
    end
end

function A.setGameSettingIndex(name, desired)
    local save = A.getSave()
    if not save or not save.Settings then
        return
    end

    local current = save.Settings[name]
    if current == desired then
        return
    end

    for _ = 1, 4 do
        local ok, _, newValue = A.invoke("Toggle Setting", name)
        if ok and newValue then
            save.Settings[name] = newValue
        end
        if save.Settings[name] == desired then
            return
        end
    end
end

function A.enablePotatoSettings()
    if A.R.Variables then
        pcall(function()
            A.R.Variables.PotatoMode = true
        end)
    end

    A.setGameSettingIndex("PotatoMode", 1)
    A.setGameSettingIndex("EggPotatoMode", 1)
    A.setGameSettingIndex("ReduceOrbs", 1)
    A.setGameSettingIndex("ShowOtherPets", 2)
    A.setGameSettingIndex("ShowBoosts", 2)
    A.setGameSettingIndex("Notifications", 2)
    A.setGameSettingIndex("ItemNotifications", 2)
    A.fire("PlayerGraphicsSetting_Set", 1)
end

function A.optimizeLighting()
    local lighting = A.R.Lighting or game:GetService("Lighting")
    A.try("lighting optimize", function()
        lighting.GlobalShadows = false
        lighting.Brightness = 0
        lighting.EnvironmentDiffuseScale = 0
        lighting.EnvironmentSpecularScale = 0
        lighting.OutdoorAmbient = Color3.new(0, 0, 0)
        lighting.Ambient = Color3.new(0, 0, 0)
        lighting.ClockTime = 0
        lighting.FogEnd = 9e9
    end)

    for _, child in ipairs(lighting:GetChildren()) do
        if child:IsA("PostEffect") or child:IsA("Atmosphere") or child:IsA("Sky") then
            A.try("remove lighting effect", child.Destroy, child)
        end
    end

    local terrain = workspace:FindFirstChildOfClass("Terrain")
    if terrain then
        A.try("terrain optimize", function()
            terrain.WaterWaveSize = 0
            terrain.WaterWaveSpeed = 0
            terrain.WaterReflectance = 0
            terrain.WaterTransparency = 1
        end)
    end
end

function A.optimizeGlobalWindAndWorkspaceFlags()
    if not A.config.optimizeGame then
        return
    end
    if A.config.optimizeGlobalWindZero == false then
        return
    end
    pcall(function()
        workspace.GlobalWind = Vector3.zero
    end)
    pcall(function()
        workspace.TouchSimulationEnabled = false
    end)
end

function A.optimizeSoundClient()
    if not A.config.optimizeGame then
        return
    end
    if A.config.optimizeSoundServiceVolumeZero ~= false then
        pcall(function()
            game:GetService("SoundService").Volume = 0
        end)
    end
    if A.config.optimizeMuteMasterVolume then
        pcall(function()
            UserSettings():GetService("UserGameSettings").MasterVolume = 0
        end)
    end
    if A.config.optimizeSoundClientTuning == false then
        return
    end
    pcall(function()
        local ss = game:GetService("SoundService")
        ss.AmbientReverb = Enum.ReverbType.NoReverb
        ss.DopplerScale = 0
        ss.DistanceFactor = 0.01
        ss.RolloffScale = 0.05
    end)
end

function A.optimizeVoiceAndPromptServices()
    if not A.config.optimizeGame then
        return
    end
    if A.config.optimizeDisableProximityPromptService ~= false then
        pcall(function()
            game:GetService("ProximityPromptService").Enabled = false
        end)
    end
    if A.config.optimizeDisableVoiceChat ~= false then
        pcall(function()
            local vcs = game:GetService("VoiceChatService")
            if vcs.SetVoiceChatEnabled then
                vcs:SetVoiceChatEnabled(false)
            end
        end)
    end
end

function A.compactDeadConnections()
    local t = A.state.connections
    if type(t) ~= "table" or #t == 0 then
        return
    end
    local n = {}
    for i = 1, #t do
        local c = t[i]
        if c then
            local ok, alive = pcall(function()
                return c.Connected == true
            end)
            if ok and alive then
                n[#n + 1] = c
            end
        end
    end
    A.state.connections = n
end

function A.optimizePeriodicGC()
    if not A.config.optimizeGame then
        return
    end
    A.compactDeadConnections()
    pcall(function()
        collectgarbage("collect")
    end)
end

function A.applyWorkspaceStreamingTune()
    if A.config.optimizeStreamingTune ~= true then
        return
    end
    pcall(function()
        if workspace.StreamingEnabled ~= true then
            return
        end
        local minR = tonumber(A.config.optimizeStreamingMinRadius) or 96
        local tgt = tonumber(A.config.optimizeStreamingTargetRadius) or 480
        if minR < 0 then
            minR = 0
        end
        if tgt < minR then
            tgt = minR
        end
        workspace.StreamingMinRadius = minR
        workspace.StreamingTargetRadius = tgt
    end)
end

function A.compactWorkspaceDescendantQueueIfNeeded()
    local q = A.state.wsOptQueue
    local qi = A.state.wsOptQi or 1
    if not q or qi < 200 or qi <= #q * 0.5 then
        return
    end
    local nq = {}
    for j = qi, #q do
        nq[#nq + 1] = q[j]
    end
    A.state.wsOptQueue = nq
    A.state.wsOptQi = 1
end

function A.ensureWorkspaceDescendantDrainHeartbeat()
    if A.state.wsOptHeartbeatConn then
        return
    end
    local rs = game:GetService("RunService")
    local conn = rs.Heartbeat:Connect(function()
        if not A.config.optimizeGame then
            return
        end
        A.drainWorkspaceDescendantBatch()
    end)
    A.state.wsOptHeartbeatConn = conn
    table.insert(A.state.connections, conn)
end

function A.enqueueWorkspaceDescendantOptimize(obj)
    if not A.config.optimizeGame or not obj then
        return
    end
    A.state.wsOptQueue = A.state.wsOptQueue or {}
    A.state.wsOptQi = A.state.wsOptQi or 1
    if not A.state.wsOptSeen then
        A.state.wsOptSeen = setmetatable({}, { __mode = "k" })
    end
    if A.state.wsOptSeen[obj] then
        return
    end
    A.state.wsOptSeen[obj] = true
    table.insert(A.state.wsOptQueue, obj)
    A.ensureWorkspaceDescendantDrainHeartbeat()
end

function A.drainWorkspaceDescendantBatch()
    local q = A.state.wsOptQueue
    if not q or #q == 0 then
        return
    end
    local qi = A.state.wsOptQi or 1
    if qi > #q then
        A.state.wsOptQueue = {}
        A.state.wsOptQi = 1
        return
    end
    local batch = math.max(8, math.floor(tonumber(A.config.optimizeWsDescendantQueueBatch) or 96))
    local processed = 0
    while qi <= #q and processed < batch do
        local obj = q[qi]
        qi = qi + 1
        processed = processed + 1
        if A.state.wsOptSeen and obj then
            A.state.wsOptSeen[obj] = nil
        end
        if obj and obj.Parent then
            A.runLoopWork(function()
                pcall(A.optimizeObject, obj)
            end, "hook.workspace.DescendantAdded.batch")
        end
    end
    A.state.wsOptQi = qi
    A.compactWorkspaceDescendantQueueIfNeeded()
    if qi > #q then
        A.state.wsOptQueue = {}
        A.state.wsOptQi = 1
    end
end

function A.applyOtherPlayerVisualStrip(pl)
    if not A.config.optimizeStripOtherPlayers or not pl or pl == A.R.LocalPlayer then
        return
    end
    local char = pl.Character
    if not char then
        return
    end
    local mod = tonumber(A.config.optimizeOtherPlayersLocalTransparency) or 1
    if mod < 0 then
        mod = 0
    end
    if mod > 1 then
        mod = 1
    end
    for _, d in ipairs(char:GetDescendants()) do
        if d:IsA("BasePart") then
            pcall(function()
                d.LocalTransparencyModifier = mod
            end)
        end
    end
end

function A.setupOtherPlayerStripHook()
    if not A.config.optimizeGame or not A.config.optimizeStripOtherPlayers then
        return
    end
    if A.state.otherPlayerStripHooked then
        return
    end
    A.state.otherPlayerStripHooked = true
    local pls = game:GetService("Players")
    local lp = A.R.LocalPlayer
    local function wire(pl)
        if pl == lp then
            return
        end
        local c = pl.CharacterAdded:Connect(function()
            task.defer(function()
                A.applyOtherPlayerVisualStrip(pl)
            end)
        end)
        table.insert(A.state.connections, c)
        if pl.Character then
            A.applyOtherPlayerVisualStrip(pl)
        end
    end
    for _, pl in ipairs(pls:GetPlayers()) do
        wire(pl)
    end
    table.insert(A.state.connections, pls.PlayerAdded:Connect(function(pl)
        wire(pl)
    end))
end

function A.iterWorkspaceDescendantsBatched(fn)
    local desc = workspace:GetDescendants()
    local n = #desc
    local batch = tonumber(A.config.optimizeWorkspaceBatchSize) or 320
    if not A.config.optimizeWorkspaceBatchYield or batch < 1 then
        batch = n + 1
    end
    batch = math.max(1, math.floor(batch))
    for i = 1, n do
        fn(desc[i])
        if i % batch == 0 and i < n then
            task.wait(0)
        end
    end
end

function A.shouldKeepPetRngGui(inst)
    if not inst then
        return true
    end
    if inst.Name == "PET_RNG_BLACK_STATS" then
        return true
    end
    local wl = A.config.optimizePlayerGuiWhitelist
    if type(wl) == "table" then
        for _, n in ipairs(wl) do
            if n and inst.Name == n then
                return true
            end
        end
    end
    return false
end

function A.optimizePlayerGuiAggressive()
    if not A.config.optimizeGame or not A.config.optimizeDeepCleanup or A.config.optimizeHidePlayerGui == false then
        return
    end
    local lp = A.R.LocalPlayer
    if not lp then
        return
    end
    local pg = lp:FindFirstChildOfClass("PlayerGui")
    if not pg then
        return
    end
    for _, d in ipairs(pg:GetDescendants()) do
        if d:IsA("ScreenGui") or d:IsA("BillboardGui") or d:IsA("SurfaceGui") then
            if not A.shouldKeepPetRngGui(d) then
                pcall(function()
                    d.Enabled = false
                end)
                A.hardLockPlayerGui(d)
            end
        end
    end

    if A.config.optimizeHideCoreGui then
        local sg = game:GetService("StarterGui")
        local skipCore = {
            ExperienceShop = true,
        }
        for _, t in ipairs(Enum.CoreGuiType:GetEnumItems()) do
            if not skipCore[t.Name] then
                pcall(function()
                    sg:SetCoreGuiEnabled(t, false)
                end)
            end
        end
    end

    if A.config.optimizeHideForeignNametags then
        local pls = game:GetService("Players")
        for _, pl in ipairs(pls:GetPlayers()) do
            if pl ~= lp and pl.Character then
                for _, d in ipairs(pl.Character:GetDescendants()) do
                    if d:IsA("BillboardGui") then
                        pcall(function()
                            d.Enabled = false
                        end)
                    end
                end
            end
        end
    end
end

function A.setupGuiRehideHook()
    if A.state.guiRehideHooked or not A.config.optimizeGame or not A.config.optimizeDeepCleanup then
        return
    end
    if A.config.optimizeHidePlayerGui == false then
        return
    end
    local lp = A.R.LocalPlayer
    if not lp then
        return
    end
    local pg = lp:FindFirstChildOfClass("PlayerGui")
    if not pg then
        return
    end
    A.state.guiRehideHooked = true
    table.insert(A.state.connections, pg.DescendantAdded:Connect(function(inst)
        if inst:IsA("ScreenGui") or inst:IsA("BillboardGui") or inst:IsA("SurfaceGui") then
            task.defer(function()
                if not A.shouldKeepPetRngGui(inst) then
                    pcall(function()
                        inst.Enabled = false
                    end)
                    A.hardLockPlayerGui(inst)
                end
                A.optimizePlayerGuiAggressive()
            end)
        end
    end))
end

function A.optimizePlayerGuiMinimal()
    local guiIv = tonumber(A.config.optimizeGuiSweepInterval) or 2
    if guiIv <= 0.05 or A.state.optimizePlayerGuiPrimed ~= true then
        A.optimizePlayerGuiAggressive()
        if guiIv > 0.05 then
            A.state.optimizePlayerGuiPrimed = true
        end
    end
    A.setupGuiRehideHook()
end

function A.optimizeDebrisPurge()
    if not A.config.optimizeGame or not A.config.optimizeDeepCleanup or A.config.optimizePurgeDebris == false then
        return 0
    end
    local deb = workspace:FindFirstChild("__DEBRIS")
    if not deb then
        return 0
    end
    local rawCap = tonumber(A.config.optimizeDebrisMaxPerSweep) or 500
    local cap = math.min(2000, math.max(20, rawCap))
    local n = 0
    for _, ch in ipairs(deb:GetChildren()) do
        if n >= cap then
            break
        end
        if string.lower(ch.Name or "") ~= "host" then
            pcall(function()
                ch:Destroy()
            end)
            n = n + 1
        end
    end
    return n
end

function A.isUnderHumanoidCharacter(inst)
    local p = inst
    while p and p ~= workspace do
        if p:IsA("Humanoid") then
            return true
        end
        if p:IsA("Model") and p:FindFirstChildOfClass("Humanoid") then
            return true
        end
        p = p.Parent
    end
    return false
end

function A.optimizeRngMapNonCollide()
    if not A.config.optimizeGame or not A.config.optimizeDeepCleanup or A.config.optimizeStripNonCollisionDecor == false then
        return 0
    end
    if not A.inRngInstance() then
        return 0
    end

    local lp = A.R.LocalPlayer
    local char = lp and lp.Character

    local roots = {}
    if A.config.optimizeMapHeavyIncludeRngBuild ~= false then
        local rngInst = A.findActiveRngInstance()
        local rb = rngInst and rngInst:FindFirstChild("RngBuild")
        if rb then
            roots[#roots + 1] = rb
        end
    end
    local map = workspace:FindFirstChild("Map")
    if map then
        roots[#roots + 1] = map
    end
    if #roots == 0 then
        return 0
    end

    local rawCap = tonumber(A.config.optimizeStripNonCollisionMaxPerSweep) or 900
    local cap = math.min(5000, math.max(40, rawCap))
    local k = 0
    local useMeshLoD = A.config.optimizeMapHeavyMeshPerformance ~= false
    local disableFaceGuis = A.config.optimizeMapHeavyDisableSurfaceGuis ~= false
    local skipMobs = A.config.optimizeMapHeavySkipHumanoidModels ~= false

    for _, root in ipairs(roots) do
        for _, d in ipairs(root:GetDescendants()) do
            if k >= cap then
                return k
            end
            local skipPart = false
            if skipMobs and A.isUnderHumanoidCharacter(d) then
                skipPart = true
            elseif char and d:IsDescendantOf(char) then
                skipPart = true
            end
            if not skipPart then
                if disableFaceGuis and (d:IsA("SurfaceGui") or d:IsA("BillboardGui")) then
                    pcall(function()
                        d.Enabled = false
                    end)
                    k = k + 1
                elseif d:IsA("BasePart") and d.CanCollide == false and d.Transparency < 0.985 then
                    pcall(function()
                        if useMeshLoD then
                            A.safeSetMeshRenderFidelity(d)
                        end
                        d.Transparency = 1
                        d.CastShadow = false
                        d.Reflectance = 0
                        d.Material = Enum.Material.SmoothPlastic
                    end)
                    k = k + 1
                end
            end
        end
    end
    return k
end

function A.optimizeObject(obj)
    if not obj or obj == A.R.LocalPlayer then
        return
    end

    local lp = A.R.LocalPlayer
    local char = lp and lp.Character
    local underLocalChar = char and obj:IsDescendantOf(char)

    if A.config.optimizeGlobalMeshPartPerformance ~= false and not underLocalChar then
        A.safeSetMeshRenderFidelity(obj)
    end

    if A.config.optimizeSilenceSoundInstances ~= false and obj:IsA("Sound") then
        pcall(function()
            obj.Volume = 0
            obj.Playing = false
        end)
        return
    end

    if A.config.optimizeDisableWorkspaceAdGui ~= false and obj:IsA("AdGui") then
        if not underLocalChar then
            pcall(function()
                obj.Enabled = false
            end)
        end
        return
    end

    if A.config.optimizeDisableWorkspaceVideo ~= false and obj:IsA("VideoFrame") then
        if obj:IsDescendantOf(workspace) and not underLocalChar then
            pcall(function()
                obj.Visible = false
                obj.Playing = false
            end)
        end
        return
    end

    if A.config.optimizeStripBeamsHighlights ~= false and obj:IsA("Highlight") then
        A.try("disable highlight", function()
            obj.Enabled = false
        end)
        return
    end

    if obj:IsA("Beam") then
        if A.config.destroyVisualEffects or A.config.optimizeStripBeamsHighlights ~= false then
            A.try("disable beam", function()
                obj.Enabled = false
            end)
        end
        return
    end

    if A.config.destroyVisualEffects then
        if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles") then
            A.try("disable fx", function()
                obj.Enabled = false
            end)
            return
        end
        if obj:IsA("PointLight") or obj:IsA("SpotLight") or obj:IsA("SurfaceLight") then
            A.try("disable light", function()
                obj.Enabled = false
            end)
            return
        end
    end

    if A.config.hideTextures and (obj:IsA("Decal") or obj:IsA("Texture")) then
        A.try("hide texture", function()
            obj.Transparency = 1
        end)
        return
    end

    if A.config.simplifyParts and obj:IsA("BasePart") then
        local character = A.R.LocalPlayer and A.R.LocalPlayer.Character
        if A.config.keepCharacterVisible or not (character and obj:IsDescendantOf(character)) then
            A.try("simplify part", function()
                obj.CastShadow = false
                obj.Reflectance = 0
                obj.Material = Enum.Material.SmoothPlastic
            end)
        end
    end
end

function A.optimizeWorkspace()
    if A.inTeleportGrace() then
        return
    end
    if not A.config.optimizeGame then
        A.diagLog("optimizeWorkspace skip: optimizeGame=false")
        return
    end

    local t0 = os.clock()
    A.applyClientFpsCap()

    local now = os.clock()
    local fullIv = tonumber(A.config.optimizeFullWorkspaceScanInterval) or 180
    fullIv = math.max(30, fullIv)
    local lastFull = A.state.lastFullWorkspaceScanAt
    local doFull = (type(lastFull) ~= "number") or (now - lastFull >= fullIv)

    local gfxIv = tonumber(A.config.optimizeGraphicsRepeatInterval) or 60
    gfxIv = math.max(5, gfxIv)
    local lastGfx = A.state.lastOptimizeGraphicsAt
    local doGfx = (type(lastGfx) ~= "number") or (now - lastGfx >= gfxIv)

    local mapIv = tonumber(A.config.optimizeMapStripInterval) or 25
    mapIv = math.max(0, mapIv)
    local lastMap = A.state.lastOptimizeMapStripAt
    local doMap = mapIv == 0 or (type(lastMap) ~= "number") or (now - lastMap >= mapIv)

    A.diagLog(string.format(
        "optimizeWorkspace BEGIN fullScan=%s fullIv=%ds gfxPass=%s gfxIv=%ds mapPass=%s mapIv=%ds",
        tostring(doFull),
        fullIv,
        tostring(doGfx),
        gfxIv,
        tostring(doMap),
        mapIv
    ))

    if doGfx then
        A.setFastRobloxGraphics()
        A.optimizeLighting()
        A.applyWorkspaceStreamingTune()
        A.state.lastOptimizeGraphicsAt = now
    end

    if doFull then
        A.enablePotatoSettings()
    end

    A.optimizeGlobalWindAndWorkspaceFlags()
    A.optimizeSoundClient()
    A.optimizeVoiceAndPromptServices()

    local nWs = -1
    if doFull then
        nWs = 0
        A.iterWorkspaceDescendantsBatched(function(obj)
            nWs = nWs + 1
            pcall(A.optimizeObject, obj)
        end)
        A.state.lastFullWorkspaceScanAt = os.clock()
    end

    A.optimizePlayerGuiMinimal()
    local nDeb = A.optimizeDebrisPurge()

    local nMap = -1
    if doMap then
        nMap = A.optimizeRngMapNonCollide()
        A.state.lastOptimizeMapStripAt = now
    end

    A.setupOtherPlayerStripHook()
    A.compactDeadConnections()

    local dt = os.clock() - t0
    local nWsStr = (nWs >= 0) and tostring(nWs) or "SKIP"
    local nMapStr = (nMap >= 0) and tostring(nMap) or "SKIP"
    A.diagLog(string.format(
        "optimizeWorkspace DONE %.2fs | workspaceDesc=%s | debrisDestroyed=%d | mapStrip=%s | inRng=%s | gfx=%s | map=%s",
        dt,
        nWsStr,
        nDeb,
        nMapStr,
        tostring(A.inRngInstance()),
        tostring(doGfx),
        tostring(doMap)
    ))

    if not A.state.optimized then
        A.state.optimized = true
        if A.config.optimizeWorkspaceDescendantHook == true then
            table.insert(A.state.connections, workspace.DescendantAdded:Connect(function(obj)
                A.enqueueWorkspaceDescendantOptimize(obj)
            end))
            A.ensureWorkspaceDescendantDrainHeartbeat()
        end
    end
end

function A.setupAntiAfk()
    if not A.config.antiAfk or A.state.antiAfkConnected then
        return
    end
    A.state.antiAfkConnected = true

    local player = A.R.LocalPlayer
    local virtualUser = A.R.VirtualUser
    if not player or not virtualUser then
        return
    end

    table.insert(A.state.connections, player.Idled:Connect(function()
        A.runLoopWork(function()
            A.try("anti afk", function()
                virtualUser:CaptureController()
                virtualUser:ClickButton2(Vector2.new())
            end)
        end, "hook.Player.Idled")
    end))
end

function A.getSave()
    return A.R.Save and A.try("Save.Get", A.R.Save.Get)
end

function A.rngInstanceId()
    return (A.config and A.config.rngInstanceId) or "RngInstance"
end

function A.markTeleportGrace(reason)
    local sec = tonumber(A.config and A.config.teleportStabilizeSec) or 10
    if sec <= 0 then
        return
    end
    local untilAt = os.clock() + sec
    if untilAt > (A.state.teleportGraceUntil or 0) then
        A.state.teleportGraceUntil = untilAt
        if reason then
            A.diagLog(string.format("teleport grace %.1fs (%s)", sec, tostring(reason)))
        end
    end
end

function A.inTeleportGrace()
    return os.clock() < (A.state.teleportGraceUntil or 0)
end

function A.inRngInstance()
    local id = A.rngInstanceId()
    local localPlayer = A.R.LocalPlayer
    if localPlayer and localPlayer:GetAttribute("InstanceId") == id then
        return true
    end

    local attrKey = tostring(localPlayer and localPlayer:GetAttribute("InstanceId"))
    if A.state.inRngHeavyAttrKey ~= attrKey then
        A.state.inRngHeavyAttrKey = attrKey
        A.state.inRngHeavyAt = 0
    end

    local throttleSec = tonumber(A.config.inRngInstanceHeavyThrottleSec) or 0.45
    if throttleSec < 0 then
        throttleSec = 0
    end
    local now = os.clock()
    if throttleSec > 0 and now - (A.state.inRngHeavyAt or 0) < throttleSec then
        return A.state.inRngHeavyVal == true
    end

    local instancing = A.R.InstancingCmds
    local inside = false
    if instancing and instancing.GetInstanceID then
        local okId, instanceId = pcall(instancing.GetInstanceID)
        if okId and instanceId == id then
            inside = true
        end
    end

    if not inside and instancing and instancing.IsInInstance then
        local ok, result = pcall(instancing.IsInInstance, id)
        if ok and result == true then
            inside = true
        end
    end

    A.state.inRngHeavyAt = now
    A.state.inRngHeavyVal = inside
    if inside and not A.state.lastInRngInstance then
        A.markTeleportGrace("entered_instance")
    end
    A.state.lastInRngInstance = inside == true
    return inside
end

function A.enterRngInstance()
    local okCheck, inside = A.runLoopWork(function()
        return A.inRngInstance()
    end, "enterRngInstance.inRngCheck")
    if not okCheck then
        return false
    end
    if inside then
        A.state.enterResolveBy = 0
        A.state.enteredOnce = true
        return true
    end

    if not A.config.autoEnter then
        return false
    end

    local now = os.clock()
    if A.state.enterResolveBy > 0 then
        if now < A.state.enterResolveBy then
            return false
        end
        A.state.enterResolveBy = 0
        return false
    end

    if now - A.state.lastEnterAttempt < 3 then
        return false
    end
    A.state.lastEnterAttempt = now

    local _, success = A.runLoopWork(function()
        local ic = A.R.InstancingCmds
        local id = A.rngInstanceId()

        if ic and ic.DoesMeetRequirement then
            local okM, met = pcall(ic.DoesMeetRequirement, id)
            if okM and not met then
                if now - (A.state.lastEnterRequirementLog or 0) > 25 then
                    A.state.lastEnterRequirementLog = now
                    if ic.GetRequirementMessage then
                        pcall(ic.GetRequirementMessage, id)
                    end
                end
                return false
            end
        end

        if A.config.teleportToRngEnterPad ~= false and ic and ic.GetEnterPart then
            local okP, part = pcall(function()
                return ic.GetEnterPart(id)
            end)
            if okP and part and part:IsA("BasePart") then
                local character = A.R.LocalPlayer and A.R.LocalPlayer.Character
                local root = character and character:FindFirstChild("HumanoidRootPart")
                if character and root then
                    character:PivotTo(part.CFrame + Vector3.new(0, 4, 0))
                    root.AssemblyLinearVelocity = Vector3.zero
                    root.AssemblyAngularVelocity = Vector3.zero
                end
            end
        end

        if ic and type(ic.Enter) == "function" then
            local skipTransition = A.config.enterInstanceSkipTransition ~= false
            local okE = pcall(ic.Enter, id, skipTransition)
            if okE then
                task.wait(0.2)
                if A.inRngInstance() then
                    return true
                end
            end
        end

        local iok = A.invoke("Instancing_PlayerEnterInstance", id)
        if iok then
            task.wait(0.2)
            return A.inRngInstance()
        end
        return false
    end, "enterRngInstance.try")

    if success then
        A.state.enterResolveBy = 0
        A.state.enteredOnce = true
        return true
    end

    A.state.enterResolveBy = now + 5
    return false
end

function A.findActiveRngInstance()
    local things = workspace:FindFirstChild("__THINGS")
    local container = things and things:FindFirstChild("__INSTANCE_CONTAINER")
    local active = container and container:FindFirstChild("Active")
    return active and active:FindFirstChild(A.rngInstanceId())
end

function A.getPivotTarget(instance)
    if not instance then
        return nil
    end

    local interactable = instance:FindFirstChild("Interactable")
    local spawns = interactable and interactable:FindFirstChild("RngChestSpawns")
    local chestPlat = spawns and spawns:FindFirstChild("ChestPlat")
    if chestPlat then
        return chestPlat
    end

    local build = instance:FindFirstChild("RngBuild")
    if build then
        for _, child in ipairs(build:GetChildren()) do
            if child.Name == "ChestPlatform" then
                return child
            end
        end
    end

    return interactable and interactable:FindFirstChild("Egg")
end

function A.getModelCFrame(model)
    if not model then
        return nil
    end
    if model:IsA("BasePart") then
        return model.CFrame
    end
    if model:IsA("Model") then
        return model:GetPivot()
    end

    for _, inst in ipairs(model:GetDescendants()) do
        if inst:IsA("BasePart") then
            return inst.CFrame
        end
    end

    return nil
end

function A.teleportToChest()
    if A.inTeleportGrace() then
        return
    end
    if not A.config.standOnChest then
        return
    end

    local character = A.R.LocalPlayer and A.R.LocalPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not character or not root then
        return
    end

    local target = A.getPivotTarget(A.findActiveRngInstance())
    local cf = A.getModelCFrame(target)
    if not cf then
        return
    end

    character:PivotTo(cf + Vector3.new(0, 7, 0))
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
end

function A.getChestUid()
    local breakableCmds = A.R.BreakableCmds
    if breakableCmds and breakableCmds.AllByInstanceAndClass then
        local chests = A.try("AllByInstanceAndClass", breakableCmds.AllByInstanceAndClass, "Chest")
        if type(chests) == "table" then
            for _, inst in pairs(chests) do
                local okUid, uid = pcall(function()
                    return inst:GetAttribute("BreakableUID")
                end)
                if okUid and uid ~= nil and tostring(uid) ~= "" then
                    A.state.lastChestUid = tostring(uid)
                    return A.state.lastChestUid
                end
            end
        end
    end

    local things = workspace:FindFirstChild("__THINGS")
    local breakables = things and things:FindFirstChild("Breakables")
    if not breakables then
        A.state.lastChestUid = nil
        return nil
    end

    for _, model in ipairs(breakables:GetChildren()) do
        local parentId = model:GetAttribute("ParentID") or model:GetAttribute("ParentId")
        local uid = model:GetAttribute("BreakableUID")
        local id = tostring(model:GetAttribute("BreakableID") or model.Name)
        if uid and (parentId == A.rngInstanceId() or string.find(string.lower(id), "rng")) then
            A.state.lastChestUid = tostring(uid)
            return A.state.lastChestUid
        end
    end

    A.state.lastChestUid = nil
    return nil
end

function A.damageChest()
    if A.inTeleportGrace() then
        return
    end
    if not A.config.autoDamageChest then
        return
    end

    local uid = A.getChestUid()
    if uid then
        A.unreliable("Breakables_PlayerDealDamage", uid)
    end
end

function A.countItem(item)
    if not item then
        return 0
    end

    local ok, count = pcall(item.CountAny, item)
    if ok and type(count) == "number" then
        return count
    end

    local container = A.R.InventoryCmds and A.try("InventoryCmds.Container", A.R.InventoryCmds.Container)
    if container and container.CountAny then
        local ok2, count2 = pcall(container.CountAny, container, item)
        if ok2 and type(count2) == "number" then
            return count2
        end
    end

    return 0
end

function A.miscItem(id)
    if not A.R.MiscItem then
        return nil
    end
    return A.try("MiscItem " .. tostring(id), A.R.MiscItem, id)
end

function A.currencyItem(id)
    if not A.R.CurrencyItem then
        return nil
    end
    return A.try("CurrencyItem " .. tostring(id), A.R.CurrencyItem, id)
end

function A.rngCoins()
    return A.countItem(A.currencyItem("RngCoins2"))
end

function A.consumeStandardDice(opts)
    if not A.config.useStandardDice then
        return
    end

    opts = opts or {}
    local threshold = tonumber(opts.thresholdOverride) or tonumber(A.config.standardDiceRefreshBelow) or 999
    local maxPasses = math.min(40, math.max(1, tonumber(A.config.standardDiceTopUpPasses) or 24))

    for _ = 1, maxPasses do
        local remaining = 0
        if A.R.LuckyDiceCmds and A.R.LuckyDiceCmds.ComputeStandardRemaining then
            remaining = tonumber(A.try("ComputeStandardRemaining", A.R.LuckyDiceCmds.ComputeStandardRemaining)) or 0
        end

        if not opts.force and remaining >= threshold then
            break
        end

        local progressed = false
        for _, id in ipairs(A.config.standardDicePriority) do
            if A.countItem(A.miscItem(id)) > 0 then
                local ok = A.invoke("LuckyDice_Consume", id, 1)
                if ok then
                    A.state.stats.diceUsed = A.state.stats.diceUsed + 1
                    progressed = true
                end
                break
            end
        end

        if not progressed then
            break
        end
    end
end

function A.maintainStandardDiceInventory()
    if not A.config.useStandardDice or not A.inRngInstance() then
        return
    end
    local now = os.clock()
    local iv = tonumber(A.config.standardDiceMaintainInterval) or 300
    if now - (A.state.lastStandardDiceMaintain or 0) < iv then
        return
    end
    A.state.lastStandardDiceMaintain = now
    A.consumeStandardDice({ force = true })
end

function A.shouldUseMegaDice()
    if not A.config.useMegaDice then
        return false
    end
    if A.state.lastMegaUseAtRoll == A.state.rollCount then
        return false
    end

    local nextRoll = A.state.rollCount + 1
    if A.config.megaOnBonusRoll and nextRoll % 10 == 0 then
        return true
    end

    local every = tonumber(A.config.megaEveryRolls) or 0
    return every > 0 and nextRoll % every == 0
end

function A.consumeMegaDice()
    if not A.shouldUseMegaDice() then
        return
    end

    for _, id in ipairs(A.config.megaDicePriority) do
        if A.countItem(A.miscItem(id)) > 0 then
            local ok = A.invoke("LuckyDice_ConsumeMega", id, 1)
            if ok then
                A.state.lastMegaUseAtRoll = A.state.rollCount
                A.state.stats.megaDiceUsed = A.state.stats.megaDiceUsed + 1
            end
            return
        end
    end
end

function A.computeRollDelay()
    local delay = 1
    if A.R.RngEggCmds and A.R.RngEggCmds.ComputeCooldown and A.R.RngEgg then
        delay = A.try("ComputeCooldown", A.R.RngEggCmds.ComputeCooldown, A.R.RngEgg) or delay
    elseif A.R.RngEgg and A.R.RngEgg.DefaultCooldown then
        delay = A.R.RngEgg.DefaultCooldown
    end

    delay = math.max(A.config.minRollDelay, delay)
    if A.config.rollJitter and A.config.rollJitter > 0 then
        delay = delay + math.random() * A.config.rollJitter
    end

    return delay
end

function A.classifyPet(item)
    if not item then
        return nil
    end

    local okG, isG = pcall(item.IsGargantuan, item)
    if okG and isG then
        return "Gargantuan"
    end

    local okT, isT = pcall(item.IsTitanic, item)
    if okT and isT then
        return "Titanic"
    end

    local okH, isH = pcall(item.IsHuge, item)
    if okH and isH then
        return "Huge"
    end

    return nil
end

function A.itemName(item)
    if not item then
        return "Unknown"
    end
    local ok, name = pcall(item.GetName, item)
    if ok and name then
        return name
    end
    local okId, id = pcall(item.GetId, item)
    return okId and tostring(id) or "Unknown"
end

function A.itemUid(item)
    if not item then
        return nil
    end
    local ok, uid = pcall(item.GetUID, item)
    if ok and uid then
        return tostring(uid)
    end
    local okStack, stack = pcall(item.StackKey, item)
    if okStack and stack then
        return tostring(stack)
    end
    return nil
end

function A.itemNotifyKey(item)
    if not item then
        return nil
    end
    local uid = A.itemUid(item)
    if uid and uid ~= "" then
        return uid
    end
    local okId, id = pcall(item.GetId, item)
    if okId and id ~= nil and id ~= "" then
        return "id:" .. tostring(id)
    end
    return "name:" .. A.itemName(item)
end

function A.itemAmount(item)
    local ok, amount = pcall(item.GetAmount, item)
    if ok and type(amount) == "number" and amount > 0 then
        return amount
    end
    return 1
end

function A.itemIcon(item)
    local ok, icon = pcall(item.GetIcon, item)
    if not ok or type(icon) ~= "string" then
        return nil
    end

    local assetId = icon:match("rbxassetid://(%d+)")
    if assetId then
        return "https://www.roblox.com/asset-thumbnail/image?assetId=" .. assetId .. "&width=420&height=420&format=png"
    end

    return icon ~= "" and icon or nil
end

function A.rawPetIconString(item)
    if not item then
        return nil
    end
    local ok, icon = pcall(item.GetIcon, item)
    if ok and type(icon) == "string" and icon ~= "" then
        return icon
    end
    return nil
end

function A.extractRobloxThumbnailAssetId(iconStr)
    if type(iconStr) ~= "string" then
        return nil
    end
    local id = iconStr:match("rbxassetid://(%d+)")
    if id then
        return id
    end
    id = iconStr:lower():match("rbxthumb://[%w%?=&%._%-]*id=(%d+)")
    if id then
        return id
    end
    id = iconStr:match("rbxasset://%s*(%d+)")
    if id then
        return id
    end
    id = iconStr:match("asset/?%?id=(%d+)")
    if id then
        return id
    end
    return nil
end

function A.httpRequestExecutor(req)
    local requestFn = (syn and syn.request) or http_request or request
    if not requestFn then
        return false, nil
    end
    return pcall(requestFn, req)
end

function A.httpResponseStatus(res)
    if not res then
        return 0
    end
    return tonumber(res.StatusCode) or tonumber(res.Status) or tonumber(res.status) or 0
end

function A.httpResponseBody(res)
    if not res then
        return ""
    end
    return res.Body or res.body or ""
end

function A.robloxAssetThumbnailCdnUrl(assetIdStr)
    if not assetIdStr or not A.R.HttpService then
        return nil
    end
    local api = "https://thumbnails.roblox.com/v1/assets?assetIds=" .. assetIdStr .. "&size=420x420&format=Png&isCircular=false"
    local ok, res = A.httpRequestExecutor({ Url = api, Method = "GET" })
    if not ok or not res or A.httpResponseStatus(res) ~= 200 then
        return nil
    end
    local body = A.httpResponseBody(res)
    local decodeOk, data = pcall(A.R.HttpService.JSONDecode, A.R.HttpService, body)
    if not decodeOk or type(data) ~= "table" or not data.data or not data.data[1] then
        return nil
    end
    local entry = data.data[1]
    local url = entry.imageUrl
    if type(url) == "string" and url ~= "" then
        return url
    end
    return nil
end

function A.httpGetBinary(url)
    if type(url) ~= "string" or url == "" then
        return nil
    end
    local ok, res = A.httpRequestExecutor({ Url = url, Method = "GET" })
    if not ok or not res or A.httpResponseStatus(res) ~= 200 then
        return nil
    end
    local body = A.httpResponseBody(res)
    if type(body) == "string" and #body > 32 then
        return body
    end
    return nil
end

function A.preparePetWebhookImagePayload(item)
    if not item then
        return nil
    end
    local raw = A.rawPetIconString(item)
    local cdn = nil
    local bytes = nil

    if type(raw) == "string" and raw:find("^https?://") then
        cdn = raw
        bytes = A.httpGetBinary(cdn)
    else
        local aid = raw and A.extractRobloxThumbnailAssetId(raw)
        if aid then
            cdn = A.robloxAssetThumbnailCdnUrl(aid)
            if cdn then
                bytes = A.httpGetBinary(cdn)
            end
        end
    end

    if not bytes then
        if cdn then
            return { bytes = nil, filename = "pet_rng.png", cdnFallbackUrl = cdn }
        end
        return nil
    end

    local cap = tonumber(A.config.webhookImageMaxBytes) or 8388608
    if #bytes > cap then
        return { bytes = nil, filename = "pet_rng.png", cdnFallbackUrl = cdn }
    end

    return { bytes = bytes, filename = "pet_rng.png", cdnFallbackUrl = cdn, contentType = "image/png" }
end

function A.discordWebhookMultipartPayload(webhookUrl, payloadLua, fileField)
    local requestFn = (syn and syn.request) or http_request or request
    if not requestFn or not A.R.HttpService then
        return false
    end

    local payloadJson
    local encOk = pcall(function()
        payloadJson = A.R.HttpService:JSONEncode(payloadLua)
    end)
    if not encOk or type(payloadJson) ~= "string" then
        return false
    end

    local boundary = "----PetRNGForm" .. tostring(math.random(100000, 999999)) .. "b" .. tostring(os.clock())
    local crlf = "\r\n"
    local chunks = {}
    local function app(s)
        chunks[#chunks + 1] = s
    end

    app("--" .. boundary .. crlf)
    app('Content-Disposition: form-data; name="payload_json"' .. crlf .. crlf .. payloadJson .. crlf)

    if fileField and type(fileField.data) == "string" and #fileField.data > 0 then
        local fname = tostring(fileField.filename or "image.png"):gsub('["\r\n]', "")
        local ctype = tostring(fileField.contentType or "image/png")
        app("--" .. boundary .. crlf)
        app('Content-Disposition: form-data; name="files[0]"; filename="' .. fname .. '"' .. crlf)
        app("Content-Type: " .. ctype .. crlf)
        app(crlf)
        app(fileField.data)
        app(crlf)
    end

    app("--" .. boundary .. "--" .. crlf)

    local body = table.concat(chunks)
    local ok, res = pcall(requestFn, {
        Url = webhookUrl,
        Method = "POST",
        Headers = { ["Content-Type"] = "multipart/form-data; boundary=" .. boundary },
        Body = body,
    })

    if not ok then
        return false
    end
    local code = A.httpResponseStatus(res)
    if code < 200 or code >= 300 then
        return false
    end
    return true
end

function A.variantText(item)
    local out = {}
    local checks = {
        { "IsShiny", "Shiny" },
        { "IsRainbow", "Rainbow" },
        { "IsGolden", "Golden" },
    }

    for _, check in ipairs(checks) do
        local ok, result = pcall(item[check[1]], item)
        if ok and result then
            table.insert(out, check[2])
        end
    end

    return #out > 0 and table.concat(out, " ") or "Normal"
end

function A.statColor()
    if A.state.stats.gargantuans > 0 then
        return Color3.fromRGB(95, 25, 140)
    elseif A.state.stats.titanics > 0 then
        return Color3.fromRGB(125, 20, 20)
    elseif A.state.stats.huges > 0 then
        return Color3.fromRGB(20, 95, 35)
    end
    return Color3.new(0, 0, 0)
end

function A.formatRuntime()
    local seconds = math.max(0, os.time() - A.state.startedAt)
    local h = math.floor(seconds / 3600)
    local m = math.floor(seconds % 3600 / 60)
    local s = seconds % 60
    return string.format("%02d:%02d:%02d", h, m, s)
end

function A.createStatsGui()
    if not A.config.blackScreenStats or A.state.statsGui then
        return
    end

    local gui = Instance.new("ScreenGui")
    gui.Name = "PET_RNG_BLACK_STATS"
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 999999
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    local frame = Instance.new("Frame")
    frame.Name = "Blackout"
    frame.Size = UDim2.fromScale(1, 1)
    frame.BackgroundColor3 = Color3.new(0, 0, 0)
    frame.BorderSizePixel = 0
    frame.Parent = gui

    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.AnchorPoint = Vector2.new(0.5, 1)
    title.Position = UDim2.fromScale(0.5, 0.44)
    title.Size = UDim2.fromOffset(800, 70)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBlack
    title.Text = "PET RNG AUTO FARM"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextScaled = true
    title.Parent = frame

    local stats = Instance.new("TextLabel")
    stats.Name = "Stats"
    stats.AnchorPoint = Vector2.new(0.5, 0)
    stats.Position = UDim2.fromScale(0.5, 0.46)
    stats.Size = UDim2.fromOffset(760, 320)
    stats.BackgroundTransparency = 1
    stats.Font = Enum.Font.Code
    stats.Text = "Loading stats..."
    stats.TextColor3 = Color3.fromRGB(230, 230, 230)
    stats.TextScaled = true
    stats.TextXAlignment = Enum.TextXAlignment.Center
    stats.TextYAlignment = Enum.TextYAlignment.Top
    stats.Parent = frame

    local button = Instance.new("TextButton")
    button.Name = "HideButton"
    button.AnchorPoint = Vector2.new(0, 1)
    button.Position = UDim2.new(0, 12, 1, -12)
    button.Size = UDim2.fromOffset(130, 36)
    button.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    button.BorderSizePixel = 0
    button.Font = Enum.Font.GothamBold
    button.Text = "HIDE GUI"
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.TextSize = 14
    button.Parent = gui

    local copyBtn = Instance.new("TextButton")
    copyBtn.Name = "CopyLogsButton"
    copyBtn.AnchorPoint = Vector2.new(0, 1)
    copyBtn.Position = UDim2.new(0, 152, 1, -12)
    copyBtn.Size = UDim2.fromOffset(130, 36)
    copyBtn.BackgroundColor3 = Color3.fromRGB(28, 45, 90)
    copyBtn.BorderSizePixel = 0
    copyBtn.Font = Enum.Font.GothamBold
    copyBtn.Text = "COPYLOGS"
    copyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    copyBtn.TextSize = 14
    copyBtn.Parent = gui

    local parent
    if gethui then
        local okH, h = pcall(gethui)
        if okH and h then
            parent = h
        end
    end
    if not parent then
        parent = A.R.CoreGui
    end
    if not parent then
        local okCg, cg = pcall(function()
            return game:GetService("CoreGui")
        end)
        if okCg then
            parent = cg
        end
    end
    if not parent and A.R.LocalPlayer then
        parent = A.R.LocalPlayer:FindFirstChildWhichIsA("PlayerGui")
    end
    if not parent then
        pcall(function()
            gui:Destroy()
        end)
        return
    end

    local okParent = pcall(function()
        gui.Parent = parent
    end)
    if not okParent then
        pcall(function()
            gui:Destroy()
        end)
        return
    end

    local gen = A.state.runGeneration
    table.insert(A.state.connections, button.MouseButton1Click:Connect(function()
        if getgenv().PetRNGAutoGeneration ~= gen then
            return
        end
        A.state.guiHidden = not A.state.guiHidden
        frame.Visible = not A.state.guiHidden
        button.Text = A.state.guiHidden and "SHOW GUI" or "HIDE GUI"
    end))

    table.insert(A.state.connections, copyBtn.MouseButton1Click:Connect(function()
        if getgenv().PetRNGAutoGeneration ~= gen then
            return
        end
        local lines = A.state.diagLogLines or {}
        local text = #lines > 0 and table.concat(lines, "\n") or "(diag empty / logging off)"
        if setclipboard then
            pcall(setclipboard, text)
            A.diagLog("COPY LOGS → clipboard (" .. tostring(#lines) .. " lines)")
        else
            A.diagLog("COPY LOGS fail: setclipboard missing")
        end
    end))

    A.state.statsGui = gui
    A.state.statsFrame = frame
    A.state.statsText = stats
    A.state.statsButton = button
    A.state.statsCopyButton = copyBtn
end

function A.refreshStatsGuiEconomy()
    A.state.stats.coins = A.rngCoins()
end

function A.applyStatsGuiVisual()
    if not A.config.blackScreenStats then
        return
    end
    A.createStatsGui()

    local text = A.state.statsText
    local frame = A.state.statsFrame
    if not text or not frame then
        return
    end

    frame.BackgroundColor3 = A.statColor()
    text.Text = table.concat({
        "Runtime: " .. A.formatRuntime(),
        "Rolls: " .. tostring(A.state.stats.rolls),
        "RNG Coins: " .. tostring(A.state.stats.coins),
        "Upgrades bought: " .. tostring(A.state.stats.upgrades),
        "Dice used: " .. tostring(A.state.stats.diceUsed) .. " | Mega used: " .. tostring(A.state.stats.megaDiceUsed),
        "Dice bought: " .. tostring(A.state.stats.diceBought) .. " | Crafted: " .. tostring(A.state.stats.diceCrafted),
        "Pets sold: " .. tostring(A.state.stats.petsSold),
        "Huge: " .. tostring(A.state.stats.huges) .. " | Titanic: " .. tostring(A.state.stats.titanics) .. " | Gargantuan: " .. tostring(A.state.stats.gargantuans),
        "Last high-tier: " .. A.state.stats.lastDrop,
    }, "\n")
end

function A.tickStatsGuiOverlay()
    A.runLoopWork(A.refreshStatsGuiEconomy, "loop.updateStatsGui.data")
    pcall(A.applyStatsGuiVisual)
end

function A.startStatsGuiOverlayLoop()
    local g = getgenv()
    local gen = A.state.runGeneration
    local rs = A.R.RunService
    local interval = math.max(0.05, tonumber(A.config.statsUpdateInterval) or 0.5)
    local sched = (A.config.statsGuiLoopScheduler ~= nil and A.config.statsGuiLoopScheduler) or "RenderStep"

    if sched == "Spawn" then
        task.spawn(function()
            while A.config.enabled and g.PetRNGAutoGeneration == gen do
                A.tickStatsGuiOverlay()
                task.wait(interval)
            end
        end)
        return
    end

    if not rs or not rs.RenderStepped or not rs.RenderStepped.Connect then
        task.spawn(function()
            while A.config.enabled and g.PetRNGAutoGeneration == gen do
                A.tickStatsGuiOverlay()
                task.wait(interval)
            end
        end)
        return
    end

    local acc = 0
    local conn = rs.RenderStepped:Connect(function(dt)
        if not A.config.enabled or g.PetRNGAutoGeneration ~= gen then
            return
        end
        acc += dt
        while acc >= interval do
            acc -= interval
            A.tickStatsGuiOverlay()
        end
    end)
    table.insert(A.state.connections, conn)
end

function A.httpPost(url, body)
    local requestFn = (syn and syn.request) or http_request or request
    if not requestFn then
        return false
    end

    local payload = A.R.HttpService:JSONEncode(body)
    local ok, res = pcall(requestFn, {
        Url = url,
        Method = "POST",
        Headers = { ["Content-Type"] = "application/json" },
        Body = payload,
    })

    if not ok then
        return false
    end

    return res
end

function A.sendWebhook(item, tier)
    if not A.config.webhookEnabled or A.config.webhookUrl == "" then
        return
    end

    local name = A.itemName(item)
    local variant = A.variantText(item)
    local uid = A.itemUid(item) or "no-uid"
    local player = A.R.LocalPlayer
    local ping = A.config.discordUserId ~= "" and ("<@" .. A.config.discordUserId .. "> ") or ""
    local embed = {
        title = "PET RNG " .. tier .. " rolled",
        description = ("**%s**\nVariant: `%s`\nPlayer: `%s`"):format(name, variant, player and player.Name or "Unknown"),
        color = tier == "Gargantuan" and 16711935 or (tier == "Titanic" and 16753920 or 5814783),
        fields = {
            { name = "UID", value = "`" .. uid .. "`", inline = false },
        },
        timestamp = DateTime.now():ToIsoDate(),
    }

    local img = A.preparePetWebhookImagePayload(item)
    local useAttach = A.config.webhookImageAsAttachment ~= false
    local payload = {
        content = ping .. "**" .. name .. "**",
        embeds = { embed },
    }

    if img and img.bytes and useAttach then
        local fname = img.filename or "pet_rng.png"
        embed.image = { url = "attachment://" .. fname }
        if A.discordWebhookMultipartPayload(A.config.webhookUrl, payload, {
            data = img.bytes,
            filename = fname,
            contentType = img.contentType or "image/png",
        }) then
            return
        end
        embed.image = nil
    end

    if img and img.cdnFallbackUrl then
        embed.image = { url = img.cdnFallbackUrl }
    else
        local legacy = A.itemIcon(item)
        if legacy then
            embed.thumbnail = { url = legacy }
        end
    end

    A.httpPost(A.config.webhookUrl, payload)
end

function A.shouldMailTier(tier)
    if not A.config.autoMailEnabled or A.config.mailUsername == "" then
        return false
    end
    if tier == "Huge" then
        return A.config.sendAllHuges == true
    elseif tier == "Titanic" then
        return A.config.sendAllTitanics == true
    elseif tier == "Gargantuan" then
        return A.config.sendAllGargantuans == true
    end
    return false
end

function A.mailItem(item, tier)
    if not A.shouldMailTier(tier) then
        return
    end

    local uid = A.itemUid(item)
    if not uid or A.state.mailed[uid] then
        return
    end

    local okClass, className = pcall(function()
        return item.Class.Name
    end)
    if not okClass or not className then
        className = "Pet"
    end

    local ok = A.invoke("Mailbox: Send", A.config.mailUsername, A.config.mailMessage, className, uid, A.itemAmount(item))
    if ok then
        A.state.mailed[uid] = true
    end
end

function A.handleHighTier(item, source)
    local tier = A.classifyPet(item)
    if not tier then
        return
    end

    local nkey = A.itemNotifyKey(item)
    if not nkey then
        return
    end

    if source == "scan" then
        if A.state.initialHighTiers[nkey] then
            A.mailItem(item, tier)
        end
        return
    end

    if source == "added" and not A.state.petInventoryBaselineDone then
        return
    end

    if A.state.initialHighTiers[nkey] then
        return
    end

    if not A.state.notified[nkey] then
        A.state.notified[nkey] = true
        if source == "roll" then
            if tier == "Huge" then
                A.state.stats.huges = A.state.stats.huges + 1
            elseif tier == "Titanic" then
                A.state.stats.titanics = A.state.stats.titanics + 1
            elseif tier == "Gargantuan" then
                A.state.stats.gargantuans = A.state.stats.gargantuans + 1
            end
        end
        A.state.stats.lastDrop = tier .. " " .. A.itemName(item)
        A.sendWebhook(item, tier)
    end

    A.mailItem(item, tier)
end

function A.mergePetInventoryHighTierBaseline()
    local petItem = A.R.PetItem
    if not petItem or not petItem.All then
        return
    end

    local all = A.try("PetItem.All", function()
        return petItem:All()
    end)
    if type(all) ~= "table" then
        return
    end

    for _, item in pairs(all) do
        if A.classifyPet(item) then
            local nkey = A.itemNotifyKey(item)
            if nkey then
                A.state.initialHighTiers[nkey] = true
            end
        end
    end
end

function A.schedulePetInventoryBaselinePasses()
    local gen = A.state.runGeneration
    local delays = A.config.highTierBaselineDelays
    if type(delays) ~= "table" or #delays == 0 then
        A.state.petInventoryBaselineDone = true
        return
    end
    for i, sec in ipairs(delays) do
        local t = tonumber(sec) or 0
        task.delay(math.max(0, t), function()
            if getgenv().PetRNGAutoGeneration ~= gen then
                return
            end
            A.mergePetInventoryHighTierBaseline()
            if i == #delays then
                A.state.petInventoryBaselineDone = true
            end
        end)
    end
end

function A.scanHighTiers()
    local petItem = A.R.PetItem
    if not petItem or not petItem.All then
        return
    end

    local all = A.try("PetItem.All", function()
        return petItem:All()
    end)
    if type(all) ~= "table" then
        return
    end

    A.mergePetInventoryHighTierBaseline()
    for _, item in pairs(all) do
        A.handleHighTier(item, "scan")
    end
end

function A.rollOnce()
    if not A.config.autoRoll or not A.inRngInstance() then
        return
    end

    A.consumeStandardDice()
    A.consumeMegaDice()

    local rollPack = table.pack(A.try("RngEggCmds.Roll", A.R.RngEggCmds.Roll, "First"))
    if rollPack.n == 0 then
        local now = os.clock()
        if now - (A.state._diagRollPcallDead or 0) > 6 then
            A.state._diagRollPcallDead = now
            A.diagLog("Roll pcall error (RngEggCmds.Roll threw)")
        end
        return
    end

    local rollOk = rollPack[1]
    local mid = rollPack[2]
    local result = rollPack[3]
    if not rollOk or not result then
        local msg = string.lower(tostring(mid or ""))
        local now = os.clock()
        if now - (A.state._diagLastRollFail or 0) > 3 then
            A.state._diagLastRollFail = now
            A.diagLog("roll blocked/fail: " .. tostring(mid))
        end
        if string.find(msg, "hatch")
            or string.find(msg, "already")
            or string.find(msg, "rolling")
            or string.find(msg, "cooldown")
            or string.find(msg, "wait")
            or string.find(msg, "not loaded")
        then
            A.state.rollDueAt = os.clock() + 2.75
        end
        return
    end

    A.state.rollCount = A.state.rollCount + 1
    A.state.stats.rolls = A.state.rollCount
    A.state.lastRollAt = os.clock()

    local reward = result and result.Reward
    local item = reward and reward.Item
    if item then
        A.handleHighTier(item, "roll")
    end

    local every = tonumber(A.config.diagLogRollSummaryEvery) or 0
    if every > 0 and A.state.rollCount % every == 0 then
        A.diagLog(string.format(
            "roll OK #%d | coins=%s | inRng=%s",
            A.state.rollCount,
            tostring(A.state.stats.coins),
            tostring(A.inRngInstance())
        ))
    end
end

function A.buyDice()
    if not A.config.autoBuyDice or not A.inRngInstance() then
        return
    end

    local save = A.getSave()
    local dir = A.R.Directory
    local merchantUtil = A.R.MerchantUtil
    if not save or not dir or not dir.Merchants or not dir.Merchants.LuckyDiceMerchantV2 or not merchantUtil then
        return
    end

    local merchant = dir.Merchants.LuckyDiceMerchantV2
    local exp = save.MerchantExperience and save.MerchantExperience.LuckyDiceMerchantV2 or 0
    local respect = A.try("RespectLevelFromExperience", merchantUtil.RespectLevelFromExperience, exp) or 0
    local levels = merchant.SlotRespectLevels or {}

    for slot = 1, #levels do
        if respect >= levels[slot] then
            local ok, msg = A.invoke("Merchant_RequestPurchase", "LuckyDiceMerchantV2", slot)
            if ok then
                A.state.stats.diceBought = A.state.stats.diceBought + 1
            elseif msg and string.find(string.lower(tostring(msg)), "enough") then
                return
            end
        end
    end
end

function A.craftDice()
    if not A.config.autoCraftDice or not A.inRngInstance() then
        return
    end

    local order = {
        "Lucky Dice II V2",
        "Mega Lucky Dice V2",
        "Mega Lucky Dice II V2",
    }

    for _, id in ipairs(order) do
        local maxCraft = 0
        if A.R.LuckyDiceCmds and A.R.LuckyDiceCmds.ComputeMaxCraftable then
            maxCraft = A.try("ComputeMaxCraftable " .. id, A.R.LuckyDiceCmds.ComputeMaxCraftable, id) or 0
        end

        maxCraft = math.floor(tonumber(maxCraft) or 0)
        if maxCraft > 0 and maxCraft < math.huge then
            local ok = A.invoke("LuckyDice_Craft", id, maxCraft)
            if ok then
                A.state.stats.diceCrafted = A.state.stats.diceCrafted + maxCraft
            end
        end
    end
end

function A.canAffordCost(cost)
    if not cost then
        return false
    end

    local amount = A.try("cost.GetAmount", cost.GetAmount, cost) or math.huge
    local count = A.try("cost.CountAny", cost.CountAny, cost)
    if type(count) == "number" then
        return count >= amount
    end

    return A.rngCoins() >= amount
end

function A.buyUpgrades()
    if not A.config.autoUpgrade or not A.inRngInstance() then
        return
    end

    local egg = A.R.RngEgg
    local cmds = A.R.RngEggCmds
    if not egg or not egg.Upgrades or not cmds then
        return
    end

    for _, upgradeId in ipairs(A.config.upgradePriority) do
        local upgrade = egg.Upgrades[upgradeId]
        if upgrade then
            local tier = A.try("GetUpgradeTier", cmds.GetUpgradeTier, egg, upgradeId) or 0
            local maxTier = #upgrade.TierPowers
            if tier < maxTier then
                local cost = A.try("TierCosts", upgrade.TierCosts, tier + 1, 1)
                if A.canAffordCost(cost) then
                    local ok = A.invoke("Rng_PurchaseUpgrade", egg._id or "First", upgradeId)
                    if ok then
                        A.state.stats.upgrades = A.state.stats.upgrades + 1
                    end
                    return
                end
            end
        end
    end
end

function A.isSellableRngPet(item)
    if not item then
        return false
    end
    if A.classifyPet(item) then
        return false
    end
    local okLock, locked = pcall(item.IsLocked, item)
    if okLock and locked then
        return false
    end
    if A.R.RngTypes and A.R.RngTypes.IsSellableItem and A.R.RngEgg then
        local ok, result = pcall(A.R.RngTypes.IsSellableItem, item, A.R.RngEgg)
        return ok and result == true
    end
    return false
end

function A.sellEventPets()
    if not A.config.autoSellEventPets or not A.inRngInstance() then
        return
    end

    local petItem = A.R.PetItem
    if not petItem or not petItem.All then
        return
    end

    local all = A.try("PetItem.All", function()
        return petItem:All()
    end)
    if type(all) ~= "table" then
        return
    end

    local egg = A.R.RngEgg
    local bal = A.R.RngBalancing
    local rows = {}
    for _, item in pairs(all) do
        if A.isSellableRngPet(item) then
            local uid = A.itemUid(item)
            local amount = A.itemAmount(item)
            if uid and type(amount) == "number" and amount > 0 then
                local payout = 0
                if bal and bal.ComputeRngSellingPayoutFromItem and egg then
                    payout = tonumber(A.try("ComputeRngSellingPayoutFromItem", bal.ComputeRngSellingPayoutFromItem, item, egg))
                        or 0
                end
                rows[#rows + 1] = {
                    uid = uid,
                    amount = amount,
                    payout = payout,
                }
            end
        end
    end

    local keepN = math.max(0, math.floor(tonumber(A.config.keepBestRngPetsWhenSelling) or 15))
    table.sort(rows, function(a, b)
        if a.payout ~= b.payout then
            return a.payout > b.payout
        end
        return tostring(a.uid) < tostring(b.uid)
    end)

    local selection = {}
    local stacksListed = 0
    local petsMoved = 0
    local cap = math.max(1, math.floor(tonumber(A.config.sellMaxPetsPerBatch) or 80))
    for i = keepN + 1, #rows do
        if stacksListed >= cap then
            break
        end
        local r = rows[i]
        selection[r.uid] = r.amount
        stacksListed = stacksListed + 1
        petsMoved = petsMoved + r.amount
    end

    if stacksListed > 0 then
        local ok = A.invoke("RngEventPetMerchant_Activate", selection)
        if ok then
            A.state.stats.petsSold = A.state.stats.petsSold + petsMoved
        end
    end
end

function A.loopEvery(interval, contextTag, fn, schedulerOverride, threadIdentityForLoop)
    local g = getgenv()
    local gen = A.state.runGeneration
    local rs = A.R.RunService
    local sched = schedulerOverride or (A.config and A.config.loopScheduler) or "RenderStep"
    local tag = type(contextTag) == "string" and contextTag or "loop.unknown"

    if sched == "RenderStep" and rs and rs.BindToRenderStep and interval > 0 then
        A.state.renderStepSeq = (A.state.renderStepSeq or 0) + 1
        local name = "__PetRNG_" .. tostring(gen) .. "_" .. tostring(A.state.renderStepSeq)
        A.state.renderStepBindings = A.state.renderStepBindings or {}
        local acc = 0
        rs:BindToRenderStep(name, Enum.RenderPriority.Last.Value - 5, function(dt)
            if not A.config.enabled or g.PetRNGAutoGeneration ~= gen then
                return
            end
            if contextTag ~= "loop.enterRngInstance" and A.inTeleportGrace() then
                return
            end
            acc += dt
            while acc >= interval do
                acc -= interval
                A.runLoopWork(fn, tag, threadIdentityForLoop)
            end
        end)
        table.insert(A.state.renderStepBindings, name)
        return
    end

    task.spawn(function()
        while A.config.enabled and g.PetRNGAutoGeneration == gen do
            if contextTag == "loop.enterRngInstance" or not A.inTeleportGrace() then
                A.runLoopWork(fn, tag .. ".spawn", threadIdentityForLoop)
            end
            task.wait(interval)
        end
    end)
end

function A.startLoops()
    if A.state.loopsStarted then
        return
    end
    A.state.loopsStarted = true

    local g = getgenv()
    local gen = A.state.runGeneration
    local rs = A.R.RunService
    local rollSched = (A.config and A.config.rollLoopScheduler) or "Spawn"

    A.loopEvery(0.35, "loop.enterRngInstance", A.enterRngInstance)

    A.loopEvery(A.config.chestTeleportInterval, "loop.chestTeleport", function()
        if A.inRngInstance() then
            A.teleportToChest()
        end
    end)

    A.loopEvery(A.config.chestDamageInterval, "loop.chestDamage", function()
        if A.inRngInstance() then
            A.damageChest()
        end
    end)

    A.state.rollDueAt = 0
    if rollSched == "RenderStep" and rs and rs.BindToRenderStep then
        A.state.renderStepSeq = (A.state.renderStepSeq or 0) + 1
        local rollName = "__PetRNG_Roll_" .. tostring(gen) .. "_" .. tostring(A.state.renderStepSeq)
        rs:BindToRenderStep(rollName, Enum.RenderPriority.Last.Value - 8, function()
            if not A.config.enabled or g.PetRNGAutoGeneration ~= gen then
                return
            end
            if A.inTeleportGrace() then
                A.state.rollDueAt = os.clock() + 0.25
                return
            end
            local now = os.clock()
            if now < (A.state.rollDueAt or 0) then
                return
            end
            local okBlock = A.runLoopWork(function()
                if A.inRngInstance() then
                    pcall(A.rollOnce)
                    A.state.rollDueAt = os.clock() + A.computeRollDelay()
                else
                    A.state.rollDueAt = os.clock() + 1
                end
            end, "loop.roll")
            if not okBlock then
                A.state.rollDueAt = os.clock() + 0.35
            end
        end)
        table.insert(A.state.renderStepBindings, rollName)
    else
        task.spawn(function()
            while A.config.enabled and g.PetRNGAutoGeneration == gen do
                local waitSec = 1
                if A.inTeleportGrace() then
                    task.wait(0.25)
                    continue
                end
                local okBlock = A.runLoopWork(function()
                    if A.inRngInstance() then
                        pcall(A.rollOnce)
                        waitSec = A.computeRollDelay()
                    else
                        waitSec = 1
                    end
                end, "loop.roll.spawn")
                if not okBlock then
                    waitSec = 0.35
                end
                task.wait(waitSec)
            end
        end)
    end

    A.loopEvery(A.config.buyDiceInterval, "loop.buyDice", A.buyDice)
    local diceIv = tonumber(A.config.standardDiceMaintainInterval) or 300
    if diceIv > 0.2 then
        A.loopEvery(diceIv, "loop.standardDiceMaintain", A.maintainStandardDiceInventory)
    end
    A.loopEvery(A.config.craftInterval, "loop.craftDice", A.craftDice)
    A.loopEvery(A.config.upgradeInterval, "loop.buyUpgrades", A.buyUpgrades)
    A.loopEvery(A.config.sellInterval, "loop.sellEventPets", A.sellEventPets)
    A.loopEvery(A.config.mailScanInterval, "loop.scanHighTiers", A.scanHighTiers)
    A.loopEvery(A.config.optimizeSweepInterval, "loop.optimizeWorkspace", A.optimizeWorkspace)
    local guiSweep = tonumber(A.config.optimizeGuiSweepInterval) or 2
    if guiSweep > 0.05 then
        A.loopEvery(guiSweep, "loop.optimizeGuiSweep", A.optimizePlayerGuiAggressive)
    end
    local gcIv = tonumber(A.config.optimizePeriodicGCInterval) or 0
    if gcIv >= 15 then
        A.loopEvery(gcIv, "loop.optimizePeriodicGC", A.optimizePeriodicGC)
    end
    A.startStatsGuiOverlayLoop()
end

function A.connectPetAdded()
    local petItem = A.R.PetItem
    if not petItem or not petItem.Added or not petItem.Added.Connect then
        return
    end

    local gen = A.state.runGeneration
    A.try("PetItem.Added.Connect", function()
        local conn = petItem.Added:Connect(function(item)
            if getgenv().PetRNGAutoGeneration ~= gen then
                return
            end
            if item then
                A.runLoopWork(function()
                    A.handleHighTier(item, "added")
                end, "hook.PetItem.Added")
            else
                task.defer(function()
                    A.runLoopWork(A.scanHighTiers, "hook.PetItem.Added.deferScan")
                end)
            end
        end)
        if conn then
            table.insert(A.state.connections, conn)
        end
    end)
end

function A.start()
    A.mergeConfig()
    A.supersedePreviousInstance()
    math.randomseed(math.floor(os.clock() * 1000000) % 2147483647)

    A.diagLog(
        string.format(
            "boot gen=%s diagLogging=%s fpsCap=%s",
            tostring(A.state.runGeneration),
            tostring(not (A.config.diagLogging == false)),
            tostring(A.config.clientFpsCap)
        )
    )

    if not A.initRefs() then
        A.diagLog("start STOP: initRefs")
        return A
    end

    A.applyClientFpsCap()

    A.state.petInventoryBaselineDone = false
    A.mergePetInventoryHighTierBaseline()
    A.schedulePetInventoryBaselinePasses()
    A.connectPetAdded()
    A.setupAntiAfk()
    A.runLoopWork(A.optimizeWorkspace, "startup.optimizeWorkspace")
    do
        pcall(A.createStatsGui)
    end
    A.startLoops()
    A.registerInstanceShutdown()
    return A
end

local function waitUntilGameLoaded()
    if game:IsLoaded() then
        return
    end
    pcall(function()
        game.Loaded:Wait()
    end)
    if game:IsLoaded() then
        return
    end
    local deadline = os.clock() + 120
    while not game:IsLoaded() and os.clock() < deadline do
        task.wait(0.15)
    end
end

waitUntilGameLoaded()
return A.start()
