--[[
    ██████╗ ██╗   ██╗██╗  ██╗██╗   ██╗██████╗     ██████╗ ██████╗  ██████╗
    ██╔══██╗╚██╗ ██╔╝██║  ██║██║   ██║██╔══██╗    ██╔══██╗██╔══██╗██╔═══██╗
    ██║  ██║ ╚████╔╝ ███████║██║   ██║██████╔╝    ██████╔╝██████╔╝██║   ██║
    ██║  ██║  ╚██╔╝  ██╔══██║██║   ██║██╔══██╗    ██╔═══╝ ██╔══██╗██║   ██║
    ██████╔╝   ██║   ██║  ██║╚██████╔╝██████╔╝    ██║     ██║  ██║╚██████╔╝
    ╚═════╝    ╚═╝   ╚═╝  ╚═╝ ╚═════╝ ╚═════╝     ╚═╝     ╚═╝  ╚═╝ ╚═════╝

    DYHUB PRO  v2.0
    Author  : DYHUB
    Price   : 500 THB
    UI Lib  : WindUI (github.com/Footagesus/WindUI)
    Tabs    : DUPE  |  GAMEPASS  |  SETTINGS
--]]

-- ════════════════════════════════════════════════════════════
--  SERVICES
-- ════════════════════════════════════════════════════════════
local Players            = game:GetService("Players")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local RunService         = game:GetService("RunService")
local MarketplaceService = game:GetService("MarketplaceService")
local UserInputService   = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer

-- ════════════════════════════════════════════════════════════
--  EXECUTOR COMPAT
-- ════════════════════════════════════════════════════════════
local setclipboard = setclipboard or (function(t) print("[DYHUB] Clipboard: "..tostring(t)) end)
local writefile    = writefile    or (function() end)
local readfile     = readfile     or (function() return nil end)
local isfile       = isfile       or (function() return false end)

-- ════════════════════════════════════════════════════════════
--  CONFIG  (save / load)
-- ════════════════════════════════════════════════════════════
local CONFIG_PATH = "DYHUB_config.json"

local Config = {
    -- Dupe
    amount         = 999999,
    customKeywords = "",
    blacklist      = "",
    fireDelay      = 0.05,
    -- Gamepass
    autoSpeed      = 50,
    -- Settings
    antiAfk        = true,
    autoRejoin     = false,
    notifySuccess  = true,
}

local function saveConfig()
    local parts = {}
    for k, v in pairs(Config) do
        local vs
        if     type(v) == "string"  then vs = '"'..v:gsub('"','\\"')..'"'
        elseif type(v) == "boolean" then vs = tostring(v)
        elseif type(v) == "number"  then vs = tostring(v)
        end
        if vs then parts[#parts+1] = '"'..k..'":'..vs end
    end
    pcall(writefile, CONFIG_PATH, "{"..table.concat(parts,",").."}")
end

local function loadConfig()
    if not isfile(CONFIG_PATH) then return end
    local ok, raw = pcall(readfile, CONFIG_PATH)
    if not ok or not raw then return end
    for k, v in raw:gmatch('"([^"]+)":([^,}]+)') do
        if Config[k] ~= nil then
            if     v == "true"  then Config[k] = true
            elseif v == "false" then Config[k] = false
            else
                local n = tonumber(v)
                if n then Config[k] = n end
            end
        end
    end
    for k, v in raw:gmatch('"([^"]+)":"([^"]*)"') do
        if Config[k] ~= nil then Config[k] = v end
    end
end
loadConfig()

-- ════════════════════════════════════════════════════════════
--  WINDUI LOAD
-- ════════════════════════════════════════════════════════════
local WindUI = loadstring(game:HttpGet(
    "https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"
))()

-- ════════════════════════════════════════════════════════════
--  WINDOW
-- ════════════════════════════════════════════════════════════
local Window = WindUI:CreateWindow({
    Title       = "DYHUB PRO",
    Icon        = "zap",
    Author      = "by DYHUB",
    Folder      = "DYHUB",
    Size        = UDim2.fromOffset(580, 480),
    ToggleKey   = Enum.KeyCode.RightShift,
    Transparent = true,
    Theme       = "Dark",
    Resizable   = false,
})

-- ════════════════════════════════════════════════════════════
--  TABS
-- ════════════════════════════════════════════════════════════
local DupeTab     = Window:Tab({ Title = "DUPE",     Icon = "copy" })
local GamepassTab = Window:Tab({ Title = "GAMEPASS", Icon = "shopping-cart" })
local SettingsTab = Window:Tab({ Title = "SETTINGS", Icon = "settings" })

-- ════════════════════════════════════════════════════════════
--  DUPE  —  core logic
-- ════════════════════════════════════════════════════════════
local detectedRemotes = {}  -- name → true  (dedup)
local verifiedList    = {}  -- array of {name, remote, args}

local function getStatsValue()
    local total = 0
    local stats = LocalPlayer:FindFirstChild("leaderstats")
    if stats then
        for _, v in pairs(stats:GetChildren()) do
            local n = tonumber(v.Value)
            if n then total = total + n end
        end
    end
    return total
end

local function buildKeywords()
    local keys, seen = {}, {}
    local defaults = {"Money","Cash","Coin","Currency","Point","Gem",
                      "Diamond","Gold","Strength","Power","Candy"}
    for _, k in ipairs(defaults) do
        if not seen[k] then seen[k]=true; keys[#keys+1]=k end
    end
    local stats = LocalPlayer:FindFirstChild("leaderstats")
    if stats then
        for _, s in pairs(stats:GetChildren()) do
            if not seen[s.Name] then seen[s.Name]=true; keys[#keys+1]=s.Name end
        end
    end
    for w in Config.customKeywords:gmatch("([^,%s]+)") do
        if not seen[w] then seen[w]=true; keys[#keys+1]=w end
    end
    return keys
end

local function buildBlacklist()
    local bl = {}
    for n in Config.blacklist:gmatch("([^,%s]+)") do bl[n]=true end
    return bl
end

local function fireRemote(remote, args)
    pcall(function()
        if remote:IsA("RemoteEvent") then
            remote:FireServer(table.unpack(args))
        else
            remote:InvokeServer(table.unpack(args))
        end
    end)
end

-- ─── Log paragraph (updated from scan) ──────────────────────
local dupeLogLines = {}
local DupeLogPara  -- assigned after UI element creation

local function dupeLog(msg, icon)
    local prefix = icon or "»"
    table.insert(dupeLogLines, 1, prefix.." "..msg)
    if #dupeLogLines > 20 then table.remove(dupeLogLines) end
    if DupeLogPara then
        DupeLogPara:SetDesc(table.concat(dupeLogLines, "\n"))
    end
end

-- ─── Status paragraph ────────────────────────────────────────
local DupeStatusPara  -- assigned after creation

local scanRunning = false

local function runScan(mode)
    if scanRunning then
        dupeLog("Scan already running!", "⚠")
        return
    end
    scanRunning = true
    local val   = tonumber(Config.amount) or 999999
    local keys  = buildKeywords()
    local bl    = buildBlacklist()

    if DupeStatusPara then
        DupeStatusPara:SetTitle("Status: SCANNING ⚡")
        DupeStatusPara:SetDesc(mode.." — scanning ReplicatedStorage...")
    end
    dupeLog("["..mode.."] Started — "..os.date("%H:%M:%S"), "▶")

    local remotes = {}
    for _, r in pairs(ReplicatedStorage:GetDescendants()) do
        if (r:IsA("RemoteEvent") or r:IsA("RemoteFunction")) and not bl[r.Name] then
            remotes[#remotes+1] = r
        end
    end
    dupeLog("Found "..#remotes.." remotes to test.", "»")

    local checked = 0
    for _, remote in ipairs(remotes) do
        task.spawn(function()
            local oldVal = getStatsValue()
            local tests  = { {val} }
            for _, k in ipairs(keys) do
                tests[#tests+1] = {k, val}
                tests[#tests+1] = {val, k}
            end

            local found = false
            for _, args in ipairs(tests) do
                fireRemote(remote, args)
                task.wait(Config.fireDelay)
                if getStatsValue() > oldVal then
                    if not detectedRemotes[remote.Name] then
                        detectedRemotes[remote.Name] = true
                        verifiedList[#verifiedList+1] = {
                            name   = remote.Name,
                            remote = remote,
                            args   = args,
                        }
                        dupeLog("✔ SUCCESS: "..remote.Name, "✔")
                        Window:Noti({
                            Title    = "Dupe Found!",
                            Content  = remote.Name,
                            Duration = 4,
                        })
                    end
                    found = true
                    break
                end
            end

            if not found then
                dupeLog("✘ Miss: "..remote.Name, "✘")
            end

            checked = checked + 1
            if checked >= #remotes then
                scanRunning = false
                if DupeStatusPara then
                    DupeStatusPara:SetTitle("Status: DONE ✅")
                    DupeStatusPara:SetDesc(
                        "Scan complete — "..#verifiedList.." dupe(s) found."
                    )
                end
                dupeLog("Scan complete. "..#verifiedList.." verified.", "✅")
            end
        end)
        -- Sequential mode: wait between spawns
        if mode == "Normal Fire" then task.wait(0.08) end
    end
end

-- ════════════════════════════════════════════════════════════
--  TAB 1 — DUPE  UI
-- ════════════════════════════════════════════════════════════

-- Status paragraph (updated by scan)
DupeStatusPara = DupeTab:Paragraph({
    Title = "Status: IDLE ⏸",
    Desc  = "Press Normal Fire or All Fire to begin scanning.",
    Color = "Blue",
})

DupeTab:Divider()

-- Amount input
DupeTab:Input({
    Title       = "Amount",
    Desc        = "Value to fire at remotes (default 999999)",
    Icon        = "hash",
    Placeholder = "e.g. 999999",
    Value       = tostring(Config.amount),
    Callback    = function(val)
        Config.amount = tonumber(val) or 999999
    end,
})

-- Custom Keywords input
DupeTab:Input({
    Title       = "Custom Keywords",
    Desc        = "Extra keywords to test (comma-separated)",
    Icon        = "tag",
    Placeholder = "e.g. Gems, Bucks, Stars",
    Value       = Config.customKeywords,
    Callback    = function(val)
        Config.customKeywords = val
    end,
})

-- Blacklist input
DupeTab:Input({
    Title       = "Blacklist Remotes",
    Desc        = "Skip these remotes (comma-separated)",
    Icon        = "shield-off",
    Placeholder = "e.g. ChatEvent, LogEvent",
    Value       = Config.blacklist,
    Callback    = function(val)
        Config.blacklist = val
    end,
})

-- Fire Delay slider
DupeTab:Slider({
    Title = "Fire Delay",
    Desc  = "Seconds to wait between each fire attempt",
    Icon  = "timer",
    Step  = 0.01,
    Value = {
        Min     = 0.01,
        Max     = 1.0,
        Default = Config.fireDelay,
    },
    Callback = function(val)
        Config.fireDelay = val
    end,
})

DupeTab:Divider()

-- Normal Fire button
DupeTab:Button({
    Title    = "▶  NORMAL FIRE",
    Desc     = "Sequential scan — safe and steady",
    Icon     = "play",
    Callback = function()
        runScan("Normal Fire")
    end,
})

-- All Fire button
DupeTab:Button({
    Title    = "⚡  ALL FIRE",
    Desc     = "Burst scan — fires all remotes simultaneously",
    Icon     = "zap",
    Callback = function()
        runScan("All Fire")
    end,
})

DupeTab:Divider()

-- Re-fire verified
DupeTab:Button({
    Title    = "🔁  Re-Fire All Verified",
    Desc     = "Re-fire every confirmed dupe remote",
    Icon     = "repeat",
    Callback = function()
        if #verifiedList == 0 then
            Window:Noti({ Title = "DYHUB", Content = "No verified dupes yet.", Duration = 2 })
            return
        end
        for _, entry in ipairs(verifiedList) do
            fireRemote(entry.remote, entry.args)
            task.wait(Config.fireDelay)
        end
        Window:Noti({
            Title    = "Re-Fired",
            Content  = "Fired "..#verifiedList.." remote(s).",
            Duration = 3,
        })
    end,
})

-- Copy verified
DupeTab:Button({
    Title    = "📋  Copy All Verified",
    Desc     = "Copy all dupe calls to clipboard",
    Icon     = "clipboard",
    Callback = function()
        if #verifiedList == 0 then
            Window:Noti({ Title = "DYHUB", Content = "No verified dupes.", Duration = 2 })
            return
        end
        local lines = {}
        for _, e in ipairs(verifiedList) do
            local argStr = ""
            for i, v in ipairs(e.args) do
                argStr = argStr..(type(v)=="string" and ('"'..v..'"') or tostring(v))
                if i < #e.args then argStr = argStr..", " end
            end
            local mt = e.remote:IsA("RemoteEvent") and "FireServer" or "InvokeServer"
            lines[#lines+1] = string.format(
                'game:GetService("ReplicatedStorage"):FindFirstChild("%s"):%s(%s)',
                e.name, mt, argStr
            )
        end
        pcall(setclipboard, table.concat(lines, "\n"))
        Window:Noti({ Title = "Copied!", Content = #verifiedList.." entries.", Duration = 3 })
    end,
})

-- Clear results
DupeTab:Button({
    Title    = "🗑  Clear Results",
    Desc     = "Reset all scan data",
    Icon     = "trash-2",
    Callback = function()
        detectedRemotes = {}
        verifiedList    = {}
        dupeLogLines    = {}
        scanRunning     = false
        if DupeStatusPara then
            DupeStatusPara:SetTitle("Status: IDLE ⏸")
            DupeStatusPara:SetDesc("Results cleared. Ready for new scan.")
        end
        if DupeLogPara then DupeLogPara:SetDesc("Log cleared.") end
    end,
})

DupeTab:Divider()

-- Log paragraph (must be created after the function is defined)
DupeLogPara = DupeTab:Paragraph({
    Title = "Activity Log",
    Desc  = "Waiting for scan...",
    Color = "Blue",
})

-- ════════════════════════════════════════════════════════════
--  TAB 2 — GAMEPASS  logic
-- ════════════════════════════════════════════════════════════
local gpIdMap      = {}
local gpAutoLoops  = {}
local gpSuppress   = 0
local gpLogLines   = {}
local GpLogPara    -- assigned below
local GpCountPara  -- assigned below

local function gpLog(msg)
    table.insert(gpLogLines, 1, "["..os.date("%H:%M:%S").."] "..msg)
    if #gpLogLines > 30 then table.remove(gpLogLines) end
    if GpLogPara then
        GpLogPara:SetDesc(table.concat(gpLogLines, "\n"))
    end
    if GpCountPara then
        GpCountPara:SetDesc("Total captured: "..#gpLogLines.." event(s)")
    end
end

local function fireFakeSignal(sigType, id)
    gpSuppress = gpSuppress + 1
    pcall(function()
        if sigType == "Gamepass" then
            MarketplaceService:PromptGamePassPurchase(LocalPlayer, id)
        elseif sigType == "Product" then
            MarketplaceService:PromptProductPurchase(LocalPlayer, id)
        end
    end)
    task.wait(0.05)
    gpSuppress = math.max(0, gpSuppress - 1)
end

local function addGpCapture(sigType, id)
    if gpSuppress > 0 then return end
    local key = tostring(id)
    if not gpIdMap[key] then
        gpIdMap[key] = { type = sigType, id = id }
        gpLog(sigType.." — ID: "..key)
        Window:Noti({
            Title    = "Captured!",
            Content  = sigType.." ID: "..key,
            Duration = 3,
        })
    end
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(_, id, _)
    addGpCapture("Gamepass", id)
end)
MarketplaceService.PromptProductPurchaseFinished:Connect(function(_, id, _)
    addGpCapture("Product", id)
end)
MarketplaceService.PromptBulkPurchaseFinished:Connect(function(_, id, _)
    addGpCapture("Bulk", id)
end)
MarketplaceService.PromptPurchaseFinished:Connect(function(_, id, _)
    addGpCapture("Purchase", id)
end)

-- ════════════════════════════════════════════════════════════
--  TAB 2 — GAMEPASS  UI
-- ════════════════════════════════════════════════════════════

GpCountPara = GamepassTab:Paragraph({
    Title = "Captured Events",
    Desc  = "Total captured: 0 event(s)",
    Color = "Blue",
})

GamepassTab:Paragraph({
    Title = "How it works",
    Desc  = "Listens to all MarketplaceService signals.\n"
          .."Every captured ID appears in the log below.\n\n"
          .."• Fire Once = fire that ID once\n"
          .."• Auto Loop = keep firing until stopped\n"
          .."• Copy ID   = copy to clipboard",
    Color = "Blue",
})

GamepassTab:Divider()

-- Auto-fire speed slider
GamepassTab:Slider({
    Title = "Auto-fire Speed",
    Desc  = "Fires per second for auto-loop",
    Icon  = "gauge",
    Step  = 1,
    Value = {
        Min     = 1,
        Max     = 200,
        Default = Config.autoSpeed,
    },
    Callback = function(val)
        Config.autoSpeed = val
        -- Update all active loops' delay dynamically (they read Config.autoSpeed)
    end,
})

GamepassTab:Divider()

-- Fire All button
GamepassTab:Button({
    Title    = "🔁  Fire All Captured (Once)",
    Desc     = "Fire every captured ID one time",
    Icon     = "repeat",
    Callback = function()
        local count = 0
        for _, info in pairs(gpIdMap) do
            fireFakeSignal(info.type, info.id)
            count = count + 1
            task.wait(0.05)
        end
        Window:Noti({ Title = "DYHUB", Content = "Fired "..count.." ID(s).", Duration = 3 })
    end,
})

-- Auto Loop All button
GamepassTab:Button({
    Title    = "⚡  Start Auto-Loop ALL",
    Desc     = "Begin auto-firing all captured IDs",
    Icon     = "zap",
    Callback = function()
        local count = 0
        for key, info in pairs(gpIdMap) do
            if not gpAutoLoops[key] then
                gpAutoLoops[key] = task.spawn(function()
                    while gpAutoLoops[key] do
                        fireFakeSignal(info.type, info.id)
                        task.wait(1 / math.max(1, Config.autoSpeed))
                    end
                end)
                count = count + 1
            end
        end
        Window:Noti({ Title = "Auto Loop", Content = "Started "..count.." loop(s).", Duration = 3 })
    end,
})

-- Stop All loops
GamepassTab:Button({
    Title    = "⏹  Stop All Auto-Loops",
    Desc     = "Cancel all running auto-fire loops",
    Icon     = "square",
    Callback = function()
        for key, thread in pairs(gpAutoLoops) do
            pcall(task.cancel, thread)
            gpAutoLoops[key] = nil
        end
        Window:Noti({ Title = "Stopped", Content = "All loops cancelled.", Duration = 2 })
    end,
})

-- Copy All IDs
GamepassTab:Button({
    Title    = "📋  Copy All IDs",
    Desc     = "Copy all captured IDs to clipboard",
    Icon     = "clipboard",
    Callback = function()
        local lines = {}
        for key, info in pairs(gpIdMap) do
            lines[#lines+1] = info.type.." | ID: "..key
        end
        if #lines == 0 then
            Window:Noti({ Title = "DYHUB", Content = "No IDs captured yet.", Duration = 2 })
            return
        end
        pcall(setclipboard, table.concat(lines, "\n"))
        Window:Noti({ Title = "Copied!", Content = #lines.." ID(s) copied.", Duration = 3 })
    end,
})

-- Clear captured
GamepassTab:Button({
    Title    = "🗑  Clear Captured Events",
    Desc     = "Reset all captured gamepass/product data",
    Icon     = "trash-2",
    Callback = function()
        for key, thread in pairs(gpAutoLoops) do
            pcall(task.cancel, thread)
        end
        gpIdMap     = {}
        gpAutoLoops = {}
        gpLogLines  = {}
        if GpLogPara   then GpLogPara:SetDesc("No events captured yet...") end
        if GpCountPara then GpCountPara:SetDesc("Total captured: 0 event(s)") end
    end,
})

GamepassTab:Divider()

GpLogPara = GamepassTab:Paragraph({
    Title = "Event Log",
    Desc  = "No events captured yet...",
    Color = "Blue",
})

-- ════════════════════════════════════════════════════════════
--  TAB 3 — SETTINGS  logic
-- ════════════════════════════════════════════════════════════
local antiAfkConn = nil

local function setAntiAfk(on)
    if antiAfkConn then
        antiAfkConn:Disconnect()
        antiAfkConn = nil
    end
    if on then
        antiAfkConn = LocalPlayer.Idled:Connect(function()
            local vim = game:GetService("VirtualInputManager")
            vim:SendKeyEvent(true,  Enum.KeyCode.W, false, game)
            task.wait(0.1)
            vim:SendKeyEvent(false, Enum.KeyCode.W, false, game)
        end)
    end
end

if Config.antiAfk then setAntiAfk(true) end

-- ════════════════════════════════════════════════════════════
--  TAB 3 — SETTINGS  UI
-- ════════════════════════════════════════════════════════════

-- ── Anti-AFK ─────────────────────────────────────────────────
SettingsTab:Toggle({
    Title = "Anti-AFK",
    Desc  = "Prevents idle-kick disconnect",
    Icon  = "shield-check",
    Type  = "Checkbox",
    Value = Config.antiAfk,
    Callback = function(state)
        Config.antiAfk = state
        setAntiAfk(state)
    end,
})

-- ── Notify on Dupe Success ────────────────────────────────────
SettingsTab:Toggle({
    Title = "Notify on Dupe Found",
    Desc  = "Show a popup when a dupe remote is detected",
    Icon  = "bell",
    Type  = "Checkbox",
    Value = Config.notifySuccess,
    Callback = function(state)
        Config.notifySuccess = state
    end,
})

-- ── Auto-Rejoin ───────────────────────────────────────────────
SettingsTab:Toggle({
    Title = "Auto-Rejoin on Kick",
    Desc  = "Automatically rejoin if kicked or disconnected",
    Icon  = "refresh-cw",
    Type  = "Checkbox",
    Value = Config.autoRejoin,
    Callback = function(state)
        Config.autoRejoin = state
        if state then
            LocalPlayer.OnTeleport:Connect(function(tpState)
                if tpState == Enum.TeleportState.Failed then
                    pcall(function()
                        game:GetService("TeleportService"):Teleport(game.PlaceId, LocalPlayer)
                    end)
                end
            end)
        end
    end,
})

SettingsTab:Divider()

-- ── Global Fire Delay slider ──────────────────────────────────
SettingsTab:Slider({
    Title = "Global Fire Delay",
    Desc  = "Seconds between each remote fire attempt",
    Icon  = "timer",
    Step  = 0.01,
    Value = {
        Min     = 0.01,
        Max     = 2.0,
        Default = Config.fireDelay,
    },
    Callback = function(val)
        Config.fireDelay = val
    end,
})

SettingsTab:Divider()

-- ── Save Config ───────────────────────────────────────────────
SettingsTab:Button({
    Title    = "💾  Save Config",
    Desc     = "Write current settings to DYHUB_config.json",
    Icon     = "save",
    Callback = function()
        saveConfig()
        Window:Noti({
            Title    = "Saved",
            Content  = "Config saved to "..CONFIG_PATH,
            Duration = 3,
        })
    end,
})

-- ── Reload Config ─────────────────────────────────────────────
SettingsTab:Button({
    Title    = "📂  Reload Config",
    Desc     = "Load settings from DYHUB_config.json",
    Icon     = "folder-open",
    Callback = function()
        loadConfig()
        Window:Noti({
            Title    = "Loaded",
            Content  = "Config reloaded from "..CONFIG_PATH,
            Duration = 3,
        })
    end,
})

-- ── Reset Defaults ────────────────────────────────────────────
SettingsTab:Button({
    Title    = "🗑  Reset to Defaults",
    Desc     = "Wipe config and restore default values",
    Icon     = "rotate-ccw",
    Callback = function()
        Config.amount         = 999999
        Config.customKeywords = ""
        Config.blacklist      = ""
        Config.fireDelay      = 0.05
        Config.autoSpeed      = 50
        Config.antiAfk        = true
        Config.autoRejoin     = false
        Config.notifySuccess  = true
        saveConfig()
        Window:Noti({ Title = "Reset", Content = "Config reset to defaults.", Duration = 3 })
    end,
})

SettingsTab:Divider()

-- ── About ─────────────────────────────────────────────────────
SettingsTab:Paragraph({
    Title = "DYHUB PRO v2.0",
    Desc  = "Author   : DYHUB\n"
          .."Price    : 500 THB\n"
          .."UI Lib   : WindUI (github.com/Footagesus/WindUI)\n"
          .."─────────────────────────────────\n"
          .."Toggle GUI  :  RightShift\n"
          .."─────────────────────────────────\n"
          .."Unauthorized redistribution is prohibited.\n"
          .."Contact DYHUB for support & updates.",
    Color = "Blue",
})

-- ════════════════════════════════════════════════════════════
--  READY
-- ════════════════════════════════════════════════════════════
dupeLog("DYHUB PRO v2.0 ready — keywords: "..#buildKeywords(), "✅")

Window:Noti({
    Title    = "DYHUB PRO v2.0",
    Content  = "Loaded successfully! Press RightShift to toggle.",
    Duration = 5,
})
