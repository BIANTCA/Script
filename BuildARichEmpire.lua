local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local LP = Players.LocalPlayer
local fc = loadstring(game:HttpGet("https://pasteblox.com/raw/87b7cj24z3"))()
local gameName = (fc.getGameName and fc.getGameName()) or "Unknown Game"
local safeName = tostring(gameName):gsub("[^%w%-_ ]", ""):gsub("^%s+", ""):gsub("%s+$", "")
if safeName == "" then safeName = "Default" end

Gui = loadstring(game:HttpGet("https://pastebin.com/raw/2BGUWvbd"))()
Gui:Init({
    Name = gameName,
    Subtitle = "Auto farm " .. gameName,
    FolderName = "BulbConfigs",
    FileName = safeName .. ".json"
})

-- ==================================================
-- MONEY SUFFIXES (copied from Shared.Format)
-- ==================================================
local SUFFIXES = {
    "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc", "Ud", "Dd", "Td", "Qad",
    "Qid", "Sxd", "Spd", "Ocd", "Nod", "Vg", "Uvg", "Dvg", "Tvg", "Qavg", "Qivg", "Sxvg",
    "Spvg", "Ocvg", "Novg", "Tg", "Utg", "Dtg", "Ttg", "Qatg", "Qitg", "Sxtg", "Sptg", "Octg",
    "Notg", "Qag", "Uqag", "Dqag", "Tqag", "Qaqag", "Qiqag", "Sxqag", "Spqag", "Ocqag", "Noqag",
    "Qig", "Uqig", "Dqig", "Tqig", "Qaqig", "Qiqig", "Sxqig", "Spqig", "Ocqig", "Noqig", "Sxg",
    "Usxg", "Dsxg", "Tsxg", "Qasxg", "Qisxg", "Sxsxg", "Spsxg", "Ocsxg", "Nosxg", "Spg", "Uspg",
    "Dspg", "Tspg", "Qaspg", "Qispg", "Sxspg", "Spspg", "Ocspg", "Nospg", "Ocg", "Uocg", "Docg",
    "Tocg", "Qaocg", "Qiocg", "Sxocg", "Spocg", "Ococg", "Noocg", "Nog", "Unog", "Dnog", "Tnog",
    "Qanog", "Qinog", "Sxnog", "Spnog", "Ocnog", "Nonog", "Ce"
}
local SUFFIX_POWER = {}
for i, s in ipairs(SUFFIXES) do SUFFIX_POWER[s] = i - 1 end

local function parseMoney(v)
    if type(v) == "number" then return v end
    if type(v) ~= "string" then return nil end
    local s = v:gsub("[%$,%s]", "")
    local num, suf = s:match("^(%d*%.?%d+)(%a*)$")
    if not num then return nil end
    local p = SUFFIX_POWER[suf]
    if p == nil then return nil end
    return tonumber(num) * (1000 ^ p)
end

local function getCash()
    local ls = LP:FindFirstChild("leaderstats")
    local c = ls and ls:FindFirstChild("Cash")
    if not c then return nil end
    return parseMoney(c.Value)
end

-- ==================================================
-- HELPERS
-- ==================================================
local KnitRemotes = RS:WaitForChild("KnitRemotes", 10)

local function remote(service, name)
    local s = KnitRemotes and KnitRemotes:FindFirstChild(service)
    return s and s:FindFirstChild(name)
end

local function getPos(o)
    if o:IsA("Model") then return o:GetPivot().Position end
    if o:IsA("BasePart") then return o.Position end
end

local function getHRP()
    return LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
end

local myBase
local function getMyBase(force)
    if myBase and myBase.Parent and not force then return myBase end
    local hrp, bases = getHRP(), workspace:FindFirstChild("Bases")
    if not hrp or not bases then return nil end
    local best, bestDist = nil, math.huge
    for _, base in ipairs(bases:GetChildren()) do
        local items = base:FindFirstChild("Items")
        if items then
            for _, it in ipairs(items:GetChildren()) do
                local p = getPos(it)
                if p then
                    local d = (p - hrp.Position).Magnitude
                    if d < bestDist then best, bestDist = base, d end
                end
            end
        end
    end
    myBase = best
    return myBase
end

local function getMyItems()
    local base = getMyBase()
    return base and base:FindFirstChild("Items")
end

local FloorKit
pcall(function() FloorKit = require(RS.Shared.FloorKit) end)

local function isBoard(name)
    return name:match("Board$") ~= nil
end

-- TraderDesk, TraderDesk2, ClientDesk2, ... (or FloorKit "Tip" role)
local function isDesk(name)
    if name:lower():find("desk") then return true end
    local k = FloorKit and FloorKit.ByKind and FloorKit.ByKind[name]
    return k ~= nil and k.Role == "Tip"
end

-- Researcher1, Researcher2, Researcher3, ...
local function isResearcher(name)
    return name:lower():find("researcher") ~= nil
end

-- Manager (or FloorKit "Manager" role)
local function isManager(name)
    if name:lower():find("manager") then return true end
    local k = FloorKit and FloorKit.ByKind and FloorKit.ByKind[name]
    return k ~= nil and k.Role == "Manager"
end

-- PropertyInvestor1 ... PropertyInvestor4, GoldInvestor1 ... GoldInvestor4 (any name containing "investor")
local INVESTOR_MAX = 4
local function isInvestor(name)
    if not name:lower():find("investor") then return false end
    local n = tonumber(name:match("(%d+)$")) or 1
    return n <= INVESTOR_MAX
end

-- HousePlot1 ... HousePlot5
local HOUSEPLOT_MAX = 5
local function isHousePlot(name)
    if not name:lower():find("houseplot") then return false end
    local n = tonumber(name:match("(%d+)$")) or 1
    return n <= HOUSEPLOT_MAX
end

-- RenoPaint, RenoGarden, RenoRoof, ... (any item starting with "Reno")
local function isReno(name)
    return name:lower():find("^reno") ~= nil
end

-- Smelter1, Smelter2, ...
local function isSmelter(name)
    return name:lower():find("smelter") ~= nil
end

-- Foreman
local function isForeman(name)
    return name:lower():find("foreman") ~= nil
end

-- Sculptor1, Sculptor2, Sculptor3, ...
local function isSculptor(name)
    return name:lower():find("sculptor") ~= nil
end

-- Engineer1, Engineer2, ...
local function isEngineer(name)
    return name:lower():find("engineer") ~= nil
end

-- ServerRack1, ServerRack2, ...
local function isServerRack(name)
    return name:lower():find("serverrack") ~= nil
end

-- LaunchBay1, LaunchBay2, LaunchBay3, ...
local function isLaunchBay(name)
    return name:lower():find("launchbay") ~= nil
end

-- Sysadmin
local function isSysadmin(name)
    return name:lower():find("sysadmin") ~= nil
end

-- Everything that "Auto Upgrade" should upgrade
local function isUpgradeTarget(name)
    return isBoard(name) or isDesk(name) or isResearcher(name) or isManager(name)
        or isInvestor(name) or isHousePlot(name) or isReno(name) or isSmelter(name)
        or isForeman(name) or isSculptor(name) or isEngineer(name) or isServerRack(name)
        or isLaunchBay(name) or isSysadmin(name)
end

-- ==================================================
-- TAB: AUTO FARM
-- ==================================================
local Farm = Gui:CreateTab("Auto Farm", 4483362458)

local pumping, upgrading, buying = false, false, false

-- Fixed values (their controls were removed from the GUI)
local UPGRADE_INTERVAL = 0.3 -- seconds between each upgrade call
local BUY_INTERVAL = 1       -- seconds between each auto-buy check
local BUY_METHOD = "Touch"   -- always use touch (falls back to teleport if firetouchinterest is missing)

local upgradeAmount = 1

Farm:CreateSection("Hype Meter")

Farm:CreateToggle({
    Name = "Auto Pump",
    Description = "Pumps the nearest HypeMeter every 0.5s",
    Flag = "AutoPump",
    CurrentValue = false,
    Callback = function(state)
        pumping = state
        if state then
            task.spawn(function()
                while pumping do
                    pcall(function()
                        local hrp, bases = getHRP(), workspace:FindFirstChild("Bases")
                        local rf = remote("MeterService", "RF_Pump")
                        if not (hrp and bases and rf) then return end
                        local best, bestDist = nil, math.huge
                        for _, o in ipairs(bases:GetDescendants()) do
                            if o.Name == "HypeMeter" then
                                local p = getPos(o)
                                if p then
                                    local d = (p - hrp.Position).Magnitude
                                    if d < bestDist then best, bestDist = o, d end
                                end
                            end
                        end
                        if best then rf:InvokeServer(best) end
                    end)
                    task.wait(0.5)
                end
            end)
        end
        Gui:Notify({Title = "Auto Pump", Content = state and "ON (0.5s)" or "OFF", Duration = 2})
    end
})

Farm:CreateSection("Upgrade")

Farm:CreateSlider({
    Name = "Amount per Upgrade",
    Range = {1, 10},
    Increment = 1,
    CurrentValue = 1,
    Flag = "UpgradeAmount",
    Callback = function(v) upgradeAmount = v end
})

local function runUpgrade(filter, flagGetter)
    task.spawn(function()
        while flagGetter() do
            pcall(function()
                local items = getMyItems()
                local rf = remote("MachineService", "RF_Upgrade")
                if not (items and rf) then return end
                for _, it in ipairs(items:GetChildren()) do
                    if not flagGetter() then break end
                    if filter(it.Name) then
                        rf:InvokeServer(it, upgradeAmount)
                        task.wait(UPGRADE_INTERVAL)
                    end
                end
            end)
            task.wait(0.1)
        end
    end)
end

Farm:CreateToggle({
    Name = "Auto Upgrade",
    Description = "Boards, Desks, Researchers, Managers, Investors (1-4), House Plots (1-5), Reno items, Smelters, Foreman, Sculptors, Engineers, Server Racks, Launch Bays, Sysadmin",
    Flag = "AutoUpgrade",
    CurrentValue = false,
    Callback = function(state)
        upgrading = state
        if state then runUpgrade(isUpgradeTarget, function() return upgrading end) end
        Gui:Notify({Title = "Auto Upgrade", Content = state and "ON" or "OFF", Duration = 2})
    end
})

-- ==================================================
-- AUTO BUY BUTTONS
-- ==================================================
Farm:CreateSection("Buttons")

local cooldown = {}

local function getTouchPart(btn)
    local top = btn:FindFirstChild("Top")
    if not top then return nil end
    local ti = top:FindFirstChildWhichIsA("TouchInterest", true)
    if ti then return ti.Parent end
    if top:IsA("BasePart") then return top end
    return top:FindFirstChildWhichIsA("BasePart", true)
end

local function getAffordableButtons()
    local base = getMyBase()
    local folder = base and base:FindFirstChild("Buttons")
    local cash = getCash()
    if not (folder and cash) then return {}, cash end

    local list = {}
    for _, btn in ipairs(folder:GetChildren()) do
        if (cooldown[btn] or 0) <= os.clock() then
            local b = btn:FindFirstChild("Base")
            local gui = b and b:FindFirstChild("ButtonGui")
            local label = gui and gui:FindFirstChild("PriceLabel")
            local price = label and parseMoney(label.Text)
            local part = getTouchPart(btn)
            if price and part and price <= cash then
                table.insert(list, {btn = btn, price = price, part = part})
            end
        end
    end
    table.sort(list, function(a, b) return a.price < b.price end)
    return list, cash
end

local function pressButton(entry)
    local hrp = getHRP()
    if not hrp then return false end

    if BUY_METHOD == "Touch" and firetouchinterest then
        firetouchinterest(hrp, entry.part, 0)
        task.wait(0.1)
        firetouchinterest(hrp, entry.part, 1)
        return true
    end

    -- Fallback: teleport onto the button and come back
    local back = hrp.CFrame
    hrp.CFrame = entry.part.CFrame * CFrame.new(0, 3, 0)
    task.wait(0.4)
    hrp.CFrame = back
    return true
end

Farm:CreateToggle({
    Name = "Auto Buy Buttons",
    Description = "Buys the cheapest affordable upgrade button",
    Flag = "AutoBuyButtons",
    CurrentValue = false,
    Callback = function(state)
        buying = state
        if state then
            task.spawn(function()
                while buying do
                    pcall(function()
                        local list = getAffordableButtons()
                        local entry = list[1]
                        if entry then
                            pressButton(entry)
                            cooldown[entry.btn] = os.clock() + 3
                        end
                    end)
                    task.wait(BUY_INTERVAL)
                end
            end)
        end
        Gui:Notify({Title = "Auto Buy Buttons", Content = state and "ON" or "OFF", Duration = 2})
    end
})

Farm:CreateButton({
    Name = "Print Buttons Info",
    Description = "Prints price, cash and affordability (console F9)",
    Interact = "Print",
    Callback = function()
        local base = getMyBase()
        local folder = base and base:FindFirstChild("Buttons")
        print("Base:", base and base.Name, "| Cash:", getCash())
        if not folder then return end
        for _, btn in ipairs(folder:GetChildren()) do
            local b = btn:FindFirstChild("Base")
            local gui = b and b:FindFirstChild("ButtonGui")
            local label = gui and gui:FindFirstChild("PriceLabel")
            print(btn.Name, label and label.Text, parseMoney(label and label.Text), getTouchPart(btn) and "Top OK" or "no Top")
        end
        Gui:Notify({Title = "Buttons", Content = "Printed to console (F9)", Duration = 2})
    end
})

-- ==================================================
-- TAB: PLAYER
-- ==================================================
local PlayerTab = Gui:CreateTab("Player", 4483362458)

PlayerTab:CreateSection("Utility")

local afkConn
PlayerTab:CreateToggle({
    Name = "Anti AFK",
    Description = "Prevents idle kick",
    Flag = "AntiAFK",
    CurrentValue = false,
    Callback = function(state)
        if afkConn then afkConn:Disconnect() afkConn = nil end
        if state then
            local VU = game:GetService("VirtualUser")
            afkConn = LP.Idled:Connect(function()
                VU:CaptureController()
                VU:ClickButton2(Vector2.new())
            end)
        end
    end
})

local speedOn, speedVal = false, 32
PlayerTab:CreateSlider({
    Name = "WalkSpeed",
    Range = {16, 100},
    Increment = 1,
    CurrentValue = 32,
    Flag = "WalkSpeedValue",
    Callback = function(v)
        speedVal = v
        local h = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
        if speedOn and h then h.WalkSpeed = v end
    end
})

PlayerTab:CreateToggle({
    Name = "Set WalkSpeed",
    Description = "Applies the slider value above",
    Flag = "WalkSpeedOn",
    CurrentValue = false,
    Callback = function(state)
        speedOn = state
        task.spawn(function()
            while speedOn do
                local h = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
                if h then h.WalkSpeed = speedVal end
                task.wait(0.5)
            end
            local h = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
            if h then h.WalkSpeed = 16 end
        end)
    end
})

PlayerTab:CreateButton({
    Name = "Teleport to Nearest HypeMeter",
    Interact = "TP",
    Callback = function()
        local hrp, bases = getHRP(), workspace:FindFirstChild("Bases")
        if not (hrp and bases) then return end
        local best, bestDist = nil, math.huge
        for _, o in ipairs(bases:GetDescendants()) do
            if o.Name == "HypeMeter" then
                local p = getPos(o)
                if p then
                    local d = (p - hrp.Position).Magnitude
                    if d < bestDist then best, bestDist = p, d end
                end
            end
        end
        if best then hrp.CFrame = CFrame.new(best + Vector3.new(0, 4, 6)) end
    end
})

-- ==================================================
-- TAB: REMOTE TOOLS
-- ==================================================
local Tools = Gui:CreateTab("Remote Tools", 7734055278)

Tools:CreateSection("Scanner")

Tools:CreateButton({
    Name = "Scan All Knit Remotes",
    Description = "Output goes to console (F9) and clipboard",
    Interact = "Scan",
    Callback = function()
        if not KnitRemotes then return end
        local out = {}
        for _, svc in ipairs(KnitRemotes:GetChildren()) do
            table.insert(out, "[" .. svc.Name .. "]")
            for _, r in ipairs(svc:GetChildren()) do
                table.insert(out, "  " .. r.ClassName .. "  " .. r.Name)
            end
        end
        local text = table.concat(out, "\n")
        print(text)
        if setclipboard then setclipboard(text) end
        Gui:Notify({Title = "Scanner", Content = "Done, check clipboard", Duration = 3})
    end
})

Tools:CreateSection("Logger")

local logging, logBuffer, hooked = false, {}, false

local function fmtArg(v)
    if typeof(v) == "Instance" then return "<" .. v:GetFullName() .. ">" end
    if type(v) == "table" then
        local ok, s = pcall(function() return game:GetService("HttpService"):JSONEncode(v) end)
        return ok and s or "{table}"
    end
    return tostring(v)
end

local function setupHook()
    if hooked or not hookmetamethod then return end
    hooked = true
    local old
    old = hookmetamethod(game, "__namecall", function(self, ...)
        local method = getnamecallmethod()
        if logging and (method == "InvokeServer" or method == "FireServer")
            and typeof(self) == "Instance" and KnitRemotes and self:IsDescendantOf(KnitRemotes)
            and not (checkcaller and checkcaller()) then
            local args = {...}
            local parts = {}
            for i = 1, select("#", ...) do parts[i] = fmtArg(args[i]) end
            local line = string.format("[%s] %s(%s)", os.date("%H:%M:%S"), self:GetFullName(), table.concat(parts, ", "))
            table.insert(logBuffer, line)
            if #logBuffer > 300 then table.remove(logBuffer, 1) end
        end
        return old(self, ...)
    end)
end

Tools:CreateToggle({
    Name = "Remote Logger",
    Description = "Logs remotes sent by the client (do the action manually)",
    CurrentValue = false,
    Callback = function(state)
        if state and not hookmetamethod then
            Gui:Notify({Title = "Logger", Content = "Executor lacks hookmetamethod", Duration = 3})
            return
        end
        logging = state
        if state then setupHook() end
    end
})

Tools:CreateButton({
    Name = "Copy Log",
    Interact = "Copy",
    Callback = function()
        local text = table.concat(logBuffer, "\n")
        if setclipboard then setclipboard(text) end
        print(text)
        Gui:Notify({Title = "Logger", Content = #logBuffer .. " lines copied", Duration = 2})
    end
})

Tools:CreateButton({
    Name = "Clear Log",
    Callback = function() logBuffer = {} end
})
