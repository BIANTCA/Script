-- ============================================================
-- Heist Farm v3
-- Auto Farm toggle and its functions come from the v2 script.
-- GUI: BulbGui. All UI text is simple English.
-- ============================================================

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local LP = Players.LocalPlayer
local PlayerScripts = LP:WaitForChild("PlayerScripts")

-- ================= UI LIBRARY (BulbGui) =================
local RobloxGui = loadstring(game:HttpGet("https://pastebin.com/raw/2BGUWvbd"))()
local Gui = RobloxGui
Gui:Init{
    Name = "Heist Farm",
    Subtitle = "Auto farm, auto economy, auto sell",
    FolderName = "TumblrConfigs",
    FileName = "heistfarm_v3.json"
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

local function walk(t, fn, path, depth)
    path = path or ""
    depth = depth or 0
    if type(t) ~= "table" or depth > 8 then return end
    for k, v in pairs(t) do
        local p = (path == "" and tostring(k)) or (path .. "." .. tostring(k))
        fn(p, v, k)
        if type(v) == "table" then walk(v, fn, p, depth + 1) end
    end
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

-- ================= GAME MODULES / CONFIG =================
local Shared = RS:WaitForChild("Shared")
local Config = tryReq(Shared:WaitForChild("Config", 10))
local Modules = Shared:FindFirstChild("Modules")

local function loadUtil(name)
    if not Modules then return nil end
    return tryReq(Modules:FindFirstChild(name))
end

local ItemUtils = loadUtil("ItemUtils")
local UpgradeUtils = loadUtil("UpgradeUtils")
local RebirthUtils = loadUtil("RebirthUtils")
local ArmsUtils = loadUtil("ArmsUtils")
local PlotSlotUtils = loadUtil("PlotSlotUtils")
local TreasurePickupUtils = loadUtil("TreasurePickupUtils")

local DataAgg = nil
do
    local cm = PlayerScripts:WaitForChild("ClientModules", 30)
    if cm then DataAgg = tryReq(cm:WaitForChild("DataAggregation", 10)) end
end

local function pData()
    if DataAgg and type(DataAgg.GetReplica) == "function" then
        local ok, rep = pcall(DataAgg.GetReplica)
        if ok and rep and type(rep.Data) == "table" then return rep.Data end
    end
    return nil
end

local function getCash(d)
    d = d or pData()
    return (d and tonumber(d.Cash)) or 0
end

local BUSY_ATTRS = {"Jailed", "Ziplining", "DoorPunching", "BreakPartPunching", "TradeCommitting", "TradeRecovering"}
local function isBusy()
    for _, a in ipairs(BUSY_ATTRS) do
        if LP:GetAttribute(a) == true then return true end
    end
    return false
end

-- ================= REMOTES =================
local TypedRemote = Shared:WaitForChild("Packages"):WaitForChild("TypedRemote")
local Bank = tryReq(RS:FindFirstChild("RemoteBank"))

local function remote(name)
    if type(Bank) == "table" and Bank[name] then return Bank[name] end
    return TypedRemote:FindFirstChild(name) or TypedRemote:WaitForChild(name, 2)
end

local RequestStageTreasures = remote("RequestStageTreasures")
local PickupStageTreasure   = remote("PickupStageTreasure")
local DoorBroken            = remote("DoorBroken")
local DoorsReset            = remote("DoorsReset")
local ArmsAction            = remote("ArmsAction")
local PurchaseUpgrade       = remote("PurchaseUpgrade")
local UpgradePlot           = remote("UpgradePlot")
local PlaceBestLuck         = remote("PlaceBestLuck")
local SlotInteraction       = remote("SlotInteraction")
local PerformRebirth        = remote("PerformRebirth")
local SellItem              = remote("SellItem")
local SellItems             = remote("SellItems")
local RequestTeleport       = remote("RequestTeleport")
local StageTreasuresReset   = remote("StageTreasuresReset")

-- ================= TOTAL STAGES =================
local TOTAL = 1
do
    if Config and type(Config.Stages) == "table" then
        local n = 0
        for k in pairs(Config.Stages) do
            local num = tonumber(tostring(k):match("^Stage(%d+)$"))
            if num and num > n then n = num end
        end
        if n > 0 then TOTAL = n end
    end
    if Config and Config.Tower and tonumber(Config.Tower.StageCount) then
        TOTAL = math.max(TOTAL, tonumber(Config.Tower.StageCount))
    end
end

local TreasureItems = (Config and Config.Treasures and Config.Treasures.Items) or {}
local VariantCfg = (Config and Config.Variants) or {}
local DoorCfg = (Config and Config.Doors) or {SwingInterval = 0.5, HitDelay = 0.25}

-- ================= STATE =================
local S = {
    Run = false,
    AutoStage = false,
    AutoArms = true,
    AutoUpgrades = false,
    AutoPlot = false,
    AutoRebirth = false,
    AutoSell = false,

    MaxHits = 10,
    MinStage = 1,
    MaxStage = TOTAL,
    Capacity = 1,
    Delay = 0.4,
    HoldTime = 0.15,

    MoveMode = "Tween",
    TweenSpeed = 60,

    NextStage = 1,
    Blocked = nil,
    UpgradeList = {"Backpack"},
    BasePos = nil,

    Banking = false,
    PlaceMode = 1,
    SellMode = 1,
}

local Blacklist = {Arms = {}, Pickup = {}, Upgrades = {}, Plot = 0, Rebirth = 0}
local BrokenCount = 0
local brokenStages = {}
local spawnCache = {}
local lastRaw = nil
local loopThread = nil

-- server signals
if DoorBroken then
    pcall(function()
        DoorBroken.OnClientEvent:Connect(function() BrokenCount += 1 end)
    end)
end
if DoorsReset then
    pcall(function()
        DoorsReset.OnClientEvent:Connect(function()
            brokenStages = {}
            S.NextStage = 1
            S.Blocked = nil
        end)
    end)
end
if StageTreasuresReset then
    pcall(function()
        StageTreasuresReset.OnClientEvent:Connect(function()
            spawnCache = {}
        end)
    end)
end

-- ================= UI TABS =================
local MainTab = Gui:CreateTab("Main")
local EcoTab = Gui:CreateTab("Economy")
local MoveTab = Gui:CreateTab("Movement")
local ToolTab = Gui:CreateTab("Tools")

local _, _, _, StatusCtl = MainTab:CreateParagraph{Title = "Status", Content = "Idle"}
local _, _, _, InfoCtl = MainTab:CreateParagraph{Title = "Stage Info", Content = "-"}
local function setStatus(t) pcall(function() StatusCtl:SetContent(t) end) end
local function setInfo(t) pcall(function() InfoCtl:SetContent(t) end) end

-- ================= CHARACTER / MOVEMENT =================
local function root()
    local c = LP.Character
    return c and c:FindFirstChild("HumanoidRootPart") or nil
end

local function moveHumanoid(targetPos, holdTime)
    local hrp = root()
    if not hrp or not targetPos then return false end
    local dest = CFrame.new(targetPos + Vector3.new(0, 3, 0))
    if S.MoveMode == "Instant" then
        pcall(function()
            hrp.Anchored = true
            hrp.CFrame = dest
            hrp.Anchored = false
        end)
    else
        local dist = (hrp.Position - targetPos).Magnitude
        local t = math.clamp(dist / math.max(S.TweenSpeed, 1), 0.1, 15)
        pcall(function() hrp.Anchored = true end)
        pcall(function()
            local tw = TweenService:Create(hrp, TweenInfo.new(t, Enum.EasingStyle.Linear), {CFrame = dest})
            tw:Play()
            tw.Completed:Wait()
        end)
        pcall(function() hrp.Anchored = false end)
    end
    if holdTime and holdTime > 0 then task.wait(holdTime) end
    return true
end

local function moveTo(cf)
    local hrp = root()
    if not hrp then return false end
    if S.MoveMode == "Instant" then
        hrp.CFrame = cf
        return true
    end
    local dist = (hrp.Position - cf.Position).Magnitude
    local t = math.max(dist / math.max(S.TweenSpeed, 1), 0.05)
    pcall(function() hrp.Anchored = true end)
    local tw = TweenService:Create(hrp, TweenInfo.new(t, Enum.EasingStyle.Linear), {CFrame = cf})
    tw:Play()
    tw.Completed:Wait()
    pcall(function() hrp.Anchored = false end)
    return true
end

local function saveBase(cf)
    S.BasePos = cf
    if Gui._savedFlags then
        Gui._savedFlags["_HeistBase"] = {x = cf.X, y = cf.Y, z = cf.Z}
        if Gui._saveConfig then pcall(function() Gui:_saveConfig() end) end
    end
end

do
    local b = Gui._savedFlags and Gui._savedFlags["_HeistBase"]
    if type(b) == "table" and b.x then
        S.BasePos = CFrame.new(b.x, b.y, b.z)
    end
end

-- ================= BACKPACK (carried) vs INVENTORY (banked) =================
local function carriedItems()
    local out = {}
    local containers = {LP:FindFirstChildOfClass("Backpack"), LP.Character}
    for _, box in ipairs(containers) do
        if box then
            for _, t in ipairs(box:GetChildren()) do
                if t:IsA("Tool") and t:GetAttribute("InventoryItem") == true
                    and t:GetAttribute("ItemType") == "Treasure" then
                    table.insert(out, t)
                end
            end
        end
    end
    return out
end

local function carriedCount()
    return #carriedItems()
end

local function inventoryItems(d)
    d = d or pData()
    local out, seen = {}, {}
    if not d or type(d.Inventory) ~= "table" then return out end
    for _, it in pairs(d.Inventory) do
        if type(it) == "table" and it.UUID and (it.ItemType == nil or it.ItemType == "Treasure") then
            local id = tostring(it.UUID)
            if not seen[id] then
                seen[id] = true
                table.insert(out, it)
            end
        end
    end
    return out
end

local function capacity(d)
    d = d or pData()
    if d and UpgradeUtils and type(UpgradeUtils.GetValue) == "function" then
        local ok, v = pcall(UpgradeUtils.GetValue, d, "Backpack")
        if ok and tonumber(v) and tonumber(v) > 0 then return math.max(1, math.floor(tonumber(v))) end
    end
    if d and tonumber(d.BackpackCapacity) then return tonumber(d.BackpackCapacity) end
    return math.max(1, math.floor(S.Capacity or 1))
end

local function itemValue(it)
    if ItemUtils then
        local okI, inc = pcall(ItemUtils.GetIncome, it)
        local okP, val = pcall(ItemUtils.GetPrice, it)
        if okI and tonumber(inc) then
            return tonumber(inc), (okP and tonumber(val)) or 0
        end
    end
    local tc = TreasureItems[it.Key]
    local base = (tc and tonumber(tc.Income)) or 0
    local val = (tc and tonumber(tc.Value)) or 0
    local vm = 1
    if it.Variant and VariantCfg[it.Variant] then
        vm = tonumber(VariantCfg[it.Variant].MutationMulti) or 1
    end
    return base * vm, val * vm
end

local function isSellable(it)
    if ItemUtils and type(ItemUtils.IsSellable) == "function" then
        local ok, res = pcall(ItemUtils.IsSellable, it)
        if ok then return res == true end
    end
    if it.IsFavorite == true then return false end
    local tc = TreasureItems[it.Key]
    if tc and tc.Rarity == "Exclusive" then return false end
    return tc ~= nil
end

-- ================= ARMS =================
local armsCache, armsCacheT = nil, 0
local function armsList()
    local now = os.clock()
    if armsCache and now < armsCacheT then return armsCache end
    local list = {}
    local src = Config and Config.Arms
    if type(src) == "table" then
        for key, c in pairs(src) do
            if type(c) == "table" then
                table.insert(list, {
                    Key = tostring(key),
                    Cost = tonumber(c.UnlockCost) or 0,
                    Power = tonumber(c.ArmPower) or 0,
                    Order = tonumber(c.Order) or 999,
                    Robux = c.RobuxOnly == true,
                    BestPercent = tonumber(c.BestPercent),
                })
            end
        end
    end
    table.sort(list, function(a, b)
        if a.Order ~= b.Order then return a.Order < b.Order end
        return a.Cost < b.Cost
    end)
    armsCache = list
    armsCacheT = now + 30
    return list
end

local function armPower(d)
    d = d or pData()
    if d and ArmsUtils and type(ArmsUtils.GetArmPower) == "function" then
        local ok, p = pcall(ArmsUtils.GetArmPower, d)
        if ok and tonumber(p) and tonumber(p) > 0 then return tonumber(p) end
    end
    local key = d and d.EquippedArmKey
    local c = key and Config and Config.Arms and Config.Arms[key]
    if c and tonumber(c.ArmPower) then return tonumber(c.ArmPower) end
    return 1
end

local function equipArm(key)
    if not ArmsAction then return false end
    for _ = 1, 2 do
        fire(ArmsAction, "Equip", key)
        task.wait(0.25)
        local d = pData()
        if d and d.EquippedArmKey == key then
            notify("Arms", "Equipped " .. key)
            return true
        end
    end
    return false
end

local function equipBestArm()
    local d = pData()
    if not d or type(d.PurchasedArms) ~= "table" or not Config or type(Config.Arms) ~= "table" then return end
    local bestNormal = 0
    for k in pairs(d.PurchasedArms) do
        local c = Config.Arms[k]
        if c and not c.BestPercent then
            bestNormal = math.max(bestNormal, tonumber(c.ArmPower) or 0)
        end
    end
    local bestKey, bestPow = nil, -1
    for k in pairs(d.PurchasedArms) do
        local c = Config.Arms[k]
        if c then
            local p = c.BestPercent and (bestNormal * (tonumber(c.BestPercent) or 100) / 100)
                or (tonumber(c.ArmPower) or 0)
            if p > bestPow then bestPow, bestKey = p, k end
        end
    end
    if bestKey and d.EquippedArmKey ~= bestKey then
        equipArm(bestKey)
    end
end

local function buyNextArm()
    local d = pData()
    if not d or not ArmsAction then return end
    local owned = (type(d.PurchasedArms) == "table" and d.PurchasedArms) or {}

    local key
    if ArmsUtils and type(ArmsUtils.GetNextUnlockKey) == "function" then
        local ok, k = pcall(ArmsUtils.GetNextUnlockKey, d)
        if ok and type(k) == "string" then key = k end
    end
    if not key then
        for _, a in ipairs(armsList()) do
            if not a.Robux and not owned[a.Key] then key = a.Key break end
        end
    end
    if not key then return end
    if os.clock() < (Blacklist.Arms[key] or 0) then return end

    local c = Config.Arms[key]
    local cost = (c and tonumber(c.UnlockCost)) or 0
    if getCash(d) < cost then return end

    fire(ArmsAction, "Unlock", key)
    task.wait(0.4)
    local nd = pData()
    if nd and type(nd.PurchasedArms) == "table" and nd.PurchasedArms[key] then
        notify("Arms", "Bought " .. key .. " for " .. cost)
        equipArm(key)
    else
        Blacklist.Arms[key] = os.clock() + 10
    end
end

-- ================= TOWER / STAGES =================
local function isGuid(s)
    return type(s) == "string" and #s == 36 and s:match("^%x+%-%x+%-%x+%-%x+%-%x+$") ~= nil
end

local function instPos(i)
    if i:IsA("BasePart") then
        return i.Position
    elseif i:IsA("Model") then
        return i:GetPivot().Position
    elseif i:IsA("Attachment") then
        return i.WorldPosition
    end
end

local function towerRoot()
    local map = workspace:FindFirstChild("Map")
    return map and map:FindFirstChild("Tower")
end

local function stageCount()
    local tower = towerRoot()
    if not tower then return TOTAL end
    local mx = 0
    for _, c in ipairs(tower:GetChildren()) do
        local n = tonumber(c.Name:match("^Stage(%d+)$"))
        if n and n > mx then mx = n end
    end
    return mx > 0 and mx or TOTAL
end

local function stageFolder(n)
    local tower = towerRoot()
    return tower and tower:FindFirstChild("Stage" .. n)
end

local function doorOf(n)
    local st = stageFolder(n)
    return st and (st:FindFirstChild("Door") or st:FindFirstChild("Door", true))
end

local function zoneOf(n)
    local door = doorOf(n)
    if not door then return nil end
    return door:FindFirstChild("Zone") or door:FindFirstChild("Zone", true)
end

local function stageCfg(n)
    if not Config or type(Config.Stages) ~= "table" then return nil end
    return Config.Stages["Stage" .. n]
end

local function stageHealth(n)
    local st = stageCfg(n)
    return st and st.DoorHealth or nil
end

local function stageDoorHits(n)
    local st = stageCfg(n)
    return st and st.DoorHits or nil
end

local function healthLabelNumber(gui)
    if not gui then return nil end
    for _, d in ipairs(gui:GetDescendants()) do
        if d:IsA("TextLabel") and d.Text ~= "" then
            local n = tonumber(d.Text:match("%d+"))
            if n then return n end
        end
    end
end

local function snapshot(door)
    local plate = door and door:FindFirstChild("MainPlate", true)
    local gui = door and door:FindFirstChild("DoorHealthGUI", true)
    return {
        hadGui = gui ~= nil,
        trans = plate and plate.Transparency,
        collide = plate and plate.CanCollide,
    }
end

local function isBroken(door, base)
    if not door or not door.Parent then return true end
    local plate = door:FindFirstChild("MainPlate", true)
    local gui = door:FindFirstChild("DoorHealthGUI", true)
    if plate then
        if plate.Transparency >= 0.99 or not plate.CanCollide then return true end
        if base.trans ~= nil and plate.Transparency ~= base.trans then return true end
        if base.collide ~= nil and plate.CanCollide ~= base.collide then return true end
    end
    if base.hadGui and not gui then return true end
    if gui then
        if gui:IsA("LayerCollector") and gui.Enabled == false then return true end
        if healthLabelNumber(gui) == 0 then return true end
    end
    return false
end

local function findSpawn(stage, name)
    local ck = tostring(stage) .. ":" .. name
    local c = spawnCache[ck]
    if c and c.Parent then return c end
    local tower = towerRoot()
    if not tower then return nil end
    local base = stage and tower:FindFirstChild("Stage" .. stage) or tower
    if not base then return nil end
    for _, d in ipairs(base:GetDescendants()) do
        if d.Name == name and instPos(d) then
            spawnCache[ck] = d
            return d
        end
    end
end

local function keyOf(inst)
    local a = inst:GetAttribute("ItemKey") or inst:GetAttribute("Treasure") or inst:GetAttribute("Item")
    if a and TreasureItems[a] then return a end
    for _, d in ipairs(inst:GetDescendants()) do
        if TreasureItems[d.Name] then return d.Name end
    end
    local p = inst.Parent
    if p and TreasureItems[p.Name] then return p.Name end
end

local function extractTreasures(data, out)
    local function step(node, ctx, depth)
        if type(node) ~= "table" or depth > 8 then return end
        local c = {stage = ctx.stage, spawn = ctx.spawn, id = ctx.id, key = ctx.key, variant = ctx.variant}
        for k, v in pairs(node) do
            if type(v) == "string" then
                if isGuid(v) then
                    c.id = v
                elseif v:match("^ItemSpawn%d+$") then
                    c.spawn = v
                elseif TreasureItems[v] then
                    c.key = v
                elseif VariantCfg[v] then
                    c.variant = v
                end
            end
            if (k == "Stage" or k == "StageId" or k == "StageID" or k == "StageIndex") and tonumber(v) then
                c.stage = tonumber(v)
            end
        end
        if c.id and c.spawn and not out[c.id] then
            out[c.id] = {stage = c.stage, spawn = c.spawn, id = c.id, key = c.key, variant = c.variant}
        end
        for k, v in pairs(node) do
            if type(v) == "table" then
                local n = {stage = c.stage, spawn = c.spawn, id = c.id, key = c.key, variant = c.variant}
                if type(k) == "number" and depth == 0 and k >= 1 and k <= 64 then
                    n.stage = k
                elseif type(k) == "string" then
                    local sn = k:match("^Stage(%d+)$")
                    if sn then
                        n.stage = tonumber(sn)
                    elseif isGuid(k) then
                        n.id = k
                    elseif k:match("^ItemSpawn%d+$") then
                        n.spawn = k
                    elseif TreasureItems[k] then
                        n.key = k
                    end
                end
                step(v, n, depth + 1)
            end
        end
    end
    step(data, {}, 0)
end

local function fetchTreasures()
    lastRaw = nil
    local out = {}
    if not RequestStageTreasures then return out, "remote missing" end
    local ok, data = invoke(RequestStageTreasures)
    if not ok then return nil, tostring(data) end
    lastRaw = data
    extractTreasures(data, out)
    local list = {}
    for _, t in pairs(out) do table.insert(list, t) end
    return list
end

local function incomeOf(key, variant)
    local it = key and TreasureItems[key]
    if not it then return 0, 0 end
    local inc = it.Income or 0
    local vr = variant and VariantCfg[variant]
    if vr and tonumber(vr.MutationMulti) then
        inc = inc * vr.MutationMulti
    end
    return inc, it.Value or 0
end

local function holdFor(t)
    local d = pData()
    if d and TreasurePickupUtils and type(TreasurePickupUtils.GetHoldDuration) == "function" and t.key then
        local ok, r = pcall(TreasurePickupUtils.GetHoldDuration, d, {
            ItemType = "Treasure",
            Key = t.key,
            Variant = t.variant or "Normal",
        })
        if ok and tonumber(r) then return tonumber(r) + 0.2 end
    end
    return S.HoldTime
end

-- ================= PLACE =================
local function placeAll(n)
    if not PlaceBestLuck then return end
    for _ = 1, math.max(n, 1) do
        fire(PlaceBestLuck)
        task.wait(0.25)
    end
end

-- ================= AUTO STAGE =================
local function standAndBreak(n, hits)
    local zone = zoneOf(n)
    if not zone then return "nozone" end
    local pos = instPos(zone)
    if not pos then return "nozone" end
    local door = doorOf(n)
    local base = snapshot(door)
    local sig = BrokenCount
    moveTo(CFrame.new(pos))
    local limit = hits * (DoorCfg.SwingInterval or 0.5) + (DoorCfg.HitDelay or 0.25) + 4
    local t0 = os.clock()
    while S.AutoStage and os.clock() - t0 < limit do
        if BrokenCount > sig or isBroken(door, base) then
            brokenStages[n] = true
            return "broken"
        end
        local r = root()
        if r and (r.Position - pos).Magnitude > 8 then
            moveTo(CFrame.new(pos))
        end
        task.wait(0.2)
    end
    brokenStages[n] = true
    return "timeout"
end

local function progressStages()
    local power = armPower()
    local total = stageCount()
    while S.AutoStage and S.NextStage <= total do
        local n = S.NextStage
        if n < S.MinStage then S.NextStage = S.MinStage n = S.NextStage end
        if brokenStages[n] or not doorOf(n) then
            S.NextStage = n + 1
            continue
        end
        local health = stageHealth(n)
        local doorHits = stageDoorHits(n)
        if not health and not doorHits then
            S.Blocked = n
            setInfo(string.format("Stage %d: no DoorHealth/DoorHits in config", n))
            return
        end
        local need
        if health and power > 0 then
            need = math.ceil(health / power)
        else
            need = doorHits or S.MaxHits
        end
        if need > S.MaxHits then
            S.Blocked = n
            setInfo(string.format(
                "Stopped at Stage %d | Health %s | Power %s | Needs %d hits (max %d)",
                n, tostring(health), tostring(power), need, S.MaxHits
            ))
            return
        end
        S.Blocked = nil
        setInfo(string.format("Stage %d | Health %s | Power %s | Needs %d hits", n, tostring(health), tostring(power), need))
        setStatus("Standing in Zone of Stage" .. n)
        local res = standAndBreak(n, need)
        setStatus("Stage" .. n .. ": " .. res)
        S.NextStage = n + 1
    end
    if S.NextStage > total then
        setInfo("All doors done (" .. total .. " stages)")
    end
end

-- ================= LOOT =================
local function loot()
    setStatus("Getting treasure list...")
    local list, err = fetchTreasures()
    if not list then
        setStatus("Request failed: " .. tostring(err))
        task.wait(2)
        return
    end

    local candidates = {}
    for _, t in ipairs(list) do
        local bl = Blacklist.Pickup[t.id]
        local blocked = bl and os.clock() < bl
        local inRange = (not t.stage) or (t.stage >= S.MinStage and t.stage <= S.MaxStage)
        if not blocked and inRange then
            local inst = findSpawn(t.stage, t.spawn)
            if inst then
                t.inst = inst
                if not t.stage then
                    local p = inst
                    while p and p ~= workspace do
                        local n = tonumber(p.Name:match("^Stage(%d+)$"))
                        if n then t.stage = n break end
                        p = p.Parent
                    end
                end
                if not t.key then t.key = keyOf(inst) end
                t.income, t.value = incomeOf(t.key, t.variant)
                if t.stage and t.stage >= S.MinStage and t.stage <= S.MaxStage then
                    table.insert(candidates, t)
                end
            end
        end
    end

    table.sort(candidates, function(a, b)
        if a.income ~= b.income then return a.income > b.income end
        return a.value > b.value
    end)

    if #candidates == 0 then
        setStatus("No treasures found (" .. #list .. " read). Try Dump Treasures.")
        task.wait(2)
        return
    end

    local cap = capacity()
    local picked = 0
    for _, t in ipairs(candidates) do
        if not S.Run or picked >= cap then break end
        local pos = instPos(t.inst)
        if not pos then continue end
        setStatus(string.format("Getting %s (Stage %s, income %s)", tostring(t.key or "?"), tostring(t.stage), tostring(t.income)))
        moveTo(CFrame.new(pos + Vector3.new(0, 3, 0)))
        task.wait(holdFor(t))
        local ok, res = invoke(PickupStageTreasure, t.stage, t.spawn, t.id)
        if ok and res ~= false then
            picked += 1
            setStatus("Pickup OK: " .. tostring(t.key) .. " | res=" .. tostring(res))
        else
            Blacklist.Pickup[t.id] = os.clock() + 15
            setStatus("Pickup failed: " .. tostring(t.key) .. " | res=" .. tostring(res))
        end
        task.wait(S.Delay)
    end

    if picked > 0 and S.Run then
        setStatus("Going back to base and placing best...")
        if S.BasePos then moveTo(S.BasePos) end
        task.wait(0.4)
        placeAll(picked)
        task.wait(0.3)
    end
end

-- ================= BASE / BANK / SELL =================
local function returnToBase()
    if RequestTeleport then
        invoke(RequestTeleport, "Base")
        task.wait(0.6)
        local hrp = root()
        if hrp and S.BasePos and (hrp.Position - S.BasePos.Position).Magnitude < 40 then
            return true
        end
    end
    if S.BasePos then
        notify("Base", "Going back to base")
        return moveHumanoid(S.BasePos.Position, S.HoldTime)
    end
    notify("Base", "No base saved. Use Set Base Here first.")
    return false
end

local function waitBanked(timeout)
    local t0 = os.clock()
    while carriedCount() > 0 and os.clock() - t0 < (timeout or 10) do
        task.wait(0.25)
    end
    return carriedCount() == 0
end

local function plotItemCount(d)
    d = d or pData()
    local n = 0
    if d and type(d.Plot) == "table" then
        for _, floor in pairs(d.Plot) do
            if type(floor) == "table" then
                for _, slot in pairs(floor) do
                    if type(slot) == "table" and slot.Item then n += 1 end
                end
            end
        end
    end
    return n
end

local function unlockedEmptySlots(d)
    local out = {}
    if not d or not Config or type(Config.Plot) ~= "table" then return out end
    local stands = tonumber(Config.Plot.NumberStands) or 10
    local maxSlots = tonumber(Config.Plot.MaxSlots) or 20
    local floors = math.ceil(maxSlots / stands)
    for f = 1, floors do
        for s = 1, stands do
            local fn, sn = "Floor" .. f, "Slot" .. s
            local unlocked = true
            if PlotSlotUtils and type(PlotSlotUtils.IsUnlocked) == "function" then
                local ok, u = pcall(PlotSlotUtils.IsUnlocked, d, fn, sn)
                unlocked = ok and u == true
            end
            local occupied = type(d.Plot) == "table" and type(d.Plot[fn]) == "table"
                and type(d.Plot[fn][sn]) == "table" and d.Plot[fn][sn].Item ~= nil
            if unlocked and not occupied then
                table.insert(out, {Floor = fn, Slot = sn, Num = (f - 1) * stands + s})
            end
        end
    end
    table.sort(out, function(a, b) return a.Num < b.Num end)
    return out
end

local function placeBest()
    local d = pData()
    if not d then return end
    local items = inventoryItems(d)
    if #items == 0 then
        notify("Place", "Inventory is empty, nothing to place")
        return
    end

    local before = plotItemCount(d)
    if PlaceBestLuck then
        fire(PlaceBestLuck)
        task.wait(0.8)
        if plotItemCount() > before then
            notify("Place", "Best items placed")
            return
        end
    end

    for _, it in ipairs(items) do
        it._inc, it._val = itemValue(it)
    end
    table.sort(items, function(a, b)
        if a._inc ~= b._inc then return a._inc > b._inc end
        return a._val > b._val
    end)
    local slots = unlockedEmptySlots(pData() or d)
    if #slots == 0 or not SlotInteraction then
        notify("Place", "No empty unlocked slots")
        return
    end
    local placed = 0
    for i, it in ipairs(items) do
        local slot = slots[i]
        if not slot then break end
        local sigs = {
            {"Place", it.UUID, slot.Floor, slot.Slot},
            {slot.Floor, slot.Slot, it.UUID},
            {"Place", slot.Floor, slot.Slot, it.UUID},
        }
        local order = {}
        for k = 0, #sigs - 1 do table.insert(order, sigs[(S.PlaceMode - 1 + k) % #sigs + 1]) end
        for idx, args in ipairs(order) do
            fire(SlotInteraction, table.unpack(args))
            task.wait(0.35)
            local nd = pData()
            if nd and type(nd.Plot) == "table" and type(nd.Plot[slot.Floor]) == "table"
                and type(nd.Plot[slot.Floor][slot.Slot]) == "table"
                and nd.Plot[slot.Floor][slot.Slot].Item then
                placed += 1
                S.PlaceMode = (S.PlaceMode - 1 + idx - 1) % #sigs + 1
                break
            end
        end
    end
    notify("Place", "Placed " .. placed .. " items")
end

local function sellAll()
    local d = pData()
    local items = inventoryItems(d)
    local uuids = {}
    for _, it in ipairs(items) do
        if isSellable(it) then table.insert(uuids, tostring(it.UUID)) end
    end
    if #uuids == 0 then
        notify("Sell", "Nothing sellable (favorites and Exclusive are protected)")
        return
    end
    local before = #items

    local function sold()
        return #inventoryItems() < before
    end

    for k = 0, 2 do
        local mode = (S.SellMode - 1 + k) % 3 + 1
        if mode == 1 and SellItems then
            fire(SellItems, uuids)
            task.wait(0.8)
        elseif mode == 2 and SellItems then
            fire(SellItems)
            task.wait(0.8)
        elseif mode == 3 and SellItem then
            for _, id in ipairs(uuids) do
                fire(SellItem, id)
                task.wait(0.15)
            end
            task.wait(0.5)
        end
        if sold() then
            S.SellMode = mode
            notify("Sell", "Sold items, left: " .. #inventoryItems())
            return
        end
    end
    notify("Sell", "Sell sent, left in inventory: " .. #inventoryItems())
end

-- ================= ECONOMY =================
local function buyUpgrades(d)
    if not PurchaseUpgrade then return end
    for _, name in ipairs(S.UpgradeList) do
        if os.clock() >= (Blacklist.Upgrades[name] or 0)
            and UpgradeUtils and type(UpgradeUtils.GetNext) == "function" then
            local okb, b = pcall(UpgradeUtils.GetNext, d, name)
            if okb and b and tonumber(b.Cost) and getCash(d) >= tonumber(b.Cost) then
                local okl, before = pcall(UpgradeUtils.GetLevel, d, name)
                before = (okl and tonumber(before)) or 0
                invoke(PurchaseUpgrade, name)
                task.wait(0.35)
                local nd = pData()
                local okl2, after = pcall(UpgradeUtils.GetLevel, nd, name)
                after = (okl2 and tonumber(after)) or 0
                if after > before then
                    notify("Upgrade", name .. " bought (level " .. after .. ")")
                else
                    Blacklist.Upgrades[name] = os.clock() + 10
                end
            end
        end
    end
end

local function buyPlot(d)
    if os.clock() < Blacklist.Plot or not UpgradePlot then return end
    local pc = Config and Config.Plot
    if type(pc) ~= "table" or type(pc.UPGRADE_PRICES) ~= "table" then return end
    local lvl = tonumber(d.BaseLevel) or 0
    local maxL = tonumber(pc.MaxLevel) or 0
    if maxL > 0 and lvl >= maxL then return end

    local nextSlot = (tonumber(pc.DefaultUnlockedSlots) or 5) + lvl + 1
    if PlotSlotUtils and type(PlotSlotUtils.GetRequiredRebirths) == "function" then
        local ok, req = pcall(PlotSlotUtils.GetRequiredRebirths, nextSlot)
        if ok and tonumber(req) and (tonumber(d.Rebirths) or 0) < tonumber(req) then
            Blacklist.Plot = os.clock() + 30
            return
        end
    end

    local cost = tonumber(pc.UPGRADE_PRICES[lvl]) or tonumber(pc.UPGRADE_PRICES[lvl + 1])
    if not cost or getCash(d) < cost then return end

    fire(UpgradePlot)
    task.wait(0.4)
    local nd = pData()
    local nlvl = nd and (tonumber(nd.BaseLevel) or 0) or 0
    if nlvl > lvl then
        notify("Plot", "Plot upgraded to level " .. nlvl)
    else
        Blacklist.Plot = os.clock() + 10
    end
end

local function doRebirth(d)
    if os.clock() < Blacklist.Rebirth or not PerformRebirth then return end
    if not RebirthUtils or type(RebirthUtils.GetNextCost) ~= "function" then return end
    local okc, cost = pcall(RebirthUtils.GetNextCost, d)
    if not okc or not tonumber(cost) then return end
    if getCash(d) < tonumber(cost) then return end
    local rb = tonumber(d.Rebirths) or 0
    fire(PerformRebirth)
    task.wait(0.5)
    local nd = pData()
    local nrb = nd and (tonumber(nd.Rebirths) or 0) or 0
    if nrb > rb then
        notify("Rebirth", "Rebirth done (" .. nrb .. ")")
        S.NextStage = S.MinStage
        S.Blocked = nil
        brokenStages = {}
    else
        Blacklist.Rebirth = os.clock() + 10
    end
end

local function econTick()
    if isBusy() then return end
    local d = pData()
    if not d then return end
    if S.AutoArms then
        pcall(buyNextArm)
        pcall(equipBestArm)
    end
    if S.AutoUpgrades then pcall(buyUpgrades, d) end
    if S.AutoPlot then pcall(buyPlot, d) end
    if S.AutoRebirth then pcall(doRebirth, d) end
end

-- ================= MAIN LOOPS =================
local function cycle()
    local hrp = root()
    if not hrp then
        setStatus("Waiting for character...")
        task.wait(1)
        return
    end
    if isBusy() then task.wait(1) return end
    if not S.BasePos then saveBase(hrp.CFrame) end
    S.MaxStage = stageCount()
    if S.AutoStage then progressStages() end
    if S.Run then loot() end
end

local function start()
    if loopThread then return end
    loopThread = task.spawn(function()
        while S.Run or S.AutoStage do
            local ok, err = pcall(cycle)
            if not ok then
                setStatus("Error: " .. tostring(err))
                task.wait(1)
            end
            task.wait(0.15)
        end
        loopThread = nil
        setStatus("Idle")
    end)
end

task.spawn(function()
    while true do
        task.wait(1.5)
        local ok, err = pcall(econTick)
        if not ok then warn("HeistFarm econ error: " .. tostring(err)) end
    end
end)

LP.CharacterAdded:Connect(function()
    task.wait(0.5)
    spawnCache = {}
    brokenStages = {}
end)

-- ================= UI =================
MainTab:CreateParagraph{
    Title = "Fixed settings",
    Content = "Max Hits = 10 | Min Stage = 1 | Max Stage = " .. TOTAL
        .. " | Capacity = Backpack upgrade (1-4) | Delay = 0.4 | Hold Time = 0.15 | Auto Stage follows Auto Farm"
}

MainTab:CreateSection({Name = "Auto Farm", Description = "Auto Stage first, then pick up the best income treasures"})

MainTab:CreateToggle{
    Name = "Auto Farm",
    Description = "Auto Stage + pick up best income > base > Place Best",
    Flag = "AutoFarm",
    CurrentValue = false,
    Callback = function(v)
        S.Run = v and true or false
        S.AutoStage = S.Run
        if S.Run then
            start()
        elseif S.AutoSell then
            task.spawn(function()
                returnToBase()
                waitBanked(10)
                placeBest()
                sellAll()
            end)
        end
    end
}

EcoTab:CreateSection("Arms")
EcoTab:CreateToggle{
    Name = "Auto Unlock Arms",
    Flag = "AutoArms",
    CurrentValue = true,
    Callback = function(v) S.AutoArms = v and true or false end
}
EcoTab:CreateParagraph{
    Title = "Arms info",
    Content = "Uses the game's next-unlock order (Dirt -> Wood -> ... -> Nuclear). Skips Robux-only arms (TNT). Buys when cash is enough, equips right away, and keeps the best arm equipped."
}

EcoTab:CreateSection("Upgrades")
EcoTab:CreateToggle{
    Name = "Auto Buy Upgrades",
    Flag = "AutoUpgrades",
    CurrentValue = false,
    Callback = function(v) S.AutoUpgrades = v and true or false end
}
EcoTab:CreateDropdown{
    Name = "Upgrade List",
    Flag = "UpgradeList",
    Options = {"Backpack", "MoveSpeed", "PickupSpeed"},
    MultipleOptions = true,
    Callback = function(v)
        local list = {}
        if type(v) == "table" then
            for k, val in pairs(v) do
                if val == true then
                    table.insert(list, tostring(k))
                elseif type(k) == "number" and type(val) == "string" then
                    table.insert(list, val)
                end
            end
        elseif type(v) == "string" then
            list = {v}
        end
        if #list > 0 then S.UpgradeList = list end
    end
}
EcoTab:CreateParagraph{
    Title = "Upgrades info",
    Content = "Default list: Backpack. Pick more in the dropdown. PurchaseUpgrade is a RemoteFunction, every buy is checked by level change."
}

EcoTab:CreateSection("Plot and Rebirth")
EcoTab:CreateToggle{
    Name = "Auto Upgrade Plot",
    Flag = "AutoPlot",
    CurrentValue = false,
    Callback = function(v) S.AutoPlot = v and true or false end
}
EcoTab:CreateToggle{
    Name = "Auto Rebirth",
    Flag = "AutoRebirth",
    CurrentValue = false,
    Callback = function(v) S.AutoRebirth = v and true or false end
}

EcoTab:CreateSection("Sell")
EcoTab:CreateToggle{
    Name = "Auto Sell",
    Flag = "AutoSell",
    CurrentValue = false,
    Callback = function(v) S.AutoSell = v and true or false end
}
EcoTab:CreateParagraph{
    Title = "Auto Sell info",
    Content = "When Auto Farm turns OFF: go back to base, wait for banking, place best items (PlaceBestLuck), then sell the rest. Favorites and Exclusive items are never sold."
}

MoveTab:CreateDropdown{
    Name = "Move Mode",
    Flag = "MoveMode",
    Options = {"Tween", "Instant"},
    CurrentOption = "Tween",
    Callback = function(v)
        if type(v) == "string" then S.MoveMode = v end
    end
}
MoveTab:CreateSlider{
    Name = "Tween Speed",
    Flag = "TweenSpeed",
    Range = {16, 200},
    Increment = 1,
    CurrentValue = 60,
    Suffix = " studs/s",
    Callback = function(v) S.TweenSpeed = tonumber(v) or 60 end
}
MoveTab:CreateParagraph{
    Title = "Fixed",
    Content = "Hold Time = 0.15 (fixed). Farming pauses automatically while Jailed or Ziplining."
}

ToolTab:CreateSection("Base")
ToolTab:CreateButton{
    Name = "Set Base Here",
    Callback = function()
        local hrp = root()
        if hrp then
            saveBase(hrp.CFrame)
            notify("Base", "Base position saved")
        end
    end
}
ToolTab:CreateButton{
    Name = "Teleport To Base",
    Callback = function() task.spawn(returnToBase) end
}
ToolTab:CreateButton{
    Name = "Bank Now (go base + wait)",
    Callback = function()
        task.spawn(function()
            returnToBase()
            waitBanked(10)
            notify("Base", "Banked. Inventory: " .. #inventoryItems())
        end)
    end
}
ToolTab:CreateButton{
    Name = "Place Best Now",
    Callback = function() task.spawn(placeBest) end
}
ToolTab:CreateButton{
    Name = "Sell All Now",
    Callback = function() task.spawn(sellAll) end
}
ToolTab:CreateButton{
    Name = "Equip Best Arm",
    Callback = function() task.spawn(equipBestArm) end
}

ToolTab:CreateSection("Debug")
ToolTab:CreateButton{
    Name = "Dump Treasures",
    Callback = function()
        local list = fetchTreasures() or {}
        print("=== TREASURE DUMP (" .. #list .. ") ===")
        for i, t in ipairs(list) do
            print(i, tostring(t.key), tostring(t.variant), "stage=" .. tostring(t.stage),
                "spawn=" .. tostring(t.spawn), tostring(t.id))
        end
        notify("Debug", "Treasures dumped to console")
    end
}
ToolTab:CreateButton{
    Name = "Dump Doors",
    Callback = function()
        print("=== DOOR DUMP ===")
        for n = 1, stageCount() do
            local door = doorOf(n)
            if door then
                local snap = snapshot(door)
                local health = stageHealth(n)
                local hits = stageDoorHits(n)
                local power = armPower()
                local need = (health and power > 0) and math.ceil(health / power) or (hits or "?")
                local fullName = "unknown"
                pcall(function() fullName = door:GetFullName() end)
                print("Stage " .. n, fullName,
                    "broken=" .. tostring(isBroken(door, snap)),
                    "health=" .. tostring(health),
                    "doorHits=" .. tostring(hits),
                    "need=" .. tostring(need),
                    "power=" .. tostring(power),
                    "zone=" .. tostring(zoneOf(n) ~= nil))
            end
        end
        notify("Debug", "Doors dumped to console")
    end
}
ToolTab:CreateButton{
    Name = "Dump PlayerData",
    Callback = function()
        local d = pData()
        print("=== PLAYERDATA DUMP ===")
        if not d then
            print("No replica data found")
        else
            walk(d, function(path, v)
                if type(v) ~= "table" then print(path, "=", tostring(v)) end
            end)
        end
        notify("Debug", "PlayerData dumped to console")
    end
}
ToolTab:CreateButton{
    Name = "Dump Carried / Inventory",
    Callback = function()
        print("=== CARRIED TOOLS (" .. carriedCount() .. "/" .. capacity() .. ") ===")
        for _, t in ipairs(carriedItems()) do
            print(t.Name, t:GetAttribute("Key"), t:GetAttribute("Variant"), t:GetAttribute("UUID"))
        end
        local inv = inventoryItems()
        print("=== BANKED INVENTORY (" .. #inv .. ") ===")
        for _, it in ipairs(inv) do
            print(it.Key, it.Variant, "sellable=" .. tostring(isSellable(it)), it.UUID)
        end
        notify("Debug", "Carried + inventory dumped")
    end
}

ToolTab:CreateSection("Stages")
ToolTab:CreateButton{
    Name = "Reset Stage Pointer",
    Callback = function()
        S.NextStage = S.MinStage
        S.Blocked = nil
        brokenStages = {}
        spawnCache = {}
        notify("Stage", "Stage pointer reset to " .. S.MinStage)
    end
}

if not (RequestStageTreasures and PickupStageTreasure and PlaceBestLuck) then
    notify("Remote Missing", "RequestStageTreasures / PickupStageTreasure / PlaceBestLuck not found")
end
if not DataAgg then
    notify("Data Missing", "DataAggregation not found, using Config.Arms power")
end
