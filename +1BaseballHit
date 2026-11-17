local RobloxGui = loadstring(game:HttpGet("https://pastebin.com/raw/2BGUWvbd"))()

local GUI = RobloxGui:Init({
    Name = "Paper Plane Auto",
    Subtitle = "Automation, Shop & ESP",
    FolderName = "PPS_Configs",
    FileName = "settings_v6.json"
})

local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
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

local function ParseArg(str)
    if str == nil or str == "" then return nil end
    return tonumber(str) or str
end

local function CallOpt(name, argStr)
    local a = ParseArg(argStr)
    if a == nil then return Call(name) end
    return Call(name, a)
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

local function Dump(tbl, depth, seen)
    depth = depth or 0
    seen = seen or {}
    if type(tbl) ~= "table" then
        print(string.rep("  ", depth) .. tostring(tbl))
        return
    end
    if seen[tbl] or depth > 4 then return end
    seen[tbl] = true
    for k, v in pairs(tbl) do
        if type(v) == "table" then
            print(string.rep("  ", depth) .. tostring(k) .. ":")
            Dump(v, depth + 1, seen)
        else
            print(string.rep("  ", depth) .. tostring(k) .. " = " .. tostring(v))
        end
    end
end

local function Notify(title, content, dur)
    GUI:Notify({Title = title, Content = content, Duration = dur or 2})
end

local playerData = nil
do
    local ev = Remotes:FindFirstChild("DataUpdate", true)
    if ev and ev:IsA("RemoteEvent") then
        ev.OnClientEvent:Connect(function(d)
            if type(d) == "table" then playerData = d end
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

local planeIds = {}
for _, p in ipairs(planeList) do table.insert(planeIds, p.Id) end

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

local potionKinds = {"Power", "Wins", "Lucky"}
local potionMinutes = {"5", "15", "30"}

-- ============================================================
-- PlatformMap: semua world
--
-- Req       = RebirthsRequired global (dari GameConfig)
-- Index     = angka N pada TrainingPlatformN. Jika nil, platform dicari
--             otomatis lewat JARAK (lihat BuildPlatformChain): TrainingPlatform1
--             = rebirth 0, pad berikutnya = platform terdekat dari pad sebelumnya.
-- MinRebirth= perkiraan rebirth saat tiba di world (TypicalArrival),
--             hanya dipakai sebagai fallback deteksi world.
-- Pad gamepass (Robux) sengaja tidak dimasukkan.
-- LobbyPath: World1 = workspace.Lobby, World N = workspace.World<N>.Lobby
-- ============================================================
local WorldOrder = {"World1", "World2", "World3", "World4", "World5", "World6", "World7"}

local PlatformMap = {
    World1 = {
        LobbyPath = {"Lobby"},
        MinRebirth = 0,
        Pads = {
            {Index = 1, Name = "Rookie",    Req = 0},
            {Index = 2, Name = "Halloween", Req = 2},
            {Index = 7, Name = "Space",     Req = 4},
            {Index = 3, Name = "Candy",     Req = 6},
        },
    },
    World2 = {
        LobbyPath = {"World2", "Lobby"},
        MinRebirth = 12,
        Pads = {
            {Index = 1, Name = "Jungle",  Req = 0},
            {Index = 7, Name = "Volcano", Req = 15},
            {Index = 2, Name = "Desert",  Req = 20},
            {Index = 3, Name = "Snow",    Req = 24},
        },
    },
    World3 = {
        LobbyPath = {"World3", "Lobby"},
        MinRebirth = 40,
        Pads = {
            {Name = "Dino Nest",   Req = 0},
            {Name = "Fossil Dig",  Req = 44},
            {Name = "Jungle Camp", Req = 50},
            {Name = "T-Rex Ruins", Req = 56},
        },
    },
    World4 = {
        LobbyPath = {"World4", "Lobby"},
        MinRebirth = 88,
        Pads = {
            {Name = "Royal Garden",   Req = 0},
            {Name = "Knight Arena",   Req = 92},
            {Name = "Wizard Academy", Req = 100},
            {Name = "Dragon's Keep",  Req = 113},
        },
    },
    World5 = {
        LobbyPath = {"World5", "Lobby"},
        MinRebirth = 151,
        Pads = {
            {Name = "Oasis Springs",  Req = 0},
            {Name = "Bazaar Alley",   Req = 154},
            {Name = "Pyramid Quarry", Req = 160},
            {Name = "Scarab Tomb",    Req = 169},
            {Name = "Sun Temple",     Req = 179},
        },
    },
    World6 = {
        LobbyPath = {"World6", "Lobby"},
        MinRebirth = 195,
        Pads = {
            {Name = "Cloud Meadow",     Req = 0},
            {Name = "Balloon Harbor",   Req = 200},
            {Name = "Windmill Heights", Req = 225},
            {Name = "Starlight Castle", Req = 245},
        },
    },
    World7 = {
        LobbyPath = {"World7", "Lobby"},
        MinRebirth = 265,
        Pads = {
            {Name = "Sandy Shore",     Req = 0},
            {Name = "Coral Reef",      Req = 270},
            {Name = "Kelp Forest",     Req = 280},
            {Name = "Sunken Ship",     Req = 295},
            {Name = "Treasure Grotto", Req = 315},
        },
    },
}

-- Pastikan Pads tiap world terurut naik berdasarkan Req (dipakai untuk rank jarak)
for _, w in pairs(PlatformMap) do
    table.sort(w.Pads, function(a, b) return a.Req < b.Req end)
end

local trainWorldOptions = {"Auto"}
for i = 1, #WorldOrder do table.insert(trainWorldOptions, "World " .. i) end

local cfg = {
    TrainDelay       = 0.15,
    TrainBurst       = 20,
    TrainUseTeleport = true,
    TrainArriveDelay = 1,
    TrainWorld       = "Auto",
    LaunchArg        = "0.3",
    UseTeleport      = true,
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
    -- BuyEgg remote butuh (EggId, 1)
    HatchRemote      = "BuyEgg",
    HatchDelay       = 0.5,
    RunwayDelay      = 3,
    PotionKind       = potionKinds[1],
    PotionMinutes    = potionMinutes[1],
    World            = worlds[1],
    RemoteName       = "Train",
    RemoteArg        = "",
    ClaimDelay       = 30,
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
    local path = PlatformMap[worldKey].LobbyPath
    local inst = workspace
    for _, part in ipairs(path) do
        inst = inst and inst:FindFirstChild(part)
    end
    return inst
end

local function GetLobbyLabel(worldKey)
    local lobby = GetLobbyForWorld(worldKey)
    local area = lobby and lobby:FindFirstChild("LaunchArea")
    local zone = area and area:FindFirstChild("ThrowZone")
    return zone and zone:FindFirstChild("Label", true)
end

-- Deteksi world aktif:
-- 1) Override manual dari dropdown (jika bukan "Auto")
-- 2) World terendah yang Label ThrowZone-nya ada dan syarat rebirth terpenuhi
-- 3) Fallback: world tertinggi yang lobby-nya ada dan syarat rebirth terpenuhi
local function GetActiveWorldKey()
    if cfg.TrainWorld and cfg.TrainWorld ~= "Auto" then
        local key = (cfg.TrainWorld:gsub(" ", ""))
        if PlatformMap[key] then return key end
    end

    local d = GetData()
    local rebirths = d and (d.Rebirths or 0) or 0

    for _, key in ipairs(WorldOrder) do
        if rebirths >= PlatformMap[key].MinRebirth and GetLobbyLabel(key) then
            return key
        end
    end

    for i = #WorldOrder, 2, -1 do
        local key = WorldOrder[i]
        if rebirths >= PlatformMap[key].MinRebirth and GetLobbyForWorld(key) then
            return key
        end
    end
    return "World1"
end

-- Kumpulkan semua teks yang mungkin menamai sebuah TrainingPlatform
local function PlatformTexts(tp)
    local t = {tp.Name}
    for _, v in pairs(tp:GetAttributes()) do
        if type(v) == "string" then t[#t + 1] = v end
    end
    for _, d in ipairs(tp:GetDescendants()) do
        if d:IsA("TextLabel") or d:IsA("TextButton") then
            t[#t + 1] = d.Text
        elseif d:IsA("StringValue") then
            t[#t + 1] = d.Value
        end
        if d.Name ~= "Pad" then t[#t + 1] = d.Name end
    end
    return t
end

-- ============================================================
-- Resolve platform lewat jarak
-- TrainingPlatform1 selalu rebirth 0. Pad berikutnya adalah platform
-- terdekat dari pad sebelumnya (nearest-neighbor chain), sehingga urutan
-- rantai = urutan syarat rebirth naik. Index 4,5,6 (Robux) diabaikan.
-- ============================================================
local RobuxPlatformIndex = {[4] = true, [5] = true, [6] = true}

local function PlatformPosition(tp)
    local part = tp:FindFirstChild("Pad")
    if part and part:IsA("BasePart") then return part.Position end
    if part and part:IsA("Model") then return part:GetPivot().Position end
    if tp:IsA("PVInstance") then return tp:GetPivot().Position end
    return nil
end

local platformChain = {}   -- cache: [worldKey] = {instance berurutan}

-- allowPartial = true untuk debug (tetap kembalikan rantai walau jumlahnya kurang)
local function BuildPlatformChain(worldKey, allowPartial)
    local lobby = GetLobbyForWorld(worldKey)
    if not lobby then return nil end

    local cached = platformChain[worldKey]
    if cached and cached[1] and cached[1].Parent == lobby then return cached end

    local items, first = {}, nil
    for _, c in ipairs(lobby:GetChildren()) do
        local n = c.Name:match("^TrainingPlatform(%d+)$")
        n = n and tonumber(n)
        if n and not RobuxPlatformIndex[n] then
            local pos = PlatformPosition(c)
            if pos then
                local item = {Inst = c, N = n, Pos = pos}
                if n == 1 then first = item else items[#items + 1] = item end
            end
        end
    end
    if not first then return nil end

    local chain, cur = {first.Inst}, first
    while #items > 0 do
        local bestI, bestD = 1, math.huge
        for i, it in ipairs(items) do
            local d = (it.Pos - cur.Pos).Magnitude
            if d < bestD then bestI, bestD = i, d end
        end
        cur = table.remove(items, bestI)
        chain[#chain + 1] = cur.Inst
    end

    -- Jangan cache / pakai rantai yang belum lengkap (mis. platform belum ter-stream)
    if #chain < #PlatformMap[worldKey].Pads then
        return allowPartial and chain or nil
    end
    platformChain[worldKey] = chain
    return chain
end

-- Cari instance TrainingPlatformN untuk sebuah pad
local function ResolvePlatform(worldKey, pad)
    local lobby = GetLobbyForWorld(worldKey)
    if not lobby then return nil end

    if pad.Index then
        return lobby:FindFirstChild("TrainingPlatform" .. pad.Index)
    end

    local rank = table.find(PlatformMap[worldKey].Pads, pad)
    local chain = rank and BuildPlatformChain(worldKey)
    return chain and chain[rank]
end

local function GetPadCFrame(pad, worldKey)
    worldKey = worldKey or GetActiveWorldKey()
    local tp = ResolvePlatform(worldKey, pad)
    if not tp then return nil end
    local part = tp:FindFirstChild("Pad")
    if not part then return nil end
    if part:IsA("BasePart") then
        return CFrame.new(part.Position + Vector3.new(0, 3, 0))
    elseif part:IsA("Model") then
        return part:GetPivot() + Vector3.new(0, 3, 0)
    end
    return nil
end

-- Kembalikan worldKey, pad terbaik sesuai rebirth user
local function GetBestPad()
    local d = GetData()
    local rebirths = d and (d.Rebirths or 0) or 0
    local worldKey = GetActiveWorldKey()
    local best = nil
    for _, pad in ipairs(PlatformMap[worldKey].Pads) do
        if rebirths >= pad.Req and (not best or pad.Req > best.Req) then
            best = pad
        end
    end
    if not best then return nil end
    return worldKey, best
end

-- ============================================================
-- Tab: Auto Farm
-- ============================================================

local tabFarm = GUI:CreateTab({Name = "Auto Farm", Icon = 4483362458})

-- ---- Auto Train ----

local trainActivePad    = nil   -- hanya untuk notifikasi saat pad berubah
local throwingActive    = false -- true selama proses throw
local TrainPadProximity = 5     -- studs
local warnedPad         = {}

local function IsUserNearPad(cf)
    local root = GetRoot()
    if not root or not cf then return false end
    return (root.Position - cf.Position).Magnitude <= TrainPadProximity
end

local function TeleportToBestPad(alive)
    local worldKey, pad = GetBestPad()
    if not worldKey then return false end
    local cf = GetPadCFrame(pad, worldKey)
    local warnKey = worldKey .. ":" .. pad.Name
    if not cf then
        if not warnedPad[warnKey] then
            warnedPad[warnKey] = true
            Notify("Auto Train", "Pad " .. pad.Name .. " (" .. worldKey .. ") tidak ditemukan. Jalankan Scan di tab Debug", 4)
        end
        return false
    end
    warnedPad[warnKey] = nil
    MoveTo(cf)
    if alive then WaitAlive(cfg.TrainArriveDelay, alive) end

    if warnKey ~= trainActivePad then
        Notify("Auto Train", "[" .. worldKey .. "] Pad: " .. pad.Name .. " (min rebirth " .. pad.Req .. ")", 3)
    end
    trainActivePad = warnKey
    return true
end

local function TrainCycle(alive)
    -- Auto Throw sedang berjalan: jangan teleport / train
    if throwingActive then task.wait(0.2) return end
    if not GetRoot() then task.wait(1) return end

    local worldKey, pad = GetBestPad()
    if not worldKey then task.wait(1) return end

    if cfg.TrainUseTeleport then
        local cf = GetPadCFrame(pad, worldKey)
        if not cf then
            if not TeleportToBestPad(nil) then task.wait(1) end
            return
        end
        if not IsUserNearPad(cf) then
            if not TeleportToBestPad(alive) then task.wait(1) return end
            if not alive() or throwingActive then return end
        end
    end

    for _ = 1, cfg.TrainBurst do
        if not alive() or throwingActive then return end
        task.spawn(pcall, function() Call("Train") end)
        task.wait(cfg.TrainDelay)
    end
end

tabFarm:CreateSection({Name = "Auto Train"})

local _, _, _, trainStatusObj = tabFarm:CreateParagraph({
    Title   = "Train Status",
    Content = "Idle"
})

task.spawn(function()
    while true do
        task.wait(2)
        local d        = GetData()
        local rebirths = d and (d.Rebirths or 0) or 0
        local worldKey, pad = GetBestPad()
        local activeWorld = worldKey or "World1"
        local nextPad = nil
        for _, p in ipairs(PlatformMap[activeWorld].Pads) do
            if p.Req > rebirths and (not nextPad or p.Req < nextPad.Req) then
                nextPad = p
            end
        end
        local text = "Rebirths: " .. rebirths
        text = text .. "\nWorld: " .. activeWorld
        if cfg.TrainWorld ~= "Auto" then text = text .. " (manual)" end
        if pad then
            text = text .. "\nPad aktif: " .. pad.Name .. " (min " .. pad.Req .. ")"
        end
        if nextPad then
            text = text .. "\nBerikutnya: " .. nextPad.Name .. " (butuh " .. nextPad.Req .. ")"
        else
            text = text .. "\nPad: sudah tertinggi di world ini"
        end
        if throwingActive then text = text .. "\nStatus: Throwing (train ditahan)" end
        if trainStatusObj then pcall(function() trainStatusObj:SetContent(text) end) end
    end
end)

tabFarm:CreateToggle({
    Name        = "Auto Train",
    Description = "Train di pad terbaik, teleport jika jarak > 5 studs dari pad",
    Flag        = "AutoTrain",
    Callback    = SeqLoop("Train", TrainCycle)
})

tabFarm:CreateToggle({
    Name         = "Teleport ke Pad Training",
    Description  = "Off = train dari posisi berdiri saja",
    CurrentValue = true,
    Flag         = "TrainUseTeleport",
    Callback     = function(v) cfg.TrainUseTeleport = v end
})

tabFarm:CreateDropdown({
    Name          = "Training World",
    Options       = trainWorldOptions,
    CurrentOption = "Auto",
    Flag          = "TrainWorld",
    Callback      = function(opt) cfg.TrainWorld = opt end
})

-- Server: cooldown train minimum 0.15s, jadi delay di bawah itu sia-sia
tabFarm:CreateSlider({
    Name         = "Train Delay",
    Range        = {0.15, 1},
    Increment    = 0.01,
    CurrentValue = cfg.TrainDelay,
    Suffix       = "s",
    Flag         = "TrainDelay",
    Callback     = function(v) cfg.TrainDelay = v end
})

tabFarm:CreateButton({
    Name     = "Teleport ke Pad Terbaik",
    Interact = "Go",
    Flag     = "TeleportBestPad",
    Callback = function()
        local ok = TeleportToBestPad(nil)
        if not ok then Notify("Train", "Pad tidak ditemukan di workspace") end
    end
})

-- ---- Auto Throw ----

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
        local root = GetRoot()
        if not root then return end
        local origin = root.CFrame
        local target = cfg.UseTeleport and GetLabelCFrame() or nil

        if cfg.UseTeleport and not target and not warnedLabel then
            warnedLabel = true
            Notify("Throw", "ThrowZone.Label not found, throwing from current position", 4)
        end

        if target then
            MoveTo(target)
            WaitAlive(cfg.ArriveDelay, alive)
        end
        if not alive() then return end

        task.spawn(function() CallOpt("Launch", cfg.LaunchArg) end)
        WaitAlive(cfg.ThrowWait, alive)

        if target then MoveTo(origin) end
    end)

    throwingActive = false
    if not ok then warn("[PPA] ThrowCycle error:", err) end

    WaitAlive(cfg.MaxWait, alive)
end

tabFarm:CreateSection({Name = "Auto Throw"})
tabFarm:CreateToggle({
    Name        = "Auto Throw",
    Description = "Label > Throw > wait > back > wait max > repeat",
    Flag        = "AutoThrow",
    Callback    = function(state)
        local loop = SeqLoop("Throw", ThrowCycle)
        loop(state)
        if not state then throwingActive = false end
    end
})
tabFarm:CreateToggle({
    Name         = "Teleport To Throw Zone",
    Description  = "Off = throw from where you stand",
    CurrentValue = true,
    Flag         = "UseTeleport",
    Callback     = function(v) cfg.UseTeleport = v end
})
tabFarm:CreateInput({
    Name            = "Launch Argument",
    PlaceholderText = "e.g. 0.3",
    CurrentValue    = cfg.LaunchArg,
    Flag            = "LaunchArg",
    Callback        = function(v) cfg.LaunchArg = v end
})
tabFarm:CreateSlider({
    Name         = "Arrive Delay",
    Range        = {0, 1.5},
    Increment    = 0.05,
    CurrentValue = cfg.ArriveDelay,
    Suffix       = "s",
    Flag         = "ArriveDelay",
    Callback     = function(v) cfg.ArriveDelay = v end
})
tabFarm:CreateSlider({
    Name         = "Wait After Throw",
    Range        = {0.5, 10},
    Increment    = 0.1,
    CurrentValue = cfg.ThrowWait,
    Suffix       = "s",
    Flag         = "ThrowWait",
    Callback     = function(v) cfg.ThrowWait = v end
})
tabFarm:CreateSlider({
    Name         = "Max Wait Before Next Throw",
    Range        = {1, 30},
    Increment    = 0.05,
    CurrentValue = cfg.MaxWait,
    Suffix       = "s",
    Flag         = "MaxWait",
    Callback     = function(v) cfg.MaxWait = v end
})
tabFarm:CreateButton({
    Name     = "Teleport To Label",
    Interact = "Go",
    Flag     = "TeleportToLabel",
    Callback = function()
        local cf = GetLabelCFrame()
        if cf and MoveTo(cf) then
            Notify("Teleport", "Moved to ThrowZone.Label")
        else
            Notify("Teleport", "ThrowZone.Label not found")
        end
    end
})

-- ---- Rebirth & Ascend ----

tabFarm:CreateSection({Name = "Rebirth & Ascend"})
tabFarm:CreateToggle({
    Name     = "Auto Rebirth",
    Flag     = "AutoRebirth",
    Callback = AutoLoop("Rebirth",
        function() return cfg.RebirthDelay end,
        function() Call("Rebirth") end)
})
tabFarm:CreateSlider({
    Name         = "Rebirth Delay",
    Range        = {0.5, 10},
    Increment    = 0.5,
    CurrentValue = cfg.RebirthDelay,
    Suffix       = "s",
    Flag         = "RebirthDelay",
    Callback     = function(v) cfg.RebirthDelay = v end
})
tabFarm:CreateButton({
    Name     = "Ascend",
    Interact = "Ascend",
    Flag     = "AscendButton",
    Callback = function()
        GUI:ConfirmationAction({
            Title       = "Ascend",
            Message     = "Ascend now? This may reset your progress.",
            ConfirmText = "Ascend",
            CancelText  = "Cancel",
            OnConfirm   = function()
                Call("Ascend")
                Notify("Ascend", "Ascend sent")
            end
        })
    end
})

-- ---- Tap Boost ----

tabFarm:CreateSection({Name = "Tap Boost"})
tabFarm:CreateToggle({
    Name     = "Auto Tap Boost",
    Flag     = "AutoTapBoost",
    Callback = AutoLoop("TapBoost",
        function() return cfg.TapDelay end,
        function() Call("TapBoost") end)
})
tabFarm:CreateSlider({
    Name         = "Tap Delay",
    Range        = {0.05, 2},
    Increment    = 0.05,
    CurrentValue = cfg.TapDelay,
    Suffix       = "s",
    Flag         = "TapDelay",
    Callback     = function(v) cfg.TapDelay = v end
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
tabEggs:CreateSlider({
    Name         = "Hatch Delay",
    Range        = {0.1, 3},
    Increment    = 0.1,
    CurrentValue = cfg.HatchDelay,
    Suffix       = "s",
    Flag         = "HatchDelay",
    Callback     = function(v) cfg.HatchDelay = v end
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
tabEggs:CreateSlider({
    Name         = "Runway Delay",
    Range        = {0.5, 10},
    Increment    = 0.5,
    CurrentValue = cfg.RunwayDelay,
    Suffix       = "s",
    Flag         = "RunwayDelay",
    Callback     = function(v) cfg.RunwayDelay = v end
})

-- ============================================================
-- Tab: Claims & Rewards
-- ============================================================

local tabClaims = GUI:CreateTab({Name = "Claims & Rewards", Icon = 4483362458})

local claims = {
    {"Claim Daily Reward",    "ClaimDaily"},
    {"Claim Playtime Gift",   "ClaimPlaytime"},
    {"Claim Offline Rewards", "ClaimOffline"},
    {"Claim Group Chest",     "ClaimGroupChest"},
    {"Claim Index Rewards",   "IndexClaim"},
}

local function ClaimAll()
    for _, c in ipairs(claims) do
        Call(c[2])
        task.wait(0.3)
    end
end

tabClaims:CreateSection({Name = "Manual Claims"})
for _, c in ipairs(claims) do
    tabClaims:CreateButton({
        Name     = c[1],
        Interact = "Claim",
        Flag     = "Claim_" .. c[2],
        Callback = function()
            Call(c[2])
            Notify("Claim", c[1] .. " sent")
        end
    })
end
tabClaims:CreateButton({
    Name     = "Claim Everything",
    Interact = "Claim All",
    Flag     = "ClaimAll",
    Callback = function()
        task.spawn(ClaimAll)
        Notify("Claim", "All claims sent")
    end
})

tabClaims:CreateSection({Name = "Auto Claim"})
tabClaims:CreateToggle({
    Name     = "Auto Claim All",
    Flag     = "AutoClaim",
    Callback = AutoLoop("Claims",
        function() return cfg.ClaimDelay end,
        ClaimAll)
})
tabClaims:CreateSlider({
    Name         = "Claim Interval",
    Range        = {10, 300},
    Increment    = 10,
    CurrentValue = cfg.ClaimDelay,
    Suffix       = "s",
    Flag         = "ClaimDelay",
    Callback     = function(v) cfg.ClaimDelay = v end
})

-- ============================================================
-- Tab: Shop & Upgrades
-- ============================================================

local tabShop = GUI:CreateTab({Name = "Shop & Upgrades", Icon = 4483362458})

tabShop:CreateSection({Name = "Upgrades"})

tabShop:CreateToggle({
    Name     = "Auto Buy All Upgrades",
    Flag     = "AutoUpgradeAll",
    Callback = AutoLoop("UpgradeAll",
        function() return cfg.UpgradeDelay end,
        function()
            for _, id in ipairs(upgradeIds) do
                Call("BuyUpgrade", id)
                task.wait(0.1)
            end
        end)
})

local _, _, _, planeStatus = tabShop:CreateParagraph({Title = "Plane Status", Content = "Idle"})
local lastPlaneText = ""
local function SetPlaneStatus(text)
    if text ~= lastPlaneText then lastPlaneText = text; planeStatus:SetContent(text) end
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

tabShop:CreateToggle({
    Name        = "Auto Upgrade Plane",
    Description = "Beli plane termurah yang belum dimiliki",
    Flag        = "AutoUpgradePlane",
    Callback    = AutoLoop("PlaneUpgrade",
        function() return cfg.PlaneCheckDelay end,
        PlaneUpgradeStep)
})

local _, _, _, trailStatus = tabShop:CreateParagraph({Title = "Trail Status", Content = "Idle"})
local lastTrailText = ""
local function SetTrailStatus(text)
    if text ~= lastTrailText then lastTrailText = text; trailStatus:SetContent(text) end
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
    -- coba lagi tiap 5 detik untuk trail yang sama
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

tabShop:CreateToggle({
    Name        = "Auto Upgrade Trail",
    Description = "Beli trail dari urutan pertama, equip otomatis",
    Flag        = "AutoUpgradeTrail",
    Callback    = AutoLoop("TrailUpgrade",
        function() return cfg.TrailCheckDelay end,
        TrailUpgradeStep)
})

tabShop:CreateSection({Name = "Potions"})
tabShop:CreateDropdown({
    Name          = "Potion Kind",
    Options       = potionKinds,
    CurrentOption = potionKinds[1],
    Flag          = "PotionKind",
    Callback      = function(opt) cfg.PotionKind = opt end
})
tabShop:CreateDropdown({
    Name          = "Duration (min)",
    Options       = potionMinutes,
    CurrentOption = potionMinutes[1],
    Flag          = "PotionMinutes",
    Callback      = function(opt) cfg.PotionMinutes = opt end
})
tabShop:CreateButton({
    Name     = "Use Potion",
    Interact = "Use",
    Flag     = "UsePotion",
    Callback = function()
        local id = cfg.PotionKind .. cfg.PotionMinutes
        Call("UsePotion", id)
        Notify("Potion", "Use: " .. id)
    end
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
-- Tab: Visuals & Player
-- ============================================================

local tabVisuals = GUI:CreateTab({Name = "Visuals & Player", Icon = 4483362458})

local espOn = false
local espHL = {}

local function clearESP(plr)
    if espHL[plr] then espHL[plr]:Destroy(); espHL[plr] = nil end
end

local function applyESP(plr)
    if plr == Player or not espOn then return end
    local char = plr.Character
    if not char then return end
    clearESP(plr)
    local hl = Instance.new("Highlight")
    hl.FillColor        = Color3.fromRGB(255, 0, 0)
    hl.OutlineColor     = Color3.fromRGB(255, 255, 255)
    hl.FillTransparency = 0.5
    hl.Parent           = char
    espHL[plr]          = hl
end

local function watchPlayer(plr)
    plr.CharacterAdded:Connect(function()
        task.wait(0.5)
        applyESP(plr)
    end)
end
for _, plr in ipairs(Players:GetPlayers()) do watchPlayer(plr) end
Players.PlayerAdded:Connect(watchPlayer)
Players.PlayerRemoving:Connect(clearESP)

tabVisuals:CreateSection({Name = "Player ESP"})
tabVisuals:CreateToggle({
    Name     = "Enable Player ESP",
    Flag     = "PlayerESP",
    Callback = function(state)
        espOn = state
        for _, plr in ipairs(Players:GetPlayers()) do
            if state then applyESP(plr) else clearESP(plr) end
        end
    end
})

local origLighting = {
    Brightness     = Lighting.Brightness,
    ClockTime      = Lighting.ClockTime,
    FogEnd         = Lighting.FogEnd,
    GlobalShadows  = Lighting.GlobalShadows,
    OutdoorAmbient = Lighting.OutdoorAmbient,
}

tabVisuals:CreateSection({Name = "Environment"})
tabVisuals:CreateToggle({
    Name     = "Fullbright",
    Flag     = "Fullbright",
    Callback = function(state)
        if state then
            Lighting.Brightness     = 2
            Lighting.ClockTime      = 14
            Lighting.FogEnd         = 100000
            Lighting.GlobalShadows  = false
            Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
        else
            for prop, val in pairs(origLighting) do Lighting[prop] = val end
        end
    end
})

local antiAfk = false
Player.Idled:Connect(function()
    if antiAfk then
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end
end)

tabVisuals:CreateSection({Name = "Utility"})
tabVisuals:CreateToggle({
    Name         = "Anti-AFK",
    CurrentValue = true,
    Flag         = "AntiAFK",
    Callback     = function(state) antiAfk = state end
})

-- ============================================================
-- Tab: Network & Debug
-- ============================================================

local tabNetwork = GUI:CreateTab({Name = "Network & Debug", Icon = 4483362458})

tabNetwork:CreateSection({Name = "Remote Tester"})
tabNetwork:CreateInput({
    Name            = "Remote Name",
    PlaceholderText = "e.g. Train, Launch, Rebirth",
    CurrentValue    = cfg.RemoteName,
    Flag            = "RemoteName",
    Callback        = function(v) cfg.RemoteName = v end
})
tabNetwork:CreateInput({
    Name            = "Argument",
    PlaceholderText = "empty = none, numbers are converted",
    Flag            = "RemoteArg",
    Callback        = function(v) cfg.RemoteArg = v end
})
tabNetwork:CreateButton({
    Name     = "Fire Remote Once",
    Interact = "Fire",
    Flag     = "FireRemote",
    Callback = function()
        if cfg.RemoteName == "" then return end
        local res = CallOpt(cfg.RemoteName, cfg.RemoteArg)
        print("[PPA] " .. cfg.RemoteName .. " returned:", res)
        Notify("Remote", "Fired: " .. cfg.RemoteName)
    end
})

tabNetwork:CreateSection({Name = "Inspect"})
tabNetwork:CreateButton({
    Name     = "List Remotes",
    Interact = "Print",
    Flag     = "ListRemotes",
    Callback = function()
        for _, r in ipairs(Remotes:GetDescendants()) do
            if r:IsA("RemoteEvent") or r:IsA("RemoteFunction") then
                print("[PPA]", r.ClassName, r.Name)
            end
        end
        Notify("Debug", "Remote list printed to console")
    end
})
tabNetwork:CreateButton({
    Name     = "Dump Player Data",
    Interact = "Dump",
    Flag     = "DumpPlayerData",
    Callback = function()
        local d = GetData()
        print("[PPA] Player data:")
        Dump(d)
        Notify("Debug", d and "Data printed to console" or "No data yet")
    end
})
tabNetwork:CreateButton({
    Name     = "Print Plane Prices",
    Interact = "Print",
    Flag     = "PrintPlanePrices",
    Callback = function()
        for _, p in ipairs(planeList) do
            print("[PPA]", p.Id, "World", p.World, "Trophies", p.TrophyPrice, "Exp", p.ExpPrice)
        end
        Notify("Debug", "Plane prices printed to console")
    end
})

-- Tampilkan hasil deteksi jarak: urutan platform -> pad, jarak antar platform,
-- dan pembanding dengan Index yang sudah diketahui (World 1 & 2)
tabNetwork:CreateButton({
    Name     = "Print Training Platforms",
    Interact = "Print",
    Flag     = "PrintTrainPads",
    Callback = function()
        for _, worldKey in ipairs(WorldOrder) do
            local pads = PlatformMap[worldKey].Pads
            local lobby = GetLobbyForWorld(worldKey)
            print("[PPA] === " .. worldKey .. (lobby and "" or " (lobby tidak ditemukan)") .. " ===")
            if lobby then
                local chain = BuildPlatformChain(worldKey, true)
                if not chain then
                    print("[PPA] TrainingPlatform1 tidak ditemukan")
                else
                    for i, inst in ipairs(chain) do
                        local pad = pads[i]
                        local dist = 0
                        if i > 1 then
                            local a, b = PlatformPosition(inst), PlatformPosition(chain[i - 1])
                            dist = (a and b) and (a - b).Magnitude or 0
                        end
                        local note = ""
                        if pad and pad.Index then
                            note = (inst.Name == "TrainingPlatform" .. pad.Index)
                                and "OK (cocok Index)" or ("BEDA! Index tersimpan: " .. pad.Index)
                        end
                        print("[PPA]", i, inst.Name, "->",
                            pad and (pad.Name .. " (req " .. pad.Req .. ")") or "(tidak ada pad)",
                            string.format("jarak dari sebelumnya: %.1f", dist), note)
                    end
                    if #chain ~= #pads then
                        print("[PPA] PERHATIAN: jumlah platform " .. #chain .. " tapi pad di map " .. #pads)
                    end
                end
            end
        end
        Notify("Debug", "Platform list printed to console")
    end
})

-- Scan semua TrainingPlatformN di setiap world beserta teks yang menamainya
-- Gunakan hasilnya untuk mengisi Index pad World 3-7 jika pencocokan nama gagal
tabNetwork:CreateButton({
    Name     = "Scan Training Pads (All Worlds)",
    Interact = "Scan",
    Flag     = "ScanPads",
    Callback = function()
        for _, worldKey in ipairs(WorldOrder) do
            local lobby = GetLobbyForWorld(worldKey)
            if not lobby then
                print("[PPA] " .. worldKey .. ": lobby tidak ditemukan (belum ter-load / path salah)")
            else
                print("[PPA] === " .. worldKey .. " ===")
                local list = {}
                for _, c in ipairs(lobby:GetChildren()) do
                    local n = c.Name:match("^TrainingPlatform(%d+)$")
                    if n then table.insert(list, {N = tonumber(n), Inst = c}) end
                end
                table.sort(list, function(a, b) return a.N < b.N end)
                for _, e in ipairs(list) do
                    local texts = {}
                    for _, t in ipairs(PlatformTexts(e.Inst)) do
                        if #texts < 6 and t ~= "" and t ~= e.Inst.Name then
                            table.insert(texts, t)
                        end
                    end
                    print("[PPA]", "TrainingPlatform" .. e.N,
                        "Pad:", e.Inst:FindFirstChild("Pad") ~= nil,
                        "texts:", table.concat(texts, " | "))
                end
            end
        end
        Notify("Debug", "Hasil scan dicetak ke console")
    end
})

Notify("Script Loaded", "Paper Plane Auto v8 initialized!", 5)
