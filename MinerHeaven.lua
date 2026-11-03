local Tumblr = loadstring(game:HttpGet("https://pastebin.com/raw/ECe9auLu"))()

local Window = Tumblr:Init({
    Name = "Miner Heaven",
    Subtitle = "by GANTJENK",
    FolderName = "TumblrConfigs",
    FileName = tostring(game.GameId) .. ".json"
})

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local hrp = character:WaitForChild("HumanoidRootPart")

local setIdentity = setthreadidentity or set_thread_identity or (syn and syn.set_thread_identity)

local function notify(title, content, duration)
    pcall(function()
        if setIdentity then
            pcall(setIdentity, 8)
        end
        Tumblr:Notify({
            Title = title,
            Content = content,
            Duration = duration or 3
        })
    end)
end

local MainTab = Window:CreateTab("Main", 4483362458)
_G.MainTab = MainTab

local Boxes = Workspace:WaitForChild("Boxes")
local autoBoxes = false
local boxDelay = 0.2
local idleDelay = 0.1

MainTab:CreateSection("Main Menu")

local function getTargetPart(obj)
    if obj:IsA("BasePart") then
        return obj
    elseif obj:IsA("Model") then
        return obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)
    end
    return nil
end

MainTab:CreateToggle({
    Name = "Auto Teleport Boxes",
    CurrentValue = false,
    Callback = function(enabled)
        autoBoxes = enabled
        if not enabled then return end

        local originalCFrame = hrp.CFrame

        task.spawn(function()
            while autoBoxes do
                local visited = false

                for _, box in ipairs(Boxes:GetChildren()) do
                    if not autoBoxes then break end
                    local part = box.Parent and getTargetPart(box)
                    if part then
                        visited = true
                        hrp.CFrame = part.CFrame + Vector3.new(0, 3, 0)
                        task.wait(boxDelay)
                    end
                end

                if not visited then
                    hrp.CFrame = originalCFrame
                    task.wait(idleDelay)
                end
            end

            hrp.CFrame = originalCFrame
        end)
    end
})

MainTab:CreateButton({
    Name = "TP to Maskman",
    Interact = "Teleport",
    Callback = function()
        local market = Workspace:FindFirstChild("Market")
        local internal = market and market:FindFirstChild("Internal")
        local part = internal and getTargetPart(internal)

        if part then
            hrp.CFrame = part.CFrame + Vector3.new(0, 3, 0)
        else
            notify("Teleport", "Workspace.Market.Internal tidak ditemukan", 3)
        end
    end
})

MainTab:CreateButton({
    Name = "TP to Base",
    Interact = "Teleport",
    Callback = function()
        local tycoons = Workspace:FindFirstChild("Tycoons")
        if not tycoons then
            notify("Teleport", "Workspace.Tycoons tidak ditemukan", 3)
            return
        end

        local myName = player.Name:lower()

        for _, factory in ipairs(tycoons:GetChildren()) do
            local owner = factory:FindFirstChild("Owner")
            if factory:IsA("Model") and owner and owner:IsA("StringValue")
                and owner.Value:lower() == myName then

                local pos = factory.PrimaryPart and factory.PrimaryPart.Position
                    or factory:GetPivot().Position

                hrp.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))

                notify("Teleport", "Teleport to base", 2)
                return
            end
        end

        notify("Teleport", "Base kamu tidak ditemukan (belum punya Factory?)", 3)
    end
})

local CELL_NAME = "Anguished Guardian of the Gate"
local BEAM_GROW = Vector3.new(100, 100, 100)
local DROP_OFFSET = CFrame.new(0, 0, 0)
local LAVA_OFFSET = CFrame.new(0, 0, 0)

local enlargedBeams = setmetatable({}, { __mode = "k" })

local function getMyFactory()
    local tycoons = Workspace:FindFirstChild("Tycoons")
    if not tycoons then return nil end

    local myName = player.Name:lower()

    for _, factory in ipairs(tycoons:GetChildren()) do
        local owner = factory:FindFirstChild("Owner")
        if factory:IsA("Model") and owner and owner:IsA("StringValue")
            and owner.Value:lower() == myName then
            return factory
        end
    end

    return nil
end

local function enlargeBeams(factory)
    local changed = 0

    for _, cell in ipairs(factory:GetChildren()) do
        if cell:IsA("Model") then
            local model = cell:FindFirstChild("Model")
            local upgradePart = model and model:FindFirstChild("Upgrade")

            if upgradePart and upgradePart:IsA("BasePart") and not enlargedBeams[upgradePart] then
                enlargedBeams[upgradePart] = true
                upgradePart.Size = upgradePart.Size + BEAM_GROW
                upgradePart.Transparency = 1
                changed += 1
            end
        end
    end

    return changed
end

local function findLava(factory)
    local cell = factory:FindFirstChild(CELL_NAME)
    local model = cell and cell:FindFirstChild("Model")
    local lava = model and model:FindFirstChild("Lava")

    if lava and lava:IsA("BasePart") then
        return lava
    end

    for _, child in ipairs(factory:GetChildren()) do
        local childModel = child:FindFirstChild("Model")
        local childLava = childModel and childModel:FindFirstChild("Lava")

        if childLava and childLava:IsA("BasePart") then
            return childLava
        end
    end

    return nil
end

local function executeOreMove(factory, droppedFolder, lava, offset)
    local target = lava.CFrame * offset
    for _, ore in ipairs(droppedFolder:GetChildren()) do
        if ore:IsA("BasePart") then
            ore.CFrame = target
        elseif ore:IsA("Model") then
            ore:PivotTo(target)
        end
    end
end

local function boostOre()
    local factory = getMyFactory()
    if not factory then
        return false, "Factory milikmu tidak ditemukan"
    end

    local dropped = Workspace:FindFirstChild("DroppedParts")
    local droppedFolder = dropped and dropped:FindFirstChild(factory.Name)
    if not droppedFolder then
        return false, "Workspace.DroppedParts." .. factory.Name .. " tidak ditemukan"
    end

    local lava = findLava(factory)
    if not lava then
        return false, "Lava tidak ditemukan di " .. factory.Name
    end

    if enlargeBeams(factory) > 0 then
        task.wait(2)
    end

    executeOreMove(factory, droppedFolder, lava, DROP_OFFSET)
    return true
end

local function moveOreToLava()
    local factory = getMyFactory()
    if not factory then
        return false, "Factory milikmu tidak ditemukan"
    end

    local dropped = Workspace:FindFirstChild("DroppedParts")
    local droppedFolder = dropped and dropped:FindFirstChild(factory.Name)
    if not droppedFolder then
        return false, "Workspace.DroppedParts." .. factory.Name .. " tidak ditemukan"
    end

    local lava = findLava(factory)
    if not lava then
        return false, "Lava tidak ditemukan di " .. factory.Name
    end

    executeOreMove(factory, droppedFolder, lava, LAVA_OFFSET)
    return true
end

local boostButton

boostButton = MainTab:CreateButton({
    Name = "Boost Ore",
    Interact = "Boost",
    Callback = function()
        boostButton:Set("Interact", "Processing...")

        task.spawn(function()
            local ok, success, message = pcall(boostOre)

            if not ok then
                warn("[Boost Ore] Error:", success)
                notify("Boost Ore", "Terjadi kesalahan: " .. tostring(success), 3)
            elseif not success then
                notify("Boost Ore", tostring(message), 3)
            else
                notify("Boost Ore", "Berhasil mengumpulkan ore!", 2)
            end

            task.wait(1)
            boostButton:Set("Interact", "Boost")
        end)
    end
})

local moveOreRunning = false
local moveOreToggle

moveOreToggle = MainTab:CreateToggle({
    Name = "Auto TP Ore to Lava",
    CurrentValue = false,
    Callback = function(enabled)
        moveOreRunning = enabled
        if not enabled then return end

        task.spawn(function()
            while moveOreRunning do
                local ok, success, message = pcall(moveOreToLava)

                if not ok then
                    warn("[Auto TP Ore] Error:", success)
                    notify("Auto TP Ore", "Terjadi kesalahan: " .. tostring(success), 3)
                    moveOreRunning = false
                    moveOreToggle:SetValue(false)
                    break
                elseif not success then
                    notify("Auto TP Ore", tostring(message) .. " - Toggle dimatikan", 3)
                    moveOreRunning = false
                    moveOreToggle:SetValue(false)
                    break
                else
                    task.wait(0.2)
                end
            end
        end)
    end
})

MainTab:CreateButton({
    Name = "TP Character to Lava",
    Interact = "Teleport",
    Callback = function()
        local factory = getMyFactory()
        if not factory then
            notify("TP Character", "Factory milikmu tidak ditemukan", 3)
            return
        end

        local lava = findLava(factory)
        if not lava then
            notify("TP Character", "Lava tidak ditemukan di factory kamu", 3)
            return
        end

        hrp.CFrame = lava.CFrame + Vector3.new(0, 3, 0)

        notify("TP Character", "Berhasil teleport ke Lava!", 2)
    end
})


local layoutRemote
local layoutUtility -- nil = belum dicoba, false = tidak tersedia

local function resolveLayoutRemote()
    if layoutRemote then
        return layoutRemote
    end

    local ok, remote = pcall(function()
        local modules = ReplicatedStorage:FindFirstChild("Modules")
        local networking = modules and modules:FindFirstChild("Networking")
        local remotesModule = networking and networking:FindFirstChild("Remotes")
        return remotesModule and require(remotesModule).Layouts
    end)

    if ok and remote then
        layoutRemote = remote
        return layoutRemote
    end

    local folder = ReplicatedStorage:FindFirstChild("Remotes")
    layoutRemote = folder and folder:FindFirstChild("Layouts", true)
    return layoutRemote
end

local function getLayoutUtility()
    if layoutUtility == nil then
        local ok, module = pcall(function()
            local modules = ReplicatedStorage:FindFirstChild("Modules")
            local gameFolder = modules and modules:FindFirstChild("Game")
            local utility = gameFolder and gameFolder:FindFirstChild("LayoutUtility")
            return utility and require(utility)
        end)

        layoutUtility = (ok and module) or false
    end

    return layoutUtility or nil
end

-- Return: berhasil, pesan/jumlah gagal-place, fatal
local function loadLayout(slot)
    local name = "Layout" .. tostring(slot)

    local remote = resolveLayoutRemote()
    if not remote then
        return false, "Remote Layouts tidak ditemukan", true
    end

    local utility = getLayoutUtility()

    if utility then
        local okItems, itemsOk, items = pcall(utility.getItemsInLayout, player, name)
        if okItems then
            local list = (not itemsOk) and {} or items
            if type(list) ~= "table" or #list == 0 then
                return false, "Layout " .. tostring(slot) .. " kosong (belum disimpan)", true
            end
        end

        local okCan, canLoad, reason = pcall(utility.canLoadLayout, player, name)
        if okCan and not canLoad then
            return false, tostring(reason or "Layout tidak bisa di-load"), false
        end

        pcall(utility.disablePlacementAcrossAllUsers, player)
    end

    local ok, success, failed = pcall(function()
        return remote:InvokeServer("Load", name)
    end)

    if utility then
        pcall(utility.enablePlacementAcrossAllPlayers, player)
    end

    if not ok then
        return false, tostring(success), false
    end

    if not success then
        return false, "Server menolak load layout", false
    end

    return true, type(failed) == "table" and #failed or 0, false
end

-- Jalankan loadLayout di thread terpisah, return: ok, success, info, fatal
local function loadLayoutIsolated(slot, alive)
    local result
    task.spawn(function()
        result = table.pack(pcall(loadLayout, slot))
    end)

    while not result do
        if alive and not alive() then
            return true, false, "dibatalkan", false
        end
        task.wait()
    end

    return result[1], result[2], result[3], result[4]
end

MainTab:CreateSection("Auto Farm")

local layoutSlotDropdown

layoutSlotDropdown = MainTab:CreateDropdown({
    Name = "Layout Slot",
    Options = { "1", "2", "3" },
    CurrentOption = "1",
    Flag = "AutoLoadLayoutSlot",
    ListLayer = 3
})

local rebirthNet       -- nil = belum dicoba, false = tidak tersedia
local rebirthMoneyLib  -- nil = belum dicoba, false = tidak tersedia

local function getRebirthModules()
    if rebirthNet == nil then
        local ok, module = pcall(function()
            return require(ReplicatedStorage.Modules.Networking.Net)
        end)
        rebirthNet = (ok and module) or false
    end

    if rebirthMoneyLib == nil then
        local ok, module = pcall(function()
            return require(ReplicatedStorage.Modules.Game.MoneyLib)
        end)
        rebirthMoneyLib = (ok and module) or false
    end

    return rebirthNet or nil, rebirthMoneyLib or nil
end

local function getMoneyValue()
    local state = ReplicatedStorage:FindFirstChild("State")
    local mirror = state and state:FindFirstChild("MoneyMirror")
    return mirror and mirror:FindFirstChild(player.Name)
end

local function canAffordRebirth(moneyLib)
    if not moneyLib then
        return true
    end

    local ok, result = pcall(function()
        local money = getMoneyValue()
        if not money then
            return true
        end
        return money.Value >= moneyLib.RebornPrice(player)
    end)

    if ok then
        return result
    end

    return true
end

local function waitMoneyChanged()
    local money = getMoneyValue()
    if money then
        money.Changed:Wait()
    else
        task.wait()
    end
end

local function waitUntilAffordable(moneyLib, alive)
    while alive() do
        if canAffordRebirth(moneyLib) then
            return true
        end
        waitMoneyChanged()
    end
    return false
end

local function waitUntil(condition, alive)
    while alive() do
        if condition() then
            return true
        end
        task.wait()
    end
    return false
end

-- Jalankan Rebirth di thread terpisah, return: berhasil (boolean)
local function rebirthIsolated(net, alive)
    local result
    task.spawn(function()
        result = table.pack(pcall(function()
            return net.Rebirth:Invoke()
        end))
    end)

    while not result do
        if not alive() then
            return false
        end
        task.wait()
    end

    if result[1] and result[2] then
        pcall(function()
            if _G.Placement then
                _G.Placement.recalculatePlanes()
            end
        end)
        return true
    end

    return false
end

local function hasLava()
    local factory = getMyFactory()
    return factory ~= nil and findLava(factory) ~= nil
end

local autoFarmRunning = false
local autoFarmSession = 0
local autoFarmToggle

local function stopFarm()
    autoFarmRunning = false
    pcall(function() autoFarmToggle:SetValue(false) end)
    pcall(function() autoFarmToggle.Set(false) end)
end

autoFarmToggle = MainTab:CreateToggle({
    Name = "Auto Farm (Load > Boost > Rebirth)",
    CurrentValue = false,
    Flag = "AutoFarm",
    Callback = function(enabled)
        autoFarmRunning = enabled
        autoFarmSession += 1

        if not enabled then
            return
        end

        local mySession = autoFarmSession

        task.spawn(function()
            local lastMessage = nil
            local boostDelayed = false -- delay 2 detik sudah dilakukan untuk lava saat ini?

            local function alive()
                return autoFarmRunning and mySession == autoFarmSession
            end

            local function report(message)
                if message ~= lastMessage then
                    lastMessage = message
                    notify("Auto Farm", message, 3)
                end
            end

            while alive() do
                if not getMyFactory() then
                    boostDelayed = false
                    task.wait()

                elseif not hasLava() then
                    -- 1. Auto Load Layout
                    boostDelayed = false
                    local slot = tonumber(layoutSlotDropdown and layoutSlotDropdown.State()) or 1
                    local ok, success, info, fatal = loadLayoutIsolated(slot, alive)

                    if not alive() then return end

                    if ok and success then
                        lastMessage = nil
                        local content = "Auto Load berhasil: Layout " .. slot
                        if type(info) == "number" and info > 0 then
                            content = content .. " (" .. info .. " gagal dipasang)"
                        end
                        notify("Auto Farm", content, 3)

                        waitUntil(hasLava, alive)
                    else
                        report(ok and tostring(info) or tostring(success))
                        if fatal then
                            stopFarm()
                            return
                        end
                        task.wait()
                    end

                else
                    -- 2. Boost Ore (sekali per kemunculan lava, 2 detik setelah lava terdeteksi)
                    if not boostDelayed then
                        task.wait(2)

                        if not alive() then return end

                        boostDelayed = true

                        if not hasLava() then
                            boostDelayed = false
                            continue
                        end
                    end

                    local ok, success, message = pcall(boostOre)

                    if not alive() then return end

                    if ok and success then
                        lastMessage = nil
                        notify("Auto Farm", "Boost Ore berhasil", 2)

                        -- 3. Rebirth
                        local rebirthed = false

                        while alive() and hasLava() and not rebirthed do
                            local net, moneyLib = getRebirthModules()
                            if not net then
                                report("Module Net tidak ditemukan")
                                stopFarm()
                                return
                            end

                            if waitUntilAffordable(moneyLib, alive) then
                                rebirthed = rebirthIsolated(net, alive)

                                if not alive() then return end

                                if rebirthed then
                                    lastMessage = nil
                                    notify("Auto Farm", "Rebirth Success", 2)
                                else
                                    report("Rebirth gagal")
                                    waitMoneyChanged()
                                end
                            end
                        end

                        -- Setelah rebirth, tunggu lava hilang lalu kembali ke Auto Load
                        if rebirthed then
                            waitUntil(function()
                                return not hasLava()
                            end, alive)
                        end
                    else
                        report("Boost gagal: " .. (ok and tostring(message) or tostring(success)))
                        task.wait()
                    end
                end
            end
        end)
    end
})

local Universal = loadstring(game:HttpGet("https://pastebin.com/raw/436invAL"))()
Universal.CreateUniversalTab(Window, Tumblr, Players, RunService)
