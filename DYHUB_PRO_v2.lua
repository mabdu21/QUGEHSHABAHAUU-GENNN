--[[
    ██████╗ ██╗   ██╗██╗  ██╗██╗   ██╗██████╗     ██████╗ ██████╗  ██████╗ 
    ██╔══██╗╚██╗ ██╔╝██║  ██║██║   ██║██╔══██╗    ██╔══██╗██╔══██╗██╔═══██╗
    ██║  ██║ ╚████╔╝ ███████║██║   ██║██████╔╝    ██████╔╝██████╔╝██║   ██║
    ██║  ██║  ╚██╔╝  ██╔══██║██║   ██║██╔══██╗    ██╔═══╝ ██╔══██╗██║   ██║
    ██████╔╝   ██║   ██║  ██║╚██████╔╝██████╔╝    ██║     ██║  ██║╚██████╔╝
    ╚═════╝    ╚═╝   ╚═╝  ╚═╝ ╚═════╝ ╚═════╝     ╚═╝     ╚═╝  ╚═╝ ╚═════╝ 

    DYHUB PRO v2.1
    Author   : DYHUB
    Price    : 500 THB
    Tabs     : DUPE | GAMEPASS | SETTINGS
    WindUI   : https://github.com/Footagesus/WindUI
--]]

-- ╔══════════════════════════════════════════════════════╗
-- ║                   SERVICES                          ║
-- ╚══════════════════════════════════════════════════════╝
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local MarketplaceService= game:GetService("MarketplaceService")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")
local LocalPlayer       = Players.LocalPlayer

-- ╔══════════════════════════════════════════════════════╗
-- ║               EXECUTOR COMPAT                       ║
-- ╚══════════════════════════════════════════════════════╝
local setclipboard = setclipboard or (function(t) print("[DYHUB] Clipboard: " .. tostring(t)) end)
local writefile    = writefile    or (function(p, d) print("[DYHUB] writefile not supported") end)
local readfile     = readfile     or (function(p) return nil end)
local isfile       = isfile       or (function(p) return false end)

-- ╔══════════════════════════════════════════════════════╗
-- ║                   CONFIG                            ║
-- ╚══════════════════════════════════════════════════════╝
local CONFIG_PATH = "DYHUB_config.json"

local Config = {
    -- DUPE tab
    fireDelay        = 0.05,
    defaultKeywords  = {"Money","Cash","Coin","Currency","Point","Gem","Diamond","Gold","Strength","Power","Candy"},
    customKeywords   = "",
    blacklist        = "",
    amount           = "999999",
    -- GAMEPASS tab
    autoSpeed        = 50,
    -- SETTINGS tab
    antiAfk          = true,
    autoRejoin       = false,
    hideOnStart      = false,
    toggleKey        = "RightShift",
    notifyOnSuccess  = true,
}

-- Save/Load config
local function saveConfig()
    local ok, encoded = pcall(function()
        -- Simple JSON serialiser (no external deps)
        local parts = {}
        for k, v in pairs(Config) do
            local vStr
            if type(v) == "string" then
                vStr = '"' .. v:gsub('"', '\\"') .. '"'
            elseif type(v) == "boolean" then
                vStr = tostring(v)
            elseif type(v) == "number" then
                vStr = tostring(v)
            elseif type(v) == "table" then
                local arr = {}
                for _, item in ipairs(v) do
                    table.insert(arr, '"' .. tostring(item) .. '"')
                end
                vStr = "[" .. table.concat(arr, ",") .. "]"
            end
            if vStr then
                table.insert(parts, '"' .. k .. '":' .. vStr)
            end
        end
        return "{" .. table.concat(parts, ",") .. "}"
    end)
    if ok then
        pcall(writefile, CONFIG_PATH, encoded)
    end
end

local function loadConfig()
    if not isfile(CONFIG_PATH) then return end
    local ok, raw = pcall(readfile, CONFIG_PATH)
    if not ok or not raw then return end
    -- Parse booleans & numbers we care about
    for k, v in raw:gmatch('"([^"]+)":(%S+)') do
        if Config[k] ~= nil then
            if v == "true" then Config[k] = true
            elseif v == "false" then Config[k] = false
            else
                local n = tonumber(v)
                if n then Config[k] = n end
            end
        end
    end
    -- Parse strings
    for k, v in raw:gmatch('"([^"]+)":"([^"]*)"') do
        if Config[k] ~= nil then Config[k] = v end
    end
end

loadConfig()

-- ╔══════════════════════════════════════════════════════╗
-- ║              WINDUI LOADER                          ║
-- ╚══════════════════════════════════════════════════════╝
local WindUI
local ok, err = pcall(function()
    WindUI = loadstring(game:HttpGet(
        "https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"
    ))()
end)

if not ok or not WindUI then
    -- Fallback notice
    local sg = Instance.new("ScreenGui")
    sg.Name = "DYHUB_ERROR"
    sg.ResetOnSpawn = false
    sg.Parent = (RunService:IsStudio() and LocalPlayer:WaitForChild("PlayerGui")) or game:GetService("CoreGui")
    local lbl = Instance.new("TextLabel", sg)
    lbl.Size = UDim2.new(0.6, 0, 0, 60)
    lbl.Position = UDim2.new(0.2, 0, 0.45, 0)
    lbl.BackgroundColor3 = Color3.fromRGB(15, 15, 17)
    lbl.TextColor3 = Color3.fromRGB(255, 80, 80)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 16
    lbl.Text = "DYHUB PRO: WindUI failed to load.\nCheck HttpService / internet access."
    Instance.new("UICorner", lbl).CornerRadius = UDim.new(0, 10)
    return
end

-- ╔══════════════════════════════════════════════════════╗
-- ║              DUPE CORE LOGIC                        ║
-- ╚══════════════════════════════════════════════════════╝
local detectedRemotes = {}

local function getStatsValue()
    local total = 0
    local stats = LocalPlayer:FindFirstChild("leaderstats")
    if stats then
        for _, v in pairs(stats:GetChildren()) do
            if v:IsA("NumberValue") or v:IsA("IntValue") or v:IsA("StringValue") then
                local n = tonumber(v.Value)
                if n then total = total + n end
            end
        end
    end
    return total
end

local function getAllKeywords(customText)
    local keys = {}
    local seen = {}
    for _, k in ipairs(Config.defaultKeywords) do
        if not seen[k] then seen[k]=true; table.insert(keys, k) end
    end
    local stats = LocalPlayer:FindFirstChild("leaderstats")
    if stats then
        for _, s in pairs(stats:GetChildren()) do
            if not seen[s.Name] then seen[s.Name]=true; table.insert(keys, s.Name) end
        end
    end
    local src = customText or Config.customKeywords
    for word in src:gmatch("([^,%s]+)") do
        if not seen[word] then seen[word]=true; table.insert(keys, word) end
    end
    return keys
end

-- ╔══════════════════════════════════════════════════════╗
-- ║               WINDOW SETUP                         ║
-- ╚══════════════════════════════════════════════════════╝
local Window = WindUI:CreateWindow({
    Title    = "DYHUB PRO",
    SubTitle = "v2.0 — by DYHUB",
    TabWidth = 160,
    Size     = UDim2.fromOffset(580, 460),
    Resizable= true,
    Icon     = "rbxassetid://7072706620",
    Folder   = "DYHUB",
    Theme    = "Dark",
    HasCloseButton = true,
})

Window:Noti({
    Title   = "DYHUB PRO v2.0",
    Content = "Script loaded successfully!",
    Duration = 4,
})

-- ╔══════════════════════════════════════════════════════╗
-- ║                  TAB 1 — DUPE                       ║
-- ╚══════════════════════════════════════════════════════╝
local DupeTab = Window:Tab({ Title = "DUPE", Icon = "rbxassetid://7072718544" })

-- Verified dupes storage (for display)
local verifiedDupes = {}

-- ── Scan Config Section ──────────────────────────────
DupeTab:Section({ Title = "Scan Configuration" })

local AmountInput = DupeTab:Input({
    Title       = "Amount to Fire",
    Placeholder = "e.g. 999999",
    Default     = Config.amount,
    Callback    = function(val)
        Config.amount = val
    end,
})

local CustomKWInput = DupeTab:Input({
    Title       = "Custom Keywords (comma-separated)",
    Placeholder = "e.g. Gems, Bucks, Stars",
    Default     = Config.customKeywords,
    Callback    = function(val)
        Config.customKeywords = val
    end,
})

local BlacklistInput = DupeTab:Input({
    Title       = "Blacklist Remotes (comma-separated)",
    Placeholder = "e.g. ChatEvent, LogEvent",
    Default     = Config.blacklist,
    Callback    = function(val)
        Config.blacklist = val
    end,
})

local DelaySlider = DupeTab:Slider({
    Title   = "Fire Delay (seconds)",
    Min     = 0.01,
    Max     = 1,
    Default = Config.fireDelay,
    Decimals= 2,
    Callback= function(val)
        Config.fireDelay = val
    end,
})

-- ── Scan Actions ─────────────────────────────────────
DupeTab:Section({ Title = "Scan & Fire" })

local logCallback  -- will be assigned after log section

local function buildBlacklist()
    local bl = {}
    for n in Config.blacklist:gmatch("([^,%s]+)") do bl[n] = true end
    return bl
end

local function doFire(remote, args)
    pcall(function()
        if remote:IsA("RemoteEvent") then
            remote:FireServer(table.unpack(args))
        elseif remote:IsA("RemoteFunction") then
            remote:InvokeServer(table.unpack(args))
        end
    end)
end

local function runScan(mode)
    local val     = tonumber(Config.amount) or 999999
    local keys    = getAllKeywords(Config.customKeywords)
    local bl      = buildBlacklist()

    if logCallback then logCallback("[" .. mode .. "] Scan started — " .. os.date("%H:%M:%S"), "Info") end

    for _, remote in pairs(ReplicatedStorage:GetDescendants()) do
        if (remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction")) and not bl[remote.Name] then
            task.spawn(function()
                local oldVal  = getStatsValue()
                local tests   = { {val} }
                for _, k in ipairs(keys) do
                    table.insert(tests, {k, val})
                    table.insert(tests, {val, k})
                end

                local found = false
                for _, args in ipairs(tests) do
                    doFire(remote, args)
                    task.wait(Config.fireDelay)

                    if getStatsValue() > oldVal then
                        if not detectedRemotes[remote.Name] then
                            detectedRemotes[remote.Name] = { remote = remote, args = args }
                            table.insert(verifiedDupes, { name = remote.Name, remote = remote, args = args })
                        end
                        if logCallback then logCallback("✔ SUCCESS: " .. remote.Name, "Success") end
                        if Config.notifyOnSuccess then
                            Window:Noti({
                                Title   = "Dupe Found!",
                                Content = remote.Name,
                                Duration = 3,
                            })
                        end
                        found = true
                        break
                    end
                end

                if not found then
                    if logCallback then logCallback("✘ Miss: " .. remote.Name, "Error") end
                end
            end)
            if mode == "Normal Fire" then task.wait(0.08) end
        end
    end
end

DupeTab:Button({
    Title   = "▶  NORMAL FIRE  (Sequential)",
    Callback= function()
        runScan("Normal Fire")
    end,
})

DupeTab:Button({
    Title   = "⚡  ALL FIRE  (Burst)",
    Callback= function()
        runScan("All Fire")
    end,
})

DupeTab:Button({
    Title   = "🗑  Clear Results",
    Callback= function()
        detectedRemotes = {}
        verifiedDupes   = {}
        if logCallback then logCallback("Results cleared.", "Warn") end
    end,
})

-- ── Verified Dupes ───────────────────────────────────
DupeTab:Section({ Title = "Verified Dupes" })

DupeTab:Button({
    Title   = "🔁  Re-Fire All Verified Dupes",
    Callback= function()
        if #verifiedDupes == 0 then
            Window:Noti({ Title = "DYHUB", Content = "No verified dupes yet.", Duration = 2 })
            return
        end
        for _, entry in ipairs(verifiedDupes) do
            pcall(doFire, entry.remote, entry.args)
            task.wait(Config.fireDelay)
        end
        Window:Noti({ Title = "DYHUB", Content = "Re-fired " .. #verifiedDupes .. " remote(s).", Duration = 3 })
    end,
})

DupeTab:Button({
    Title   = "📋  Copy All Verified to Clipboard",
    Callback= function()
        if #verifiedDupes == 0 then
            Window:Noti({ Title = "DYHUB", Content = "No verified dupes.", Duration = 2 })
            return
        end
        local lines = {}
        for _, entry in ipairs(verifiedDupes) do
            local argStr = ""
            for i, v in ipairs(entry.args) do
                argStr = argStr .. (type(v) == "string" and ('"'..v..'"') or tostring(v))
                if i < #entry.args then argStr = argStr .. ", " end
            end
            local rType = entry.remote:IsA("RemoteEvent") and "FireServer" or "InvokeServer"
            table.insert(lines,
                string.format('game:GetService("ReplicatedStorage"):FindFirstChild("%s"):%s(%s)',
                entry.name, rType, argStr)
            )
        end
        pcall(setclipboard, table.concat(lines, "\n"))
        Window:Noti({ Title = "Copied!", Content = #verifiedDupes .. " entries copied.", Duration = 3 })
    end,
})

-- ── Activity Log ─────────────────────────────────────
DupeTab:Section({ Title = "Activity Log" })

local LogParagraph = DupeTab:Paragraph({
    Title  = "Log Output",
    Content= "Waiting for scan...",
})

local logLines = {}
logCallback = function(msg, kind)
    local prefix = kind == "Success" and "✔ " or kind == "Error" and "✘ " or kind == "Warn" and "⚠ " or "» "
    table.insert(logLines, 1, prefix .. msg)
    if #logLines > 18 then table.remove(logLines) end
    LogParagraph:Set({ Title = "Log Output", Content = table.concat(logLines, "\n") })
end

-- ╔══════════════════════════════════════════════════════╗
-- ║               TAB 2 — GAMEPASS                      ║
-- ╚══════════════════════════════════════════════════════╝
local GPTab = Window:Tab({ Title = "GAMEPASS", Icon = "rbxassetid://7072725342" })

GPTab:Section({ Title = "MarketplaceService Listener" })

GPTab:Paragraph({
    Title   = "How it works",
    Content = "This tab monitors all MarketplaceService purchase signals in real-time.\n"
           .. "Each captured event is listed below with its ID.\n"
           .. "• Run  = fire once\n"
           .. "• Auto = toggle auto-fire loop\n"
           .. "• Copy = copy ID to clipboard",
})

local gpLogLines = {}
local gpLogParagraph = GPTab:Paragraph({
    Title  = "Captured Events",
    Content= "No events captured yet...",
})

local gpAutoLoops = {}  -- id → thread
local gpAutoStates = {} -- id → bool

local function gpLog(msg)
    table.insert(gpLogLines, 1, msg)
    if #gpLogLines > 30 then table.remove(gpLogLines) end
    gpLogParagraph:Set({ Title = "Captured Events (" .. #gpLogLines .. ")", Content = table.concat(gpLogLines, "\n") })
end

local gpIdMap    = {}
local gpSuppress = 0

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

GPTab:Section({ Title = "Controls" })

local autoSpeedSlider = GPTab:Slider({
    Title   = "Auto-fire speed (fires/sec)",
    Min     = 1,
    Max     = 200,
    Default = Config.autoSpeed,
    Decimals= 0,
    Callback= function(val)
        Config.autoSpeed = val
    end,
})

GPTab:Button({
    Title   = "🔁  Fire All Captured IDs (once)",
    Callback= function()
        local count = 0
        for id, info in pairs(gpIdMap) do
            fireFakeSignal(info.type, id)
            count = count + 1
            task.wait(0.05)
        end
        Window:Noti({ Title = "DYHUB", Content = "Fired " .. count .. " ID(s).", Duration = 3 })
    end,
})

GPTab:Button({
    Title   = "⏹  Stop All Auto-loops",
    Callback= function()
        for id, thread in pairs(gpAutoLoops) do
            pcall(task.cancel, thread)
        end
        gpAutoLoops   = {}
        gpAutoStates  = {}
        Window:Noti({ Title = "DYHUB", Content = "All auto-loops stopped.", Duration = 2 })
    end,
})

GPTab:Button({
    Title   = "🗑  Clear Captured Events",
    Callback= function()
        gpIdMap    = {}
        gpLogLines = {}
        for id, thread in pairs(gpAutoLoops) do pcall(task.cancel, thread) end
        gpAutoLoops   = {}
        gpAutoStates  = {}
        gpLogParagraph:Set({ Title = "Captured Events", Content = "No events captured yet..." })
    end,
})

-- MarketplaceService hooks
local function addGpEvent(sigType, id)
    if gpSuppress > 0 then return end
    local key = tostring(id)
    if not gpIdMap[key] then
        gpIdMap[key] = { type = sigType, id = id }
        gpLog(string.format("[%s] ID: %s — %s", os.date("%H:%M:%S"), key, sigType))
        Window:Noti({
            Title   = "GP Captured",
            Content = sigType .. " ID: " .. key,
            Duration = 3,
        })
    end
end

MarketplaceService.PromptProductPurchaseFinished:Connect(function(_, id, _)
    addGpEvent("Product", id)
end)
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(_, id, _)
    addGpEvent("Gamepass", id)
end)
MarketplaceService.PromptBulkPurchaseFinished:Connect(function(_, id, _)
    addGpEvent("Bulk", id)
end)
MarketplaceService.PromptPurchaseFinished:Connect(function(_, id, _)
    addGpEvent("Purchase", id)
end)

-- ╔══════════════════════════════════════════════════════╗
-- ║               TAB 3 — SETTINGS                      ║
-- ╚══════════════════════════════════════════════════════╝
local SettingsTab = Window:Tab({ Title = "SETTINGS", Icon = "rbxassetid://7072706620" })

-- ── Anti-AFK ─────────────────────────────────────────
SettingsTab:Section({ Title = "Anti-AFK" })

local afkThread = nil
local function startAntiAfk()
    if afkThread then pcall(task.cancel, afkThread) end
    afkThread = task.spawn(function()
        local VirtualUser = game:GetService("VirtualUser")
        while Config.antiAfk do
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
            task.wait(60)
        end
    end)
end
local function stopAntiAfk()
    if afkThread then
        pcall(task.cancel, afkThread)
        afkThread = nil
    end
end

SettingsTab:Toggle({
    Title   = "Anti-AFK",
    Default = Config.antiAfk,
    Callback= function(val)
        Config.antiAfk = val
        if val then startAntiAfk() else stopAntiAfk() end
    end,
})

if Config.antiAfk then startAntiAfk() end

-- ── General ──────────────────────────────────────────
SettingsTab:Section({ Title = "General" })

SettingsTab:Toggle({
    Title   = "Notify on Dupe Success",
    Default = Config.notifyOnSuccess,
    Callback= function(val)
        Config.notifyOnSuccess = val
    end,
})

SettingsTab:Toggle({
    Title   = "Auto-Rejoin on Kick/Disconnect",
    Default = Config.autoRejoin,
    Callback= function(val)
        Config.autoRejoin = val
        if val then
            game:GetService("Players").LocalPlayer.OnTeleport:Connect(function(state)
                if state == Enum.TeleportState.Failed then
                    game:GetService("TeleportService"):Teleport(game.PlaceId, LocalPlayer)
                end
            end)
        end
    end,
})

SettingsTab:Toggle({
    Title   = "Hide GUI on Start",
    Default = Config.hideOnStart,
    Callback= function(val)
        Config.hideOnStart = val
    end,
})

-- ── Keybind ──────────────────────────────────────────
SettingsTab:Section({ Title = "Keybind" })

SettingsTab:Keybind({
    Title   = "Toggle GUI Visibility",
    Mode    = "Toggle",
    Default = Config.toggleKey,
    Callback= function(key)
        Config.toggleKey = key
    end,
})

-- ── Performance ──────────────────────────────────────
SettingsTab:Section({ Title = "Performance" })

SettingsTab:Slider({
    Title   = "Global Fire Delay (seconds)",
    Min     = 0.01,
    Max     = 2,
    Default = Config.fireDelay,
    Decimals= 2,
    Callback= function(val)
        Config.fireDelay = val
    end,
})

-- ── Save / Load Config ───────────────────────────────
SettingsTab:Section({ Title = "Configuration" })

SettingsTab:Button({
    Title   = "💾  Save Config",
    Callback= function()
        saveConfig()
        Window:Noti({
            Title   = "Config Saved",
            Content = "Settings saved to " .. CONFIG_PATH,
            Duration = 3,
        })
    end,
})

SettingsTab:Button({
    Title   = "📂  Reload Config",
    Callback= function()
        loadConfig()
        Window:Noti({
            Title   = "Config Loaded",
            Content = "Settings reloaded from " .. CONFIG_PATH,
            Duration = 3,
        })
    end,
})

SettingsTab:Button({
    Title   = "🗑  Reset to Defaults",
    Callback= function()
        Config.fireDelay       = 0.05
        Config.customKeywords  = ""
        Config.blacklist       = ""
        Config.amount          = "999999"
        Config.autoSpeed       = 50
        Config.antiAfk         = true
        Config.autoRejoin      = false
        Config.hideOnStart     = false
        Config.notifyOnSuccess = true
        saveConfig()
        Window:Noti({
            Title   = "Reset",
            Content = "Config reset to defaults.",
            Duration = 3,
        })
    end,
})

-- ── About ────────────────────────────────────────────
SettingsTab:Section({ Title = "About" })

SettingsTab:Paragraph({
    Title  = "DYHUB PRO v2.0",
    Content= "Author  : DYHUB\n"
          .. "Price   : 500 THB\n"
          .. "Version : 2.0\n"
          .. "UI Lib  : WindUI (github.com/Footagesus/WindUI)\n"
          .. "─────────────────────────────────\n"
          .. "Unauthorized redistribution is prohibited.\n"
          .. "Contact DYHUB for support.",
})

-- ╔══════════════════════════════════════════════════════╗
-- ║            HIDE ON START (if enabled)               ║
-- ╚══════════════════════════════════════════════════════╝
if Config.hideOnStart then
    -- WindUI window starts visible; toggle after a tick
    task.wait(0.1)
    -- Wind doesn't expose a direct hide API, but we can
    -- find the ScreenGui and toggle visibility
    local sg = game:GetService("CoreGui"):FindFirstChild("WindUI")
    if sg then sg.Enabled = false end
end

-- ╔══════════════════════════════════════════════════════╗
-- ║            LOAD COMPLETE NOTIFICATION               ║
-- ╚══════════════════════════════════════════════════════╝
logCallback("DYHUB PRO v2.0 — Ready to scan.", "Success")
logCallback("Keywords loaded: " .. #getAllKeywords() .. " total.", "Info")
