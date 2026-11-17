local RobloxGui = loadstring(game:HttpGet("https://pastebin.com/raw/2BGUWvbd"))()

local GUI = RobloxGui:Init({
    Name = "Paper Plane Auto",
    Subtitle = "Automation & Shop",
    FolderName = "PPS_Configs",
    FileName = "settings_v12.json"
})

local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local VirtualUser = game:GetService("VirtualUser")

local Player = Players.LocalPlayer
local Remotes = RS:WaitForChild("Remotes", 10) or RS
local Shared = RS:FindFirstChild("Shared")

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
                    warn("[PPA] " .. id .. " error:", err)
                    task.wait(1)
                end
                task.wait()
            end
        end)
    end
end

local function Notify(title, content, dur)
    GUI:Notify({Title = title, Content = content, Duration = dur or 2})
end

local playerData = nil

-- State toggle (diisi lewat SetTrain / SetRebirth)
local trainOn, rebirthOn = false, false
-- true = paksa teleport ke pad terbaik pada siklus Train berikutnya
local forceTeleportPad = false
local lastRebirths = nil

-- Rebirth dianggap sukses jika jumlah Rebirths di data bertambah.
-- Jika Auto Train DAN Auto Rebirth ON, paksa teleport ke pad terbaik.
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

local planeList = {}
do
    local c = SafeRequire({"Config", "BatConfig"})
    if c and c.Bats then
        for _, b in ipairs(c.Bats) do
            if not b.RobuxPass and not b.Exclusive and (b.TrophyPrice or b.ExpPrice) then
                table.insert(planeList, {
                    Id = b.Id,
                    World = b.World or 1,
                    Level = b.Level or 0,
                    TrophyPrice = b.TrophyPrice or 0,
                    ExpPrice = b.ExpPrice or 0,
                })
            end
        end
    end
    if #planeList == 0 then
        local fallback = {
            {"WoodBat", 0}, {"MapleBat", 50}, {"AluminumBat", 75}, {"BlackInkBat", 150},
            {"CandyCaneBat", 300}, {"GoldenBat", 600}, {"IceBat", 1500}, {"LavaBat", 4500},
            {"GalaxyBat", 14000}, {"RainbowLegendBat", 40000},
        }
        for i, f in ipairs(fallback) do
            table.insert(planeList, {Id = f[1], World = 1, Level = i, TrophyPrice = f[2], ExpPrice = 0})
        end
    end
    table.sort(planeList, function(a, b)
        if a.TrophyPrice ~= b.TrophyPrice then return a.TrophyPrice < b.TrophyPrice end
        return a.Level < b.Level
    end)
end

local trailIds = {"Cloud", "Bubblegum", "Ocean", "Golden", "Toxic", "Candy", "Frost",
    "Inferno", "Shadow", "Aurora", "Galaxy", "Solar", "Rainbow"}

local eggIds = {"EggStone", "EggToxicScale", "EggFrostShard", "EggVoidCrystal"}
do
    local c = SafeRequire({"Config", "PetConfig"})
    if c and c.Eggs then
        local list = {}
        for id, egg in pairs(c.Eggs) do
            if not egg.Hidden and not egg.RunwayEgg then
                table.insert(list, {Id = id, World = egg.World or 1, Price = egg.Price or 0})
            end
        end
        table.sort(list, function(a, b)
            if a.World ~= b.World then return a.World < b.World end
            return a.Price < b.Price
        end)
        if #list > 0 then
            eggIds = {}
            for _, e in ipairs(list) do table.insert(eggIds, e.Id) end
        end
    end
end

-- ============================================================
-- WorldMap: hanya path ke lobby per world.
-- Req dibaca LANGSUNG dari TextLabel "Rebirths" di dalam setiap TrainingPlatform.
-- ============================================================
local WorldOrder = {"World1", "World2", "World3", "World4", "World5", "World6", "World7"}

local WorldMap = {
    World1 = {LobbyPath = {"Lobby"},          MinRebirth = 0},
    World2 = {LobbyPath = {"World2", "Lobby"}, MinRebirth = 12},
    World3 = {LobbyPath = {"World3", "Lobby"}, MinRebirth = 40},
    World4 = {LobbyPath = {"World4", "Lobby"}, MinRebirth = 88},
    World5 = {LobbyPath = {"World5", "Lobby"}, MinRebirth = 151},
    World6 = {LobbyPath = {"World6", "Lobby"}, MinRebirth = 195},
    World7 = {LobbyPath = {"World7", "Lobby"}, MinRebirth = 265},
}

-- Semua nilai tetap (tidak ada slider / input)
local cfg = {
    TrainDelay       = 0.15,   -- jeda antar spam Train (server minimum 0.15s)
    TrainBurst       = 5,      -- spam remote Train 5x per siklus
    TrainUseTeleport = true,
    TrainArriveDelay = 1,
    LaunchArg        = 0.3,    -- argumen remote Launch (tetap)
    ArriveDelay      = 0.2,
    ThrowWait        = 2,
    MaxWait          = 9.25,
    RebirthDelay     = 2,
    TapDelay         = 0.2,
    UpgradeDelay     = 1,
    PlaneCheckDelay  = 1,
    AutoEquipPlane   = true,
    TrailCheckDelay  = 1,
    AutoEquipTrail   = true,
    EggId            = eggIds[1],
    HatchRemote      = "BuyEgg",
    HatchDelay       = 0.5,
    RunwayDelay      = 3,
    ClaimDelay       = 30,     -- interval auto claim (detik)
    PlaytimeSlots    = 12,     -- ClaimPlaytime argumen 1..12 (fallback)
    World            = worlds[1],
}

-- ============================================================
-- Helpers shared
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
-- World & training pad helpers
-- ============================================================

local function GetLobbyForWorld(worldKey)
    local path = WorldMap[worldKey].LobbyPath
    local inst = workspace
    for _, part in ipairs(path) do
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
-- Platform helpers — baca Req dari TextLabel "Rebirths" di workspace
--
-- Struktur per TrainingPlatform:
--   TrainingPlatformN
--     Pad          (BasePart / Model)
--     PlatformTitle
--       Title
--         Rebirths (TextLabel) <- LocalizedText = angka minimal rebirth
--
-- Pad Robux tidak punya Rebirths label (atau nilainya bukan angka) -> dilewati.
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

-- Return: list {Inst, Req, CF} diurutkan Req naik
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
    if cached and #cached > 0 and cached[1].Inst.Parent == lobby then
        return cached
    end
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

-- Kembalikan worldKey, CF, Req, Name untuk pad terbaik saat ini
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
-- Auto Train / Auto Throw / Auto Rebirth (logic)
-- ============================================================

local trainActivePad = nil   -- "worldKey:req", untuk deteksi perubahan pad
local throwingActive = false
local TrainPadProx   = 5     -- studs

local function IsUserNearCF(cf)
    local root = GetRoot()
    if not root or not cf then return false end
    return (root.Position - cf.Position).Magnitude <= TrainPadProx
end

local function TeleportToBestPad(alive)
    local worldKey, cf, req, name = GetBestPad()
    if not worldKey then return false end
    if not cf then
        Notify("Auto Train", "Pad tidak ditemukan di " .. worldKey .. " (belum ter-load?)", 3)
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
        -- Teleport jika rebirth baru sukses (Auto Train + Auto Rebirth ON) atau jauh dari pad
        if forceTeleportPad or not IsUserNearCF(cf) then
            if not TeleportToBestPad(alive) then task.wait(1) return end
            forceTeleportPad = false
            if not alive() or throwingActive then return end
        end
    end

    -- Spam remote Train sebanyak TrainBurst (5x) per siklus
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

-- Selalu teleport ke ThrowZone.Label, throw, lalu kembali ke posisi awal
local function ThrowCycle(alive)
    if not GetRoot() then task.wait(1) return end
    throwingActive = true
    local ok, err = pcall(function()
        local root = GetRoot()
        if not root then return end
        local origin = root.CFrame
        local target = GetLabelCFrame()
        if not target and not warnedLabel then
            warnedLabel = true
            Notify("Throw", "ThrowZone.Label not found, throwing from current position", 4)
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
    if not ok then warn("[PPA] ThrowCycle error:", err) end
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

local _, _, _, trainStatusObj = tabFarm:CreateParagraph({
    Title   = "Train Status",
    Content = "Idle"
})

task.spawn(function()
    while true do
        task.wait(2)
        local d           = GetData()
        local rebirths    = d and (d.Rebirths or 0) or 0
        local worldKey, _, req, name = GetBestPad()
        local activeWorld = worldKey or "World1"
        local nextName, nextReq = GetNextPad(activeWorld, rebirths)
        local text = "Rebirths: " .. rebirths
        text = text .. "\nWorld: " .. activeWorld
        if name then text = text .. "\nPad aktif: " .. name .. " (min " .. req .. ")" end
        if nextName then
            text = text .. "\nBerikutnya: " .. nextName .. " (butuh " .. nextReq .. ")"
        else
            text = text .. "\nPad: sudah tertinggi di world ini"
        end
        if throwingActive then text = text .. "\nStatus: Throwing (train ditahan)" end
        if trainStatusObj then pcall(function() trainStatusObj:SetContent(text) end) end
    end
end)

tabFarm:CreateToggle({
    Name         = "Auto Train",
    Description  = "Train di pad terbaik (spam 5x). Teleport jika jarak > 5 studs / setelah rebirth sukses",
    CurrentValue = true,
    Flag         = "AutoTrain",
    Callback     = SetTrain
})

tabFarm:CreateToggle({
    Name         = "Auto Throw",
    Description  = "Label > Throw > wait > back > wait max > repeat",
    CurrentValue = true,
    Flag         = "AutoThrow",
    Callback     = SetThrow
})

tabFarm:CreateToggle({
    Name         = "Auto Rebirth",
    CurrentValue = true,
    Flag         = "AutoRebirth",
    Callback     = SetRebirth
})

tabFarm:CreateToggle({
    Name         = "Teleport ke Pad Training",
    Description  = "Off = train dari posisi berdiri saja",
    CurrentValue = true,
    Flag         = "TrainUseTeleport",
    Callback     = function(v) cfg.TrainUseTeleport = v end
})

-- ============================================================
-- Tab: Eggs & Pets
-- ============================================================

local tabEggs = GUI:CreateTab({Name = "Eggs & Pets", Icon = 4483362458})

tabEggs:CreateSection({Name = "Auto Hatching"})
tabEggs:CreateDropdown({
    Name          = "Egg",
    Options       = eggIds,
    CurrentOption = eggIds[1],
    Flag          = "EggId",
    Callback      = function(opt) cfg.EggId = opt end
})
tabEggs:CreateDropdown({
    Name          = "Hatch Remote",
    Options       = {"BuyEgg", "OpenEgg"},
    CurrentOption = "BuyEgg",
    Flag          = "HatchRemote",
    Callback      = function(opt) cfg.HatchRemote = opt end
})

local function HatchOnce()
    if cfg.HatchRemote == "BuyEgg" then
        Call("BuyEgg", cfg.EggId, 1)
    else
        Call(cfg.HatchRemote, cfg.EggId)
    end
end

tabEggs:CreateToggle({
    Name     = "Auto Hatch",
    Flag     = "AutoHatch",
    Callback = AutoLoop("Hatch",
        function() return cfg.HatchDelay end,
        HatchOnce)
})
tabEggs:CreateButton({
    Name     = "Hatch Once",
    Interact = "Hatch",
    Flag     = "HatchOnce",
    Callback = function()
        HatchOnce()
        Notify("Egg", cfg.HatchRemote .. ": " .. tostring(cfg.EggId))
    end
})

tabEggs:CreateSection({Name = "Runway Eggs"})
tabEggs:CreateToggle({
    Name     = "Auto Open Runway Egg",
    Flag     = "AutoRunway",
    Callback = AutoLoop("Runway",
        function() return cfg.RunwayDelay end,
        function() Call("OpenRunwayEgg") end)
})

-- ============================================================
-- Tab: Shop & Upgrades
-- ============================================================

local tabShop = GUI:CreateTab({Name = "Shop & Upgrades", Icon = 4483362458})

tabShop:CreateSection({Name = "Upgrades"})

-- Satu paragraf untuk status Plane dan Trail
local _, _, _, shopStatus = tabShop:CreateParagraph({
    Title   = "Upgrade Status",
    Content = "Plane: Idle\nTrail: Idle"
})

local planeText, trailText, lastShopText = "Idle", "Idle", ""

local function RefreshShopStatus()
    local text = "Plane: " .. planeText .. "\nTrail: " .. trailText
    if text ~= lastShopText then
        lastShopText = text
        if shopStatus then pcall(function() shopStatus:SetContent(text) end) end
    end
end

local function SetPlaneStatus(text)
    planeText = (text:gsub("\n", " | "))
    RefreshShopStatus()
end

local function SetTrailStatus(text)
    trailText = (text:gsub("\n", " | "))
    RefreshShopStatus()
end

local function NextPlane(d)
    local unlocked = d.UnlockedWorld or 1
    local owned    = d.OwnedPlanes   or {}
    for _, p in ipairs(planeList) do
        if not owned[p.Id] and p.World <= unlocked then return p end
    end
    return nil
end

local lastBuyId, lastBuyTime = nil, 0

local function PlaneUpgradeStep()
    local d = GetData()
    if not d then SetPlaneStatus("Waiting for player data...") return end
    local p = NextPlane(d)
    if not p then SetPlaneStatus("All available planes are owned") return end
    local trophies  = d.Trophies or 0
    local exp       = d.Exp      or 0
    local canAfford = trophies >= p.TrophyPrice and exp >= p.ExpPrice
    if canAfford then
        if lastBuyId == p.Id and os.clock() - lastBuyTime < 3 then return end
        lastBuyId, lastBuyTime = p.Id, os.clock()
        SetPlaneStatus("Buying " .. p.Id .. "...")
        Call("BuyPlane", p.Id)
        task.wait(0.5)
        if cfg.AutoEquipPlane then Call("EquipPlane", p.Id) end
        Notify("Plane", "Bought " .. p.Id .. " (" .. Short(p.TrophyPrice) .. ")")
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
    if not nextTrail then SetTrailStatus("All trails are owned") return end
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
        SetTrailStatus("Belum mampu beli: " .. nextTrail)
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
    Description  = "Beli plane termurah yang belum dimiliki",
    CurrentValue = true,
    Flag         = "AutoUpgradePlane",
    Callback     = startPlane
})

tabShop:CreateToggle({
    Name         = "Auto Upgrade Trail",
    Description  = "Beli trail dari urutan pertama, equip otomatis",
    CurrentValue = true,
    Flag         = "AutoUpgradeTrail",
    Callback     = startTrail
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
    Callback      = function(opt) cfg.World = opt end
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
-- Selalu aktif tanpa toggle (tidak ada di UI)
-- ============================================================

-- Anti-AFK
Player.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)

-- Auto Tap Boost
AutoLoop("TapBoost",
    function() return cfg.TapDelay end,
    function() Call("TapBoost") end)(true)

-- Auto Buy All Upgrades
AutoLoop("UpgradeAll",
    function() return cfg.UpgradeDelay end,
    function()
        for _, id in ipairs(upgradeIds) do
            Call("BuyUpgrade", id)
            task.wait(0.1)
        end
    end)(true)

-- Auto Claim Rewards
-- ClaimPlaytime(index) dipanggil untuk index 1..N (N = jumlah slot Playtime,
-- fallback PlaytimeSlots). Slot yang sudah ada di Playtime.Claimed dilewati.
local function ClaimAll()
    local d = GetData()
    local pt = d and d.Playtime
    local claimed = pt and pt.Claimed or {}
    local slots = (pt and type(pt.Amounts) == "table" and #pt.Amounts > 0) and #pt.Amounts
        or cfg.PlaytimeSlots

    for i = 1, slots do
        if not (claimed[i] or claimed[tostring(i)]) then
            Call("ClaimPlaytime", i)
            task.wait(0.3)
        end
    end

    Call("ClaimDaily")
    task.wait(0.3)
    Call("ClaimOffline")
    task.wait(0.3)
    if not (d and d.GroupChestClaimed) then
        Call("ClaimGroupChest")
        task.wait(0.3)
    end
    Call("IndexClaim")
end

AutoLoop("Claims",
    function() return cfg.ClaimDelay end,
    ClaimAll)(true)

-- ============================================================
-- Default ON: jalankan juga secara manual agar tetap aktif
-- walau GUI tidak memanggil Callback saat toggle dibuat.
-- (Aman dipanggil dua kali: loop lama otomatis berhenti.)
-- ============================================================
SetTrain(true)
SetThrow(true)
SetRebirth(true)
startPlane(true)
startTrail(true)

Notify("Script Loaded", "Paper Plane Auto v13 initialized!", 5)
