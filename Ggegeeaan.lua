-- 5252
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local setclipboard = setclipboard or print -- รองรับ Executor ส่วนใหญ่

-- --- [ CONFIGURATION ] ---
local defaultKeywords = {"Money", "Cash", "Coin", "Currency", "Point", "Gem", "Diamond", "Gold", "Strength", "Power", "Candy"}
local fireDelay = 0.05 
local detectedRemotes = {}

-- --- [ UI THEME COLORS ] ---
local BG_COLOR = Color3.fromRGB(18, 18, 20)
local SECONDARY_COLOR = Color3.fromRGB(30, 30, 33)
local ACCENT_COLOR = Color3.fromRGB(80, 80, 85)
local SUCCESS_COLOR = Color3.fromRGB(0, 255, 150)
local FAIL_COLOR = Color3.fromRGB(255, 80, 80)
local TEXT_COLOR = Color3.fromRGB(240, 240, 240)

-- --- [ UI CREATION ] ---
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "DYHUB_DUPER"
ScreenGui.Parent = (RunService:IsStudio() and LocalPlayer:WaitForChild("PlayerGui")) or game:GetService("CoreGui")
ScreenGui.ResetOnSpawn = false

-- Toggle Button (Top Left)
local OpenCloseBtn = Instance.new("TextButton", ScreenGui)
OpenCloseBtn.Size = UDim2.new(0, 120, 0, 35)
OpenCloseBtn.Position = UDim2.new(0, 15, 0, 15)
OpenCloseBtn.BackgroundColor3 = BG_COLOR
OpenCloseBtn.Text = "DYHUB"
OpenCloseBtn.TextColor3 = TEXT_COLOR
OpenCloseBtn.Font = Enum.Font.GothamBold
local BtnCorner = Instance.new("UICorner", OpenCloseBtn)
local BtnStroke = Instance.new("UIStroke", OpenCloseBtn)
BtnStroke.Color = ACCENT_COLOR

-- Main Window
local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 400, 0, 550)
MainFrame.Position = UDim2.new(0.5, -200, 0.5, -275)
MainFrame.BackgroundColor3 = BG_COLOR
MainFrame.BorderSizePixel = 0
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 12)
local MainStroke = Instance.new("UIStroke", MainFrame)
MainStroke.Thickness = 1.5; MainStroke.Color = ACCENT_COLOR

-- Header
local Header = Instance.new("Frame", MainFrame)
Header.Size = UDim2.new(1, 0, 0, 50); Header.BackgroundTransparency = 1
local Title = Instance.new("TextLabel", Header)
Title.Size = UDim2.new(1, -20, 1, 0); Title.Position = UDim2.new(0, 20, 0, 0)
Title.Text = "DYHUB GEN V1"; Title.TextColor3 = TEXT_COLOR
Title.Font = Enum.Font.GothamBold; Title.TextSize = 20; Title.TextXAlignment = "Left"; Title.BackgroundTransparency = 1

-- --- [ SUCCESS LOG PANEL ] ---
local SuccessPanel = Instance.new("Frame", MainFrame)
SuccessPanel.Size = UDim2.new(0, 250, 0, 550)
SuccessPanel.Position = UDim2.new(1, 15, 0, 0)
SuccessPanel.BackgroundColor3 = BG_COLOR
Instance.new("UICorner", SuccessPanel)
Instance.new("UIStroke", SuccessPanel).Color = SUCCESS_COLOR

local STitle = Instance.new("TextLabel", SuccessPanel)
STitle.Size = UDim2.new(1, 0, 0, 45); STitle.Text = "VERIFIED DUPES"; STitle.TextColor3 = SUCCESS_COLOR
STitle.Font = Enum.Font.GothamBold; STitle.BackgroundTransparency = 1

local SuccessScroll = Instance.new("ScrollingFrame", SuccessPanel)
SuccessScroll.Size = UDim2.new(0.9, 0, 0.88, 0); SuccessScroll.Position = UDim2.new(0.05, 0, 0.1, 0)
SuccessScroll.BackgroundTransparency = 1; SuccessScroll.ScrollBarThickness = 1
local SuccessLayout = Instance.new("UIListLayout", SuccessScroll); SuccessLayout.Padding = UDim.new(0, 6)

-- --- [ INPUT BOXES (TEXT = "") ] ---
local function createInput(placeholder, pos, sizeX)
    local tb = Instance.new("TextBox", MainFrame)
    tb.Size = UDim2.new(sizeX, 0, 0, 35); tb.Position = pos
    tb.BackgroundColor3 = SECONDARY_COLOR; tb.PlaceholderText = placeholder
    tb.Text = ""; tb.TextColor3 = TEXT_COLOR; tb.Font = Enum.Font.Gotham; tb.TextSize = 12
    Instance.new("UICorner", tb)
    return tb
end

local BlacklistInput = createInput("Blacklist Remotes (Comma separated)", UDim2.new(0.05, 0, 0.1, 0), 0.9)
local AmountInput = createInput("Amount", UDim2.new(0.05, 0, 0.18, 0), 0.43)
local CustomKeywordsInput = createInput("Target Keywords", UDim2.new(0.52, 0, 0.18, 0), 0.43)

-- Log Window
local LogFrame = Instance.new("ScrollingFrame", MainFrame)
LogFrame.Size = UDim2.new(0.9, 0, 0.35, 0); LogFrame.Position = UDim2.new(0.05, 0, 0.27, 0)
LogFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 17); LogFrame.ScrollBarThickness = 1
Instance.new("UICorner", LogFrame)
local LogLayout = Instance.new("UIListLayout", LogFrame); LogLayout.Padding = UDim.new(0, 2)

-- --- [ CORE FUNCTIONS ] ---

local function getStatsValue()
    local total = 0
    local stats = LocalPlayer:FindFirstChild("leaderstats")
    if stats then
        for _, v in pairs(stats:GetChildren()) do
            if v:IsA("NumberValue") or v:IsA("IntValue") then total = total + v.Value end
        end
    end
    return total
end

local function addLog(text, color)
    local l = Instance.new("TextLabel", LogFrame)
    l.Size = UDim2.new(1, -10, 0, 20); l.BackgroundTransparency = 1
    l.Text = "  " .. text; l.TextColor3 = color; l.TextSize = 11; l.Font = Enum.Font.Code; l.TextXAlignment = "Left"
    LogFrame.CanvasSize = UDim2.new(0, 0, 0, LogLayout.AbsoluteContentSize.Y)
    LogFrame.CanvasPosition = Vector2.new(0, LogLayout.AbsoluteContentSize.Y)
end

local function addToSuccessList(remote, lastArgs)
    if detectedRemotes[remote.Name] then return end
    detectedRemotes[remote.Name] = true
    
    local Item = Instance.new("Frame", SuccessScroll)
    Item.Size = UDim2.new(1, 0, 0, 45); Item.BackgroundColor3 = SECONDARY_COLOR
    Instance.new("UICorner", Item)
    
    local Name = Instance.new("TextLabel", Item)
    Name.Size = UDim2.new(0.5, 0, 1, 0); Name.Position = UDim2.new(0.05, 0, 0, 0)
    Name.Text = remote.Name; Name.TextColor3 = SUCCESS_COLOR; Name.BackgroundTransparency = 1; Name.TextSize = 10; Name.TextXAlignment = "Left"
    
    -- EXE Button
    local Exe = Instance.new("TextButton", Item)
    Exe.Size = UDim2.new(0.2, 0, 0.6, 0); Exe.Position = UDim2.new(0.55, 0, 0.2, 0)
    Exe.BackgroundColor3 = Color3.fromRGB(50, 50, 55); Exe.Text = "EXE"; Exe.TextColor3 = Color3.fromRGB(255, 255, 255)
    Instance.new("UICorner", Exe)
    
    -- COPY Button
    local Copy = Instance.new("TextButton", Item)
    Copy.Size = UDim2.new(0.2, 0, 0.6, 0); Copy.Position = UDim2.new(0.77, 0, 0.2, 0)
    Copy.BackgroundColor3 = Color3.fromRGB(70, 70, 75); Copy.Text = "COPY"; Copy.TextColor3 = Color3.fromRGB(255, 255, 255)
    Instance.new("UICorner", Copy)
    
    local function fire()
        local val = tonumber(AmountInput.Text) or 999999
        pcall(function()
            if remote:IsA("RemoteEvent") then remote:FireServer(unpack(lastArgs)) else remote:InvokeServer(unpack(lastArgs)) end
        end)
    end

    Exe.MouseButton1Click:Connect(fire)
    Copy.MouseButton1Click:Connect(function()
        local path = "game:GetService(\"ReplicatedStorage\")." .. remote.Name
        local argStr = ""
        for i, v in ipairs(lastArgs) do
            argStr = argStr .. (type(v) == "string" and "\""..v.."\"" or tostring(v)) .. (i < #lastArgs and ", " or "")
        end
        local fullCode = string.format("%s:%s(%s)", path, (remote:IsA("RemoteEvent") and "FireServer" or "InvokeServer"), argStr)
        setclipboard(fullCode)
        addLog("Copied to clipboard!", SUCCESS_COLOR)
    end)
    
    SuccessScroll.CanvasSize = UDim2.new(0, 0, 0, SuccessLayout.AbsoluteContentSize.Y)
end

local function getAllKeywords()
    local keys = {}
    for _, k in ipairs(defaultKeywords) do table.insert(keys, k) end
    local stats = LocalPlayer:FindFirstChild("leaderstats")
    if stats then for _, s in pairs(stats:GetChildren()) do table.insert(keys, s.Name) end end
    for word in string.gmatch(CustomKeywordsInput.Text, "([^,%s]+)") do table.insert(keys, word) end
    return keys
end

-- --- [ FIRE MODES ] ---

local function runFire(mode)
    local val = tonumber(AmountInput.Text) or 999999
    local keys = getAllKeywords()
    local blacklist = {}
    for n in string.gmatch(BlacklistInput.Text, "([^,%s]+)") do blacklist[n] = true end
    
    addLog("--- " .. mode .. " STARTED ---", Color3.fromRGB(200, 200, 200))
    
    for _, remote in pairs(ReplicatedStorage:GetDescendants()) do
        if (remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction")) and not blacklist[remote.Name] then
            task.spawn(function()
                local oldVal = getStatsValue()
                local tests = {{val}}
                for _, k in ipairs(keys) do table.insert(tests, {k, val}) end
                
                local successFound = false
                for _, args in ipairs(tests) do
                    pcall(function()
                        if remote:IsA("RemoteEvent") then remote:FireServer(unpack(args)) 
                        else remote:InvokeServer(unpack(args)) end
                    end)
                    task.wait(fireDelay)
                    
                    if getStatsValue() > oldVal then
                        addLog("SUCCESS DETECTED: " .. remote.Name, SUCCESS_COLOR)
                        addToSuccessList(remote, args)
                        successFound = true
                        break
                    end
                end
                
                if not successFound then
                    addLog("NOT SUCCESS: " .. remote.Name, FAIL_COLOR)
                end
            end)
            if mode == "NORMAL FIRE" then task.wait(0.1) end -- หน่วงเวลาสำหรับ Normal Fire
        end
    end
end

-- --- [ MAIN BUTTONS ] ---
local function createMainBtn(text, pos, color, func)
    local btn = Instance.new("TextButton", MainFrame)
    btn.Size = UDim2.new(0.9, 0, 0, 45); btn.Position = pos
    btn.BackgroundColor3 = color; btn.Text = text; btn.TextColor3 = Color3.fromRGB(255, 255, 255); btn.Font = "GothamBold"
    Instance.new("UICorner", btn)
    btn.MouseButton1Click:Connect(func)
    return btn
end

createMainBtn("NORMAL FIRE", UDim2.new(0.05, 0, 0.65, 0), Color3.fromRGB(45, 45, 50), function() runFire("NORMAL FIRE") end)
createMainBtn("ALL FIRE", UDim2.new(0.05, 0, 0.75, 0), Color3.fromRGB(60, 60, 65), function() runFire("ULTRA BURST") end)

-- --- [ DRAG & TOGGLE ] ---
local function makeDraggable(obj, handle)
    local dragging, dragInput, dragStart, startPos
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = input.Position; startPos = obj.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            obj.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)
end
makeDraggable(MainFrame, Header)

OpenCloseBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = not MainFrame.Visible
end)

addLog("DYHUB GEN V1 LOADED", SUCCESS_COLOR)
addLog("Ready to scan...", TEXT_COLOR)
