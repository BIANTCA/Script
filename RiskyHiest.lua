--[[
    Heist Farm (fixed from test.lua dump)
    - BulbGui: pastebin 2BGUWvbd (per style preference)
    - Remotes via TypedRemote / RemoteBank
    - Stages, Treasures, Arms, Plot, Rebirth sesuai Shared.Config
    - v3: arms yang baru dibeli langsung dipakai, semua pembelian/upgrade
      dicocokkan dengan cash saat ini (menunggu otomatis sampai cukup),
      UI dibersihkan (nilai fixed), Auto Stage menyala bersama Auto Farm
]]

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local LP = Players.LocalPlayer

local BulbGui = loadstring(game:HttpGet("https://pastebin.com/raw/2BGUWvbd"))()
local Gui = BulbGui:Init({
    Name = "Heist Farm",
    Subtitle = "Income First + Auto Stage",
    FolderName = "TumblrConfigs",
    FileName = "heistfarm_v2.json"
})

local function mod(...)
    local o = RS
    for _, n in ipairs({...}) do
        o = o and o:FindFirstChild(n)
    end
    if o then
        local ok, m = pcall(require, o)
        if ok then return m end
    end
    return nil
end

local Config = mod("Shared", "Config")
local ArmsUtils = mod("Shared", "Modules", "ArmsUtils")
local UpgradeUtils = mod("Shared", "Modules", "UpgradeUtils")
local RebirthUtils = mod("Shared", "Modules", "RebirthUtils")
local PickupUtils = mod("Shared", "Modules", "TreasurePickupUtils")

local DataAgg = nil
pcall(function()
    DataAgg = require(LP:WaitForChild("PlayerScripts"):WaitForChild("ClientModules", 10):WaitForChild("DataAggregation", 10))
end)

local Items = (Config and Config.Treasures and Config.Treasures.Items) or {}
local Variants = (Config and Config.Variants) or {}
local DoorCfg = (Config and Config.Doors) or { SwingInterval = 0.5, HitDelay = 0.25 }
local TOTAL = (Config and Config.Tower and Config.Tower.StageCount) or 21
local ArmsCfg = (Config and Config.Arms) or {}
local PlotCfg = (Config and Config.Plot) or {}

-- Remote: TypedRemote ada di Shared.Packages.TypedRemote
local RemoteRoot = RS:WaitForChild("Shared"):WaitForChild("Packages"):WaitForChild("TypedRemote")
local function R(name)
    return RemoteRoot:FindFirstChild(name)
end

-- Utamakan module RemoteBank jika ada (instance sama)
local function bank(modName, key)
    local m = mod("RemoteBank", modName)
    if m and m[key] then return m[key] end
    return R(key)
end

local RequestRemote = bank("Stages", "RequestStageTreasures") or R("RequestStageTreasures")
local PickupRemote = bank("Stages", "PickupStageTreasure") or R("PickupStageTreasure")
local StageTreasuresReset = bank("Stages", "StageTreasuresReset") or R("StageTreasuresReset")
local PlaceRemote = bank("Plot", "PlaceBestLuck") or R("PlaceBestLuck")
local UpgradePlotRemote = bank("Plot", "UpgradePlot") or R("UpgradePlot")
local RebirthRemote = R("PerformRebirth") -- main RemoteBank
local ArmsRemote = bank("Arms", "ArmsAction") or R("ArmsAction")
local ArmsEquipRemote = bank("Arms", "EquipArm") or R("EquipArm") or R("EquipArms")
local PurchaseRemote = bank("Upgrades", "PurchaseUpgrade") or R("PurchaseUpgrade")
local DoorBrokenRemote = bank("Doors", "DoorBroken") or R("DoorBroken")
local DoorsResetRemote = bank("Doors", "DoorsReset") or R("DoorsReset")
local RequestDoorsRemote = bank("Doors", "RequestDoors") or R("RequestDoors")

local S = {
    Run = false,
    AutoStage = false,
    Capacity = 1, -- cadangan jika nilai Backpack tidak terbaca
    MaxHits = 10,
    MinStage = 1,
    MaxStage = TOTAL,
    Hold = 1.2,
    MoveMode = "Tween",
    Speed = 160,
    Delay = 0.4,
    Base = nil,
    NextStage = 1,
    Blocked = nil,
    EcoPlot = false,
    EcoRebirth = false,
    EcoArms = false,
    EcoUpgrades = false,
    EcoList = {}
}

local blacklist = {}
local spawnCache = {}
local brokenStages = {}
local armBlacklist = {}
local upgradeBlacklist = {}
local plotCooldown = 0
local lastRaw = nil
local loopThread = nil
local brokenSignal = 0

local Tab = Gui:CreateTab("Farm", 4483362458)
local _, _, _, StatusCtl = Tab:CreateParagraph({ Title = "Status", Content = "Idle" })
local _, _, _, InfoCtl = Tab:CreateParagraph({ Title = "Stage Info", Content = "-" })
local function setStatus(t) pcall(function() StatusCtl:SetContent(t) end) end
local function setInfo(t) pcall(function() InfoCtl:SetContent(t) end) end

local function pdata()
    if not DataAgg then return nil end
    local ok, r = pcall(function()
        local rep = DataAgg.GetReplica()
        return rep and rep.Data
    end)
    return ok and r or nil
end

local function equippedKey()
    local d = pdata()
    return d and d.EquippedArmKey or nil
end

-- Pakai arms yang baru saja dibeli (coba remote equip khusus, lalu ArmsAction)
local function equipArm(key)
    if not key then return false end
    if equippedKey() == key then return true end
    if ArmsEquipRemote then
        pcall(function()
            if ArmsEquipRemote:IsA("RemoteFunction") then
                ArmsEquipRemote:InvokeServer(key)
            else
                ArmsEquipRemote:FireServer(key)
            end
        end)
        task.wait(0.5)
        if equippedKey() == key then
            setStatus("Arms dipakai: " .. key)
            return true
        end
    end
    if ArmsRemote then
        for _, act in ipairs({ "Equip", "Select" }) do
            pcall(function() ArmsRemote:FireServer(act, key) end)
            task.wait(0.4)
            if equippedKey() == key then
                setStatus("Arms dipakai: " .. key)
                return true
            end
        end
    end
    setStatus("Equip arms " .. key .. " belum terverifikasi")
    return false
end

local function armPower()
    local d = pdata()
    if d and ArmsUtils then
        local ok, p = pcall(ArmsUtils.GetArmPower, d)
        if ok and tonumber(p) and p > 0 then
            return p
        end
    end
    -- fallback: Config.Arms[EquippedArmKey].ArmPower
    if d and type(d.EquippedArmKey) == "string" and ArmsCfg[d.EquippedArmKey] then
        local ap = ArmsCfg[d.EquippedArmKey].ArmPower
        if tonumber(ap) and ap > 0 then return ap end
    end
    return 1
end

local function capacity()
    -- Auto: selalu ikuti upgrade Backpack
    if UpgradeUtils then
        local d = pdata()
        if d then
            local ok, v = pcall(UpgradeUtils.GetValue, d, "Backpack")
            if ok and tonumber(v) then return math.max(1, math.floor(v)) end
        end
    end
    return math.max(1, math.floor(S.Capacity or 1))
end

local function stageData(n)
    return Config and Config.Stages and Config.Stages["Stage" .. n]
end

local function stageHealth(n)
    local st = stageData(n)
    return st and st.DoorHealth or nil
end

local function stageDoorHits(n)
    local st = stageData(n)
    return st and st.DoorHits or nil
end

local function isGuid(s)
    return type(s) == "string" and #s == 36 and s:match("^%x+%-%x+%-%x+%-%x+%-%x+$") ~= nil
end

local function incomeOf(key, variant)
    local it = key and Items[key]
    if not it then return 0, 0 end
    local inc = it.Income or 0
    local vr = variant and Variants[variant]
    if vr and tonumber(vr.MutationMulti) then
        inc = inc * vr.MutationMulti
    end
    return inc, it.Value or 0
end

local function dump(v, d, seen)
    d = d or 0
    seen = seen or {}
    if type(v) ~= "table" then
        if typeof(v) == "Instance" then return "<" .. v:GetFullName() .. ">" end
        return tostring(v)
    end
    if seen[v] or d > 5 then return "{...}" end
    seen[v] = true
    local pad = string.rep("  ", d + 1)
    local s = "{\n"
    for k, x in pairs(v) do
        s = s .. pad .. "[" .. tostring(k) .. "] = " .. dump(x, d + 1, seen) .. ",\n"
    end
    return s .. string.rep("  ", d) .. "}"
end

local function walk(node, ctx, out, seen, depth)
    if type(node) ~= "table" or depth > 8 or seen[node] then return end
    seen[node] = true
    local c = { stage = ctx.stage, spawn = ctx.spawn, id = ctx.id, key = ctx.key, variant = ctx.variant }
    for k, v in pairs(node) do
        if type(v) == "string" then
            if isGuid(v) then
                c.id = v
            elseif v:match("^ItemSpawn%d+$") then
                c.spawn = v
            elseif Items[v] then
                c.key = v
            elseif Variants[v] then
                c.variant = v
            end
        end
        if (k == "Stage" or k == "StageId" or k == "StageID" or k == "StageIndex") and tonumber(v) then
            c.stage = tonumber(v)
        end
    end
    if c.id and c.spawn and not out[c.id] then
        out[c.id] = { stage = c.stage, spawn = c.spawn, id = c.id, key = c.key, variant = c.variant }
    end
    for k, v in pairs(node) do
        if type(v) == "table" then
            local n = { stage = c.stage, spawn = c.spawn, id = c.id, key = c.key, variant = c.variant }
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
                elseif Items[k] then
                    n.key = k
                end
            end
            walk(v, n, out, seen, depth + 1)
        end
    end
end

local function fetch()
    if not RequestRemote then return nil, "remote missing" end
    local ok, data = pcall(function() return RequestRemote:InvokeServer() end)
    if not ok then return nil, tostring(data) end
    lastRaw = data
    local out = {}
    walk(data, {}, out, {}, 0)
    local list = {}
    for _, t in pairs(out) do table.insert(list, t) end
    return list
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

local function findSpawn(stage, name)
    local ck = tostring(stage) .. ":" .. name
    local c = spawnCache[ck]
    if c and c.Parent then return c end
    local tower = towerRoot()
    if not tower then return nil end
    local root = stage and tower:FindFirstChild("Stage" .. stage) or tower
    if not root then return nil end
    for _, d in ipairs(root:GetDescendants()) do
        if d.Name == name and instPos(d) then
            spawnCache[ck] = d
            return d
        end
    end
end

local function keyOf(inst)
    local a = inst:GetAttribute("ItemKey") or inst:GetAttribute("Treasure") or inst:GetAttribute("Item")
    if a and Items[a] then return a end
    for _, d in ipairs(inst:GetDescendants()) do
        if Items[d.Name] then return d.Name end
    end
    local p = inst.Parent
    if p and Items[p.Name] then return p.Name end
end

local function hrp()
    local c = LP.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function moveTo(cf)
    local root = hrp()
    if not root then return false end
    if S.MoveMode == "Instant" then
        root.CFrame = cf
        return true
    end
    local dist = (root.Position - cf.Position).Magnitude
    local t = math.max(dist / math.max(S.Speed, 1), 0.05)
    pcall(function() root.Anchored = true end)
    local tw = TweenService:Create(root, TweenInfo.new(t, Enum.EasingStyle.Linear), { CFrame = cf })
    tw:Play()
    tw.Completed:Wait()
    pcall(function() root.Anchored = false end)
    return true
end

local function saveBase(cf)
    S.Base = cf
    if Gui._savedFlags then
        Gui._savedFlags["_HeistBase"] = { x = cf.X, y = cf.Y, z = cf.Z }
        if Gui._saveConfig then pcall(function() Gui:_saveConfig() end) end
    end
end

do
    local b = Gui._savedFlags and Gui._savedFlags["_HeistBase"]
    if type(b) == "table" and b.x then
        S.Base = CFrame.new(b.x, b.y, b.z)
    end
end

local function placeAll(n)
    if not PlaceRemote then return end
    for _ = 1, math.max(n, 1) do
        PlaceRemote:FireServer()
        task.wait(0.25)
    end
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
        collide = plate and plate.CanCollide
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

if DoorBrokenRemote and DoorBrokenRemote:IsA("RemoteEvent") then
    DoorBrokenRemote.OnClientEvent:Connect(function()
        brokenSignal += 1
    end)
end

if DoorsResetRemote and DoorsResetRemote:IsA("RemoteEvent") then
    DoorsResetRemote.OnClientEvent:Connect(function()
        brokenStages = {}
        S.NextStage = 1
        S.Blocked = nil
    end)
end

if StageTreasuresReset and StageTreasuresReset:IsA("RemoteEvent") then
    StageTreasuresReset.OnClientEvent:Connect(function()
        -- bersihkan cache spawn saat treasure di-reset
        table.clear(spawnCache)
    end)
end

local function standAndBreak(n, hits)
    local zone = zoneOf(n)
    if not zone then return "nozone" end
    local pos = instPos(zone)
    if not pos then return "nozone" end
    local door = doorOf(n)
    local base = snapshot(door)
    local sig = brokenSignal
    moveTo(CFrame.new(pos))
    local limit = hits * (DoorCfg.SwingInterval or 0.5) + (DoorCfg.HitDelay or 0.25) + 4
    local t0 = os.clock()
    while S.AutoStage and os.clock() - t0 < limit do
        if brokenSignal > sig or isBroken(door, base) then
            brokenStages[n] = true
            return "broken"
        end
        local root = hrp()
        if root and (root.Position - pos).Magnitude > 8 then
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
        if brokenStages[n] or not doorOf(n) then
            S.NextStage = n + 1
            continue
        end
        local health = stageHealth(n)
        local doorHits = stageDoorHits(n)
        if not health and not doorHits then
            S.Blocked = n
            setInfo(string.format("Stage %d: tidak ada DoorHealth/DoorHits di Config", n))
            return
        end
        -- utamakan hit dari health/power; fallback DoorHits dari stage data
        local need
        if health and power > 0 then
            need = math.ceil(health / power)
        else
            need = doorHits or S.MaxHits
        end
        if need > S.MaxHits then
            S.Blocked = n
            setInfo(string.format(
                "Berhenti di Stage %d | Health %s | Power %s | Perlu %d hit (max %d)",
                n, tostring(health), tostring(power), need, S.MaxHits
            ))
            return
        end
        S.Blocked = nil
        setInfo(string.format("Stage %d | Health %s | Power %s | Perlu %d hit", n, tostring(health), tostring(power), need))
        setStatus("Berdiri di Zone Stage" .. n)
        local res = standAndBreak(n, need)
        setStatus("Stage" .. n .. ": " .. res)
        S.NextStage = n + 1
    end
    if S.NextStage > total then
        setInfo("Semua door sudah dilewati (" .. total .. " stage)")
    end
end

local function holdFor(t)
    local d = pdata()
    if d and PickupUtils and t.key then
        local ok, r = pcall(PickupUtils.GetHoldDuration, d, {
            ItemType = "Treasure",
            Key = t.key,
            Variant = t.variant or "Normal"
        })
        if ok and tonumber(r) then return r + 0.2 end
    end
    return S.Hold
end

local function loot()
    setStatus("Mengambil daftar treasure...")
    local list, err = fetch()
    if not list then
        setStatus("Gagal request: " .. tostring(err))
        task.wait(2)
        return
    end

    local candidates = {}
    for _, t in ipairs(list) do
        local bl = blacklist[t.id]
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
        setStatus("Tidak ada treasure (" .. #list .. " terbaca). Coba Debug Dump.")
        task.wait(2)
        return
    end

    local cap = capacity()
    local picked = 0
    for _, t in ipairs(candidates) do
        if not S.Run or picked >= cap then break end
        local pos = instPos(t.inst)
        if not pos then continue end
        setStatus(string.format("Ambil %s (Stage %s, income %s)", tostring(t.key or "?"), tostring(t.stage), tostring(t.income)))
        moveTo(CFrame.new(pos + Vector3.new(0, 3, 0)))
        task.wait(holdFor(t))
        local ok, res = pcall(function()
            return PickupRemote:InvokeServer(t.stage, t.spawn, t.id)
        end)
        if ok and res ~= false then
            picked += 1
            setStatus("Pickup OK: " .. tostring(t.key) .. " | res=" .. tostring(res))
        else
            blacklist[t.id] = os.clock() + 15
            setStatus("Pickup gagal: " .. tostring(t.key) .. " | res=" .. tostring(res))
        end
        task.wait(S.Delay)
    end

    if picked > 0 and S.Run then
        setStatus("Kembali ke base & place best...")
        moveTo(S.Base)
        task.wait(0.4)
        placeAll(picked)
        task.wait(0.3)
    end
end

local function cycle()
    local root = hrp()
    if not root then
        setStatus("Menunggu karakter...")
        task.wait(1)
        return
    end
    if not S.Base then saveBase(root.CFrame) end
    S.MaxStage = stageCount() -- Max Stage selalu mengikuti stage terakhir
    if S.AutoStage then progressStages() end -- Auto Stage menyala bersama Auto Farm
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

local UpgradeNames = { "Backpack", "PickupSpeed", "MoveSpeed" }

local function cashOf(d)
    return tonumber(d and d.Cash) or 0
end

-- Semua pembelian/upgrade dicek dulu dengan cash saat ini:
-- jika belum cukup, hanya mencocokkan (menunggu); saat cukup, langsung dibeli
local function econTick()
    local d = pdata()
    if not d then return end

    -- Arms: cocokkan arm berikutnya dengan cash, beli saat cukup, langsung dipakai
    if S.EcoArms and ArmsRemote and next(ArmsCfg) then
        d = pdata() or d
        local cash = cashOf(d)
        local owned = type(d.PurchasedArms) == "table" and d.PurchasedArms or {}
        local key, cost = nil, nil
        if ArmsUtils and ArmsUtils.GetNextUnlockKey then
            local ok, k = pcall(ArmsUtils.GetNextUnlockKey, owned)
            if ok and type(k) == "string" and ArmsCfg[k] and not ArmsCfg[k].RobuxOnly then
                key, cost = k, tonumber(ArmsCfg[k].UnlockCost)
            end
        end
        if not key then
            -- fallback: arm termurah yang belum dimiliki (pembelian berikutnya)
            local best = nil
            for k, cfg in pairs(ArmsCfg) do
                if not cfg.RobuxOnly and tonumber(cfg.UnlockCost) and owned[k] ~= true then
                    local o = tonumber(cfg.Order) or 0
                    if not best or cfg.UnlockCost < best.cost or (cfg.UnlockCost == best.cost and o < best.order) then
                        best = { key = k, cost = cfg.UnlockCost, order = o }
                    end
                end
            end
            if best then key, cost = best.key, best.cost end
        end
        if key and cost then
            local bl = armBlacklist[key]
            if not (bl and os.clock() < bl) then
                if cash >= cost then
                    setStatus(string.format("Beli arms %s (butuh %s, cash %s)", key, tostring(cost), tostring(cash)))
                    pcall(function() ArmsRemote:FireServer("Unlock", key) end)
                    task.wait(1)
                    local nd = pdata()
                    local got = nd and type(nd.PurchasedArms) == "table" and nd.PurchasedArms[key] == true
                    if got then
                        equipArm(key) -- langsung pakai arms yang baru dibeli
                    else
                        armBlacklist[key] = os.clock() + 10
                        setStatus("Unlock arms " .. key .. " gagal, coba lagi nanti")
                    end
                else
                    setStatus(string.format("Menunggu cash untuk arms %s (butuh %s, cash %s)", key, tostring(cost), tostring(cash)))
                end
            end
        end
    end

    -- Upgrades: tiap upgrade dicek dengan cash saat ini, beli saat cukup
    if S.EcoUpgrades and UpgradeUtils and PurchaseRemote then
        local names = {}
        for _, n in ipairs(UpgradeNames) do
            if next(S.EcoList) == nil or S.EcoList[n] then table.insert(names, n) end
        end
        for _, name in ipairs(names) do
            local bl = upgradeBlacklist[name]
            if not (bl and os.clock() < bl) then
                d = pdata() or d
                local cash = cashOf(d)
                local ok, nxt = pcall(UpgradeUtils.GetNext, d, name)
                if ok and nxt and tonumber(nxt.Cost) then
                    if cash >= nxt.Cost then
                        setStatus(string.format("Beli upgrade %s (butuh %s, cash %s)", name, tostring(nxt.Cost), tostring(cash)))
                        pcall(function() PurchaseRemote:InvokeServer(name) end)
                        task.wait(0.5)
                        local nd = pdata()
                        if cashOf(nd) >= cash then
                            -- cash tidak berkurang: pembelian gagal, jeda sebentar
                            upgradeBlacklist[name] = os.clock() + 10
                            setStatus("Beli upgrade " .. name .. " gagal, coba lagi nanti")
                        end
                    else
                        setStatus(string.format("Menunggu cash untuk upgrade %s (butuh %s, cash %s)", name, tostring(nxt.Cost), tostring(cash)))
                    end
                end
            end
        end
    end

    -- Plot: cek harga level berikutnya dengan cash saat ini
    if S.EcoPlot and UpgradePlotRemote and PlotCfg.UPGRADE_PRICES then
        d = pdata() or d
        local cash = cashOf(d)
        local lvl = tonumber(d.BaseLevel) or 0
        local maxLvl = tonumber(PlotCfg.MaxLevel) or 15
        local price = tonumber(PlotCfg.UPGRADE_PRICES[lvl])
        if lvl < maxLvl and price and os.clock() >= plotCooldown then
            if cash >= price then
                setStatus(string.format("Upgrade plot ke lv%d (butuh %s, cash %s)", lvl + 1, tostring(price), tostring(cash)))
                pcall(function() UpgradePlotRemote:FireServer() end)
                task.wait(0.5)
                local nd = pdata()
                local nl = (nd and tonumber(nd.BaseLevel)) or lvl
                if nl <= lvl then
                    plotCooldown = os.clock() + 10
                    setStatus("Upgrade plot gagal, coba lagi nanti")
                end
            else
                setStatus(string.format("Menunggu cash untuk plot lv%d (butuh %s, cash %s)", lvl + 1, tostring(price), tostring(cash)))
            end
        end
    end

    -- Rebirth: cek biaya dengan cash saat ini
    if S.EcoRebirth and RebirthUtils and RebirthRemote then
        d = pdata() or d
        local cash = cashOf(d)
        local ok, cost = pcall(RebirthUtils.GetNextCost, d)
        if ok and tonumber(cost) then
            if cash >= cost then
                setStatus(string.format("Rebirth (butuh %s, cash %s)", tostring(cost), tostring(cash)))
                pcall(function() RebirthRemote:FireServer() end)
                brokenStages = {}
                S.NextStage = 1
                S.Blocked = nil
                task.wait(2)
            else
                setStatus(string.format("Menunggu cash untuk rebirth (butuh %s, cash %s)", tostring(cost), tostring(cash)))
            end
        end
    end
end

task.spawn(function()
    while true do
        if S.EcoArms or S.EcoUpgrades or S.EcoPlot or S.EcoRebirth then
            pcall(econTick)
        end
        task.wait(1.5)
    end
end)

if not (RequestRemote and PickupRemote and PlaceRemote) then
    Gui:Notify({
        Title = "Remote Missing",
        Content = "RequestStageTreasures / PickupStageTreasure / PlaceBestLuck tidak ditemukan",
        Duration = 5
    })
end
if not DataAgg then
    Gui:Notify({
        Title = "Data Missing",
        Content = "DataAggregation tidak ditemukan, power fallback Config.Arms",
        Duration = 5
    })
end

Tab:CreateSection({ Name = "Auto Farm", Description = "Auto Stage dulu sampai batas kemampuan, lalu loot income terbesar" })

Tab:CreateToggle({
    Name = "Auto Farm",
    Description = "Auto Stage + Pickup income terbesar > base > Place Best",
    Flag = "HF_Run",
    CurrentValue = false,
    Callback = function(v)
        S.Run = v
        S.AutoStage = v -- Auto Stage ikut menyala saat Auto Farm dinyalakan
        if v then start() end
    end
})

Tab:CreateSection({ Name = "Auto Stage", Description = "Berdiri di StageN.Door.Zone sampai door hancur (Max Hits 10)" })

Tab:CreateButton({
    Name = "Reset Stage Pointer",
    Description = "Mulai ulang dari Stage1",
    Interact = "Reset",
    Callback = function()
        brokenStages = {}
        S.NextStage = 1
        S.Blocked = nil
    end
})

Tab:CreateSection({ Name = "Economy" })

Tab:CreateToggle({
    Name = "Auto Unlock Arms",
    Description = "ArmsAction Unlock (GetNextUnlockKey), langsung dipakai setelah beli",
    Flag = "HF_EcoArms",
    CurrentValue = false,
    Callback = function(v) S.EcoArms = v end
})

Tab:CreateToggle({
    Name = "Auto Buy Upgrades",
    Description = "PurchaseUpgrade sesuai daftar",
    Flag = "HF_EcoUpgrades",
    CurrentValue = false,
    Callback = function(v) S.EcoUpgrades = v end
})

Tab:CreateDropdown({
    Name = "Upgrade List",
    Description = "Kosong = semua",
    Options = UpgradeNames,
    MultipleOptions = true,
    Flag = "HF_EcoList",
    Callback = function(v) S.EcoList = v end
})

Tab:CreateToggle({
    Name = "Auto Upgrade Plot",
    Description = "UpgradePlot saat cash cukup",
    Flag = "HF_EcoPlot",
    CurrentValue = false,
    Callback = function(v) S.EcoPlot = v end
})

Tab:CreateToggle({
    Name = "Auto Rebirth",
    Description = "PerformRebirth saat cash cukup",
    Flag = "HF_EcoRebirth",
    CurrentValue = false,
    Callback = function(v) S.EcoRebirth = v end
})

Tab:CreateSection({ Name = "Movement" })

local MoveDrop = Tab:CreateDropdown({
    Name = "Move Mode",
    Options = { "Tween", "Instant" },
    CurrentOption = "Tween",
    Flag = "HF_MoveMode",
    Callback = function(v) S.MoveMode = v end
})
S.MoveMode = MoveDrop.State() or "Tween"

Tab:CreateSlider({
    Name = "Tween Speed",
    Range = { 50, 500 },
    Increment = 10,
    CurrentValue = 160,
    Suffix = " st/s",
    Flag = "HF_Speed",
    Callback = function(v) S.Speed = v end
})

Tab:CreateSlider({
    Name = "Hold Time",
    Description = "Cadangan jika durasi hold tidak terbaca",
    Range = { 0.1, 5 },
    Increment = 0.1,
    CurrentValue = 1.2,
    Suffix = "s",
    Flag = "HF_Hold",
    Callback = function(v) S.Hold = v end
})

Tab:CreateSection({ Name = "Base & Tools" })

Tab:CreateButton({
    Name = "Set Base Here",
    Description = "Simpan posisi sekarang sebagai base",
    Interact = "Set",
    Callback = function()
        local root = hrp()
        if root then
            saveBase(root.CFrame)
            Gui:Notify({ Title = "Base Saved", Content = "Posisi base disimpan", Duration = 2 })
        end
    end
})

Tab:CreateButton({
    Name = "Teleport To Base",
    Interact = "Go",
    Callback = function()
        if S.Base then task.spawn(moveTo, S.Base) end
    end
})

Tab:CreateButton({
    Name = "Place Best Now",
    Interact = "Place",
    Callback = function() task.spawn(placeAll, 1) end
})

local function copyDump(v, title)
    local text = dump(v)
    print("[" .. title .. "]\n" .. text)
    pcall(setclipboard, text)
    Gui:Notify({ Title = title, Content = "Disalin ke clipboard & console", Duration = 3 })
end

Tab:CreateButton({
    Name = "Dump Treasures",
    Description = "Hasil RequestStageTreasures",
    Interact = "Dump",
    Callback = function()
        task.spawn(function()
            if not lastRaw then fetch() end
            copyDump(lastRaw, "Treasures")
        end)
    end
})

Tab:CreateButton({
    Name = "Dump Doors",
    Description = "Hasil RequestDoors",
    Interact = "Dump",
    Callback = function()
        task.spawn(function()
            if not RequestDoorsRemote then return end
            local ok, res = pcall(function() return RequestDoorsRemote:InvokeServer() end)
            copyDump(ok and res or tostring(res), "Doors")
        end)
    end
})

Tab:CreateButton({
    Name = "Dump Player Data",
    Description = "Cek field Cash, BaseLevel, EquippedArmKey",
    Interact = "Dump",
    Callback = function()
        local d = pdata()
        local flat = {}
        if d then
            for k, v in pairs(d) do
                flat[k] = type(v) == "table" and "{table}" or v
            end
        end
        copyDump(flat, "PlayerData")
    end
})

Gui:Notify({
    Title = "Heist Farm",
    Content = "Loaded | Items: " .. (next(Items) and "OK" or "KOSONG")
        .. " | Data: " .. (DataAgg and "OK" or "KOSONG")
        .. " | Stages: " .. TOTAL,
    Duration = 3
})
