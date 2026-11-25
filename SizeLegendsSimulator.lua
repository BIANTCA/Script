local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LP = Players.LocalPlayer

local function resolve(root, ...)
    local cur = root
    for _, name in ipairs({...}) do
        cur = cur and cur:FindFirstChild(name)
        if not cur then return nil end
    end
    return cur
end

local function fire(remote, ...)
    if not remote then return false, "missing remote" end
    if remote:IsA("RemoteEvent") then
        return pcall(remote.FireServer, remote, ...)
    elseif remote:IsA("RemoteFunction") then
        return pcall(remote.InvokeServer, remote, ...)
    end
    return false, "not a remote"
end

local Events = ReplicatedStorage:WaitForChild("Events")
local Functions = ReplicatedStorage:WaitForChild("Functions")

local ToolEquipped = resolve(Events, "ToolEquipped")
local ToolActivation = resolve(Events, "ToolActivation")
local SellSize = resolve(Events, "SellSize")
local PurchaseInit = resolve(Functions, "PurchaseInit")
local PurchaseHandle = resolve(Functions, "PurchaseHandle")
local AutoSellHandle = resolve(Functions, "AutoSellHandle")
local TeleportCheck = resolve(Functions, "TeleportCheck")

local SizeValues = require(ReplicatedStorage:WaitForChild("SizeValues"))

local toolsList = {}
for name, data in pairs(SizeValues.Tools) do
    if not data.gamepass then
        table.insert(toolsList, {name = name, price = data.price or 0, strength = data.strength or 0, category = 1})
    end
end
table.sort(toolsList, function(a, b) return a.strength < b.strength end)

local dnaList = {}
for name, data in pairs(SizeValues.DNA) do
    if not data.gamepass then
        table.insert(dnaList, {name = name, price = data.price or 0, capacity = data.capacity or 0, category = 2})
    end
end
table.sort(dnaList, function(a, b) return a.capacity < b.capacity end)

local rankList = {}
for _, data in ipairs(SizeValues.RankValues) do
    table.insert(rankList, {name = data.name, price = data.price or 0, multiplier = data.multiplier or 1, category = 3})
end

local worldList = {}
for name, data in pairs(SizeValues.WorldCriterias) do
    table.insert(worldList, {name = name, size = data.size or 0})
end
table.sort(worldList, function(a, b) return a.size < b.size end)

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

local function getAffordableUpgrade(list)
    local coins = tonumber(LP:GetAttribute("RealCoins")) or 0
    local currentItemName = ""
    
    if list[1].category == 1 then
        currentItemName = LP:GetAttribute("Tool") or "Pencil"
    elseif list[1].category == 2 then
        currentItemName = LP:GetAttribute("DNA") or "Kid"
    elseif list[1].category == 3 then
        currentItemName = LP:GetAttribute("Rank") or "Stage 1"
    end
    
    local foundCurrent = false
    for _, item in ipairs(list) do
        if foundCurrent then
            if coins >= item.price then
                return item
            end
        end
        if item.name == currentItemName then
            foundCurrent = true
        end
    end
    return nil
end

local function getSellPart()
    local area = workspace:FindFirstChild("Map")
    area = area and area:FindFirstChild("Spawn")
    area = area and area:FindFirstChild("Buildings")
    area = area and area:FindFirstChild("SellArea")
    if not area then return nil end
    return area:FindFirstChild("Hitbox", true) or (area:IsA("BasePart") and area) or area:FindFirstChildWhichIsA("BasePart", true)
end

local function getSellArea()
    local area = workspace:FindFirstChild("Map")
    area = area and area:FindFirstChild("Spawn")
    area = area and area:FindFirstChild("Buildings")
    return area and area:FindFirstChild("SellArea")
end

local function getTeleportCFrame()
    local area = getSellArea()
    if not area then return nil end

    local att = area:FindFirstChildWhichIsA("Attachment", true)
    if att then return att.WorldCFrame end

    local tp = area:FindFirstChild("TeleportTo", true)
    if not tp then return nil end
    if tp:IsA("BasePart") then return tp.CFrame end
    if tp:IsA("Model") then return tp:GetPivot() end
    local inner = tp:FindFirstChildWhichIsA("BasePart", true)
    return inner and inner.CFrame
end

local function isFull()
    local size = tonumber(LP:GetAttribute("TestSize")) or 0
    local max = tonumber(LP:GetAttribute("MaxSize")) or math.huge
    return size >= max
end

local function sellAndReturn()
    local char = LP.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local targetCF = getTeleportCFrame()
    if not hrp or not targetCF then return end

    local backCF = hrp.CFrame

    hrp.CFrame = targetCF
    task.wait(0.3)

    hrp.CFrame = hrp.CFrame + hrp.CFrame.LookVector * 2

    local t = tick()
    while tick() - t < 15 do
        if (tonumber(LP:GetAttribute("TestSize")) or 0) <= 0 then break end
        task.wait(0.1)
    end

    task.wait(0.2)
    hrp.CFrame = backCF + Vector3.new(0, 6, 0)
end

local Gui = loadstring(game:HttpGet("https://pastebin.com/raw/2BGUWvbd"))()
Gui:Init({
    Name = "Size Simulator",
    Subtitle = "Automation",
    FolderName = "BulbConfigs",
    FileName = "SizeSimulator.json"
})

local Farm = Gui:CreateTab("Auto Farm", 4483362458)
Farm:CreateSection("Core Loop")

Farm:CreateToggle({
    Name = "Auto Click",
    Description = "Automatically activates your current tool to gain size",
    Flag = "AutoClick",
    CurrentValue = false,
    Callback = function(state)
        setLoop("AutoClick", state, 0.15, function(alive)
            local tool = LP:GetAttribute("Tool") or "Pencil"
            fire(ToolEquipped, tool)
            fire(ToolActivation, tool)
        end)
    end
})

Farm:CreateToggle({
    Name = "Auto Sell (Teleport)",
    Description = "Teleport ke SellArea saat kapasitas penuh, lalu kembali",
    Flag = "AutoSellTP",
    CurrentValue = false,
    Callback = function(state)
        setLoop("AutoSellTP", state, 0.5, function(alive)
            if isFull() then
                sellAndReturn()
            end
        end)
    end
})

Farm:CreateToggle({
    Name = "Auto World",
    Description = "Automatically teleports to the highest world your current Size qualifies for",
    Flag = "AutoWorld",
    CurrentValue = false,
    Callback = function(state)
        setLoop("AutoWorld", state, 2.0, function(alive)
            local currentSize = tonumber(LP:GetAttribute("TestSize")) or 0
            local currentWorld = LP:GetAttribute("CurrentWorld") or "Spawn"
            local targetWorld = "Spawn"
            
            for _, world in ipairs(worldList) do
                if currentSize >= world.size then
                    targetWorld = world.name
                else
                    break
                end
            end
            
            if targetWorld ~= currentWorld and TeleportCheck then
                fire(TeleportCheck, targetWorld)
            end
        end)
    end
})

Farm:CreateSection("Upgrades")

Farm:CreateToggle({
    Name = "Auto Upgrade Tools",
    Description = "Buys the next affordable tool automatically",
    Flag = "AutoUpgradeTools",
    CurrentValue = false,
    Callback = function(state)
        setLoop("AutoUpgradeTools", state, 1.0, function(alive)
            local item = getAffordableUpgrade(toolsList)
            if item then
                fire(PurchaseInit, item.name, item.category)
                task.wait(0.1)
                fire(PurchaseHandle, item.name, item.category)
            end
        end)
    end
})

Farm:CreateToggle({
    Name = "Auto Upgrade DNA",
    Description = "Buys the next affordable DNA to increase max size",
    Flag = "AutoUpgradeDNA",
    CurrentValue = false,
    Callback = function(state)
        setLoop("AutoUpgradeDNA", state, 1.0, function(alive)
            local item = getAffordableUpgrade(dnaList)
            if item then
                fire(PurchaseInit, item.name, item.category)
                task.wait(0.1)
                fire(PurchaseHandle, item.name, item.category)
            end
        end)
    end
})

Farm:CreateToggle({
    Name = "Auto Upgrade Rank",
    Description = "Buys the next affordable Rank/Stage for multipliers",
    Flag = "AutoUpgradeRank",
    CurrentValue = false,
    Callback = function(state)
        setLoop("AutoUpgradeRank", state, 1.0, function(alive)
            local item = getAffordableUpgrade(rankList)
            if item then
                fire(PurchaseInit, item.name, item.category)
                task.wait(0.1)
                fire(PurchaseHandle, item.name, item.category)
            end
        end)
    end
})

local Misc = Gui:CreateTab("Misc", 4483362458)
Misc:CreateSection("Utilities")

Misc:CreateToggle({
    Name = "Anti-AFK",
    Description = "Prevents being kicked for inactivity",
    Flag = "AntiAFK",
    CurrentValue = false,
    Callback = function(state)
        if state then
            local VirtualUser = game:GetService("VirtualUser")
            game:GetService("Players").LocalPlayer.Idled:Connect(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new())
            end)
            Gui:Notify({Title = "Anti-AFK", Content = "Enabled", Duration = 2})
        end
    end
})

Misc:CreateButton({
    Name = "Print Debug Info",
    Description = "Prints current stats, attributes, and remote status to console (F9)",
    Interact = "Print",
    Callback = function()
        print("=== DEBUG INFO ===")
        print("Tool :", LP:GetAttribute("Tool"))
        print("DNA  :", LP:GetAttribute("DNA"))
        print("Rank :", LP:GetAttribute("Rank"))
        print("Size :", LP:GetAttribute("TestSize"))
        print("Coins:", LP:GetAttribute("RealCoins"))
        print("Max  :", LP:GetAttribute("MaxSize"))
        print("World:", LP:GetAttribute("CurrentWorld"))
        print("------------------")
        print("ToolEquipped   :", ToolEquipped and "Found" or "MISSING")
        print("ToolActivation :", ToolActivation and "Found" or "MISSING")
        print("SellSize       :", SellSize and "Found" or "MISSING")
        print("PurchaseInit   :", PurchaseInit and "Found" or "MISSING")
        print("PurchaseHandle :", PurchaseHandle and "Found" or "MISSING")
        print("AutoSellHandle :", AutoSellHandle and "Found" or "MISSING")
        print("TeleportCheck  :", TeleportCheck and "Found" or "MISSING")
        print("SellArea part  :", getSellPart() and "Found" or "MISSING")
        print("Attachment/TP  :", getTeleportCFrame() and "Found" or "MISSING")
        print("==================")
    end
})
