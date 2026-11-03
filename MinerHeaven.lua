local Tumblr = loadstring(game:HttpGet("https://pastebin.com/raw/ECe9auLu"))()

local Window = Tumblr:Init({
    Name = "Miner Heaven",
    Subtitle = "by GANTJENK",
    FolderName = "TumblrConfigs",
    FileName = tostring(game.GameId) .. ".json"
})

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")

-- Player
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local hrp = character:WaitForChild("HumanoidRootPart")

-- Main tab
local MainTab = Window:CreateTab("Main", 4483362458)
_G.MainTab = MainTab

local Boxes = Workspace:WaitForChild("Boxes")
local autoBoxes = false
local boxDelay = 0.2   -- jeda tiap box
local idleDelay = 0.1  -- jeda saat folder kosong

MainTab:CreateSection("Main Menu")

-- Ambil part tujuan dari Part / MeshPart / Model
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
            Tumblr:Notify({
                Title = "Teleport",
                Content = "Workspace.Market.Internal tidak ditemukan",
                Duration = 3
            })
        end
    end
})

MainTab:CreateButton({
    Name = "TP to Base",
    Interact = "Teleport",
    Callback = function()
        local tycoons = Workspace:FindFirstChild("Tycoons")
        if not tycoons then
            Tumblr:Notify({
                Title = "Teleport",
                Content = "Workspace.Tycoons tidak ditemukan",
                Duration = 3
            })
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

                Tumblr:Notify({
                    Title = "Teleport",
                    Content = "Teleport to base",
                    Duration = 2
                })
                return
            end
        end

        Tumblr:Notify({
            Title = "Teleport",
            Content = "Base kamu tidak ditemukan (belum punya Factory?)",
            Duration = 3
        })
    end
})

-- Boost Ore
local CELL_NAME = "Anguished Guardian of the Gate" -- nama cell kamu (jika tidak ketemu, cari Lava otomatis)
local BOOST_INTERVAL = 10                           -- jeda tiap pengulangan (detik)
local BEAM_GROW = Vector3.new(100, 100, 100)       -- tambahan ukuran part "Upgrade"
local DROP_OFFSET = CFrame.new(0, 10, 0)           -- posisi ore di atas Lava

local enlargedBeams = setmetatable({}, { __mode = "k" })

-- Cari Factory milik user (Workspace.Tycoons.FactoryX dengan Owner = username)
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

-- Perbesar part "Upgrade" (hanya sekali per part). Return: jumlah part yang baru diperbesar
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

-- Satu putaran boost. Return: true / false, pesan error
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

    local target = lava.CFrame * DROP_OFFSET

    for _, ore in ipairs(droppedFolder:GetChildren()) do
        if ore:IsA("BasePart") then
            ore.CFrame = target
        elseif ore:IsA("Model") then
            ore:PivotTo(target)
        end
    end

    return true
end

local boostRunning = false
local boostSession = 0
local boostButton

boostButton = MainTab:CreateButton({
    Name = "Boost Ore",
    Interact = "Start",
    Callback = function()
        boostRunning = not boostRunning
        boostSession += 1

        if not boostRunning then
            boostButton:Set("Interact", "Start")
            Tumblr:Notify({
                Title = "Boost Ore",
                Content = "Stopped",
                Duration = 2
            })
            return
        end

        local factory = getMyFactory()
        if not factory then
            boostRunning = false
            Tumblr:Notify({
                Title = "Boost Ore",
                Content = "Factory milikmu tidak ditemukan",
                Duration = 3
            })
            return
        end

        boostButton:Set("Interact", "Stop")
        Tumblr:Notify({
            Title = "Boost Ore",
            Content = "Running on " .. factory.Name,
            Duration = 2
        })

        local mySession = boostSession

        task.spawn(function()
            while boostRunning and mySession == boostSession do
                local ok, success, message = pcall(boostOre)

                if not ok then
                    warn("[Boost Ore]", success)
                elseif not success then
                    boostRunning = false
                    boostButton:Set("Interact", "Start")
                    Tumblr:Notify({
                        Title = "Boost Ore",
                        Content = message,
                        Duration = 3
                    })
                    return
                end

                task.wait(BOOST_INTERVAL)
            end
        end)
    end
})

-- Teleport tab
local TeleportTab = Window:CreateTab("Teleport", 4483362458)
local Map = Workspace:WaitForChild("Map")

local function createTeleportButton(model)
    TeleportTab:CreateButton({
        Name = "TP to " .. model.Name,
        Interact = "Teleport",
        Callback = function()
            pcall(function()
                local part = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
                if part then
                    hrp.CFrame = part.CFrame + Vector3.new(0, 3, 0)
                end
            end)
        end
    })
end

for _, child in ipairs(Map:GetChildren()) do
    if child:IsA("Model") then
        createTeleportButton(child)
    end
end

TeleportTab:CreateButton({
    Name = "🔄 Refresh Teleport List",
    Interact = "Refresh",
    Callback = function()
        TeleportTab:CreateSection("Updated Models")
        for _, child in ipairs(Map:GetChildren()) do
            if child:IsA("Model") then
                createTeleportButton(child)
            end
        end
    end
})

-- Universal tab (script eksternal)
local Universal = loadstring(game:HttpGet("https://pastebin.com/raw/436invAL"))()
Universal.CreateUniversalTab(Window, Tumblr, Players, RunService)
