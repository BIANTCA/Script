local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
 Name = "Brainrot Army",
 LoadingTitle = "Rayfield Interface",
 LoadingSubtitle = "by GANTJENK",
 ConfigurationSaving = { Enabled = false }
})

local MainTab = Window:CreateTab("Main", 4483362458)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local plr = Players.LocalPlayer

local autoFarm = false
local farmDelay = 0.5

MainTab:CreateSection("Automatically")
MainTab:CreateToggle({
 Name = "Auto Rebirths",
 CurrentValue = false,
 Callback = function(value)
  autoFarm = value
  if value then
   task.spawn(function()
    while autoFarm do
     local money = 0
     local prevTier = 0

     if plr:FindFirstChild("leaderstats") and plr.leaderstats:FindFirstChild("Cash") and plr.leaderstats.Cash:IsA("NumberValue") then
      money = plr.leaderstats.Cash.Value
     end

     if money <= 100000000 then
      pcall(function()
       ReplicatedStorage.Remotes.CrateDestroyed:FireServer(1e70)
      end)
     end

     if plr:FindFirstChild("SpawnTier") and plr.SpawnTier:IsA("IntValue") then
      prevTier = plr.SpawnTier.Value
     end

     pcall(function()
      ReplicatedStorage.Remotes.UpgradeSpawnTier:FireServer()
     end)
     task.wait(farmDelay)

     local newTier = 0
     if plr:FindFirstChild("SpawnTier") and plr.SpawnTier:IsA("IntValue") then
      newTier = plr.SpawnTier.Value
     end

     if newTier <= prevTier then
      if plr:FindFirstChild("Rebirths") and plr.Rebirths:IsA("IntValue") then
       if plr.Rebirths.Value >= 8 then
        autoFarm = false
        Rayfield:Notify({
         Title = "AutoFarm",
         Content = "Max Rebirths reached! AutoFarm turned off.",
         Duration = 4,
         Image = 4483362458
        })
        break
       end
      end

      pcall(function()
       ReplicatedStorage.Remotes.BuyBrainrot:FireServer(3)
      end)

      pcall(function()
       ReplicatedStorage.Remotes.Rebirth:FireServer()
      end)

      task.wait(3)
     end
    end
   end)
  end
 end
})

MainTab:CreateSection("Manually")
MainTab:CreateButton({
 Name = "Inf Money",
 Callback = function()
  pcall(function()
   ReplicatedStorage.Remotes.CrateDestroyed:FireServer(1e70)
  end)
 end
})

MainTab:CreateButton({
 Name = "Upgrade Spawn Tier",
 Callback = function()
  pcall(function()
   ReplicatedStorage.Remotes.UpgradeSpawnTier:FireServer()
  end)
 end
})

MainTab:CreateButton({
 Name = "Rebirth",
 Callback = function()
  pcall(function()
   ReplicatedStorage.Remotes.Rebirth:FireServer()
  end)
 end
})

MainTab:CreateButton({
 Name = "Buy Brainrot",
 Callback = function()
  pcall(function()
   ReplicatedStorage.Remotes.BuyBrainrot:FireServer(3)
  end)
 end
})
