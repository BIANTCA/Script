local JendralHans = loadstring(game:HttpGet("https://pastebin.com/raw/kMrXLdJd"))()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local MarketplaceService = game:GetService("MarketplaceService")
local VirtualUser = game:GetService("VirtualUser")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

local Window = JendralHans:Init({
    Name = "Treasure Hunt Simulator",
    Subtitle = "By JendralHans",
    FolderName = "JendralHansConfigs",
    FileName = "TreasureHunt.json",
    LoadedNotification = false
})

local MainTab = Window:CreateTab("Main", 4483362458)
_G.MainTab = MainTab
local CratesTab = Window:CreateTab("Crates", 4483362458)
local ChestsTab = Window:CreateTab("Chests", 4483362458)

local Events = ReplicatedStorage:WaitForChild("Events")
local AreaSell = Events:WaitForChild("AreaSell")
local RebirthEvent = Events:WaitForChild("Rebirth")
local GetStats = Events:WaitForChild("GetStats")
local EquipShovel = Events:FindFirstChild("EquipShovel")
local Checkout = Events:FindFirstChild("Checkout")
local CheckIfOwned = Events:FindFirstChild("CheckIfOwned")
local BuyCrate = Events:FindFirstChild("BuyCrate")
local SendOpenCrate = Events:FindFirstChild("SendOpenCrate")
local SandBlocks = Workspace:WaitForChild("SandBlocks")
local Shovels = ReplicatedStorage:WaitForChild("Shovels")
local CratesFolder = ReplicatedStorage:FindFirstChild("Crates")
local ChestsFolder = ReplicatedStorage:FindFirstChild("Chests")
local OldChestsFolder = ReplicatedStorage:FindFirstChild("OldChests")

local QUICK_DIG_ID = 3831582
local SELL_POS = CFrame.new(3, 10, -160)
local AREA = {minX = -40, maxX = 20, minZ = -235, maxZ = -175}

local STAT_INDEX = {
    coins = 7,
    rubies = 15,
    candy = 44,
}

local CRATE_INDEX = {
    Tier1 = 16, Tier2 = 17, Tier3 = 18, Tier4 = 19, Tier5 = 20, Tier6 = 21,
    Tier1Hat = 22, Tier2Hat = 23, Tier3Hat = 24, Tier4Hat = 25, Tier5Hat = 26, Tier6Hat = 27,
    Tier1Halloween = 28, Tier2Halloween = 29,
}

local State = {
    autoFarm = false,
    autoDig = false,
    autoSell = true,
    autoRebirth = false,
    antiAfk = false,
    limitArea = true,
    alwaysShovel = false,
    autoBuyCrate = false,
    autoOpenCrate = false,
    digDelay = 0.05,
    digTimeout = 10,
    buyQty = 1,
    openDelay = 10,
    selectedShovel = nil,
    buyCrate = nil,
    openCrate = "All",
    chestsFarmed = 0,
    cratesBought = 0,
    cratesOpened = 0,
    status = "Idle",
}

local excludedChests = {}
local blacklist = {}
local selling = false
local quickDig = false

local function notify(title, content, duration)
    pcall(function()
        Window:Notify({Title = title, Content = content, Duration = duration or 2})
    end)
end

pcall(function()
    quickDig = MarketplaceService:UserOwnsGamePassAsync(LocalPlayer.UserId, QUICK_DIG_ID)
end)

local function getHRP()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function getStats()
    local t = {pcall(function() return GetStats:InvokeServer() end)}
    if not t[1] then return nil end
    table.remove(t, 1)
    return t
end

local function getTool()
    local char = LocalPlayer.Character
    if not char then return nil end
    local tool = char:FindFirstChildOfClass("Tool")
    if tool then return tool end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
    if hum and bp then
        local pick
        if State.selectedShovel then
            pick = bp:FindFirstChild(State.selectedShovel)
        end
        pick = pick or bp:FindFirstChildOfClass("Tool")
        if pick then
            hum:EquipTool(pick)
            task.wait(0.1)
            return char:FindFirstChildOfClass("Tool")
        end
    end
    return nil
end

local function getGui()
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    return pg and pg:FindFirstChild("Gui")
end

local function backpackFull()
    local ok, res = pcall(function()
        return getGui().Popups.BackpackFull.Visible == true
    end)
    return ok and res
end

local function readNumber(path)
    local ok, res = pcall(function()
        local obj = getGui()
        for _, name in ipairs(path) do
            obj = obj[name]
        end
        return tonumber((obj.Text:gsub("[^%d]", "")))
    end)
    return ok and res or nil
end

local function sellAndReturn()
    if selling then return end
    local hrp = getHRP()
    if not hrp then return end
    selling = true
    local saved = hrp.CFrame
    hrp.CFrame = SELL_POS
    task.wait(0.1)
    pcall(function() AreaSell:FireServer() end)
    task.wait(0.2)
    hrp = getHRP()
    if hrp then hrp.CFrame = saved end
    selling = false
end

local rainbowColor
do
    local rc = ChestsFolder and ChestsFolder:FindFirstChild("Rainbow Chest")
    local part = rc and rc:FindFirstChildWhichIsA("BasePart")
    rainbowColor = part and part.BrickColor.Color
end

local function isChest(block)
    return block:FindFirstChild("Chest") ~= nil or block:FindFirstChild("BasicChest") ~= nil
end

local function chestNames(block)
    local names = {block.Name:lower()}
    for _, key in ipairs({"Chest", "BasicChest", "Mat"}) do
        local child = block:FindFirstChild(key)
        if child then
            table.insert(names, child.Name:lower())
            if child:IsA("ValueBase") and type(child.Value) == "string" then
                table.insert(names, child.Value:lower())
            end
        end
    end
    return names
end

local function isExcluded(block)
    if rainbowColor and excludedChests["Rainbow Chest"] and block.BrickColor.Color == rainbowColor then
        return true
    end
    local names = chestNames(block)
    for chestName, excluded in pairs(excludedChests) do
        if excluded then
            local needle = chestName:lower()
            for _, n in ipairs(names) do
                if string.find(n, needle, 1, true) then
                    return true
                end
            end
        end
    end
    return false
end

local function inArea(block)
    local p = block.Position
    return p.X > AREA.minX and p.X < AREA.maxX and p.Z > AREA.minZ and p.Z < AREA.maxZ
end

local function findTarget()
    local hrp = getHRP()
    local origin = hrp and hrp.Position or Vector3.zero
    local best, bestDist = nil, math.huge
    local now = tick()
    for _, block in ipairs(SandBlocks:GetChildren()) do
        if block:IsA("BasePart") and isChest(block) then
            local bl = blacklist[block]
            if not (bl and now < bl) and not isExcluded(block) and (not State.limitArea or inArea(block)) then
                local d = (block.Position - origin).Magnitude
                if d < bestDist then
                    best, bestDist = block, d
                end
            end
        end
    end
    return best
end

local function fireDig(tool, block)
    local remote = tool and tool:FindFirstChild("RemoteClick")
    if remote and block and block.Parent then
        pcall(function() remote:FireServer(block) end)
        return true
    end
    return false
end

local function digChest(block)
    local startTime = tick()
    block.CanCollide = false
    while State.autoFarm and block.Parent and tick() - startTime < State.digTimeout do
        if State.autoSell and backpackFull() then
            sellAndReturn()
        end
        local hrp = getHRP()
        if not hrp then break end
        hrp.CFrame = block.CFrame
        hrp.AssemblyLinearVelocity = Vector3.zero
        local tool = getTool()
        if tool then
            fireDig(tool, block)
        end
        task.wait(State.digDelay)
    end
    if not block.Parent then
        State.chestsFarmed += 1
        return true
    end
    blacklist[block] = tick() + 15
    return false
end

task.spawn(function()
    while true do
        if State.autoFarm then
            State.status = "Mencari chest..."
            local target = findTarget()
            if target then
                State.status = "Farming chest"
                digChest(target)
            else
                State.status = "Tidak ada chest"
                task.wait(0.5)
            end
            task.wait()
        else
            task.wait(0.3)
        end
    end
end)

task.spawn(function()
    while true do
        if State.autoDig and not State.autoFarm then
            local tool = getTool()
            local cfg = tool and tool:FindFirstChild("Configurations")
            local hrp = getHRP()
            if cfg and hrp and cfg:FindFirstChild("ToolType") and cfg.ToolType.Value ~= "Bomb" then
                local range = cfg.DigRange.Value
                local best, bestDist = nil, range
                for _, b in ipairs(SandBlocks:GetChildren()) do
                    if b:IsA("BasePart") and b:FindFirstChild("Health") and not b:FindFirstChild("Rock") then
                        local d = (b.Position - hrp.Position).Magnitude
                        if d <= bestDist then
                            best, bestDist = b, d
                        end
                    end
                end
                if best then
                    fireDig(tool, best)
                end
                local delay = cfg.AttackLength.Value
                if quickDig then delay = delay / 2 end
                task.wait(delay + 0.05)
            else
                task.wait(0.5)
            end
        else
            task.wait(0.3)
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(1)
        if State.autoSell and not State.autoFarm and backpackFull() then
            sellAndReturn()
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(1)
        if State.autoRebirth then
            local coins = readNumber({"Buttons", "Coins", "Amount"})
            local needed = readNumber({"Rebirth", "Needed", "Coins", "Amount"})
            if coins and needed and coins >= needed then
                pcall(function() RebirthEvent:FireServer() end)
                local t = tick()
                repeat
                    task.wait(0.1)
                    local ok, vis = pcall(function() return getGui().Popups.GiveReward.Visible end)
                until (ok and vis) or tick() - t > 3
                pcall(function() getGui().Popups.GiveReward.Visible = false end)
                notify("Auto Rebirth", "Rebirth berhasil")
                task.wait(1)
            end
        end
    end
end)

LocalPlayer.Idled:Connect(function()
    if State.antiAfk then
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
    end
end)

-- Always use selected shovel
local function equippedShovelName()
    local char = LocalPlayer.Character
    local tool = char and char:FindFirstChildOfClass("Tool")
    return tool and tool.Name or nil
end

local function isShovelOwned(name)
    if not CheckIfOwned then return false end
    local ok, res = pcall(function() return CheckIfOwned:InvokeServer(name) end)
    return ok and res == true
end

task.spawn(function()
    while true do
        task.wait(2)
        if State.alwaysShovel and State.selectedShovel and State.selectedShovel ~= "None" then
            if equippedShovelName() ~= State.selectedShovel then
                local name = State.selectedShovel
                if isShovelOwned(name) then
                    if EquipShovel then
                        pcall(function() EquipShovel:FireServer(name) end)
                    end
                else
                    local shovel = Shovels:FindFirstChild(name)
                    local price = shovel and shovel:FindFirstChild("Price")
                    local stats = getStats()
                    local coins = stats and stats[STAT_INDEX.coins]
                    if price and coins and coins >= price.Value and Checkout then
                        pcall(function() Checkout:FireServer(name) end)
                    end
                end
            end
        end
    end
end)

-- Crates
local function crateCost(crate)
    if crate:FindFirstChild("CoinsCost") then
        return "coins", crate.CoinsCost.Value
    elseif crate:FindFirstChild("RubyCost") then
        return "rubies", crate.RubyCost.Value
    elseif crate:FindFirstChild("CandyCost") then
        return "candy", crate.CandyCost.Value
    end
    return nil, nil
end

local crateOptions = {}
if CratesFolder then
    for _, c in ipairs(CratesFolder:GetChildren()) do
        table.insert(crateOptions, c.Name)
    end
    table.sort(crateOptions)
end
local openOptions = {"All"}
for _, n in ipairs(crateOptions) do
    table.insert(openOptions, n)
end
State.buyCrate = crateOptions[1]

task.spawn(function()
    while true do
        task.wait(1)
        if State.autoBuyCrate and BuyCrate and CratesFolder and State.buyCrate then
            local crate = CratesFolder:FindFirstChild(State.buyCrate)
            if crate then
                local currency, cost = crateCost(crate)
                local stats = getStats()
                if currency and cost and stats then
                    local balance = stats[STAT_INDEX[currency]]
                    local total = cost * State.buyQty
                    if balance and balance >= total then
                        pcall(function()
                            BuyCrate:FireServer(crate, LocalPlayer.Name, State.buyQty)
                        end)
                        State.cratesBought += State.buyQty
                        task.wait(0.5)
                    end
                end
            end
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(0.5)
        if State.autoOpenCrate and SendOpenCrate and CratesFolder then
            local stats = getStats()
            if stats then
                local opened = false
                for _, name in ipairs(crateOptions) do
                    if not State.autoOpenCrate then break end
                    if State.openCrate == "All" or State.openCrate == name then
                        local idx = CRATE_INDEX[name]
                        local owned = idx and stats[idx] or 0
                        local crate = CratesFolder:FindFirstChild(name)
                        if crate and type(owned) == "number" and owned > 0 then
                            pcall(function() SendOpenCrate:FireServer(crate) end)
                            State.cratesOpened += 1
                            opened = true
                            task.wait(State.openDelay)
                            stats = getStats() or stats
                        end
                    end
                end
                if not opened then
                    task.wait(1)
                end
            end
        end
    end
end)

local shovelOptions = {}
for _, s in ipairs(Shovels:GetChildren()) do
    table.insert(shovelOptions, s.Name)
end
table.sort(shovelOptions)

local defaultShovel
do
    local char = LocalPlayer.Character
    local tool = char and char:FindFirstChildOfClass("Tool")
    if tool and table.find(shovelOptions, tool.Name) then
        defaultShovel = tool.Name
    else
        defaultShovel = shovelOptions[1] or "None"
    end
end
State.selectedShovel = defaultShovel

-- ===================== UI =====================
MainTab:CreateSection("Auto Farm")

local _, _, _, statusCtrl = MainTab:CreateParagraph({
    Title = "Status",
    Content = "Idle"
})

MainTab:CreateToggle({
    Name = "Auto Farm Chest",
    Description = "Teleport ke chest terdekat lalu gali otomatis",
    Flag = "THS_AutoFarm",
    CurrentValue = false,
    Callback = function(v)
        State.autoFarm = v
        if not v then
            State.status = "Idle"
            local hrp = getHRP()
            if hrp then hrp.CFrame = SELL_POS end
        end
        notify("Auto Farm", v and "Enabled" or "Disabled")
    end
})

MainTab:CreateToggle({
    Name = "Auto Dig (Terdekat)",
    Description = "Gali blok dalam jangkauan tool tanpa teleport",
    Flag = "THS_AutoDig",
    CurrentValue = false,
    Callback = function(v)
        State.autoDig = v
        notify("Auto Dig", v and "Enabled" or "Disabled")
    end
})

MainTab:CreateToggle({
    Name = "Auto Sell",
    Description = "Jual otomatis saat backpack penuh",
    Flag = "THS_AutoSell",
    CurrentValue = true,
    Callback = function(v)
        State.autoSell = v
    end
})

MainTab:CreateToggle({
    Name = "Auto Rebirth",
    Description = "Rebirth otomatis saat koin cukup",
    Flag = "THS_AutoRebirth",
    CurrentValue = false,
    Callback = function(v)
        State.autoRebirth = v
        notify("Auto Rebirth", v and "Enabled" or "Disabled")
    end
})

MainTab:CreateToggle({
    Name = "Limit Start Area",
    Description = "Hanya farm chest di area awal",
    Flag = "THS_LimitArea",
    CurrentValue = true,
    Callback = function(v)
        State.limitArea = v
    end
})

MainTab:CreateToggle({
    Name = "Anti AFK",
    Flag = "THS_AntiAfk",
    CurrentValue = false,
    Callback = function(v)
        State.antiAfk = v
    end
})

MainTab:CreateSection("Settings")

MainTab:CreateSlider({
    Name = "Dig Delay",
    Description = "Jeda antar serangan saat farm",
    Range = {0.01, 0.5},
    Increment = 0.01,
    Suffix = " s",
    Flag = "THS_DigDelay",
    CurrentValue = 0.05,
    Callback = function(v)
        State.digDelay = v
    end
})

MainTab:CreateSlider({
    Name = "Dig Timeout",
    Description = "Lewati chest jika tidak hancur dalam waktu ini",
    Range = {3, 30},
    Increment = 1,
    Suffix = " s",
    Flag = "THS_DigTimeout",
    CurrentValue = 10,
    Callback = function(v)
        State.digTimeout = v
    end
})

MainTab:CreateSection("Shovel")

local shovelDropdown = MainTab:CreateDropdown({
    Name = "Select Shovel",
    Options = shovelOptions,
    CurrentOption = defaultShovel,
    Flag = "THS_Shovel",
    Callback = function(option)
        if type(option) == "table" then option = option[1] end
        if not option then return end
        State.selectedShovel = option
    end
})

do
    local saved = shovelDropdown.State()
    if type(saved) == "string" and table.find(shovelOptions, saved) then
        State.selectedShovel = saved
    else
        shovelDropdown:Set(defaultShovel)
        State.selectedShovel = defaultShovel
    end
end

MainTab:CreateToggle({
    Name = "Always Use This Shovel",
    Description = "Cek tiap 2 detik: equip jika punya, beli jika koin cukup",
    Flag = "THS_AlwaysShovel",
    CurrentValue = false,
    Callback = function(v)
        State.alwaysShovel = v
        notify("Always Shovel", v and ("ON: " .. tostring(State.selectedShovel)) or "OFF")
    end
})

MainTab:CreateButton({
    Name = "Equip Selected Shovel",
    Interact = "Equip",
    Callback = function()
        if EquipShovel and State.selectedShovel then
            pcall(function() EquipShovel:FireServer(State.selectedShovel) end)
            notify("Shovel", "Equip: " .. State.selectedShovel)
        end
    end
})

MainTab:CreateButton({
    Name = "Buy Selected Shovel",
    Interact = "Buy",
    Callback = function()
        if Checkout and State.selectedShovel then
            pcall(function() Checkout:FireServer(State.selectedShovel) end)
            notify("Shovel", "Checkout: " .. State.selectedShovel)
        end
    end
})

MainTab:CreateSection("Teleport")

MainTab:CreateButton({
    Name = "Teleport to Sell",
    Interact = "Teleport",
    Callback = function()
        local hrp = getHRP()
        if hrp then hrp.CFrame = SELL_POS end
    end
})

MainTab:CreateButton({
    Name = "Sell Now",
    Interact = "Sell",
    Callback = function()
        task.spawn(sellAndReturn)
    end
})

MainTab:CreateButton({
    Name = "Rebirth Now",
    Interact = "Rebirth",
    Callback = function()
        pcall(function() RebirthEvent:FireServer() end)
    end
})

MainTab:CreateButton({
    Name = "Reset Blacklist",
    Interact = "Reset",
    Callback = function()
        blacklist = {}
        notify("Blacklist", "Direset")
    end
})

-- Crates tab
CratesTab:CreateSection({Name = "Auto Buy Crate", Description = "Beli crate otomatis jika mata uang cukup"})

local buyDropdown = CratesTab:CreateDropdown({
    Name = "Crate to Buy",
    Options = crateOptions,
    CurrentOption = crateOptions[1],
    Flag = "THS_BuyCrate",
    Callback = function(option)
        if type(option) == "table" then option = option[1] end
        if option then State.buyCrate = option end
    end
})

do
    local saved = buyDropdown.State()
    if type(saved) == "string" and table.find(crateOptions, saved) then
        State.buyCrate = saved
    end
end

CratesTab:CreateSlider({
    Name = "Buy Quantity",
    Range = {1, 100},
    Increment = 1,
    Flag = "THS_BuyQty",
    CurrentValue = 1,
    Callback = function(v)
        State.buyQty = v
    end
})

CratesTab:CreateToggle({
    Name = "Auto Buy Crate",
    Flag = "THS_AutoBuyCrate",
    CurrentValue = false,
    Callback = function(v)
        State.autoBuyCrate = v
        notify("Auto Buy Crate", v and "Enabled" or "Disabled")
    end
})

CratesTab:CreateButton({
    Name = "Buy Once",
    Interact = "Buy",
    Callback = function()
        if BuyCrate and CratesFolder and State.buyCrate then
            local crate = CratesFolder:FindFirstChild(State.buyCrate)
            if crate then
                pcall(function()
                    BuyCrate:FireServer(crate, LocalPlayer.Name, State.buyQty)
                end)
            end
        end
    end
})

CratesTab:CreateSection({Name = "Auto Open Crate", Description = "Buka crate yang dimiliki di inventory"})

local openDropdown = CratesTab:CreateDropdown({
    Name = "Crate to Open",
    Options = openOptions,
    CurrentOption = "All",
    Flag = "THS_OpenCrate",
    Callback = function(option)
        if type(option) == "table" then option = option[1] end
        if option then State.openCrate = option end
    end
})

do
    local saved = openDropdown.State()
    if type(saved) == "string" and table.find(openOptions, saved) then
        State.openCrate = saved
    end
end

CratesTab:CreateSlider({
    Name = "Open Delay",
    Description = "Jeda antar buka crate (animasi spinner ~9 detik)",
    Range = {1, 15},
    Increment = 1,
    Suffix = " s",
    Flag = "THS_OpenDelay",
    CurrentValue = 10,
    Callback = function(v)
        State.openDelay = v
    end
})

CratesTab:CreateToggle({
    Name = "Auto Open Crate",
    Flag = "THS_AutoOpenCrate",
    CurrentValue = false,
    Callback = function(v)
        State.autoOpenCrate = v
        notify("Auto Open Crate", v and "Enabled" or "Disabled")
    end
})

CratesTab:CreateButton({
    Name = "Open Once",
    Interact = "Open",
    Callback = function()
        if SendOpenCrate and CratesFolder then
            local name = State.openCrate == "All" and State.buyCrate or State.openCrate
            local crate = name and CratesFolder:FindFirstChild(name)
            if crate then
                pcall(function() SendOpenCrate:FireServer(crate) end)
            end
        end
    end
})

-- Chests tab
local function addChestToggles(folder)
    if not folder then return end
    for _, chest in ipairs(folder:GetChildren()) do
        if excludedChests[chest.Name] == nil then
            local default = chest.Name:lower():find("rainbow") ~= nil
            excludedChests[chest.Name] = default
            local t = ChestsTab:CreateToggle({
                Name = "Skip " .. chest.Name,
                Flag = "THS_Skip_" .. chest.Name,
                CurrentValue = default,
                Callback = function(v)
                    excludedChests[chest.Name] = v
                end
            })
            excludedChests[chest.Name] = t.State()
        end
    end
end

ChestsTab:CreateSection({Name = "Exclude Chests", Description = "ON = chest dilewati saat Auto Farm"})
addChestToggles(ChestsFolder)
addChestToggles(OldChestsFolder)

task.spawn(function()
    while true do
        task.wait(1)
        local coins = readNumber({"Buttons", "Coins", "Amount"}) or 0
        local text = string.format(
            "State: %s\nChest digali: %d\nCrate dibeli: %d\nCrate dibuka: %d\nKoin: %d\nQuick Dig: %s",
            State.status,
            State.chestsFarmed,
            State.cratesBought,
            State.cratesOpened,
            coins,
            quickDig and "Ya" or "Tidak"
        )
        pcall(function() statusCtrl:Set(nil, text) end)
    end
end)

notify("Treasure Hunt", "Script loaded", 3)

local Universal = loadstring(game:HttpGet("https://raw.githubusercontent.com/BIANTCA/Script/refs/heads/main/universal.lua"))()
Universal.CreateUniversalTab(Window, JendralHans, Players, RunService)
