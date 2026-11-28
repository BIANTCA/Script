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
-- HELPERS
-- ==================================================
local KnitRemotes = RS:WaitForChild("KnitRemotes", 10)

local function notify(title, content)
    Gui:Notify({Title = title, Content = content, Duration = 2})
end

local function remote(service, name)
    local s = KnitRemotes and KnitRemotes:FindFirstChild(service)
    return s and s:FindFirstChild(name)
end

-- Calls a Knit RemoteFunction safely. Returns ok, result.
local function call(service, name, ...)
    local r = remote(service, name)
    if not r then return false, "missing remote " .. service .. "." .. name end
    return pcall(r.InvokeServer, r, ...)
end

local function getHRP()
    return LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
end

local function getCash()
    local c = LP:GetAttribute("Cash")
    return type(c) == "number" and c or 0
end

-- Finds the base owned by the local player (BaseName attribute, then OwnerUserId).
local myBase
local function getMyBase()
    if myBase and myBase.Parent then return myBase end
    local bases = workspace:FindFirstChild("Bases")
    if not bases then return nil end
    local name = LP:GetAttribute("BaseName")
    local byName = name and bases:FindFirstChild(name)
    if byName then
        myBase = byName
        return myBase
    end
    for _, base in ipairs(bases:GetChildren()) do
        if base:GetAttribute("OwnerUserId") == LP.UserId then
            myBase = base
            return myBase
        end
    end
    return nil
end

local function getItems()
    local base = getMyBase()
    return base and base:FindFirstChild("Items")
end

local function findItem(fragment)
    local items = getItems()
    if not items then return nil end
    for _, it in ipairs(items:GetChildren()) do
        if it.Name:lower():find(fragment, 1, true) then return it end
    end
    return nil
end

-- Generation based loop runner: turning a toggle off (or on again) stops the old loop.
local generation = {}
local function setLoop(name, state, interval, fn)
    generation[name] = (generation[name] or 0) + 1
    if not state then return end
    local mine = generation[name]
    local function alive() return generation[name] == mine end
    task.spawn(function()
        while alive() do
            local ok, err = pcall(fn, alive)
            if not ok then warn("[" .. name .. "] " .. tostring(err)) end
            task.wait(interval)
        end
    end)
end

-- ==================================================
-- TAB: AUTO FARM
-- ==================================================
local Farm = Gui:CreateTab("Auto Farm", 4483362458)

Farm:CreateSection("Hype Meter")

Farm:CreateToggle({
    Name = "Auto Pump",
    Description = "Pumps your own HypeMeter every 0.5s",
    Flag = "AutoPump",
    CurrentValue = false,
    Callback = function(state)
        setLoop("pump", state, 0.5, function()
            local items = getItems()
            local rf = remote("MeterService", "RF_Pump")
            if not (items and rf) then return end
            for _, it in ipairs(items:GetChildren()) do
                if it.Name == "HypeMeter" then rf:InvokeServer(it) end
            end
        end)
        notify("Auto Pump", state and "ON" or "OFF")
    end
})

Farm:CreateSection("Upgrade")

local UPGRADE_DELAY = 0.3
local upgradeAmount = 1

Farm:CreateDropdown({
    Name = "Amount per Upgrade",
    Options = {"1", "5", "10"},
    CurrentOption = "1",
    Flag = "UpgradeAmountChoice",
    Callback = function(opt)
        local v = type(opt) == "table" and opt[1] or opt
        upgradeAmount = tonumber(v) or 1
    end
})

local function costAttr(amount)
    return amount == 1 and "UpgradeCost" or ("UpgradeCost" .. amount)
end

-- Upgrades every item in your base that exposes an UpgradeCost attribute (-1 means max level).
local function upgradeOnce(alive)
    local items = getItems()
    local rf = remote("MachineService", "RF_Upgrade")
    if not (items and rf) then return end

    local list = {}
    for _, it in ipairs(items:GetChildren()) do
        local amount = upgradeAmount
        local cost = amount > 1 and it:GetAttribute(costAttr(amount)) or nil
        if type(cost) ~= "number" or cost < 0 then
            amount = 1
            cost = it:GetAttribute("UpgradeCost")
        end
        if type(cost) == "number" and cost >= 0 then
            table.insert(list, {item = it, cost = cost, amount = amount})
        end
    end
    table.sort(list, function(a, b) return a.cost < b.cost end)

    for _, e in ipairs(list) do
        if not alive() then return end
        if e.cost <= getCash() then
            rf:InvokeServer(e.item, e.amount)
            task.wait(UPGRADE_DELAY)
        end
    end
end

Farm:CreateToggle({
    Name = "Auto Upgrade",
    Description = "Upgrades every upgradable item in your base, cheapest first",
    Flag = "AutoUpgrade",
    CurrentValue = false,
    Callback = function(state)
        setLoop("upgrade", state, 0.2, upgradeOnce)
        notify("Auto Upgrade", state and "ON" or "OFF")
    end
})

Farm:CreateSection("Buttons")

local BUY_INTERVAL = 1
local allowTokenUse = false
local cooldown = {}

local function getTouchPart(btn)
    local top = btn:FindFirstChild("Top")
    if not top then return nil end
    local ti = top:FindFirstChildWhichIsA("TouchInterest", true)
    if ti then return ti.Parent end
    if top:IsA("BasePart") then return top end
    return top:FindFirstChildWhichIsA("BasePart", true)
end

local function pressButton(part)
    local hrp = getHRP()
    if not hrp then return end
    if firetouchinterest then
        firetouchinterest(hrp, part, 0)
        task.wait(0.1)
        firetouchinterest(hrp, part, 1)
        return
    end
    local back = hrp.CFrame
    hrp.CFrame = part.CFrame * CFrame.new(0, 3, 0)
    task.wait(0.4)
    hrp.CFrame = back
end

local function buyOnce()
    local base = getMyBase()
    local folder = base and base:FindFirstChild("Buttons")
    if not folder then return end
    if (LP:GetAttribute("Skips") or 0) > 0 and not allowTokenUse then return end

    local cash = getCash()
    local best
    for _, btn in ipairs(folder:GetChildren()) do
        local price = btn:GetAttribute("Price")
        if type(price) == "number" and price <= cash and (cooldown[btn] or 0) <= os.clock() then
            local part = getTouchPart(btn)
            if part and (not best or price < best.price) then
                best = {btn = btn, price = price, part = part}
            end
        end
    end
    if best then
        cooldown[best.btn] = os.clock() + 3
        pressButton(best.part)
    end
end

Farm:CreateToggle({
    Name = "Auto Buy Buttons",
    Description = "Buys the cheapest affordable button every second",
    Flag = "AutoBuyButtons",
    CurrentValue = false,
    Callback = function(state)
        setLoop("buy", state, BUY_INTERVAL, buyOnce)
        notify("Auto Buy Buttons", state and "ON" or "OFF")
    end
})

Farm:CreateToggle({
    Name = "Allow Token Use",
    Description = "When OFF, auto buy pauses while you hold skip tokens so they are not spent",
    Flag = "AllowTokenUse",
    CurrentValue = false,
    Callback = function(state) allowTokenUse = state end
})

Farm:CreateSection("Progress")

Farm:CreateToggle({
    Name = "Auto Rebirth",
    Description = "Rebirths when available. This RESETS cash, floors and upgrades",
    Flag = "AutoRebirth",
    CurrentValue = false,
    Callback = function(state)
        setLoop("rebirth", state, 5, function()
            local ok, info = call("RebirthService", "RF_GetInfo")
            if ok and type(info) == "table" and info.CanRebirth then
                local ok2, res = call("RebirthService", "RF_Rebirth")
                if ok2 and type(res) == "table" and res.Ok then
                    notify("Auto Rebirth", "Rebirthed")
                end
            end
        end)
        notify("Auto Rebirth", state and "ON" or "OFF")
    end
})

Farm:CreateButton({
    Name = "Claim Free Tokens",
    Description = "Claims the free skip tokens if they are still available",
    Interact = "Claim",
    Callback = function()
        if LP:GetAttribute("FreeTokensClaimed") ~= false then
            notify("Tokens", "Nothing to claim")
            return
        end
        local ok, res = call("MonetizationService", "RF_ClaimFreeTokens")
        notify("Tokens", (ok and res) and "Claimed" or "Claim failed")
    end
})

Farm:CreateButton({
    Name = "Finish Tutorial",
    Interact = "Skip",
    Callback = function()
        local ok = call("DataService", "RF_FinishTutorial")
        notify("Tutorial", ok and "Requested" or "Failed")
    end
})

Farm:CreateButton({
    Name = "Print Base Info",
    Description = "Prints base, items and buttons (console F9)",
    Interact = "Print",
    Callback = function()
        local base = getMyBase()
        print("Base:", base and base.Name, "| Cash:", getCash(), "| Tokens:", LP:GetAttribute("Skips"))
        local items = getItems()
        if items then
            for _, it in ipairs(items:GetChildren()) do
                print("Item", it.Name, "UpgradeCost", it:GetAttribute("UpgradeCost"), "ReadyAt", it:GetAttribute("ReadyAt"))
            end
        end
        local folder = base and base:FindFirstChild("Buttons")
        if folder then
            for _, btn in ipairs(folder:GetChildren()) do
                print("Button", btn.Name, btn:GetAttribute("Price"), getTouchPart(btn) and "Top OK" or "no Top")
            end
        end
        notify("Info", "Printed to console (F9)")
    end
})

-- ==================================================
-- AUTO MINIGAMES
-- ==================================================
Farm:CreateSection("Minigames")

local function serverNow()
    return workspace:GetServerTimeNow()
end

local function waitUntil(t, alive)
    while alive() and serverNow() < t do task.wait(0.05) end
    return alive()
end

local function playCrash(r, alive)
    local target = r.Crash * 0.9
    if not waitUntil(r.Start + math.log(target) / r.Growth, alive) then return nil end
    local mult = math.min(math.exp(r.Growth * (serverNow() - r.Start)), target)
    local ok, res = call("CrashService", "RF_Sell", mult)
    if ok and type(res) == "table" and res.Ok then return res end
    return nil
end

local function playGoldRush(r, alive)
    if not waitUntil(r.Start, alive) then return nil end
    local startedAt = serverNow()
    call("GoldRushService", "RF_PourStart")
    if not waitUntil(startedAt + r.Target / r.Rate, alive) then return nil end
    local fill = r.Rate * (serverNow() - startedAt)
    local ok, res = call("GoldRushService", "RF_PourStop", fill)
    if ok and type(res) == "table" and res.Ok then return res end
    return nil
end

local function playHarbour(r, alive)
    local delay = math.min(0.35 * #r.Sequence, (r.Par or 4) * 0.7)
    if not waitUntil(r.InputOpen + delay, alive) then return nil end
    local elapsed = serverNow() - r.InputOpen
    local ok, res = call("HarbourSignalsService", "RF_Submit", r.Sequence, elapsed)
    if ok and type(res) == "table" and res.Ok then return res end
    return nil
end

local function needleAt(r, now)
    local p = ((now - r.Start) / r.Period + r.Phase) % 2
    if p > 1 then p = 2 - p end
    return p
end

local function playLaunch(r, alive)
    local bestT
    for _, target in ipairs({r.Center, 2 - r.Center}) do
        local k = math.ceil((0.2 / r.Period - (target - r.Phase)) / 2)
        local t = r.Period * (target - r.Phase + 2 * k)
        if not bestT or t < bestT then bestT = t end
    end
    if not waitUntil(r.Start + bestT, alive) then return nil end
    local ok, res = call("LaunchControlService", "RF_Fire", needleAt(r, serverNow()))
    if ok and type(res) == "table" and res.Ok then return res end
    return nil
end

local MINIGAMES = {
    {item = "crashgame", service = "CrashService", play = playCrash},
    {item = "goldrush", service = "GoldRushService", play = playGoldRush},
    {item = "harboursignals", service = "HarbourSignalsService", play = playHarbour},
    {item = "launchcontrol", service = "LaunchControlService", play = playLaunch},
}

local function runMinigame(cfg, alive)
    local item = findItem(cfg.item)
    if not item then return end
    if item:GetAttribute("OwnerUserId") ~= LP.UserId then return end
    if (item:GetAttribute("ReadyAt") or 0) > serverNow() then return end

    local ok, st = call(cfg.service, "RF_Start")
    if not (ok and type(st) == "table" and st.Ok) then return end

    local round = st.Round or 0
    local rounds = st.Rounds or 3
    while alive() and round < rounds do
        local ok2, r = call(cfg.service, "RF_StartRound")
        if not (ok2 and type(r) == "table" and r.Ok) then return end
        local res = cfg.play(r, alive)
        if not res then return end
        round = r.Round or (round + 1)
    end
end

Farm:CreateToggle({
    Name = "Auto Minigames",
    Description = "Crash, Gold Rush, Harbour Signals and Launch Control when their cooldown is ready",
    Flag = "AutoMinigames",
    CurrentValue = false,
    Callback = function(state)
        setLoop("minigames", state, 5, function(alive)
            for _, cfg in ipairs(MINIGAMES) do
                if not alive() then return end
                local ok, err = pcall(runMinigame, cfg, alive)
                if not ok then warn("[Minigame " .. cfg.service .. "] " .. tostring(err)) end
            end
        end)
        notify("Auto Minigames", state and "ON" or "OFF")
    end
})

-- ==================================================
-- TAB: PLAYER
-- ==================================================
local PlayerTab = Gui:CreateTab("Player", 4483362458)

PlayerTab:CreateSection("Utility")

local afkConn
local function setAntiAfk(state)
    if afkConn then afkConn:Disconnect() afkConn = nil end
    if state then
        local VU = game:GetService("VirtualUser")
        afkConn = LP.Idled:Connect(function()
            VU:CaptureController()
            VU:ClickButton2(Vector2.new())
        end)
    end
end
setAntiAfk(true)

PlayerTab:CreateToggle({
    Name = "Anti AFK",
    Description = "Prevents the idle kick and the game's idle rejoin (ON by default)",
    Flag = "AntiAFK",
    CurrentValue = true,
    Callback = function(state) setAntiAfk(state) end
})

local speedVal = 32
PlayerTab:CreateSlider({
    Name = "WalkSpeed",
    Range = {16, 100},
    Increment = 1,
    CurrentValue = 32,
    Flag = "WalkSpeedValue",
    Callback = function(v) speedVal = v end
})

PlayerTab:CreateToggle({
    Name = "Set WalkSpeed",
    Description = "Applies the slider value above",
    Flag = "WalkSpeedOn",
    CurrentValue = false,
    Callback = function(state)
        setLoop("walkspeed", state, 0.5, function()
            local h = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
            if h then h.WalkSpeed = speedVal end
        end)
        if not state then
            local h = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
            if h then h.WalkSpeed = 16 end
        end
    end
})

PlayerTab:CreateButton({
    Name = "Teleport to My HypeMeter",
    Interact = "TP",
    Callback = function()
        local hrp = getHRP()
        local meter = findItem("hypemeter")
        if not (hrp and meter) then
            notify("Teleport", "HypeMeter not found")
            return
        end
        local pos = meter:GetPivot().Position
        hrp.CFrame = CFrame.new(pos + Vector3.new(0, 4, 6))
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
        notify("Scanner", "Done, check clipboard")
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
            notify("Logger", "Executor lacks hookmetamethod")
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
        notify("Logger", #logBuffer .. " lines copied")
    end
})

Tools:CreateButton({
    Name = "Clear Log",
    Callback = function() logBuffer = {} end
})
