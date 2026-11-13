local luaCxre = loadstring(game:HttpGet("https://pastebin.com/raw/i1hqRFbq"))()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local MarketplaceService = game:GetService("MarketplaceService")
local VirtualUser = game:GetService("VirtualUser")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

local Window = luaCxre:Init({
    Name = "Treasure Hunt Simulator",
    Subtitle = "By luaCxre",
    FolderName = "luaCxreConfigs",
    FileName = "TreasureHunt.json",
    LoadedNotification = false
})

local MainTab = Window:CreateTab("Main", 4483362458)
_G.MainTab = MainTab
local ChestsTab = Window:CreateTab("Chests", 4483362458)

local Events = ReplicatedStorage:WaitForChild("Events")
local AreaSell = Events:WaitForChild("AreaSell")
local RebirthEvent = Events:WaitForChild("Rebirth")
local EquipShovel = Events:FindFirstChild("EquipShovel")
local Checkout = Events:FindFirstChild("Checkout")
local SandBlocks = Workspace:WaitForChild("SandBlocks")
local Shovels = ReplicatedStorage:WaitForChild("Shovels")
local ChestsFolder = ReplicatedStorage:FindFirstChild("Chests")
local OldChestsFolder = ReplicatedStorage:FindFirstChild("OldChests")

local QUICK_DIG_ID = 3831582
local SELL_POS = CFrame.new(3, 10, -160)
local AREA = {minX = -40, maxX = 20, minZ = -235, maxZ = -175}

local State = {
    autoFarm = false,
    autoDig = false,
    autoSell = true,
    autoRebirth = false,
    antiAfk = false,
    limitArea = true,
    digDelay = 0.05,
    digTimeout = 10,
    selectedShovel = nil,
    chestsFarmed = 0,
    status = "Idle",
}

local excludedChests = {}
local blacklist = {}
local selling = false
local quickDig = false
local uiReady = false

local function notify(title, content, duration)
    pcall(function()
        luaCxre:Notify({Title = title, Content = content, Duration = duration or 2})
    end)
end

pcall(function()
    quickDig = MarketplaceService:UserOwnsGamePassAsync(LocalPlayer.UserId, QUICK_DIG_ID)
end)

local function getHRP()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild("HumanoidRootPart")
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
            State.status = "Searching for chests..."
            local target = findTarget()
            if target then
                State.status = "Farming chest"
                digChest(target)
            else
                State.status = "No chests found"
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
                notify("Auto Rebirth", "Rebirth successful")
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

local shovelOptions = {}
for _, s in ipairs(Shovels:GetChildren()) do
    table.insert(shovelOptions, s.Name)
end
table.sort(shovelOptions)

do
    local char = LocalPlayer.Character
    local tool = char and char:FindFirstChildOfClass("Tool")
    if tool and table.find(shovelOptions, tool.Name) then
        State.selectedShovel = tool.Name
    else
        State.selectedShovel = shovelOptions[1] or "None"
    end
end

MainTab:CreateSection({Name = "Auto Farm", Description = "Automated chest farming"})

local _, _, _, statusPara = MainTab:CreateParagraph({
    Title = "Status",
    Content = "Idle"
})

MainTab:CreateToggle({
    Name = "Auto Farm Chest",
    Description = "Teleports to the nearest chest and digs it",
    CurrentValue = false,
    Callback = function(v)
        State.autoFarm = v
        if not v then
            State.status = "Idle"
            local hrp = getHRP()
            if hrp then hrp.CFrame = SELL_POS end
        end
        if uiReady then
            notify("Auto Farm", v and "Enabled" or "Disabled")
        end
    end
})

MainTab:CreateToggle({
    Name = "Auto Dig (Nearest)",
    Description = "Digs the nearest block in range",
    CurrentValue = false,
    Callback = function(v)
        State.autoDig = v
        if uiReady then
            notify("Auto Dig", v and "Enabled" or "Disabled")
        end
    end
})

MainTab:CreateToggle({
    Name = "Auto Sell",
    Description = "Sells automatically when the backpack is full",
    CurrentValue = true,
    Callback = function(v)
        State.autoSell = v
    end
})

MainTab:CreateToggle({
    Name = "Auto Rebirth",
    Description = "Rebirths when you have enough coins",
    CurrentValue = false,
    Callback = function(v)
        State.autoRebirth = v
        if uiReady then
            notify("Auto Rebirth", v and "Enabled" or "Disabled")
        end
    end
})

MainTab:CreateToggle({
    Name = "Limit Start Area",
    Description = "Only farm chests inside the starting area",
    CurrentValue = true,
    Callback = function(v)
        State.limitArea = v
    end
})

MainTab:CreateToggle({
    Name = "Anti AFK",
    CurrentValue = false,
    Callback = function(v)
        State.antiAfk = v
    end
})

MainTab:CreateSection({Name = "Settings"})

MainTab:CreateSlider({
    Name = "Dig Delay",
    Range = {0.01, 0.5},
    Increment = 0.01,
    Suffix = " s",
    CurrentValue = 0.05,
    Callback = function(v)
        State.digDelay = v
    end
})

MainTab:CreateSlider({
    Name = "Dig Timeout",
    Range = {3, 30},
    Increment = 1,
    Suffix = " s",
    CurrentValue = 10,
    Callback = function(v)
        State.digTimeout = v
    end
})

MainTab:CreateSection({Name = "Shovel"})

MainTab:CreateDropdown({
    Name = "Select Shovel",
    Options = shovelOptions,
    CurrentOption = State.selectedShovel,
    Callback = function(option)
        if type(option) == "table" then option = option[1] end
        if not option then return end
        State.selectedShovel = option
    end
})

MainTab:CreateButton({
    Name = "Equip Selected Shovel",
    Interact = "Equip",
    Callback = function()
        if EquipShovel and State.selectedShovel then
            pcall(function() EquipShovel:FireServer(State.selectedShovel) end)
            notify("Shovel", "Equipped: " .. State.selectedShovel)
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

MainTab:CreateSection({Name = "Teleport"})

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
        notify("Blacklist", "Blacklist cleared")
    end
})

local function addChestToggles(folder)
    if not folder then return end
    for _, chest in ipairs(folder:GetChildren()) do
        if excludedChests[chest.Name] == nil then
            local default = chest.Name:lower():find("rainbow") ~= nil
            excludedChests[chest.Name] = default
            ChestsTab:CreateToggle({
                Name = "Skip " .. chest.Name,
                CurrentValue = default,
                Callback = function(v)
                    excludedChests[chest.Name] = v
                    if uiReady then
                        notify("Chest Filter", chest.Name .. (v and " will be skipped" or " will be farmed"))
                    end
                end
            })
        end
    end
end

ChestsTab:CreateSection({Name = "Exclude Chests", Description = "Enabled = skipped"})
addChestToggles(ChestsFolder)
addChestToggles(OldChestsFolder)

local function setStatus(text)
    pcall(function() statusPara:Set("Status", text) end)
end

task.spawn(function()
    while true do
        task.wait(1)
        local coins = readNumber({"Buttons", "Coins", "Amount"}) or 0
        setStatus(string.format(
            "State: %s\nChests dug: %d\nCoins: %d\nQuick Dig: %s",
            State.status,
            State.chestsFarmed,
            coins,
            quickDig and "Yes" or "No"
        ))
    end
end)

task.delay(1, function()
    uiReady = true
end)

notify("Treasure Hunt", "Script loaded", 3)
