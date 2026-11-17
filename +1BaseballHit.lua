local RobloxGui = loadstring(game:HttpGet("https://pastebin.com/raw/2BGUWvbd"))()

local GUI = RobloxGui:Init({
    Name       = "+1 Baseball Hit",
    Subtitle   = "Best Auto Farm",
    FolderName = "PPT_Configs",
    FileName   = "settings.json"
})

local RS           = game:GetService("ReplicatedStorage")
local Players      = game:GetService("Players")
local VirtualUser  = game:GetService("VirtualUser")

local Player  = Players.LocalPlayer
local Remotes = RS:WaitForChild("Remotes", 10) or RS
local Shared  = RS:FindFirstChild("Shared")

-- ============================================================
-- Remote call helper
-- ============================================================

local function Call(name, ...)
    if not name or name == "" then return nil end
    local r = Remotes:FindFirstChild(name, true)
    if not r then return nil end
    local args = table.pack(...)
    if r:IsA("RemoteFunction") then
        local ok, res = pcall(function()
            return r:InvokeServer(table.unpack(args, 1, args.n))
        end)
        return ok and res or nil
    elseif r:IsA("RemoteEvent") then
        pcall(function()
            r:FireServer(table.unpack(args, 1, args.n))
        end)
    end
    return nil
end

local function SafeRequire(path)
    local ok, mod = pcall(function()
        local inst = Shared
        for _, part in ipairs(path) do
            inst = inst and inst:FindFirstChild(part)
        end
        return inst and require(inst)
    end)
    return ok and mod or nil
end

-- ============================================================
-- Loop helpers
-- ============================================================

local loopTokens = {}

local function AutoLoop(id, delay, fn, burst)
    return function(state)
        loopTokens[id] = (loopTokens[id] or 0) + 1
        local token = loopTokens[id]
        if not state then return end
        task.spawn(function()
            while loopTokens[id] == token do
                local n = type(burst) == "function" and burst() or burst or 1
                for _ = 1, n do
                    if loopTokens[id] ~= token then break end
                    task.spawn(pcall, fn)
                end
                task.wait(type(delay) == "function" and delay() or delay)
            end
        end)
    end
end

local function SeqLoop(id, fn)
    return function(state)
        loopTokens[id] = (loopTokens[id] or 0) + 1
        local token = loopTokens[id]
        if not state then return end
        task.spawn(function()
            while loopTokens[id] == token do
                local ok, err = pcall(fn, function() return loopTokens[id] == token end)
                if not ok then
                    warn("[PPT] " .. id .. " error:", err)
                    task.wait(1)
                end
                task.wait()
            end
        end)
    end
end

-- ============================================================
-- Notify & UI helpers
-- ============================================================

local function Notify(title, content, dur)
    GUI:Notify({Title = title, Content = content, Duration = dur or 2})
end

local function NewParagraph(tab, title, content)
    local packed = table.pack(tab:CreateParagraph({Title = title, Content = content}))
    local obj
    for i = packed.n, 1, -1 do
        local v = packed[i]
        if type(v) == "table" and (type(v.SetContent) == "function" or type(v.Set) == "function") then
            obj = v
            break
        end
    end
    return {
        Set = function(_, text)
            if not obj then return end
            if type(obj.SetContent) == "function" then
                if pcall(obj.SetContent, obj, text) then return end
            end
            if type(obj.Set) == "function" then
                if pcall(obj.Set, obj, text) then return end
                pcall(obj.Set, obj, {Content = text})
            end
        end
    }
end

-- ============================================================
-- Player data
-- ============================================================

local playerData    = nil
local trainOn       = false
local rebirthOn     = false
local forceTeleportPad = false
local lastRebirths  = nil

local function CheckRebirthChange()
    local r = playerData and tonumber(playerData.Rebirths)
    if not r then return end
    if lastRebirths and r > lastRebirths and trainOn and rebirthOn then
        forceTeleportPad = true
    end
    lastRebirths = r
end

do
    local ev = Remotes:FindFirstChild("DataUpdate", true)
    if ev and ev:IsA("RemoteEvent") then
        ev.OnClientEvent:Connect(function(d)
            if type(d) == "table" then
                playerData = d
                CheckRebirthChange()
            end
        end)
    end
end

local function GetData()
    if playerData then return playerData end
    local s = Call("GetState")
    if type(s) == "table" then playerData = s end
    return playerData
end

local function Short(n)
    n = tonumber(n) or 0
    local units = {"", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"}
    local i = 1
    while n >= 1000 and i < #units do
        n = n / 1000
        i = i + 1
    end
    return string.format(i == 1 and "%d" or "%.2f%s", n, units[i])
end

-- ============================================================
-- World / config data
-- ============================================================

local worlds = {"World 1", "World 2", "World 3", "World 4", "World 5", "World 6", "World 7"}
do
    local c = SafeRequire({"Config", "WorldsConfig"})
    if c and c.Worlds then
        worlds = {}
        for _, w in ipairs(c.Worlds) do table.insert(worlds, w.Name) end
    end
end

local upgradeIds = {"QuickHands", "StrongArm", "LuckyWind"}
do
    local c = SafeRequire({"Config", "UpgradeConfig"})
    if c and c.Upgrades then
        upgradeIds = {}
        for _, u in ipairs(c.Upgrades) do table.insert(upgradeIds, u.Id) end
    end
end

local PlaneList = {}
do
    local c = SafeRequire({"Config", "PlaneConfig"})
    if c and c.Planes then
        for _, b in ipairs(c.Planes) do
            if not b.RobuxPass and not b.Exclusive and (b.TrophyPrice or b.ExpPrice) then
                table.insert(PlaneList, {
                    Id          = b.Id,
                    World       = b.World or 1,
                    Level       = b.Level or 0,
                    TrophyPrice = b.TrophyPrice or 0,
                    ExpPrice    = b.ExpPrice or 0,
                })
            end
        end
    end
    if #PlaneList == 0 then
        local fallback = {
            {"WoodPlane", 0}, {"MaplePlane", 50}, {"AluminumPlane", 75}, {"BlackInkPlane", 150},
            {"CandyCanePlane", 300}, {"GoldenPlane", 600}, {"IcePlane", 1500}, {"LavaPlane", 4500},
            {"GalaxyPlane", 14000}, {"RainbowLegendPlane", 40000},
        }
        for i, f in ipairs(fallback) do
            table.insert(PlaneList, {Id = f[1], World = 1, Level = i, TrophyPrice = f[2], ExpPrice = 0})
        end
    end
    table.sort(PlaneList, function(a, b)
        if a.TrophyPrice ~= b.TrophyPrice then return a.TrophyPrice < b.TrophyPrice end
        return a.Level < b.Level
    end)
end

local trailIds = {
    "Cloud", "Bubblegum", "Ocean", "Golden", "Toxic", "Candy", "Frost",
    "Inferno", "Shadow", "Aurora", "Galaxy", "Solar", "Rainbow"
}

local WorldOrder = {"World1", "World2", "World3", "World4", "World5", "World6", "World7"}

local WorldMap = {
    World1 = {LobbyPath = {"Lobby"},           MinRebirth = 0},
    World2 = {LobbyPath = {"World2", "Lobby"}, MinRebirth = 12},
    World3 = {LobbyPath = {"World3", "Lobby"}, MinRebirth = 40},
    World4 = {LobbyPath = {"World4", "Lobby"}, MinRebirth = 88},
    World5 = {LobbyPath = {"World5", "Lobby"}, MinRebirth = 151},
    World6 = {LobbyPath = {"World6", "Lobby"}, MinRebirth = 195},
    World7 = {LobbyPath = {"World7", "Lobby"}, MinRebirth = 265},
}

local cfg = {
    ToggleDelay      = 1,
    TrainDelay       = 0.15,
    TrainBurst       = 5,
    TrainUseTeleport = true,
    TrainArriveDelay = 1,
    LaunchArg        = 0.3,
    ArriveDelay      = 0.2,
    ThrowWait        = 2,
    MaxWait          = 9.25,
    RebirthDelay     = 2,
    TapDelay         = 0.2,
    UpgradeDelay     = 30,
    PlaneCheckDelay  = 1,
    AutoEquipPlane   = true,
    TrailCheckDelay  = 1,
    AutoEquipTrail   = true,
    EggId            = "",
    BuyEggDelay      = 0.5,
    RunwayDelay      = 3,
    ClaimDelay       = 30,
    PlaytimeSlots    = 12,
    World            = worlds[1],
}

-- ============================================================
-- DelayedToggle — FIXED: captures state correctly
-- ============================================================

local function DelayedToggle(fn)
    local token = 0
    return function(state)
        token = token + 1
        local mine     = token
        local captured = state  -- capture state at time of call
        task.delay(cfg.ToggleDelay, function()
            if token == mine then
                fn(captured)
            end
        end)
    end
end

-- ============================================================
-- Movement helpers
-- ============================================================

local function GetRoot()
    local char = Player.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function MoveTo(cf)
    local root = GetRoot()
    if not root then return false end
    root.AssemblyLinearVelocity = Vector3.zero
    root.CFrame = cf
    return true
end

local function WaitAlive(seconds, alive)
    local t0 = os.clock()
    while alive() and os.clock() - t0 < seconds do
        task.wait(0.05)
    end
end

-- ============================================================
-- Lobby & world helpers
-- ============================================================

local function GetLobbyForWorld(worldKey)
    local map = WorldMap[worldKey]
    if not map then return nil end
    local inst = workspace
    for _, part in ipairs(map.LobbyPath) do
        inst = inst and inst:FindFirstChild(part)
    end
    return inst
end

local function GetLobbyLabel(worldKey)
    local lobby = GetLobbyForWorld(worldKey)
    local area  = lobby and lobby:FindFirstChild("LaunchArea")
    local zone  = area  and area:FindFirstChild("ThrowZone")
    return zone and zone:FindFirstChild("Label", true)
end

local function GetActiveWorldKey()
    local d        = GetData()
    local rebirths = d and (d.Rebirths or 0) or 0
    for _, key in ipairs(WorldOrder) do
        if rebirths >= WorldMap[key].MinRebirth and GetLobbyLabel(key) then
            return key
        end
    end
    for i = #WorldOrder, 2, -1 do
        local key = WorldOrder[i]
        if rebirths >= WorldMap[key].MinRebirth and GetLobbyForWorld(key) then
            return key
        end
    end
    return "World1"
end

-- ============================================================
-- World center cache (for proximity detection)
-- ============================================================

local worldCenterCache = {}

local function GetWorldCenter(worldKey)
    local lobby = GetLobbyForWorld(worldKey)
    if not lobby then return nil end
    local cached = worldCenterCache[worldKey]
    if cached and cached.Lobby == lobby then return cached.Pos end
    local sum, n = Vector3.zero, 0
    for _, child in ipairs(lobby:GetChildren()) do
        local taken = 0
        if child:IsA("BasePart") then
            sum = sum + child.Position
            n   = n + 1
            taken = 1
        end
        for _, d in ipairs(child:GetDescendants()) do
            if d:IsA("BasePart") then
                sum   = sum + d.Position
                n     = n + 1
                taken = taken + 1
                if taken >= 10 then break end
            end
        end
    end
    if n == 0 then return nil end
    local pos = sum / n
    worldCenterCache[worldKey] = {Lobby = lobby, Pos = pos}
    return pos
end

local lastKnownWorld = nil

local function GetCurrentWorldKey()
    local root = GetRoot()
    if root then
        local bestKey, bestDist = nil, math.huge
        for _, key in ipairs(WorldOrder) do
            local pos = GetWorldCenter(key)
            if pos then
                local dist = (root.Position - pos).Magnitude
                if dist < bestDist then
                    bestDist, bestKey = dist, key
                end
            end
        end
        if bestKey then
            lastKnownWorld = bestKey
            return bestKey
        end
    end
    if lastKnownWorld and GetLobbyForWorld(lastKnownWorld) then
        return lastKnownWorld
    end
    local d = GetData()
    local w = d and (d.World or d.CurrentWorld or d.WorldId)
    if type(w) == "number" then
        local key = "World" .. tostring(w)
        if WorldMap[key] then
            lastKnownWorld = key; return key
        end
    elseif type(w) == "string" then
        local key = w:gsub("%s+", "")
        if WorldMap[key] then
            lastKnownWorld = key; return key
        end
    end
    local rebirths = d and tonumber(d.Rebirths) or 0
    local best = "World1"
    for _, key in ipairs(WorldOrder) do
        if rebirths >= WorldMap[key].MinRebirth and GetLobbyForWorld(key) then
            best = key
        end
    end
    lastKnownWorld = best
    return best
end

-- ============================================================
-- Egg helpers (kept for later use, no UI)
-- ============================================================

local function LabelText(lbl)
    if not lbl then return "" end
    local ok, t = pcall(function()
        if lbl.Text and lbl.Text ~= "" then return lbl.Text end
        return lbl.LocalizedText or ""
    end)
    return ok and t or ""
end

local function ResolveEggId(ep, tag, displayName)
    local id
    pcall(function()
        id = ep:GetAttribute("EggId") or ep:GetAttribute("Egg")
        if not id and tag then
            id = tag:GetAttribute("EggId") or tag:GetAttribute("Egg")
        end
    end)
    if not id then
        local v = ep:FindFirstChild("EggId", true) or ep:FindFirstChild("Egg", true)
        if v and v:IsA("StringValue") and v.Value ~= "" then id = v.Value end
    end
    if id and id ~= "" then return tostring(id) end
    local cleaned = displayName:gsub("[Ee][Gg][Gg]", ""):gsub("[^%w]", "")
    if cleaned == "" then return displayName end
    return "Egg" .. cleaned
end

local function ReadEggPlatform(ep)
    local nameLbl, amountLbl, priceLbl, tag
    for _, d in ipairs(ep:GetDescendants()) do
        if d.Name == "Robux" and d:IsA("GuiObject") then
            return nil
        elseif d.Name == "EggName"  and (d:IsA("TextLabel") or d:IsA("TextButton")) then nameLbl   = d
        elseif d.Name == "Amount"   and (d:IsA("TextLabel") or d:IsA("TextButton")) then amountLbl = d
        elseif d.Name == "Price"    and (d:IsA("TextLabel") or d:IsA("TextButton")) then priceLbl  = d
        elseif d.Name == "EggTag"   then tag = d
        end
    end
    local displayName = LabelText(nameLbl)
    if displayName == "" then displayName = ep.Name end
    displayName = displayName:gsub("^%s+", ""):gsub("%s+$", "")
    local priceText = LabelText(amountLbl)
    if priceText == "" then priceText = LabelText(priceLbl) end
    if priceText == "" then priceText = "?" end
    return {Id = ResolveEggId(ep, tag, displayName), Name = displayName, Price = priceText, PlatformInst = ep}
end

local function GetEggList(worldKey)
    local lobby = GetLobbyForWorld(worldKey)
    if not lobby then return {} end
    local platforms = lobby:FindFirstChild("EggPlatforms")
    if not platforms then return {} end
    local list = {}
    for _, ep in ipairs(platforms:GetChildren()) do
        if ep.Name:match("^EggPlatform%d+$") then
            local info = ReadEggPlatform(ep)
            if info then list[#list + 1] = info end
        end
    end
    table.sort(list, function(a, b)
        local na = tonumber(a.PlatformInst.Name:match("%d+")) or 0
        local nb = tonumber(b.PlatformInst.Name:match("%d+")) or 0
        return na < nb
    end)
    local used = {}
    for _, info in ipairs(list) do
        local display = info.Name .. " (" .. info.Price .. ")"
        if used[display] then display = display .. " [" .. info.PlatformInst.Name .. "]" end
        used[display] = true
        info.DisplayName = display
    end
    return list
end

local function BuyEggOnce()
    local id = cfg.EggId
    if not id or id == "" then return end
    Call("BuyEgg", id, 1)
end

-- ============================================================
-- Training pad helpers
-- ============================================================

local function ReadPlatformReq(tp)
    local title = tp:FindFirstChild("PlatformTitle")
    title = title and title:FindFirstChild("Title")
    local lbl = title and title:FindFirstChild("Rebirths")
    if not lbl then return nil end
    return tonumber(lbl.LocalizedText) or tonumber(lbl.Text)
end

local function GetTPCFrame(tp)
    local part = tp:FindFirstChild("Pad")
    if not part then return nil end
    if part:IsA("BasePart") then
        return CFrame.new(part.Position + Vector3.new(0, 3, 0))
    elseif part:IsA("Model") then
        return part:GetPivot() + Vector3.new(0, 3, 0)
    end
    return nil
end

local function CollectFreePlatforms(lobby)
    local list = {}
    for _, c in ipairs(lobby:GetChildren()) do
        if c.Name:match("^TrainingPlatform%d+$") then
            local req = ReadPlatformReq(c)
            local cf  = GetTPCFrame(c)
            if req and cf then
                list[#list + 1] = {Inst = c, Req = req, CF = cf}
            end
        end
    end
    table.sort(list, function(a, b) return a.Req < b.Req end)
    return list
end

local platformCache = {}

local function GetFreePlatforms(worldKey)
    local lobby = GetLobbyForWorld(worldKey)
    if not lobby then return {} end
    local cached = platformCache[worldKey]
    if cached and #cached > 0 and cached[1].Inst.Parent == lobby then return cached end
    local list = CollectFreePlatforms(lobby)
    if #list > 0 then platformCache[worldKey] = list end
    return list
end

local function GetBestPadCFrame(worldKey, rebirths)
    local platforms = GetFreePlatforms(worldKey)
    local bestCF, bestReq, bestName = nil, -1, "?"
    for _, p in ipairs(platforms) do
        if rebirths >= p.Req and p.Req > bestReq then
            bestReq  = p.Req
            bestCF   = p.CF
            bestName = p.Inst.Name
        end
    end
    return bestCF, bestReq, bestName
end

local function GetBestPad()
    local d        = GetData()
    local rebirths = d and (d.Rebirths or 0) or 0
    local worldKey = GetActiveWorldKey()
    local cf, req, name = GetBestPadCFrame(worldKey, rebirths)
    if not cf then return nil end
    return worldKey, cf, req, name, rebirths
end

local function GetNextPad(worldKey, rebirths)
    local platforms = GetFreePlatforms(worldKey)
    local nextReq, nextName = math.huge, nil
    for _, p in ipairs(platforms) do
        if p.Req > rebirths and p.Req < nextReq then
            nextReq  = p.Req
            nextName = p.Inst.Name
        end
    end
    return nextName, nextReq
end

-- ============================================================
-- Auto Train / Throw / Rebirth
-- ============================================================

local trainActivePad = nil
local throwingActive = false
local TrainPadProx   = 5

local function IsUserNearCF(cf)
    local root = GetRoot()
    if not root or not cf then return false end
    return (root.Position - cf.Position).Magnitude <= TrainPadProx
end

local function TeleportToBestPad(alive)
    local worldKey, cf, req, name = GetBestPad()
    if not worldKey then return false end
    if not cf then
        Notify("Auto Train", "No pad found in " .. worldKey, 3)
        return false
    end
    MoveTo(cf)
    if alive then WaitAlive(cfg.TrainArriveDelay, alive) end
    local padKey = worldKey .. ":" .. tostring(req)
    if padKey ~= trainActivePad then
        trainActivePad = padKey
        Notify("Auto Train", "[" .. worldKey .. "] " .. name .. " (min rebirth " .. req .. ")", 3)
    end
    return true
end

local function TrainCycle(alive)
    CheckRebirthChange()
    if throwingActive then task.wait(0.2) return end
    if not GetRoot() then task.wait(1) return end

    local worldKey, cf = GetBestPad()
    if not worldKey then task.wait(1) return end

    if cfg.TrainUseTeleport then
        if not cf then task.wait(1) return end
        if forceTeleportPad or not IsUserNearCF(cf) then
            if not TeleportToBestPad(alive) then task.wait(1) return end
            forceTeleportPad = false
            if not alive() or throwingActive then return end
        end
    end

    for _ = 1, cfg.TrainBurst do
        if not alive() or throwingActive then return end
        task.spawn(pcall, function() Call("Train") end)
        task.wait(cfg.TrainDelay)
    end
end

local function GetLabelCFrame()
    local label = GetLobbyLabel(GetActiveWorldKey())
    if not label then return nil end
    if label:IsA("BasePart") then
        return CFrame.new(label.Position + Vector3.new(0, 3, 0))
    elseif label:IsA("Model") then
        return label:GetPivot() + Vector3.new(0, 3, 0)
    end
    return nil
end

local warnedLabel = false

local function ThrowCycle(alive)
    if not GetRoot() then task.wait(1) return end
    throwingActive = true
    local ok, err = pcall(function()
        local root   = GetRoot()
        if not root then return end
        local origin = root.CFrame
        local target = GetLabelCFrame()
        if not target and not warnedLabel then
            warnedLabel = true
            Notify("Throw", "ThrowZone.Label not found, throwing in place", 4)
        end
        if target then
            MoveTo(target)
            WaitAlive(cfg.ArriveDelay, alive)
        end
        if not alive() then return end
        task.spawn(function() Call("Launch", cfg.LaunchArg) end)
        WaitAlive(cfg.ThrowWait, alive)
        if target then MoveTo(origin) end
    end)
    throwingActive = false
    if not ok then warn("[PPT] ThrowCycle error:", err) end
    WaitAlive(cfg.MaxWait, alive)
end

local startTrain   = SeqLoop("Train", TrainCycle)
local startThrow   = SeqLoop("Throw", ThrowCycle)
local startRebirth = AutoLoop("Rebirth",
    function() return cfg.RebirthDelay end,
    function() Call("Rebirth") end)

local function SetThrow(state)
    startThrow(state)
    if not state then throwingActive = false end
end

local function SetTrain(state)
    trainOn = state and true or false
    startTrain(state)
end

local function SetRebirth(state)
    rebirthOn = state and true or false
    startRebirth(state)
end

-- ============================================================
-- Tab: Auto Farm
-- ============================================================

local tabFarm = GUI:CreateTab({Name = "Auto Farm", Icon = 4483362458})

tabFarm:CreateSection({Name = "Auto Farm"})

local trainStatus = NewParagraph(tabFarm, "Train Status", "Idle")

task.spawn(function()
    while true do
        task.wait(2)
        local d           = GetData()
        local rebirths    = d and (d.Rebirths or 0) or 0
        local worldKey, _, req, name = GetBestPad()
        local activeWorld = worldKey or "World1"
        local nextName, nextReq = GetNextPad(activeWorld, rebirths)
        local text = "Rebirths: " .. rebirths .. "\nWorld: " .. activeWorld
        if name then text = text .. "\nActive pad: " .. name .. " (min " .. req .. ")" end
        if nextName then text = text .. "\nNext: " .. nextName .. " (needs " .. nextReq .. ")"
        else             text = text .. "\nHighest pad reached" end
        if throwingActive then text = text .. "\nThrowing (train paused)" end
        trainStatus:Set(text)
    end
end)

tabFarm:CreateToggle({
    Name         = "Auto Train",
    Description  = "Train on the best pad",
    CurrentValue = false,
    Flag         = "AutoTrain",
    Callback     = DelayedToggle(SetTrain)
})

tabFarm:CreateToggle({
    Name         = "Auto Throw",
    Description  = "Throw the Plane on loop",
    CurrentValue = false,
    Flag         = "AutoThrow",
    Callback     = DelayedToggle(SetThrow)
})

tabFarm:CreateToggle({
    Name         = "Auto Rebirth",
    Description  = "Rebirth when ready",
    CurrentValue = true,
    Flag         = "AutoRebirth",
    Callback     = DelayedToggle(SetRebirth)
})

tabFarm:CreateToggle({
    Name         = "Teleport to Training Pad",
    Description  = "Off = train from where you stand",
    CurrentValue = true,
    Flag         = "TrainUseTeleport",
    -- Direct apply, no delay needed for a config flag
    Callback     = function(v)
        cfg.TrainUseTeleport = v
    end
})

-- ============================================================
-- Tab: Shop & Upgrades
-- ============================================================

local tabShop = GUI:CreateTab({Name = "Shop & Upgrades", Icon = 4483362458})

tabShop:CreateSection({Name = "Upgrades"})

local shopStatus = NewParagraph(tabShop, "Upgrade Status", "Bat: Idle\nTrail: Idle")

local PlaneText, trailText, lastShopText = "Idle", "Idle", ""

local function RefreshShopStatus()
    local text = "Bat: " .. PlaneText .. "\nTrail: " .. trailText
    if text ~= lastShopText then
        lastShopText = text
        shopStatus:Set(text)
    end
end

local function SetPlaneStatus(text)
    PlaneText = (text:gsub("\n", " | "))
    RefreshShopStatus()
end

local function SetTrailStatus(text)
    trailText = (text:gsub("\n", " | "))
    RefreshShopStatus()
end

local function NextPlane(d)
    local unlocked = d.UnlockedWorld or 1
    local owned    = d.OwnedPlanes   or {}
    for _, p in ipairs(PlaneList) do
        if not owned[p.Id] and p.World <= unlocked then return p end
    end
    return nil
end

local lastBuyId, lastBuyTime = nil, 0

local function PlaneUpgradeStep()
    local d = GetData()
    if not d then SetPlaneStatus("Waiting for player data...") return end
    local p = NextPlane(d)
    if not p then SetPlaneStatus("All Bats owned") return end
    local trophies  = d.Trophies or 0
    local exp       = d.Exp      or 0
    local canAfford = trophies >= p.TrophyPrice and exp >= p.ExpPrice
    if canAfford then
        if lastBuyId == p.Id and os.clock() - lastBuyTime < 3 then return end
        lastBuyId, lastBuyTime = p.Id, os.clock()
        SetPlaneStatus("Buying " .. p.Id .. "...")
        Call("BuyBat", p.Id)
        task.wait(0.5)
        if cfg.AutoEquipPlane then Call("EquipBat", p.Id) end
        Notify("Bat", "Bought " .. p.Id .. " (" .. Short(p.TrophyPrice) .. ")")
    else
        SetPlaneStatus("Next: " .. p.Id .. "\nPrice: " .. Short(p.TrophyPrice) .. " | Have: " .. Short(trophies))
    end
end

local lastBuyTrailId, lastBuyTrailTime = nil, 0

local function TrailUpgradeStep()
    local d = GetData()
    if not d then SetTrailStatus("Waiting for player data...") return end
    local owned     = d.OwnedTrails or {}
    local nextTrail = nil
    for _, id in ipairs(trailIds) do
        if not owned[id] then nextTrail = id break end
    end
    if not nextTrail then SetTrailStatus("All trails owned") return end
    if lastBuyTrailId == nextTrail and os.clock() - lastBuyTrailTime < 5 then return end
    lastBuyTrailId, lastBuyTrailTime = nextTrail, os.clock()
    SetTrailStatus("Buying " .. nextTrail .. "...")
    Call("BuyTrail", nextTrail)
    task.wait(0.5)
    local d2     = GetData()
    local owned2 = d2 and (d2.OwnedTrails or {}) or {}
    if owned2[nextTrail] then
        if cfg.AutoEquipTrail then Call("EquipTrail", nextTrail) end
        Notify("Trail", "Bought " .. nextTrail)
        lastBuyTrailId = nil
    else
        SetTrailStatus("Cannot afford: " .. nextTrail)
    end
end

local startPlane = AutoLoop("PlaneUpgrade",
    function() return cfg.PlaneCheckDelay end,
    PlaneUpgradeStep)
local startTrail = AutoLoop("TrailUpgrade",
    function() return cfg.TrailCheckDelay end,
    TrailUpgradeStep)

tabShop:CreateToggle({
    Name         = "Auto Upgrade Plane",
    Description  = "Buy the cheapest new Plane",
    CurrentValue = true,
    Flag         = "AutoUpgradePlane",
    Callback     = DelayedToggle(startPlane)
})

tabShop:CreateToggle({
    Name         = "Auto Upgrade Trail",
    Description  = "Buy and equip trails in order",
    CurrentValue = true,
    Flag         = "AutoUpgradeTrail",
    Callback     = DelayedToggle(startTrail)
})

-- ============================================================
-- Tab: Teleport & World
-- ============================================================

local tabWorld = GUI:CreateTab({Name = "Teleport & World", Icon = 4483362458})

tabWorld:CreateSection({Name = "World Teleport"})
tabWorld:CreateDropdown({
    Name          = "Select World",
    Options       = worlds,
    CurrentOption = worlds[1],
    Flag          = "SelectedWorld",
    Callback      = function(opt)
        if type(opt) == "table" then opt = opt[1] end
        if opt then cfg.World = opt end
    end
})
tabWorld:CreateButton({
    Name     = "Teleport to Selected World",
    Interact = "Teleport",
    Flag     = "TeleportWorld",
    Callback = function()
        local index = table.find(worlds, cfg.World) or 1
        Call("TeleportWorld", index)
        Notify("Teleport", "Teleporting to " .. tostring(cfg.World), 3)
    end
})

-- ============================================================
-- Background tasks (always on)
-- ============================================================

Player.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)

AutoLoop("TapBoost",
    function() return cfg.TapDelay end,
    function() Call("TapBoost") end)(true)

AutoLoop("UpgradeAll",
    function() return cfg.UpgradeDelay end,
    function()
        for _, id in ipairs(upgradeIds) do
            Call("BuyUpgrade", id)
            task.wait(0.1)
        end
    end)(true)

local function ClaimAll()
    local d  = GetData()
    local pt = d and d.Playtime
    local claimed = pt and pt.Claimed or {}
    local slots   = (pt and type(pt.Amounts) == "table" and #pt.Amounts > 0)
        and #pt.Amounts or cfg.PlaytimeSlots
    for i = 1, slots do
        if not (claimed[i] or claimed[tostring(i)]) then
            Call("ClaimPlaytime", i)
            task.wait(0.3)
        end
    end
    Call("ClaimDaily")  task.wait(0.3)
    Call("ClaimOffline") task.wait(0.3)
    if not (d and d.GroupChestClaimed) then
        Call("ClaimGroupChest") task.wait(0.3)
    end
    Call("IndexClaim")
end

AutoLoop("Claims",
    function() return cfg.ClaimDelay end,
    ClaimAll)(true)

-- ============================================================
-- Defaults ON — FIXED: respect saved flags from JSON
-- ============================================================

task.defer(function()
    -- Wait for GUI to finish loading saved flags from settings_v17.json
    task.wait(0.5)

    -- Read saved flags; nil means first run → default true
    local function ReadFlag(flag, default)
        local ok, val = pcall(function() return GUI:GetFlag(flag) end)
        if not ok or val == nil then return default end
        return val
    end

    local flagTrain    = ReadFlag("AutoTrain",          true)
    local flagThrow    = ReadFlag("AutoThrow",          true)
    local flagRebirth  = ReadFlag("AutoRebirth",        true)
    local flagPlane    = ReadFlag("AutoUpgradePlane",   true)
    local flagTrail    = ReadFlag("AutoUpgradeTrail",   true)
    local flagTeleport = ReadFlag("TrainUseTeleport",   true)

    cfg.TrainUseTeleport = flagTeleport

    SetTrain(flagTrain)
    SetThrow(flagThrow)
    SetRebirth(flagRebirth)
    startPlane(flagPlane)
    startTrail(flagTrail)

    Notify("BulbGui Loaded", "Script v17 loaded!", 5)
end)
