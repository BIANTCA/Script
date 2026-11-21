local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local VirtualUser = game:GetService("VirtualUser")

local LP = Players.LocalPlayer

-- ================= UI LIBRARY =================
local RobloxGui = loadstring(game:HttpGet("https://pastebin.com/raw/2BGUWvbd"))()
local Gui = RobloxGui
Gui:Init{
    Name = "Kick Farm",
    Subtitle = "Auto train, auto kick, auto economy",
    FolderName = "TumblrConfigs",
    FileName = "kickfarm.json"
}

-- ================= SAFE HELPERS =================
local function tryReq(path)
    if not path or not path:IsA("ModuleScript") then return nil end
    local ok, res = pcall(require, path)
    if ok and res ~= nil then return res end
    return nil
end

local function notify(title, text)
    pcall(function()
        Gui:Notify{Title = title, Content = tostring(text), Duration = 3}
    end)
end

local function fire(r, ...)
    if not r then return false end
    return (pcall(r.FireServer, r, ...))
end

local function invoke(r, ...)
    if not r then return false, nil end
    local ok, res = pcall(r.InvokeServer, r, ...)
    return ok, res
end

local function send(r, ...)
    if not r then return false, nil end
    if r:IsA("RemoteFunction") then
        return invoke(r, ...)
    end
    return fire(r, ...), nil
end

local function num(v)
    return (type(v) == "number" and v) or tonumber(v) or 0
end

-- ================= GAME MODULES =================
local ConfigFolder = RS:WaitForChild("Config", 30)
local SharedFolder = RS:FindFirstChild("Shared")

local function cfg(name)
    if not ConfigFolder then return nil end
    return tryReq(ConfigFolder:FindFirstChild(name))
end

local BallCfg   = cfg("BallConfig")
local TrainCfg  = cfg("TrainingConfig")
local KickCfg   = cfg("KickConfig")
local WorldCfg  = cfg("WorldConfig")
local ProgCfg   = cfg("ProgressionConfig")
local EggCfg    = cfg("EggConfig")
local PetCfg    = cfg("PetConfig")
local GameCfg   = cfg("GameConfig")

local Formulas = SharedFolder and tryReq(SharedFolder:FindFirstChild("Formulas")) or nil
local NumberFmt = SharedFolder and tryReq(SharedFolder:FindFirstChild("NumberFormat")) or nil

local SUFFIX = {"", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"}
local function abbrev(n)
    n = num(n)
    if NumberFmt and type(NumberFmt.Abbreviate) == "function" then
        local ok, s = pcall(NumberFmt.Abbreviate, n)
        if ok and s then return s end
    end
    local neg = n < 0
    n = math.abs(n)
    local i = 1
    while n >= 1000 and i < #SUFFIX do
        n = n / 1000
        i += 1
    end
    local s = (i > 1) and string.format("%.2f", n) .. SUFFIX[i] or tostring(math.floor(n))
    return neg and "-" .. s or s
end

-- ================= REMOTES =================
local RemotesFolder = RS:WaitForChild("Remotes", 30)

local function byName(name)
    if not RemotesFolder then return nil end
    local f = RemotesFolder:FindFirstChild(name, true)
    if f and (f:IsA("RemoteEvent") or f:IsA("RemoteFunction")) then return f end
    return nil
end

local function byKeyword(words)
    if not RemotesFolder then return nil end
    for _, d in ipairs(RemotesFolder:GetDescendants()) do
        if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") then
            local low = d.Name:lower()
            for _, w in ipairs(words) do
                if low:find(w) then return d end
            end
        end
    end
    return nil
end

local TrainRequest = byName("TrainRequest")
local KickRequest = byName("KickRequest")

local CANDIDATES = {
    Rebirth = {"RebirthRequest", "Rebirth", "RequestRebirth", "PerformRebirth", "DoRebirth"},
    Ball = {"BallRequest", "BallsRequest", "BuyBallRequest", "BallAction", "PurchaseBallRequest"},
    Egg = {"EggRequest", "EggsRequest", "HatchRequest", "HatchEggRequest", "EggAction", "HatchEgg"},
    Pet = {"PetRequest", "PetsRequest", "PetAction", "PetsAction"},
    Reward = {"RewardRequest", "RewardsRequest", "ClaimRewardRequest", "PlaytimeRequest", "ClaimPlaytimeRequest"},
    Travel = {"TravelRequest", "TravelToRequest", "WorldRequest", "TeleportRequest", "PortalRequest", "RequestTeleport"},
    Trail = {"TrailRequest", "TrailsRequest", "EquipTrailRequest", "TrailAction"},
}

local KEYWORDS = {
    Rebirth = {"rebirth"},
    Egg = {"hatch", "egg"},
    Pet = {"pet"},
    Reward = {"reward", "playtime"},
    Travel = {"travel", "teleport", "portal"},
}

local R = {}
for key, names in pairs(CANDIDATES) do
    for _, n in ipairs(names) do
        local r = byName(n)
        if r then R[key] = r break end
    end
    if not R[key] and KEYWORDS[key] then
        R[key] = byKeyword(KEYWORDS[key])
    end
end

-- ================= TOKEN WATCHER =================
local LastToken, LastTokenAt = nil, 0
do
    local function watchArgs(...)
        for _, a in ipairs({...}) do
            local t = type(a)
            if t == "number" and a >= 100000 and a == math.floor(a) then
                LastToken, LastTokenAt = a, os.clock()
            elseif t == "string" and #a <= 12 and tonumber(a) and tonumber(a) >= 100000 then
                LastToken, LastTokenAt = tonumber(a), os.clock()
            end
        end
    end
    if RemotesFolder then
        for _, d in ipairs(RemotesFolder:GetDescendants()) do
            if d:IsA("RemoteEvent") then
                pcall(function() d.OnClientEvent:Connect(watchArgs) end)
            end
        end
        RemotesFolder.DescendantAdded:Connect(function(d)
            if d:IsA("RemoteEvent") then
                task.wait(0.1)
                pcall(function() d.OnClientEvent:Connect(watchArgs) end)
            end
        end)
    end
end

local function getToken()
    if LastToken ~= nil and os.clock() - LastTokenAt < 3 then
        return LastToken
    end
    return nil
end

-- ================= PLAYER DATA =================
local function getStat(name)
    local ls = LP:FindFirstChild("leaderstats")
    if ls then
        local v = ls:FindFirstChild(name)
        if v and v:IsA("ValueBase") then
            local ok, val = pcall(function() return v.Value end)
            if ok then return val end
        end
    end
    local attr = LP:GetAttribute(name)
    if attr ~= nil then return attr end
    for _, fname in ipairs({"Stats", "Values", "Data", "PlayerData"}) do
        local f = LP:FindFirstChild(fname)
        if f then
            local v = f:FindFirstChild(name)
            if v and v:IsA("ValueBase") then
                local ok, val = pcall(function() return v.Value end)
                if ok then return val end
            end
        end
    end
    return nil
end

local function statNum(name)
    return num(getStat(name))
end

local S
local padCache, padCacheT = {}, 0
local ballCache, ballCacheT = nil, 0
local kickPadCache, kickPadCacheWorld = nil, nil

-- ================= REBIRTH COUNT (always updated) =================
local rbObj = nil
local rbAttr = nil

local function findRebirthSource()
    if rbObj and rbObj.Parent then return end
    rbObj = nil
    rbAttr = nil
    local exact = {"rebirths", "rebirth", "rebirthcount", "totalrebirths"}
    local found
    for _, d in ipairs(LP:GetDescendants()) do
        if d:IsA("ValueBase") then
            local low = d.Name:lower()
            for _, e in ipairs(exact) do
                if low == e then found = d break end
            end
            if found then break end
        end
    end
    if not found then
        for _, d in ipairs(LP:GetDescendants()) do
            if d:IsA("ValueBase") then
                local low = d.Name:lower()
                if low:find("rebirth") and not low:find("power") and not low:find("level")
                    and not low:find("cost") and not low:find("multi") then
                    found = d
                    break
                end
            end
        end
    end
    if found then rbObj = found return end
    for name, _ in pairs(LP:GetAttributes()) do
        local low = tostring(name):lower()
        if low:find("rebirth") and not low:find("power") and not low:find("level")
            and not low:find("cost") and not low:find("multi") then
            rbAttr = name
            return
        end
    end
end

local function refreshRebirths()
    findRebirthSource()
    local v
    if rbObj and rbObj.Parent then
        local ok, val = pcall(function() return rbObj.Value end)
        if ok then v = tonumber(val) end
    elseif rbAttr then
        v = tonumber(LP:GetAttribute(rbAttr))
    end
    if v == nil then
        local g = getStat("Rebirths") or getStat("Rebirth")
        v = tonumber(g)
    end
    if v ~= nil then
        if S and v ~= S.Rebirths then
            S.Rebirths = v
            padCache, padCacheT = {}, 0
            ballCache, ballCacheT = nil, 0
        end
    end
    return S and S.Rebirths or 0
end

local function rebirths()
    return refreshRebirths()
end

local function guessWorld()
    local w = getStat("World") or getStat("CurrentWorld") or LP:GetAttribute("CurrentWorld")
    if type(w) == "string" and WorldCfg and WorldCfg.ById and WorldCfg.ById[w] then
        return w
    end
    if WorldCfg and WorldCfg.Worlds and WorldCfg.Worlds[1] then
        return WorldCfg.Worlds[1].Id
    end
    return "World1"
end

local function petStorage()
    for _, fname in ipairs({"Pets", "PetStorage", "PlayerPets"}) do
        local f = LP:FindFirstChild(fname)
        if f then return f end
    end
    local ls = LP:FindFirstChild("leaderstats")
    if ls then
        local f = ls:FindFirstChild("Pets")
        if f then return f end
    end
    return nil
end

-- ================= MOVEMENT =================
local MoveBusy = false

local function root()
    local c = LP.Character
    return c and c:FindFirstChild("HumanoidRootPart") or nil
end

local function moveHumanoid(targetPos, holdTime)
    local hrp = root()
    if not hrp or not targetPos then return false end
    MoveBusy = true
    local dest = CFrame.new(targetPos + Vector3.new(0, 3, 0))
    if S and S.MoveMode == "Instant" then
        pcall(function()
            hrp.Anchored = true
            hrp.CFrame = dest
            hrp.Anchored = false
        end)
    else
        local speed = (S and S.TweenSpeed) or 60
        local dist = (hrp.Position - targetPos).Magnitude
        local t = math.clamp(dist / math.max(speed, 1), 0.1, 15)
        pcall(function() hrp.Anchored = true end)
        pcall(function()
            local tw = TweenService:Create(hrp, TweenInfo.new(t, Enum.EasingStyle.Linear), {CFrame = dest})
            tw:Play()
            tw.Completed:Wait()
        end)
        pcall(function() hrp.Anchored = false end)
    end
    MoveBusy = false
    if holdTime and holdTime > 0 then task.wait(holdTime) end
    return true
end

-- ================= STATE =================
S = {
    AutoFarm = false,
    AutoTrain = false,
    AutoKick = false,
    AutoRebirth = false,
    AutoBuyBall = false,
    AutoHatch = false,
    AutoEquipPets = false,
    AutoRewards = false,
    AntiAFK = false,

    Rebirths = 0,

    TrainStation = "auto",
    Egg = nil,
    MoveMode = "Tween",
    TweenSpeed = 60,

    TrainSeconds = 10,
    KickStay = 1,
    KickDelay = 0.5,

    Phase = "train",
    PhaseEnd = 0,

    KickSpot = nil,
    Modes = {Rebirth = 1, Ball = 1, Egg = 1, Pet = 1, Reward = 1},

    SessionBalls = {},
    LastTrainAt = 0,
    LastKickAt = 0,
    LastRewardAt = 0,
    LastEquipPetsAt = 0,
    LastRebirthAt = 0,
    LastBuyAt = 0,
    LastHatchAt = 0,
    FullNoteAt = 0,
}

-- ================= STATIONS =================
local function stations()
    return (TrainCfg and TrainCfg.Stations) or {}
end

local function stationById(id)
    if TrainCfg and TrainCfg.ById then return TrainCfg.ById[id] end
    for _, st in ipairs(stations()) do
        if st.Id == id then return st end
    end
end

local function meetsReq(req)
    if not req then return true end
    local list = req.Type and {req} or req
    local rb = rebirths()
    local world = guessWorld()
    for _, r in ipairs(list) do
        if r.Type == "Rebirths" then
            if rb < (tonumber(r.Value) or 0) then return false end
        elseif r.Type == "World" then
            if world ~= r.Value then return false end
        end
    end
    return true
end

local function bestStation()
    local best, mult = nil, -1
    for _, st in ipairs(stations()) do
        if not st.Premium and st.World == guessWorld() and meetsReq(st.Requirement) then
            if (st.Multiplier or 0) > mult then
                best, mult = st, st.Multiplier or 0
            end
        end
    end
    if best then return best end
    for _, st in ipairs(stations()) do
        if not st.Premium and meetsReq(st.Requirement) then
            if (st.Multiplier or 0) > mult then
                best, mult = st, st.Multiplier or 0
            end
        end
    end
    return best or stationById("Starter")
end

local function currentStation()
    if S.TrainStation == "auto" then return bestStation() end
    return stationById(S.TrainStation) or bestStation()
end

-- ================= PADS / BALLS =================
local function objPos(obj)
    if not obj then return nil end
    if obj:IsA("BasePart") then return obj.Position end
    local ok, pv = pcall(function() return obj:GetPivot().Position end)
    if ok then return pv end
    local p = obj:FindFirstChildWhichIsA("BasePart", true)
    return p and p.Position or nil
end

local function padFor(stationId)
    local now = os.clock()
    if padCache[stationId] and now < padCacheT then return padCache[stationId] end
    local best, bestD = nil, math.huge
    local hrp = root()
    for _, obj in ipairs(workspace:GetDescendants()) do
        local match = false
        if obj:IsA("BasePart") or obj:IsA("Model") then
            if obj.Name == stationId then
                match = true
            else
                local a = obj:GetAttribute("StationId") or obj:GetAttribute("Station") or obj:GetAttribute("TrainingId")
                if a == stationId then match = true end
            end
        end
        if match then
            local pos = objPos(obj)
            if pos then
                local d = hrp and (pos - hrp.Position).Magnitude or 0
                if d < bestD then best, bestD = pos, d end
            end
        end
    end
    padCache[stationId] = best
    padCacheT = now + 5
    return best
end

-- Kick pad: workspace.KickZones.WorldN.Pad
local function kickPadPart()
    local w = guessWorld()
    if kickPadCache and kickPadCache.Parent and kickPadCacheWorld == w then
        return kickPadCache
    end
    kickPadCache = nil

    local pad
    local kz = workspace:FindFirstChild("KickZones")
    if kz then
        local wf = kz:FindFirstChild(w)
        if wf then
            pad = wf:FindFirstChild("Pad") or wf:FindFirstChild("Pad", true)
        end
    end

    kickPadCache = pad
    kickPadCacheWorld = w
    return pad
end

local function kickPadPos()
    return objPos(kickPadPart())
end

local function ballIds()
    local set = {}
    if BallCfg and BallCfg.Balls then
        for _, b in ipairs(BallCfg.Balls) do set[b.Id] = b end
    end
    if BallCfg and BallCfg.ById then set = BallCfg.ById end
    return set
end

local function findBall()
    local now = os.clock()
    if ballCache and now < ballCacheT and ballCache.Parent then return ballCache end
    local ids = ballIds()
    local char = LP.Character
    local best, bestD = nil, math.huge
    local hrp = root()
    for _, obj in ipairs(workspace:GetDescendants()) do
        if (obj:IsA("BasePart") or obj:IsA("Model")) and not (char and obj:IsDescendantOf(char)) then
            local attr = obj:GetAttribute("BallId") or obj:GetAttribute("Ball") or obj:GetAttribute("BallType")
            local nm = obj.Name
            local isBall = (attr and ids[attr] ~= nil)
                or ids[nm] ~= nil
                or nm:lower():find("ball") ~= nil
            if isBall and (ids[nm] == nil and attr == nil) then
                local low = nm:lower()
                if low:find("spawn") or low:find("zone") or low:find("court")
                    or low:find("marker") or low:find("holder") or low:find("socket")
                    or low:find("machine") or low:find("spot") then
                    isBall = false
                end
            end
            if isBall then
                local pos = objPos(obj)
                if pos then
                    local d = hrp and (pos - hrp.Position).Magnitude or 0
                    if d < bestD then best, bestD = obj, d end
                end
            end
        end
    end
    ballCache = best
    ballCacheT = now + 2
    return best
end

-- ================= POWER / FORMULAS =================
local function power() return statNum("Power") end
local function wins() return statNum("Wins") end

local function petEquipCap()
    local cap = (GameCfg and GameCfg.PetEquipCap) or 3
    local slots = statNum("BonusPetSlots")
    if slots > 0 and slots < 100 then cap += math.floor(slots) end
    return cap
end

local function canRebirth()
    if Formulas and Formulas.CanRebirth then
        local ok, res = pcall(Formulas.CanRebirth, power(), rebirths())
        if ok then return res == true end
    end
    local rp = statNum("RebirthPower")
    if rp > 0 then return power() >= rp end
    return true
end

local function levelOf()
    if Formulas and Formulas.GetLevelInfo then
        local ok, info = pcall(Formulas.GetLevelInfo, power(), rebirths())
        if ok and info then return info end
    end
    return nil
end

local function kickDistance()
    local p = power()
    if Formulas and Formulas.GetKickDistance then
        local ok, d = pcall(Formulas.GetKickDistance, p, guessWorld())
        if ok and d then return d end
    end
    local w = WorldCfg and WorldCfg.ById and WorldCfg.ById[guessWorld()]
    local ppm = (w and w.PowerPerMeter) or 1
    local base = (KickCfg and KickCfg.BaseDistance) or 6
    return base + math.max(0, p) / ppm
end

local function flightTime()
    local dist = kickDistance()
    local path = KickCfg and KickCfg.Path
    if path and path.DurationBase then
        local t = path.DurationBase * (dist / (path.DurationRefLength or 100)) ^ (path.DurationExponent or 0.27)
        return math.clamp(t, 1, 12)
    end
    return 2
end

-- ================= TRAINING =================
local function trainTick()
    local st = currentStation()
    if not st then return end
    if not TrainRequest then return end
    local now = os.clock()
    local interval = (TrainCfg and TrainCfg.AutoInterval) or 0.33
    if now - S.LastTrainAt < interval then return end
    if not MoveBusy then
        local pad = padFor(st.Id)
        local hrp = root()
        if pad and hrp and (pad - hrp.Position).Magnitude > 6 then
            moveHumanoid(pad, 0)
        end
    end
    S.LastTrainAt = os.clock()
    fire(TrainRequest, st.Id)
end

-- ================= KICKING =================
local function kickTarget()
    local pad = kickPadPos()
    if pad then return pad end
    if S.KickSpot then return S.KickSpot.Position end
    return nil
end

local function goToKickSpot(hold)
    local target = kickTarget()
    local hrp = root()
    if not target then return false end
    if hrp and (target - hrp.Position).Magnitude > 6 then
        moveHumanoid(target, hold or 0)
    end
    return true
end

local function sendKick(p)
    local token = getToken()
    local sigs
    if token then
        sigs = {{p.X, p.Y, p.Z, token}, {p.X, p.Y, p.Z}}
    else
        sigs = {{p.X, p.Y, p.Z}}
    end
    for _, a in ipairs(sigs) do
        local ok = invoke(KickRequest, table.unpack(a))
        if ok then return true end
    end
    return false
end

local function kickPosition()
    ballCacheT = 0
    local obj = findBall()
    local p = obj and objPos(obj)
    if not p then p = kickTarget() end
    return p
end

-- farm kick: go to pad, kick right away, stay exactly KickStay seconds after arriving
local function farmKick()
    if not KickRequest then
        if os.clock() > S.FullNoteAt then
            S.FullNoteAt = os.clock() + 20
            notify("Kick", "KickRequest not found. Use Dump Remotes.")
        end
        return
    end
    if not kickTarget() then
        if os.clock() > S.FullNoteAt then
            S.FullNoteAt = os.clock() + 20
            notify("Kick", "Kick pad not found. Use Dump Kick Pad.")
        end
        return
    end

    goToKickSpot(0)
    local arrived = os.clock()

    local gap = (KickCfg and KickCfg.MinKickGap) or 0.6
    local wait = gap - (os.clock() - S.LastKickAt)
    if wait > 0 then task.wait(wait) end

    local p = kickPosition()
    if p then
        S.LastKickAt = os.clock()
        task.spawn(sendKick, p)
    end

    local left = (S.KickStay or 1) - (os.clock() - arrived)
    if left > 0 then task.wait(left) end
end

-- manual / auto kick: wait for the full kick animation and ball flight
local function kickOnce()
    local now = os.clock()
    local gap = (KickCfg and KickCfg.MinKickGap) or 0.6
    if now - S.LastKickAt < gap then return end
    if not KickRequest then
        if os.clock() > S.FullNoteAt then
            S.FullNoteAt = os.clock() + 20
            notify("Kick", "KickRequest not found. Use Dump Remotes.")
        end
        return
    end
    if not kickTarget() then
        if os.clock() > S.FullNoteAt then
            S.FullNoteAt = os.clock() + 20
            notify("Kick", "Kick pad not found. Set a Kick Spot.")
        end
        return
    end

    goToKickSpot(0.1)
    local p = kickPosition()
    if not p then return end

    S.LastKickAt = os.clock()
    local sent = sendKick(p)
    if sent then
        local windup = (KickCfg and KickCfg.WindupTime) or 0.32
        local strike = (KickCfg and KickCfg.StrikeTime) or 0.13
        task.wait(windup + strike + flightTime() + (S.KickDelay or 0.5))
    end
end

-- ================= ECONOMY =================
local function ballsSorted()
    local list = {}
    if BallCfg and BallCfg.Balls then
        for _, b in ipairs(BallCfg.Balls) do
            if not b.Premium then table.insert(list, b) end
        end
        table.sort(list, function(a, b2) return (a.Power or 0) < (b2.Power or 0) end)
    end
    return list
end

local function buyBallTick()
    if not R.Ball or os.clock() - S.LastBuyAt < 3 then return end
    S.LastBuyAt = os.clock()
    local w = wins()
    for _, b in ipairs(ballsSorted()) do
        if not S.SessionBalls[b.Id] then
            local cost = num(b.Cost)
            if w >= cost then
                local before = w
                local sigs = {{"Buy", b.Id}, {b.Id}, {"Purchase", b.Id}}
                local idx = S.Modes.Ball
                local order = {}
                for k = 0, #sigs - 1 do table.insert(order, sigs[(idx - 1 + k) % #sigs + 1]) end
                for _, a in ipairs(order) do
                    send(R.Ball, table.unpack(a))
                    task.wait(0.4)
                    if wins() < before then
                        S.SessionBalls[b.Id] = true
                        S.Modes.Ball = (table.find(sigs, a) or 1)
                        notify("Ball", "Bought " .. tostring(b.Id))
                        send(R.Ball, "Equip", b.Id)
                        task.wait(0.2)
                        send(R.Ball, b.Id)
                        return
                    end
                end
                return
            end
            return
        end
    end
end

local function eggsSorted()
    local list = {}
    if EggCfg and EggCfg.Eggs then
        for _, e in ipairs(EggCfg.Eggs) do
            if not e.IsPremium then table.insert(list, e) end
        end
        table.sort(list, function(a, b) return (a.Cost or 0) < (b.Cost or 0) end)
    end
    return list
end

local function eggById(id)
    if EggCfg and EggCfg.ById then return EggCfg.ById[id] end
    for _, e in ipairs(eggsSorted()) do
        if e.Id == id then return e end
    end
end

local function hatchTick()
    if not R.Egg or os.clock() - S.LastHatchAt < 2 then return end
    S.LastHatchAt = os.clock()
    local egg = S.Egg and eggById(S.Egg) or nil
    if not egg then
        local w = wins()
        for _, e in ipairs(eggsSorted()) do
            if w >= num(e.Cost) then egg = e end
        end
    end
    if not egg then return end
    if wins() < num(egg.Cost) then return end
    local before = wins()
    local count = (GameCfg and GameCfg.MultiHatchBase) or 2
    local sigs = {
        {egg.Id}, {"Hatch", egg.Id}, {egg.Id, count}, {egg.Id, 1}, {"Hatch", egg.Id, count},
    }
    local idx = S.Modes.Egg
    local order = {}
    for k = 0, #sigs - 1 do table.insert(order, sigs[(idx - 1 + k) % #sigs + 1]) end
    for _, a in ipairs(order) do
        send(R.Egg, table.unpack(a))
        task.wait(0.5)
        if wins() < before then
            S.Modes.Egg = (table.find(sigs, a) or 1)
            notify("Egg", "Hatched " .. tostring(egg.Id))
            return
        end
    end
end

local function ownedPetIds()
    local out = {}
    local store = petStorage()
    if store then
        for _, v in ipairs(store:GetChildren()) do
            table.insert(out, v.Name)
        end
    end
    local attr = LP:GetAttribute("Pets")
    if type(attr) == "table" then
        for id in pairs(attr) do table.insert(out, tostring(id)) end
    end
    return out
end

local function petBonusOf(petId)
    local c = PetCfg and PetCfg.ById and PetCfg.ById[petId]
    if c then return num(c.Bonus) end
    return 0
end

local function equipBestPets()
    if not R.Pet then
        notify("Pets", "Pet remote not found. Use Dump Remotes.")
        return
    end
    local ids = ownedPetIds()
    if #ids == 0 then
        notify("Pets", "No pet storage found. Use Dump PlayerData.")
        return
    end
    table.sort(ids, function(a, b) return petBonusOf(a) > petBonusOf(b) end)
    local cap = petEquipCap()
    local equipped = 0
    for i, id in ipairs(ids) do
        if i > cap then break end
        local sigs = {{id}, {"Equip", id}}
        local a = sigs[(S.Modes.Pet - 1) % #sigs + 1]
        send(R.Pet, table.unpack(a))
        equipped += 1
        task.wait(0.25)
    end
    notify("Pets", "Equip sent for " .. equipped .. " pets (cap " .. cap .. ")")
end

local function claimRewards()
    if not R.Reward then return end
    local sigs = {{}, {1}, {"Claim"}}
    local a = sigs[(S.Modes.Reward - 1) % #sigs + 1]
    send(R.Reward, table.unpack(a))
end

-- ================= REBIRTH =================
local function rebirthTick(force)
    if not force and os.clock() - S.LastRebirthAt < 2 then return end
    S.LastRebirthAt = os.clock()
    refreshRebirths()
    if not force and not canRebirth() then return end
    if not R.Rebirth then
        R.Rebirth = byKeyword({"rebirth"})
    end
    if not R.Rebirth then
        if os.clock() > S.FullNoteAt then
            S.FullNoteAt = os.clock() + 20
            notify("Rebirth", "Rebirth remote not found. Use Dump Remotes.")
        end
        return
    end

    local before = rebirths()
    local beforePower = power()
    local sigs = {{}, {"Rebirth"}, {true}}
    local idx = S.Modes.Rebirth
    local order = {}
    for k = 0, #sigs - 1 do table.insert(order, sigs[(idx - 1 + k) % #sigs + 1]) end

    for _, a in ipairs(order) do
        local ok, res = send(R.Rebirth, table.unpack(a))
        local success = false
        for _ = 1, 8 do
            task.wait(0.25)
            refreshRebirths()
            if rebirths() > before or power() < beforePower then
                success = true
                break
            end
        end
        if not success and ok and res == true then
            if not rbObj and not rbAttr then
                S.Rebirths = before + 1
                success = true
            end
        end
        if success then
            S.Modes.Rebirth = (table.find(sigs, a) or 1)
            padCache, padCacheT = {}, 0
            ballCache, ballCacheT = nil, 0
            kickPadCache = nil
            S.LastTrainAt = 0
            notify("Rebirth", "Rebirth done! Total: " .. tostring(rebirths()))
            return
        end
    end
end

-- ================= TRAVEL =================
local function travelTo(worldId)
    local sent = false
    if R.Travel then
        sent = send(R.Travel, worldId)
    end
    task.wait(0.8)
    local target = workspace:FindFirstChild(worldId, true)
    if target then
        local pos = objPos(target)
        if pos then
            moveHumanoid(pos, 0.3)
            sent = true
        end
    end
    padCache, padCacheT = {}, 0
    kickPadCache = nil
    notify("World", sent and ("Travel sent: " .. tostring(worldId)) or ("No travel remote for " .. tostring(worldId)))
end

-- ================= ANTI AFK =================
local antiAFKConn = nil
local function setAntiAFK(on)
    if antiAFKConn then
        antiAFKConn:Disconnect()
        antiAFKConn = nil
    end
    if on then
        antiAFKConn = LP.Idled:Connect(function()
            pcall(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new())
            end)
        end)
        notify("AFK", "Anti AFK ON")
    else
        notify("AFK", "Anti AFK OFF")
    end
end

-- ================= MAIN LOOP =================
task.spawn(function()
    while true do
        local ok, err = pcall(function()
            refreshRebirths()

            if S.AutoFarm then
                if S.Phase == "train" then
                    trainTick()
                    if os.clock() >= S.PhaseEnd then
                        S.Phase = "kick"
                    end
                else
                    farmKick()
                    S.Phase = "train"
                    S.PhaseEnd = os.clock() + S.TrainSeconds
                    S.LastTrainAt = 0
                end
            else
                if S.AutoTrain then trainTick() end
                if S.AutoKick then kickOnce() end
            end

            if S.AutoRebirth then rebirthTick(false) end
            if S.AutoBuyBall then buyBallTick() end
            if S.AutoHatch then hatchTick() end
            if S.AutoRewards and os.clock() - S.LastRewardAt > 30 then
                S.LastRewardAt = os.clock()
                claimRewards()
            end
            if S.AutoEquipPets and os.clock() - S.LastEquipPetsAt > 15 then
                S.LastEquipPetsAt = os.clock()
                equipBestPets()
            end
        end)
        if not ok then warn("KickFarm loop error: " .. tostring(err)) end
        task.wait(0.1)
    end
end)

LP.CharacterAdded:Connect(function()
    task.wait(0.5)
    ballCacheT = 0
    padCacheT = 0
    padCache = {}
    kickPadCache = nil
end)

-- ================= UI =================
local MainTab = Gui:CreateTab("Main")
local TrainTab = Gui:CreateTab("Training")
local KickTab = Gui:CreateTab("Kicking")
local EcoTab = Gui:CreateTab("Economy")
local WorldTab = Gui:CreateTab("Worlds")
local MoveTab = Gui:CreateTab("Movement")
local ToolTab = Gui:CreateTab("Tools")

MainTab:CreateSection("Auto Farm")
MainTab:CreateParagraph{
    Title = "What it does",
    Content = "Auto Farm trains on the pad for Train Seconds. Then it goes to the kick pad, kicks, stays for Kick Stay Time, and goes back to train."
}
MainTab:CreateToggle{
    Name = "Auto Farm (train + kick)",
    Flag = "AutoFarm",
    CurrentValue = false,
    Callback = function(v)
        S.AutoFarm = v and true or false
        S.Phase = "train"
        S.PhaseEnd = os.clock() + S.TrainSeconds
        notify("Farm", S.AutoFarm and "Auto farm ON" or "Auto farm OFF")
    end
}
MainTab:CreateSlider{
    Name = "Train Seconds",
    Flag = "TrainSeconds",
    Range = {3, 120},
    Increment = 1,
    CurrentValue = 10,
    Suffix = "s",
    Callback = function(v) S.TrainSeconds = tonumber(v) or 10 end
}
MainTab:CreateSlider{
    Name = "Kick Stay Time",
    Flag = "KickStay",
    Range = {1, 10},
    Increment = 1,
    CurrentValue = 1,
    Suffix = "s",
    Callback = function(v) S.KickStay = tonumber(v) or 1 end
}
MainTab:CreateToggle{
    Name = "Auto Rebirth",
    Flag = "AutoRebirth",
    CurrentValue = false,
    Callback = function(v)
        S.AutoRebirth = v and true or false
        notify("Rebirth", S.AutoRebirth and "Auto rebirth ON" or "Auto rebirth OFF")
    end
}
MainTab:CreateToggle{
    Name = "Anti AFK",
    Flag = "AntiAFK",
    CurrentValue = false,
    Callback = function(v)
        S.AntiAFK = v and true or false
        setAntiAFK(S.AntiAFK)
    end
}

TrainTab:CreateSection("Training")
TrainTab:CreateToggle{
    Name = "Auto Train",
    Flag = "AutoTrain",
    CurrentValue = false,
    Callback = function(v) S.AutoTrain = v and true or false end
}
do
    local opts, map = {}, {}
    opts[1] = "Auto (best unlocked)"
    map["Auto (best unlocked)"] = "auto"
    for _, st in ipairs(stations()) do
        local label = st.Id .. " (x" .. tostring(st.Multiplier) .. ")"
        table.insert(opts, label)
        map[label] = st.Id
    end
    TrainTab:CreateDropdown{
        Name = "Station",
        Flag = "TrainStation",
        Options = opts,
        CurrentOption = "Auto (best unlocked)",
        Callback = function(v)
            local key = (type(v) == "table" and v[1]) or v
            local id = map[key]
            if id then
                S.TrainStation = id
                notify("Train", "Station: " .. id)
            end
        end
    }
end
TrainTab:CreateParagraph{
    Title = "Station info",
    Content = "Auto picks the best station for your rebirths. The rebirth count is read again every loop."
}
TrainTab:CreateButton{
    Name = "Go To Station Pad",
    Callback = function()
        local st = currentStation()
        local pad = st and padFor(st.Id)
        if pad then
            task.spawn(moveHumanoid, pad, 0.3)
            notify("Train", "Moving to " .. tostring(st and st.Id))
        else
            notify("Train", "Pad not found in workspace")
        end
    end
}

KickTab:CreateSection("Kicking")
KickTab:CreateToggle{
    Name = "Auto Kick",
    Flag = "AutoKick",
    CurrentValue = false,
    Callback = function(v) S.AutoKick = v and true or false end
}
KickTab:CreateSlider{
    Name = "Kick Delay",
    Flag = "KickDelay",
    Range = {0, 5},
    Increment = 0.1,
    CurrentValue = 0.5,
    Suffix = "s extra",
    Callback = function(v) S.KickDelay = tonumber(v) or 0.5 end
}
KickTab:CreateButton{
    Name = "Go To Kick Pad",
    Callback = function()
        local pad = kickPadPos()
        if pad then
            task.spawn(moveHumanoid, pad, 0.3)
            notify("Kick", "Moving to kick pad")
        else
            notify("Kick", "Kick pad not found")
        end
    end
}
KickTab:CreateButton{
    Name = "Kick Now",
    Callback = function()
        task.spawn(function()
            S.LastKickAt = 0
            kickOnce()
        end)
    end
}
KickTab:CreateButton{
    Name = "Set Kick Spot Here",
    Callback = function()
        local hrp = root()
        if hrp then
            S.KickSpot = hrp.CFrame
            notify("Kick", "Kick spot saved")
        end
    end
}
KickTab:CreateButton{
    Name = "Clear Kick Spot",
    Callback = function()
        S.KickSpot = nil
        notify("Kick", "Kick spot cleared")
    end
}
KickTab:CreateParagraph{
    Title = "Kick info",
    Content = "Pad path: workspace.KickZones.World.Pad. Auto Kick waits for the kick animation and the ball flight. Auto Farm waits only Kick Stay Time."
}

EcoTab:CreateSection("Balls")
EcoTab:CreateToggle{
    Name = "Auto Buy Ball",
    Flag = "AutoBuyBall",
    CurrentValue = false,
    Callback = function(v) S.AutoBuyBall = v and true or false end
}
EcoTab:CreateParagraph{
    Title = "Ball info",
    Content = "Buys the cheapest ball you do not own, then the next one. Costs Wins. Premium balls are skipped."
}

EcoTab:CreateSection("Eggs")
EcoTab:CreateToggle{
    Name = "Auto Hatch Egg",
    Flag = "AutoHatch",
    CurrentValue = false,
    Callback = function(v) S.AutoHatch = v and true or false end
}
do
    local opts, map = {}, {}
    for _, e in ipairs(eggsSorted()) do
        local label = e.Id .. " (" .. abbrev(e.Cost) .. " wins)"
        table.insert(opts, label)
        map[label] = e.Id
    end
    if #opts == 0 then
        table.insert(opts, "Best affordable")
        map["Best affordable"] = nil
    end
    EcoTab:CreateDropdown{
        Name = "Egg",
        Flag = "Egg",
        Options = opts,
        CurrentOption = opts[1],
        Callback = function(v)
            local key = (type(v) == "table" and v[1]) or v
            S.Egg = map[key]
            notify("Egg", "Egg: " .. tostring(S.Egg or "best affordable"))
        end
    }
end

EcoTab:CreateSection("Pets / Rewards")
EcoTab:CreateToggle{
    Name = "Auto Equip Best Pets",
    Flag = "AutoEquipPets",
    CurrentValue = false,
    Callback = function(v) S.AutoEquipPets = v and true or false end
}
EcoTab:CreateToggle{
    Name = "Auto Claim Rewards",
    Flag = "AutoRewards",
    CurrentValue = false,
    Callback = function(v) S.AutoRewards = v and true or false end
}
EcoTab:CreateButton{
    Name = "Equip Best Pets Now",
    Callback = function() task.spawn(equipBestPets) end
}

WorldTab:CreateSection("Worlds")
do
    local opts, map = {}, {}
    if WorldCfg and WorldCfg.Worlds then
        local sorted = {}
        for _, w in ipairs(WorldCfg.Worlds) do table.insert(sorted, w) end
        table.sort(sorted, function(a, b) return (a.Order or 0) < (b.Order or 0) end)
        for _, w in ipairs(sorted) do
            local label = w.Id .. " - " .. tostring(w.DisplayName)
            table.insert(opts, label)
            map[label] = w.Id
        end
    end
    WorldTab:CreateDropdown{
        Name = "World",
        Flag = "World",
        Options = #opts > 0 and opts or {"World1"},
        CurrentOption = opts[1],
        Callback = function(v)
            local key = (type(v) == "table" and v[1]) or v
            S.TargetWorld = map[key]
        end
    }
end
WorldTab:CreateButton{
    Name = "Travel",
    Callback = function()
        task.spawn(travelTo, S.TargetWorld or guessWorld())
    end
}

MoveTab:CreateSection("Movement")
MoveTab:CreateDropdown{
    Name = "Move Mode",
    Flag = "MoveMode",
    Options = {"Tween", "Instant"},
    CurrentOption = "Tween",
    Callback = function(v)
        local key = (type(v) == "table" and v[1]) or v
        if key == "Tween" or key == "Instant" then S.MoveMode = key end
    end
}
MoveTab:CreateSlider{
    Name = "Tween Speed",
    Flag = "TweenSpeed",
    Range = {16, 300},
    Increment = 1,
    CurrentValue = 60,
    Suffix = " studs/s",
    Callback = function(v) S.TweenSpeed = tonumber(v) or 60 end
}
MoveTab:CreateParagraph{
    Title = "Tip",
    Content = "Use Instant mode for the fastest switch between the training pad and the kick pad."
}

ToolTab:CreateSection("Stats")
ToolTab:CreateButton{
    Name = "Show Stats",
    Callback = function()
        local lv = levelOf()
        local lvTxt = lv and ("level " .. tostring(lv.Level) .. " (" .. math.floor((lv.Progress or 0) * 100) .. "%)") or "?"
        local st = currentStation()
        notify("Stats",
            "Power " .. abbrev(power())
            .. " | Wins " .. abbrev(wins())
            .. " | Rebirths " .. tostring(rebirths())
            .. " | " .. lvTxt
            .. " | Station " .. tostring(st and st.Id)
            .. " | Kick " .. abbrev(kickDistance()) .. " m"
            .. " | Token " .. (getToken() and "yes" or "none"))
    end
}
ToolTab:CreateButton{
    Name = "Rebirth Now",
    Callback = function()
        task.spawn(function()
            rebirthTick(true)
        end)
    end
}
ToolTab:CreateButton{
    Name = "Refresh Rebirth Count",
    Callback = function()
        rbObj, rbAttr = nil, nil
        local v = refreshRebirths()
        notify("Rebirth", "Rebirths: " .. tostring(v) .. " | source: " .. tostring(rbObj and rbObj:GetFullName() or rbAttr or "none"))
    end
}

ToolTab:CreateSection("Debug")
ToolTab:CreateButton{
    Name = "Dump Remotes",
    Callback = function()
        print("=== REMOTE DUMP ===")
        if not RemotesFolder then
            print("No Remotes folder")
        else
            for _, d in ipairs(RemotesFolder:GetDescendants()) do
                if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") then
                    print(d.ClassName, d:GetFullName())
                end
            end
        end
        for k, r in pairs(R) do print("Matched", k, r:GetFullName()) end
        notify("Debug", "Remotes dumped to console")
    end
}
ToolTab:CreateButton{
    Name = "Dump PlayerData",
    Callback = function()
        print("=== PLAYERDATA DUMP ===")
        local ls = LP:FindFirstChild("leaderstats")
        if ls then
            for _, v in ipairs(ls:GetChildren()) do
                print(v.Name, "=", tostring(v.Value))
            end
        end
        for name, val in pairs(LP:GetAttributes()) do
            print("attr", name, "=", tostring(val))
        end
        for _, f in ipairs(LP:GetChildren()) do
            if f:IsA("Folder") or f:IsA("Configuration") then
                print("Folder: " .. f.Name)
                for _, v in ipairs(f:GetChildren()) do
                    if v:IsA("ValueBase") then
                        print("  " .. f.Name .. "." .. v.Name, "=", tostring(v.Value))
                    end
                end
            end
        end
        notify("Debug", "PlayerData dumped to console")
    end
}
ToolTab:CreateButton{
    Name = "Dump Kick Pad",
    Callback = function()
        kickPadCache = nil
        local pad = kickPadPart()
        print("=== KICK PAD ===")
        print("World:", guessWorld())
        print(pad and pad:GetFullName() or "not found")
        local pos = kickPadPos()
        if pos then print("Position", pos) end
        local kz = workspace:FindFirstChild("KickZones")
        if kz then
            for _, c in ipairs(kz:GetChildren()) do print("KickZones child:", c.Name) end
        end
        notify("Debug", pad and "Kick pad found" or "Kick pad not found")
    end
}
ToolTab:CreateButton{
    Name = "Dump Stations",
    Callback = function()
        print("=== STATION DUMP ===")
        for _, st in ipairs(stations()) do
            print(st.Id, "world=" .. tostring(st.World), "x" .. tostring(st.Multiplier),
                "premium=" .. tostring(st.Premium or false), "pad=" .. tostring(padFor(st.Id) ~= nil))
        end
        notify("Debug", "Stations dumped to console")
    end
}
ToolTab:CreateButton{
    Name = "Dump Balls",
    Callback = function()
        print("=== BALL DUMP ===")
        for _, b in ipairs(ballsSorted()) do
            print(b.Id, "power=" .. tostring(b.Power), "cost=" .. tostring(b.Cost),
                "world=" .. tostring(b.World))
        end
        notify("Debug", "Balls dumped to console")
    end
}
ToolTab:CreateButton{
    Name = "Dump Eggs",
    Callback = function()
        print("=== EGG DUMP ===")
        for _, e in ipairs(eggsSorted()) do
            print(e.Id, "cost=" .. tostring(e.Cost), "world=" .. tostring(e.World),
                "pets=" .. tostring(e.Pets and #e.Pets or 0))
        end
        notify("Debug", "Eggs dumped to console")
    end
}
ToolTab:CreateButton{
    Name = "Dump Pets",
    Callback = function()
        print("=== PET DUMP (config) ===")
        if PetCfg and PetCfg.Pets then
            for _, p in ipairs(PetCfg.Pets) do
                print(p.Id, "bonus=" .. tostring(p.Bonus), "rarity=" .. tostring(p.Rarity),
                    "world=" .. tostring(p.World), "premium=" .. tostring(p.Premium or false))
            end
        end
        print("=== PET STORAGE (client) ===")
        for _, id in ipairs(ownedPetIds()) do
            print(id, "bonus=" .. tostring(petBonusOf(id)))
        end
        notify("Debug", "Pets dumped to console")
    end
}
ToolTab:CreateButton{
    Name = "Show Last Token",
    Callback = function()
        local t = getToken()
        if t then
            print("Last token:", t, "age:", string.format("%.2f", os.clock() - LastTokenAt))
            notify("Token", "Last token: " .. tostring(t))
        else
            notify("Token", "No token seen yet.")
        end
    end
}

refreshRebirths()
notify("Kick Farm", "Loaded. Rebirths: " .. tostring(S.Rebirths))
