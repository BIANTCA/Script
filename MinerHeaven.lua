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

local CELL_NAME = "Anguished Guardian of the Gate"
local BEAM_GROW = Vector3.new(100, 100, 100)
local DROP_OFFSET = CFrame.new(0, 10, 0)

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
                Tumblr:Notify({
                    Title = "Boost Ore",
                    Content = "Terjadi kesalahan: " .. tostring(success),
                    Duration = 3
                })
            elseif not success then
                Tumblr:Notify({
                    Title = "Boost Ore",
                    Content = message,
                    Duration = 3
                })
            else
                Tumblr:Notify({
                    Title = "Boost Ore",
                    Content = "Berhasil mengumpulkan ore!",
                    Duration = 2
                })
            end

            task.wait(1)
            boostButton:Set("Interact", "Boost")
        end)
    end
})

-- Universal tab (script eksternal)
local Universal = loadstring(game:HttpGet("https://pastebin.com/raw/436invAL"))()
Universal.CreateUniversalTab(Window, Tumblr, Players, RunService)
