-- Teleport GUI (versi bersih / deobfuscated)
-- Perubahan dari script asli:
--   * Auto Teleport Boxes: kunjungi SEMUA isi folder Boxes (Part/MeshPart/Model)
--   * Tombol "TP to Market Internal" di bawah toggle

local Rayfield = loadstring(game:HttpGet("https://pastebin.com/raw/ECe9auLu"))()

local Window = Rayfield:CreateWindow({
    Name = "Teleport GUI",
    LoadingTitle = "Rayfield Interface",
    LoadingSubtitle = "by GANTJENK",
    ConfigurationSaving = { Enabled = false }
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
    Name = "TP to Market Internal",
    Callback = function()
        local market = Workspace:FindFirstChild("Market")
        local internal = market and market:FindFirstChild("Internal")
        local part = internal and getTargetPart(internal)

        if part then
            hrp.CFrame = part.CFrame + Vector3.new(0, 3, 0)
        else
            Rayfield:Notify({
                Title = "Teleport",
                Content = "Workspace.Map.Market.Internal tidak ditemukan",
                Duration = 3
            })
        end
    end
})

-- Teleport tab
local TeleportTab = Window:CreateTab("Teleport", 4483362458)
local Map = Workspace:WaitForChild("Map")

local function createTeleportButton(model)
    TeleportTab:CreateButton({
        Name = "TP to " .. model.Name,
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
local Universal = loadstring(game:HttpGet("https://raw.githubusercontent.com/BIANTCA/Script/refs/heads/main/universal.lua"))()
Universal.CreateUniversalTab(Window, Rayfield, Players, RunService)
